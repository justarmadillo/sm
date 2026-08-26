/// Builds the scheduler safety metrics from live collection state.
///
/// These are not product analytics. A scheduler can pass every unit test and
/// still fail slowly: low-priority topics quietly vanish, a priority band ends
/// up with the worst retention, or today's queue looks clean only because
/// tomorrow's is growing. None of that is visible from inside a single day, so
/// the numbers that would expose it are treated as part of correctness and are
/// computed here from the same rows the queue itself reads.
///
/// Everything is derived. Nothing in this file writes, and no metric is
/// allowed to become an input to a scheduling decision — a measurement that
/// steers the thing it measures stops being a measurement.
library;

import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/scheduler_metrics.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../ports/repositories.dart';
import '../queue/queue_handlers.dart';
import '../scheduling/scheduling_context.dart';

/// How far back the activity window reaches, in study days.
const int kMetricsActivityWindowDays = 30;

/// Assembles [SchedulerMetricsSnapshot] from repositories.
final class SchedulerMetricsQuery {
  const SchedulerMetricsQuery({
    required LearningRepository learning,
    required SchedulingContext context,
    required QueueHandlers queue,
  }) : _learning = learning,
       _context = context,
       _queue = queue;

  final LearningRepository _learning;
  final SchedulingContext _context;
  final QueueHandlers _queue;

  Future<SchedulerMetricsSnapshot> collect() async {
    final StudyDayCalendar calendar = await _context.calendar();
    final StudyDay today = await _context.today();
    final PriorityScale scale = await _context.priorityScale();
    final StudyDay windowStart = today.addDays(
      -(kMetricsActivityWindowDays - 1),
    );

    final List<QueueCandidate> candidates = await _queue.loadCandidates(today);
    final List<DueMetricSample> due = <DueMetricSample>[];
    final List<BranchWorkloadMetricSample> workload =
        <BranchWorkloadMetricSample>[];
    final Map<String, Map<ElementType, int>> branchCounts =
        <String, Map<ElementType, int>>{};
    final List<TopicEncounterMetricSample> topicPolicies =
        <TopicEncounterMetricSample>[];

    for (final QueueCandidate candidate in candidates) {
      final CardState? card = candidate.card;
      final StudyDay dueDay = card != null
          ? calendar.dayOf(card.memory.dueAtUtc)
          : candidate.schedule.algorithmicDueDay;
      final String branchId = candidate.schedule.rootId ?? candidate.ref.id;
      due.add(
        DueMetricSample(
          element: candidate.ref,
          due: dueDay,
          branchId: branchId,
        ),
      );
      if (dueDay > today) {
        final Map<ElementType, int> byType = branchCounts.putIfAbsent(
          branchId,
          () => <ElementType, int>{},
        );
        byType[candidate.ref.type] = (byType[candidate.ref.type] ?? 0) + 1;
      }
      final TopicState? topic = candidate.topic;
      if (topic != null && topic.intervalDays > 0) {
        topicPolicies.add(
          TopicEncounterMetricSample(
            policyVersion: topic.schedulerVersion,
            intervalDays: topic.intervalDays,
            aFactor: topic.aFactor > 0 ? topic.aFactor : null,
          ),
        );
      }
    }
    branchCounts.forEach((String branchId, Map<ElementType, int> byType) {
      byType.forEach((ElementType type, int count) {
        workload.add(
          BranchWorkloadMetricSample(
            branchId: branchId,
            elementType: type,
            count: count,
            estimatedForegroundMs: 0,
          ),
        );
      });
    });

    final List<DailySchedulerActivity> activity = await _dailyActivity(
      today: today,
      windowStart: windowStart,
    );

    return const SchedulerMetricsCollector().collect(
      SchedulerMetricsInput(
        asOfStudyDay: today,
        activityStart: windowStart,
        activityEnd: today,
        due: due,
        activity: activity,
        mercyBatches: await _mercyBatches(windowStart, calendar),
        priorityOutcomes: await _priorityOutcomes(
          windowStart: windowStart,
          calendar: calendar,
          scale: scale,
        ),
        futureWorkload: workload,
        topicEncounters: topicPolicies,
      ),
    );
  }

  /// Per-day counters, read back from what the day actually recorded.
  ///
  /// Review, encounter, and manual-Later counts from the repetition log.
  Future<List<DailySchedulerActivity>> _dailyActivity({
    required StudyDay today,
    required StudyDay windowStart,
  }) async {
    final List<DailySchedulerActivity> activity = <DailySchedulerActivity>[];
    for (StudyDay day = windowStart; day <= today; day = day.addDays(1)) {
      final Map<RevlogEventType, int> counts = await _learning.countRevlogOn(
        day,
      );
      final int reviews = counts[RevlogEventType.review] ?? 0;
      final int encounters = counts[RevlogEventType.topicRead] ?? 0;
      activity.add(
        DailySchedulerActivity(
          day: day,
          manualLaterCount: counts[RevlogEventType.postpone] ?? 0,
          actualCardReviews: reviews,
          topicsCompleted: encounters,
          cardOpportunities: reviews,
          topicOpportunities: encounters,
        ),
      );
    }
    return activity;
  }

  Future<List<MercyBatchMetricSample>> _mercyBatches(
    StudyDay windowStart,
    StudyDayCalendar calendar,
  ) async {
    return <MercyBatchMetricSample>[
      for (final batch in await _learning.listAppliedMercyBatchesSince(
        windowStart,
      ))
        MercyBatchMetricSample(
          batchId: batch.batchId,
          studyDay: calendar.dayOf(batch.appliedAtUtc!),
          size: batch.preview.selectedCount,
        ),
    ];
  }

  /// Lateness and recall by priority decile.
  ///
  /// Only genuine graded reviews contribute. If the top decile is being
  /// recalled worse than the bottom one, priority is being spent on material
  /// the schedule is failing to hold, and that is a policy failure no
  /// per-element view would ever show.
  Future<List<PriorityOutcomeMetricSample>> _priorityOutcomes({
    required StudyDay windowStart,
    required StudyDayCalendar calendar,
    required PriorityScale scale,
  }) async {
    final List<RevlogEntry> recent = await _learning.recentRevlog(limit: 2000);
    final List<PriorityOutcomeMetricSample> outcomes =
        <PriorityOutcomeMetricSample>[];
    for (final RevlogEntry entry in recent) {
      if (calendar.dayOf(entry.atUtc) < windowStart) continue;
      final bool isReview = entry.eventType == RevlogEventType.review;
      final bool isEncounter = entry.eventType == RevlogEventType.topicRead;
      if (!isReview && !isEncounter) continue;
      final double? pressure =
          entry.before.pressure ??
          (entry.before.priorityKey == null
              ? null
              : scale
                    .positionOf(PriorityRank(entry.before.priorityKey!))
                    ?.fraction);
      if (pressure == null) continue;
      final double lateness =
          (entry.elapsedDays ?? 0) - (entry.scheduledDays ?? 0);
      outcomes.add(
        PriorityOutcomeMetricSample(
          elementType: entry.ref.type,
          priorityDecile: PriorityOutcomeMetricSample.decileForPriorityFraction(
            pressure,
          ),
          latenessDays: lateness.isFinite && lateness > 0 ? lateness : 0,
          cardRecalled: isReview && entry.grade != null
              ? entry.grade != CardRating.again.value
              : null,
        ),
      );
    }
    return outcomes;
  }
}
