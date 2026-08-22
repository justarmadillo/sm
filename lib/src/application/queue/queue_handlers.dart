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

import 'dart:convert';

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/presentation_plan.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/schedule_adjustment.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/settings/app_settings.dart';
import '../../domain/transfer/dataset_lineage.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/schedule_adjustment_service.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'queue_commands.dart';

/// Activity kind recorded once per study day when admission runs.
const String kDailyAdmissionKind = 'queue.admission';

/// Activity kind recorded when the user asks for more work.
const String kStudyMoreKind = 'queue.study_more';

/// `[Derived]` Versioned capacity planner. The headroom value is exposed here
/// pending calibration rather than being presented as a SuperMemo constant.
const String kOverflowPolicyVersion = 'supermemo_like_v1';
const double kOverflowHeadroomFraction = 0.10;

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
       _adjustments = ScheduleAdjustmentService(learning: learning, ids: ids),
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final ScheduleAdjustmentService _adjustments;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// Runs the rollover-only overflow policy, then returns a durable plan.
  Future<Result<AdmissionOutcome>> runDailyAdmission(
    RunDailyAdmission command,
  ) async {
    try {
      return await _transactions.run<Result<AdmissionOutcome>>(() async {
        final AppSettings settings = await _context.settings();
        final bool applied = await _learning.hasActivity(
          command.operationId.value,
          kDailyAdmissionKind,
        );
        var deferred = 0;
        if (!applied) {
          if (settings.queue.autoPostpone) {
            deferred = await _applyRolloverOverflow(command, settings);
          }
          await _transfer.advanceGeneration();
        }

        final List<QueueCandidate> candidates = await loadCandidates(
          command.day,
        );
        final DatasetIdentity dataset = await _transfer.currentIdentity();
        final QueuePolicy configured = await _context.queuePolicy();
        final QueuePolicy policy = QueuePolicy(
          settings: configured.settings,
          scale: configured.scale,
          datasetId: dataset.datasetId,
          policyVersion: configured.policyVersion,
        );
        final StoredPresentationPlan? stored = await _learning
            .findPresentationPlan(command.day);
        final QueuePlan fresh = policy.build(
          candidates: candidates,
          nowUtc: _clock.nowUtc(),
          today: command.day,
          extraAdmissions: command.extraAdmissions,
          mergeCursor: stored?.mergeCursor ?? QueueMergeCursor.zero,
        );
        final PresentationPlanIdentity planIdentity = _presentationPlanIdentity(
          command.day,
          settings,
          dataset,
          candidates,
          policy,
        );
        final QueuePlan plan = await _persistOrResumePlan(
          identity: planIdentity,
          fresh: fresh,
          candidates: candidates,
          stored: stored,
          forceRebuild: command.extraAdmissions > 0,
          atUtc: command.timestampUtc,
        );
        if (!applied) {
          // Written after the plan exists, not before: the counters are the
          // whole point of the row. A later rebuild sees only the survivors,
          // so this is the only moment at which what was due, what was
          // admitted, and what did not fit are all known.
          await _learning.appendActivity(
            ActivityRecord(
              id: _ids.newId(),
              operationId: command.operationId.value,
              kind: kDailyAdmissionKind,
              atUtc: command.timestampUtc,
              metadata: <String, Object?>{
                'day': command.day.toString(),
                'deferred': deferred,
                'overflow_profile': kOverflowPolicyVersion,
                ...plan.counters.toMetadata(),
              },
            ),
          );
        }
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kDailyAdmissionKind,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: <String, Object?>{
              ...plan.counters.toMetadata(),
              'rollover_deferred': deferred,
            },
          ),
        );

        return Ok<AdmissionOutcome>(
          AdmissionOutcome(
            plan: plan,
            deferred: deferred,
            alreadyApplied: applied,
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
        if (await _learning.hasActivity(
          command.operationId.value,
          kStudyMoreKind,
        )) {
          final List<ActivityRecord> recent = await _learning.recentActivity(
            limit: 500,
          );
          ActivityRecord? prior;
          for (final ActivityRecord record in recent) {
            if (record.operationId == command.operationId.value &&
                record.kind == kStudyMoreKind) {
              prior = record;
              break;
            }
          }
          return Ok<int>((prior?.metadata?['recalled'] as num?)?.toInt() ?? 0);
        }
        final AppSettings settings = await _context.settings();
        final int limit = command.count ?? settings.queue.studyMoreStep;
        if (limit <= 0) return const Ok<int>(0);

        final List<ScheduleAdjustment> automatic = await _learning
            .listActiveAdjustments(
              reasons: const <ScheduleAdjustmentReason>{
                ScheduleAdjustmentReason.autoOverflow,
              },
            );
        final Map<ElementRef, ElementSchedule> schedules =
            <ElementRef, ElementSchedule>{};
        for (final ScheduleAdjustment adjustment in automatic) {
          final ElementSchedule? schedule = await _learning.findSchedule(
            adjustment.element,
          );
          if (schedule != null) schedules[adjustment.element] = schedule;
        }
        final List<ElementRef> selected = schedules.keys.toList()
          ..sort((ElementRef left, ElementRef right) {
            final int byPriority = schedules[left]!.priority.compareTo(
              schedules[right]!.priority,
            );
            return byPriority != 0 ? byPriority : left.compareTo(right);
          });
        if (selected.length > limit) {
          selected.removeRange(limit, selected.length);
        }
        final ScheduleAdjustmentMutation mutation = await _adjustments
            .clearAutoOverflow(
              elements: selected,
              atUtc: command.timestampUtc,
              studyDay: command.day,
              operationId: command.operationId.value,
            );
        final int recalled = mutation.beforeSnapshot.activeAdjustments
            .where(
              (ScheduleAdjustment adjustment) =>
                  adjustment.reason == ScheduleAdjustmentReason.autoOverflow,
            )
            .length;

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
        return Ok<int>(recalled);
      });
    } on Object catch (error, stackTrace) {
      return Err<int>(_fail(command, kStudyMoreKind, error, stackTrace));
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
    final List<ElementSchedule> topicSchedules = await _learning.listSchedules(
      types: const <ElementType>{ElementType.source, ElementType.extract},
      lifecycles: const <ElementLifecycle>{ElementLifecycle.active},
    );
    final Map<ElementRef, TopicState> topics = await _learning.findTopics(
      <ElementRef>[
        for (final ElementSchedule schedule in topicSchedules) schedule.ref,
      ],
    );
    final List<CardState> cards = await _learning.listCardStates(
      lifecycles: const <ElementLifecycle>{ElementLifecycle.active},
    );
    final Set<ElementRef> refs = <ElementRef>{
      ...topicSchedules.map((ElementSchedule schedule) => schedule.ref),
      ...cards.map((CardState card) => card.ref),
    };
    final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(elements: refs),
    );
    const EffectiveDueService effectiveDue = EffectiveDueService();
    return <QueueCandidate>[
      for (final ElementSchedule schedule in topicSchedules)
        if (topics[schedule.ref] case final TopicState topic)
          QueueCandidate.topic(
            topic,
            rootId: schedule.rootId,
            effectiveDueDay: effectiveDue.topicDueStudyDay(
              topic: topic.ref,
              algorithmicDueStudyDay: topic.schedule.algorithmicDueDay,
              adjustments: adjustments,
            ),
          ),
      for (final CardState card in cards)
        QueueCandidate.card(
          card,
          rootId: card.schedule.rootId,
          effectiveDueAtUtc: effectiveDue.cardDueAtUtc(
            card: card.ref,
            algorithmicDueAtUtc: card.memory.dueAtUtc,
            adjustments: adjustments,
          ),
        ),
    ];
  }

  Future<int> _applyRolloverOverflow(
    RunDailyAdmission command,
    AppSettings settings,
  ) async {
    final List<QueueCandidate> candidates = await loadCandidates(command.day);
    final DatasetIdentity dataset = await _transfer.currentIdentity();
    final QueuePolicy configured = await _context.queuePolicy();
    final QueuePolicy policy = QueuePolicy(
      settings: configured.settings,
      scale: configured.scale,
      datasetId: dataset.datasetId,
      policyVersion: configured.policyVersion,
    );
    final QueuePlan admission = policy.build(
      candidates: candidates,
      nowUtc: command.timestampUtc,
      today: command.day,
    );
    final StudyDayCalendar calendar = await _context.calendar();
    final List<ScoredCandidate> backlog =
        admission.overflow.where((ScoredCandidate scored) {
          final QueueCandidate candidate = scored.candidate;
          if (scored.isProtected || candidate.isIntradayStep) return false;
          if (scored.lane == QueueLane.availableNewCard) return false;
          final StudyDay canonicalDay = candidate.isCard
              ? calendar.dayOf(candidate.card!.memory.dueAtUtc)
              : candidate.topic!.schedule.algorithmicDueDay;
          // The default profile touches only work already outstanding before
          // rollover. Material becoming due today remains canonical and due.
          return canonicalDay < command.day;
        }).toList()..sort((ScoredCandidate left, ScoredCandidate right) {
          final int byPriority = left.candidate.schedule.priority.compareTo(
            right.candidate.schedule.priority,
          );
          return byPriority != 0 ? byPriority : left.ref.compareTo(right.ref);
        });
    if (backlog.isEmpty) return 0;

    final _FutureCapacityLedger ledger = _FutureCapacityLedger(
      today: command.day,
      cardCapacity: _capacityAfterHeadroom(settings.queue.maxCards),
      topicCapacity: _capacityAfterHeadroom(settings.queue.maxTopics),
    );
    for (final QueueCandidate candidate in candidates) {
      final StudyDay effectiveDay = candidate.isCard
          ? calendar.dayOf(
              candidate.effectiveCardDueAtUtc ??
                  candidate.card!.memory.dueAtUtc,
            )
          : candidate.effectiveTopicDueDay ??
                candidate.topic!.schedule.algorithmicDueDay;
      if (effectiveDay > command.day) {
        ledger.addExisting(effectiveDay, isCard: candidate.isCard);
      }
    }

    final List<RevlogEntry> compatibilityEntries = <RevlogEntry>[];
    var deferred = 0;
    for (final ScoredCandidate scored in backlog) {
      final QueueCandidate candidate = scored.candidate;
      final StudyDay? destination = ledger.reserveNext(
        isCard: candidate.isCard,
      );
      if (destination == null) continue;
      final AdjustmentApplication applied = await _adjustments.setLowerBound(
        element: candidate.ref,
        reason: ScheduleAdjustmentReason.autoOverflow,
        operationId: command.operationId.value,
        atUtc: command.timestampUtc,
        studyDay: command.day,
        notBeforeAtUtc: candidate.isCard
            ? calendar.startOfDayUtc(destination)
            : null,
        notBeforeStudyDay: candidate.isCard ? null : destination,
        replaceSameReason: true,
        policyVersion: kOverflowPolicyVersion,
      );
      if (applied.alreadyApplied) continue;
      compatibilityEntries.add(
        _journal.build(
          operationId: command.operationId.value,
          ref: candidate.ref,
          eventType: RevlogEventType.autoPostpone,
          atUtc: command.timestampUtc,
          before: RevlogSnapshot(
            priorityKey: candidate.schedule.priority.orderKey,
            lifecycle: candidate.schedule.lifecycle.index,
          ),
          after: RevlogSnapshot(
            dueAtUtc: calendar.startOfDayUtc(destination),
            priorityKey: candidate.schedule.priority.orderKey,
            lifecycle: candidate.schedule.lifecycle.index,
          ),
          scheduledDays: candidate.scheduledDays,
          metadata: <String, Object?>{
            'destination': destination.toString(),
            'stream': candidate.isCard ? 'card' : 'topic',
            'policy_version': kOverflowPolicyVersion,
            'headroom_fraction': kOverflowHeadroomFraction,
          },
        ),
      );
      deferred++;
    }
    await _journal.appendAll(compatibilityEntries);
    return deferred;
  }

  int _capacityAfterHeadroom(int cap) =>
      (cap * (1 - kOverflowHeadroomFraction)).floor().clamp(0, cap).toInt();

  PresentationPlanIdentity _presentationPlanIdentity(
    StudyDay day,
    AppSettings settings,
    DatasetIdentity dataset,
    List<QueueCandidate> candidates,
    QueuePolicy policy,
  ) {
    final List<QueueCandidate> ordered = candidates.toList()
      ..sort(
        (QueueCandidate left, QueueCandidate right) =>
            left.ref.compareTo(right.ref),
      );
    final String candidateState = <String>[
      for (final QueueCandidate candidate in ordered)
        '${candidate.ref}|${candidate.schedule.revision}|'
            '${candidate.card?.memory.revision ?? candidate.topic?.revision}|'
            '${candidate.effectiveCardDueAtUtc?.millisecondsSinceEpoch ?? candidate.effectiveTopicDueDay?.epochDay}',
    ].join(';');
    final List<MapEntry<String, String>> settingEntries =
        settings.toMap().entries.toList()..sort(
          (MapEntry<String, String> left, MapEntry<String, String> right) =>
              left.key.compareTo(right.key),
        );
    return PresentationPlanIdentity(
      studyDay: day,
      policyVersion: policy.policyVersion,
      settingsRevision: _stableDigest(
        jsonEncode(<String, String>{
          for (final entry in settingEntries) entry.key: entry.value,
        }),
      ),
      datasetGeneration: dataset.generation,
      candidateRevision: _stableDigest(candidateState),
      deterministicSeedVersion: policy.policyVersion,
    );
  }

  Future<QueuePlan> _persistOrResumePlan({
    required PresentationPlanIdentity identity,
    required QueuePlan fresh,
    required List<QueueCandidate> candidates,
    required StoredPresentationPlan? stored,
    required bool forceRebuild,
    required DateTime atUtc,
  }) async {
    final Map<ElementRef, QueueCandidate> byRef = <ElementRef, QueueCandidate>{
      for (final candidate in candidates) candidate.ref: candidate,
    };
    final Map<ElementRef, QueueLane> freshLanes = <ElementRef, QueueLane>{
      for (final scored in fresh.scored) scored.ref: scored.lane,
    };

    // A stored plan is resumed only while it was planned under the same
    // rules. A different study day, policy, or settings revision is a
    // different day's plan, and quietly resuming the old one would ignore the
    // change the user just made.
    final bool resumable =
        stored != null &&
        !forceRebuild &&
        identity.sharesBasisWith(stored.identity);

    if (stored != null && resumable) {
      final List<PresentationPlanEntry> remaining = <PresentationPlanEntry>[
        for (final entry in stored.remainingEntries)
          if (byRef[entry.ref] case final QueueCandidate candidate)
            if (candidate.isEligible(
              nowUtc: _clock.nowUtc(),
              today: identity.studyDay,
            ))
              entry,
      ];
      final Set<ElementRef> present = remaining
          .map((PresentationPlanEntry entry) => entry.ref)
          .toSet();
      final List<PresentationPlanEntry> mandatory = <PresentationPlanEntry>[
        for (final scored in fresh.scored)
          if (scored.lane == QueueLane.mandatoryIntradayStep &&
              !present.contains(scored.ref))
            PresentationPlanEntry(ref: scored.ref, lane: scored.lane),
      ];
      if (mandatory.isNotEmpty) {
        final int nextCard = remaining.indexWhere(
          (PresentationPlanEntry entry) => entry.ref.type == ElementType.card,
        );
        remaining.insertAll(nextCard < 0 ? 0 : nextCard, mandatory);
        present.addAll(
          mandatory.map((PresentationPlanEntry entry) => entry.ref),
        );
      }
      // Work admitted since the plan was written — recalled by Study More, or
      // newly created — joins the tail rather than waiting for tomorrow. The
      // caps already decided this set, so appending it cannot exceed them, and
      // appending keeps the user's current place instead of reshuffling it.
      remaining.addAll(<PresentationPlanEntry>[
        for (final QueueCandidate candidate in fresh.entries)
          if (!present.contains(candidate.ref))
            PresentationPlanEntry(
              ref: candidate.ref,
              lane: freshLanes[candidate.ref] ?? QueueLane.regularDueTopic,
            ),
      ]);
      final StoredPresentationPlan resumed = StoredPresentationPlan(
        identity: identity,
        remainingEntries: List<PresentationPlanEntry>.unmodifiable(remaining),
        mergeCursor: stored.mergeCursor,
        createdAtUtc: stored.createdAtUtc,
        updatedAtUtc: atUtc,
      );
      await _learning.savePresentationPlan(resumed);
      return QueuePlan(
        entries: <QueueCandidate>[
          for (final entry in remaining)
            if (byRef[entry.ref] case final QueueCandidate candidate) candidate,
        ],
        overflow: fresh.overflow,
        counters: fresh.counters,
        scored: fresh.scored,
        nextMergeCursor: stored.mergeCursor,
      );
    }

    final List<PresentationPlanEntry> entries = <PresentationPlanEntry>[
      for (final candidate in fresh.entries)
        PresentationPlanEntry(
          ref: candidate.ref,
          lane: freshLanes[candidate.ref] ?? QueueLane.regularDueTopic,
        ),
    ];
    final StoredPresentationPlan created = StoredPresentationPlan(
      identity: identity,
      remainingEntries: List<PresentationPlanEntry>.unmodifiable(entries),
      mergeCursor: stored?.mergeCursor ?? QueueMergeCursor.zero,
      createdAtUtc: stored?.createdAtUtc ?? atUtc,
      updatedAtUtc: atUtc,
    );
    await _learning.savePresentationPlan(created);
    return fresh;
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

final class _FutureCapacityLedger {
  _FutureCapacityLedger({
    required this.today,
    required this.cardCapacity,
    required this.topicCapacity,
  });

  final StudyDay today;
  final int cardCapacity;
  final int topicCapacity;
  final Map<int, int> _cardLoad = <int, int>{};
  final Map<int, int> _topicLoad = <int, int>{};

  void addExisting(StudyDay day, {required bool isCard}) {
    final Map<int, int> load = isCard ? _cardLoad : _topicLoad;
    load.update(day.epochDay, (int value) => value + 1, ifAbsent: () => 1);
  }

  StudyDay? reserveNext({required bool isCard}) {
    final int capacity = isCard ? cardCapacity : topicCapacity;
    if (capacity <= 0) return null;
    final Map<int, int> load = isCard ? _cardLoad : _topicLoad;
    for (var offset = 1; offset <= 36500; offset++) {
      final StudyDay day = today.addDays(offset);
      final int current = load[day.epochDay] ?? 0;
      if (current >= capacity) continue;
      load[day.epochDay] = current + 1;
      return day;
    }
    return null;
  }
}

String _stableDigest(String value) {
  var hash = 0x811c9dc5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
