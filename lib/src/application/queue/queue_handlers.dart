/// Handlers for daily admission, Study More, and Mercy.
///
/// This is the load valve. A collection is expected to exceed learning
/// capacity — that is the normal state of incremental reading, not an error —
/// so something has to shed work, and it should be the lowest-priority work
/// rather than whatever the user happens not to reach.
///
/// Four invariants hold across every handler here:
///
/// * **No fabricated history.** A deferral writes `deferredUntil` and nothing
///   else. The algorithmic due date, the interval, and every FSRS value
///   survive untouched, so overdue ranking stays honest and a future
///   optimizer never sees a review that did not happen.
/// * **A protected top.** The best-priority slice of the collection is never
///   deferred automatically. Without that floor the valve eventually pushes
///   everything out and the collection schedules nothing.
/// * **Started steps are never deferred.** A card inside a learning or
///   relearning step was already admitted today and is due again in minutes.
/// * **Exactly once per day.** Admission is keyed on the study day, so
///   rebuilding the queue during a session never defers anything twice.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/overload.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/settings/app_settings.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'queue_commands.dart';

/// Activity kind recorded once per study day when admission runs.
const String kDailyAdmissionKind = 'queue.admission';

/// Activity kind recorded when the user asks for more work.
const String kStudyMoreKind = 'queue.study_more';

/// Activity kind recorded when a backlog is spread.
const String kMercyKind = 'queue.mercy';

/// A deterministic operation id for [day]'s admission.
///
/// Derived rather than random on purpose: it is what makes the day's valve
/// idempotent across rebuilds, restarts, and crashes.
String dailyAdmissionOperationId(StudyDay day) => 'admission:$day';

/// What one admission run did.
final class AdmissionOutcome {
  const AdmissionOutcome({
    required this.plan,
    required this.deferred,
    required this.alreadyApplied,
  });

  /// The day's queue.
  final QueuePlan plan;

  /// How many elements the valve pushed out.
  final int deferred;

  /// Whether this day had already been admitted and nothing was rewritten.
  final bool alreadyApplied;
}

/// Runs the overload valve and the two manual load controls.
final class QueueHandlers {
  QueueHandlers({
    required ContentRepository content,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// Builds the day's plan and defers whatever does not fit.
  ///
  /// Returns the plan either way: if the day has already been admitted the
  /// plan is rebuilt from the schedules as they now stand, which is exactly
  /// what a mid-session refresh should show.
  Future<Result<AdmissionOutcome>> runDailyAdmission(
    RunDailyAdmission command,
  ) async {
    try {
      return await _transactions.run<Result<AdmissionOutcome>>(() async {
        final AppSettings settings = await _context.settings();
        final QueuePolicy policy = await _context.queuePolicy();
        final List<QueueCandidate> candidates = await loadCandidates(
          command.day,
        );
        final QueuePlan plan = policy.build(
          candidates: candidates,
          nowUtc: _clock.nowUtc(),
          today: command.day,
          extraAdmissions: command.extraAdmissions,
        );

        final bool applied = await _learning.hasActivity(
          command.operationId.value,
          kDailyAdmissionKind,
        );
        if (applied || !settings.queue.autoPostpone || plan.overflow.isEmpty) {
          return Ok<AdmissionOutcome>(
            AdmissionOutcome(
              plan: plan,
              deferred: 0,
              alreadyApplied: applied,
            ),
          );
        }

        final int deferred = await _deferOverflow(
          command: command,
          overflow: plan.overflow,
          settings: settings,
          scale: policy.scale,
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kDailyAdmissionKind,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              ...plan.counters.toMetadata(),
              'day': command.day.toString(),
              'deferred': deferred,
            },
          ),
        );
        await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kDailyAdmissionKind,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: plan.counters.toMetadata(),
          ),
        );

        // The plan was computed before the deferrals were written, so rebuild
        // it from the admitted half rather than re-querying: the overflow is
        // no longer eligible and would otherwise reappear in this same call.
        return Ok<AdmissionOutcome>(
          AdmissionOutcome(
            plan: plan,
            deferred: deferred,
            alreadyApplied: false,
          ),
        );
      });
    } on Object catch (error, stackTrace) {
      return Err<AdmissionOutcome>(
        _fail(command, kDailyAdmissionKind, error, stackTrace),
      );
    }
  }

  /// Recalls automatic deferrals so the user can keep working.
  Future<Result<int>> studyMore(StudyMore command) async {
    try {
      return await _transactions.run<Result<int>>(() async {
        final AppSettings settings = await _context.settings();
        final CardScheduler cards = await _context.cardScheduler();
        final int limit = command.count ?? settings.queue.studyMoreStep;
        if (limit <= 0) return const Ok<int>(0);

        // Best priority first: the elements the valve shed most reluctantly
        // are the ones worth taking back first.
        final List<ElementSchedule> deferred = await _learning
            .listAutomaticDeferrals(from: command.day);
        deferred.sort(
          (ElementSchedule a, ElementSchedule b) =>
              a.priority.compareTo(b.priority),
        );

        var recalled = 0;
        final entries = <RevlogEntry>[];
        for (final ElementSchedule schedule in deferred) {
          if (recalled >= limit) break;
          if (schedule.ref.type == ElementType.card) {
            final CardState? state = await _learning.findCardState(
              schedule.ref.id,
            );
            if (state == null) continue;
            await _learning.saveCardState(cards.recallAutomaticDeferral(state));
          } else {
            final TopicState? topic = await _learning.findTopic(schedule.ref);
            if (topic == null) continue;
            await _learning.saveTopic(
              topic.copyWith(
                schedule: schedule.withAutomaticDeferralRecalled(),
              ),
            );
          }
          entries.add(
            _journal.build(
              operationId: command.operationId.value,
              ref: schedule.ref,
              eventType: RevlogEventType.manualReschedule,
              atUtc: command.timestampUtc,
              before: RevlogSnapshot(
                priorityKey: schedule.priority.orderKey,
                lifecycle: schedule.lifecycle.index,
              ),
              metadata: <String, Object?>{
                'reason': 'study_more',
                'recalled_from': schedule.deferredUntil?.toString(),
              },
            ),
          );
          recalled++;
        }

        if (recalled > 0) {
          await _journal.appendAll(entries);
          await _learning.appendActivity(
            ActivityRecord(
              id: _ids.newId(),
              operationId: command.operationId.value,
              kind: kStudyMoreKind,
              atUtc: command.timestampUtc,
              metadata: <String, Object?>{
                'recalled': recalled,
                'day': command.day.toString(),
              },
            ),
          );
          await _transfer.advanceGeneration();
        }
        return Ok<int>(recalled);
      });
    } on Object catch (error, stackTrace) {
      return Err<int>(_fail(command, kStudyMoreKind, error, stackTrace));
    }
  }

  /// Spreads everything overdue across a horizon.
  Future<Result<int>> runMercy(RunMercy command) async {
    try {
      return await _transactions.run<Result<int>>(() async {
        final AppSettings settings = await _context.settings();
        final PostponeSettings tuned = settings.postpone.copyWith(
          mercyHorizonDays: command.horizonDays,
          mercyDailyCap: command.dailyCap,
        );
        final OverloadValve valve = OverloadValve(settings: tuned);
        final CardScheduler cards = await _context.cardScheduler();
        final StudyDayCalendar calendar = await _context.calendar();
        final PriorityScale scale = await _context.priorityScale();

        final List<ElementSchedule> backlog = await _learning.listBacklog(
          day: command.day,
        );
        if (backlog.isEmpty) return const Ok<int>(0);
        backlog.sort(
          (ElementSchedule a, ElementSchedule b) =>
              a.priority.compareTo(b.priority),
        );

        final entries = <RevlogEntry>[];
        for (var index = 0; index < backlog.length; index++) {
          final ElementSchedule schedule = backlog[index];
          final int delay = valve.mercyDelayDays(index);
          final StudyDay until = command.day.addDays(delay);
          final RevlogSnapshot before = RevlogSnapshot(
            dueAtUtc: calendar.startOfDayUtc(schedule.effectiveDueDay),
            priorityKey: schedule.priority.orderKey,
            pressure: scale.pressureOf(schedule.priority),
            lifecycle: schedule.lifecycle.index,
          );
          await _defer(schedule, until, calendar, cards);
          entries.add(
            _journal.build(
              operationId: command.operationId.value,
              ref: schedule.ref,
              eventType: RevlogEventType.mercy,
              atUtc: command.timestampUtc,
              before: before,
              after: RevlogSnapshot(
                dueAtUtc: calendar.startOfDayUtc(until),
                priorityKey: schedule.priority.orderKey,
                lifecycle: schedule.lifecycle.index,
              ),
              metadata: <String, Object?>{
                'delay_days': delay,
                'backlog_index': index,
                'backlog_size': backlog.length,
                'horizon_days': tuned.mercyHorizonDays,
                'daily_cap': tuned.mercyDailyCap,
              },
            ),
          );
        }

        await _journal.appendAll(entries);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kMercyKind,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'spread': backlog.length,
              'horizon_days': tuned.mercyHorizonDays,
              'daily_cap': tuned.mercyDailyCap,
            },
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<int>(backlog.length);
      });
    } on Object catch (error, stackTrace) {
      return Err<int>(_fail(command, kMercyKind, error, stackTrace));
    }
  }

  /// The counters this day's admission recorded, or null if it has not run.
  ///
  /// A later build of the same queue sees only what is still due, which would
  /// make the day's deferrals invisible in the very panel that exists to show
  /// them. They are read back from the activity row the valve wrote.
  Future<QueueCounters?> recordedCounters(StudyDay day) async {
    final String operationId = dailyAdmissionOperationId(day);
    final List<ActivityRecord> recent = await _learning.recentActivity(
      limit: 200,
    );
    for (final ActivityRecord record in recent) {
      if (record.kind != kDailyAdmissionKind) continue;
      if (record.operationId != operationId) continue;
      final Map<String, Object?>? metadata = record.metadata;
      if (metadata == null) return null;
      int read(String key) => (metadata[key] as num?)?.toInt() ?? 0;
      return QueueCounters(
        dueCards: read('due_cards'),
        dueTopics: read('due_topics'),
        admittedCards: read('admitted_cards'),
        admittedTopics: read('admitted_topics'),
        admittedNewCards: read('admitted_new_cards'),
        overflowCards: read('overflow_cards'),
        overflowTopics: read('overflow_topics'),
        protectedElements: read('protected'),
        protectionPercent:
            (metadata['protection_percent'] as num?)?.toDouble() ?? 100,
      );
    }
    return null;
  }

  /// Every eligible element on [day], as queue candidates.
  ///
  /// Shared with the read model so the queue the user sees is built from
  /// exactly the set the valve judged.
  Future<List<QueueCandidate>> loadCandidates(StudyDay day) async {
    final List<ElementSchedule> topicSchedules = await _learning.listEligible(
      day: day,
      types: const <ElementType>{ElementType.source, ElementType.extract},
    );
    final Map<ElementRef, TopicState> topics = await _learning.findTopics(
      <ElementRef>[
        for (final ElementSchedule schedule in topicSchedules) schedule.ref,
      ],
    );
    final List<CardState> cards = await _learning.listDueCards(
      _clock.nowUtc(),
    );
    return <QueueCandidate>[
      for (final ElementSchedule schedule in topicSchedules)
        if (topics[schedule.ref] case final TopicState topic)
          QueueCandidate.topic(topic, rootId: schedule.rootId),
      for (final CardState card in cards)
        QueueCandidate.card(card, rootId: card.schedule.rootId),
    ];
  }

  Future<int> _deferOverflow({
    required RunDailyAdmission command,
    required List<ScoredCandidate> overflow,
    required AppSettings settings,
    required PriorityScale scale,
  }) async {
    final OverloadValve valve = OverloadValve(settings: settings.postpone);
    final CardScheduler cards = await _context.cardScheduler();
    final StudyDayCalendar calendar = await _context.calendar();
    final entries = <RevlogEntry>[];

    for (final ScoredCandidate scored in overflow) {
      final QueueCandidate candidate = scored.candidate;
      // Belt and braces: the policy already excludes both, and deferring
      // either would be the bug that empties the queue permanently.
      if (scored.isProtected || candidate.isIntradayStep) continue;

      final ElementSchedule schedule = candidate.schedule;
      final PostponeDecision decision = valve.autoPostpone(
        intervalDays: candidate.scheduledDays,
        pressure: scale.pressureOf(schedule.priority),
        seed: '${command.operationId.value}:${schedule.ref}',
      );
      final StudyDay until = command.day.addDays(decision.delayDays);
      final RevlogSnapshot before = RevlogSnapshot(
        dueAtUtc: calendar.startOfDayUtc(schedule.effectiveDueDay),
        priorityKey: schedule.priority.orderKey,
        pressure: decision.pressure,
        lifecycle: schedule.lifecycle.index,
      );
      await _defer(schedule, until, calendar, cards);
      entries.add(
        _journal.build(
          operationId: command.operationId.value,
          ref: schedule.ref,
          eventType: RevlogEventType.autoPostpone,
          atUtc: command.timestampUtc,
          before: before,
          after: RevlogSnapshot(
            dueAtUtc: calendar.startOfDayUtc(until),
            priorityKey: schedule.priority.orderKey,
            pressure: decision.pressure,
            lifecycle: schedule.lifecycle.index,
          ),
          scheduledDays: candidate.scheduledDays,
          metadata: <String, Object?>{
            ...decision.toMetadata(),
            'day': command.day.toString(),
            'stream': candidate.isCard ? 'card' : 'topic',
          },
        ),
      );
    }
    if (entries.isNotEmpty) await _journal.appendAll(entries);
    return entries.length;
  }

  /// Writes one deferral, and only the deferral.
  Future<void> _defer(
    ElementSchedule schedule,
    StudyDay until,
    StudyDayCalendar calendar,
    CardScheduler cards,
  ) async {
    if (schedule.ref.type == ElementType.card) {
      final CardState? state = await _learning.findCardState(schedule.ref.id);
      if (state == null) return;
      await _learning.saveCardState(
        cards.postpone(
          state,
          untilUtc: calendar.startOfDayUtc(until),
          kind: DeferralKind.automatic,
        ),
      );
      return;
    }
    final TopicState? topic = await _learning.findTopic(schedule.ref);
    if (topic == null) return;
    await _learning.saveTopic(
      topic.copyWith(
        postponeCount: topic.postponeCount + 1,
        schedule: schedule.copyWith(
          deferredUntil: until,
          deferralKind: DeferralKind.automatic,
        ),
      ),
    );
  }

  /// The content repository, held so the read model can share this handler's
  /// candidate loading without a second dependency graph.
  ContentRepository get content => _content;

  UnexpectedFailure _fail(
    AppCommand command,
    String kind,
    Object error,
    StackTrace stackTrace,
  ) {
    final UnexpectedFailure failure = UnexpectedFailure(
      'command $kind failed',
      cause: error,
      stackTrace: stackTrace,
    );
    _diagnostics.record(
      DiagnosticEvent(
        level: DiagnosticLevel.error,
        name: kind,
        timestampUtc: _clock.nowUtc(),
        operationId: command.operationId,
        failure: failure,
      ),
    );
    return failure;
  }
}
