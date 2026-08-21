import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/scheduler_metrics.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const String zone = 'Europe/Berlin';
  const StudyDay today = StudyDay(year: 2026, month: 8, day: 21, zoneId: zone);
  const ElementRef card = ElementRef(id: 'card-1', type: ElementType.card);
  const ElementRef source = ElementRef(
    id: 'source-1',
    type: ElementType.source,
  );
  const ElementRef extract = ElementRef(
    id: 'extract-1',
    type: ElementType.extract,
  );

  test('collects every required operational metric without mutating input', () {
    final SchedulerMetricsInput input = SchedulerMetricsInput(
      asOfStudyDay: today,
      due: <DueMetricSample>[
        DueMetricSample(
          element: card,
          algorithmicDue: today,
          effectiveDue: today.addDays(2),
          branchId: 'branch-a',
          estimatedForegroundMs: 12000,
        ),
        DueMetricSample(
          element: source,
          algorithmicDue: today.addDays(1),
          effectiveDue: today.addDays(1),
          branchId: 'branch-a',
          estimatedForegroundMs: 60000,
        ),
        DueMetricSample(
          element: extract,
          algorithmicDue: today.addDays(-3),
          effectiveDue: today.addDays(-1),
          branchId: 'branch-b',
        ),
        DueMetricSample(
          element: const ElementRef(id: 'card-outside', type: ElementType.card),
          algorithmicDue: today.addDays(30),
          effectiveDue: today.addDays(30),
          branchId: 'branch-b',
        ),
      ],
      activeAdjustments: const <AdjustmentLoadSample>[
        AdjustmentLoadSample(
          element: card,
          reason: ScheduleAdjustmentReason.manualLater,
          mode: ScheduleAdjustmentMode.lowerBound,
        ),
        AdjustmentLoadSample(
          element: card,
          reason: ScheduleAdjustmentReason.siblingBury,
          mode: ScheduleAdjustmentMode.lowerBound,
        ),
        AdjustmentLoadSample(
          element: source,
          reason: ScheduleAdjustmentReason.mercy,
          mode: ScheduleAdjustmentMode.exactOverride,
        ),
      ],
      activity: <DailySchedulerActivity>[
        DailySchedulerActivity(
          day: today,
          dueWorkCount: 100,
          automaticOverflowCount: 30,
          manualLaterCount: 4,
          newCardsIntroduced: 7,
          actualCardReviews: 60,
          topicsCompleted: 15,
          cardOpportunities: 80,
          topicOpportunities: 20,
          cardForegroundMs: 800000,
          topicForegroundMs: 400000,
        ),
        DailySchedulerActivity(
          day: today.addDays(-40),
          dueWorkCount: 10,
          automaticOverflowCount: 10,
          manualLaterCount: 99,
        ),
      ],
      mercyBatches: <MercyBatchMetricSample>[
        MercyBatchMetricSample(batchId: 'mercy-1', studyDay: today, size: 24),
      ],
      priorityOutcomes: <PriorityOutcomeMetricSample>[
        PriorityOutcomeMetricSample(
          elementType: ElementType.card,
          priorityDecile: 1,
          latenessDays: 1,
          cardRecalled: true,
        ),
        PriorityOutcomeMetricSample(
          elementType: ElementType.card,
          priorityDecile: 1,
          latenessDays: 3,
          cardRecalled: false,
        ),
        PriorityOutcomeMetricSample(
          elementType: ElementType.source,
          priorityDecile: 1,
          latenessDays: 5,
        ),
      ],
      futureWorkload: <BranchWorkloadMetricSample>[
        BranchWorkloadMetricSample(
          branchId: 'branch-a',
          elementType: ElementType.card,
          count: 12,
          estimatedForegroundMs: 120000,
        ),
        BranchWorkloadMetricSample(
          branchId: 'branch-a',
          elementType: ElementType.extract,
          count: 3,
          estimatedForegroundMs: 180000,
        ),
      ],
      topicEncounters: <TopicEncounterMetricSample>[
        TopicEncounterMetricSample(
          policyVersion: 'topic_afactor_v1/1',
          intervalDays: 2,
          aFactor: 1.4,
        ),
        TopicEncounterMetricSample(
          policyVersion: 'topic_afactor_v1/1',
          intervalDays: 6,
          aFactor: 2.0,
        ),
        TopicEncounterMetricSample(
          policyVersion: 'legacy_sequence/1',
          intervalDays: 3,
        ),
      ],
      overloadWeeks: <WeeklyOverloadMetricSample>[
        for (var index = 0; index < 3; index++)
          WeeklyOverloadMetricSample(
            weekStart: today.addDays(-14 + index * 7),
            dueWorkCount: 100,
            automaticOverflowCount: 30,
          ),
      ],
    );

    const SchedulerMetricsCollector collector = SchedulerMetricsCollector();
    final SchedulerMetricsSnapshot result = collector.collect(input);

    expect(result.policyVersion, schedulerMetricsPolicyVersion);
    expect(result.next30Days, hasLength(30));
    expect(result.next30Days.first.algorithmicCards, 1);
    expect(result.next30Days.first.effectiveCards, 0);
    expect(result.next30Days[1].algorithmicTopics, 1);
    expect(result.next30Days[2].effectiveCards, 1);
    expect(result.algorithmicOverdueTopics, 1);
    expect(result.effectiveOverdueTopics, 1);
    expect(
      result
          .activeAdjustmentLoadByReason[ScheduleAdjustmentReason.manualLater]!
          .lowerBoundCount,
      1,
    );
    expect(
      result
          .activeAdjustmentLoadByReason[ScheduleAdjustmentReason.mercy]!
          .exactOverrideCount,
      1,
    );
    expect(result.automaticOverflowCount, 30);
    expect(result.automaticOverflowFraction, 0.3);
    expect(result.manualLaterCount, 4);
    expect(result.mercyCount, 1);
    expect(result.mercyBatchSizes, <int>[24]);
    expect(result.newCardsIntroduced, 7);
    expect(result.actualCardReviews, 60);
    expect(result.topicsCompleted, 15);
    expect(result.cardTopicOpportunityRatio.value, 4);
    expect(result.cardTopicForegroundTimeRatio.value, 2);
    expect(result.priorityDeciles.first.allLateness.median, 3);
    expect(result.priorityDeciles.first.cardLateness.median, 2);
    expect(result.priorityDeciles.first.measuredCardRetention, 0.5);
    expect(result.protectionInvariantHolds, isTrue);
    expect(result.futureWorkloadByBranch.single.cardCount, 12);
    expect(result.futureWorkloadByBranch.single.topicCount, 3);
    expect(result.futureWorkloadByBranch.single.totalForegroundMs, 300000);
    expect(result.topicPolicies, hasLength(2));
    expect(result.topicPolicies.last.intervals.median, 4);
    expect(result.topicPolicies.last.aFactors.median, 1.7);
    expect(result.overloadWarning.active, isTrue);
  });

  group('sustained overload warning', () {
    const SustainedOverloadWarningEvaluator evaluator =
        SustainedOverloadWarningEvaluator();

    test('requires three contiguous weeks at or above thirty percent', () {
      final SustainedOverloadWarning twoWeeks = evaluator
          .evaluate(<WeeklyOverloadMetricSample>[
            WeeklyOverloadMetricSample(
              weekStart: today.addDays(-7),
              dueWorkCount: 10,
              automaticOverflowCount: 3,
            ),
            WeeklyOverloadMetricSample(
              weekStart: today,
              dueWorkCount: 10,
              automaticOverflowCount: 3,
            ),
          ]);
      expect(twoWeeks.active, isFalse);
      expect(twoWeeks.latestConsecutiveWeeks, 2);

      final SustainedOverloadWarning threeWeeks = evaluator
          .evaluate(<WeeklyOverloadMetricSample>[
            WeeklyOverloadMetricSample(
              weekStart: today.addDays(-14),
              dueWorkCount: 10,
              automaticOverflowCount: 3,
            ),
            WeeklyOverloadMetricSample(
              weekStart: today.addDays(-7),
              dueWorkCount: 10,
              automaticOverflowCount: 3,
            ),
            WeeklyOverloadMetricSample(
              weekStart: today,
              dueWorkCount: 10,
              automaticOverflowCount: 3,
            ),
          ]);
      expect(threeWeeks.active, isTrue);
      expect(threeWeeks.latestConsecutiveWeeks, 3);
    });

    test('a gap, a low week, or a zero-volume week resets the streak', () {
      final SustainedOverloadWarning result = evaluator
          .evaluate(<WeeklyOverloadMetricSample>[
            WeeklyOverloadMetricSample(
              weekStart: today.addDays(-28),
              dueWorkCount: 10,
              automaticOverflowCount: 4,
            ),
            WeeklyOverloadMetricSample(
              weekStart: today.addDays(-14),
              dueWorkCount: 10,
              automaticOverflowCount: 4,
            ),
            WeeklyOverloadMetricSample(
              weekStart: today.addDays(-7),
              dueWorkCount: 0,
              automaticOverflowCount: 0,
            ),
            WeeklyOverloadMetricSample(
              weekStart: today,
              dueWorkCount: 10,
              automaticOverflowCount: 4,
            ),
          ]);
      expect(result.active, isFalse);
      expect(result.latestConsecutiveWeeks, 1);
    });
  });

  test('deciles preserve zero-at-top and one-at-bottom semantics', () {
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(0), 1);
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(0.099), 1);
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(0.1), 2);
    expect(PriorityOutcomeMetricSample.decileForPriorityFraction(1), 10);
  });

  test('ratios remain undefined instead of inventing a zero denominator', () {
    const RatioMetric ratio = RatioMetric(numerator: 7, denominator: 0);
    expect(ratio.value, isNull);
  });
}
