/// Application transactions for SM20's three learning queues.
///
/// Outstanding is the only mixed and priority-sorted queue. Final Drill and
/// Pending are durable fallback stages and are intentionally never admitted
/// through a capacity valve or injected as mandatory steps.
library;

import 'dart:math' as math;

import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_postpone.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kDailyAdmissionType = 'sm20.queue.opened';
const String kSmartPostponeType = 'sm20.smart_postpone';
const String kEnterStageType = 'sm20.queue.stage_entered';
const String kCutDrillsType = 'sm20.queue.drills_cut';
const String kRandomizeQueueType = 'sm20.queue.randomized';

String dailyAdmissionOperationId(StudyDay day) => 'sm20-queue:$day';

final class AdmissionOutcome {
  const AdmissionOutcome({
    required this.plan,
    required this.automaticallyPostponed,
    required this.wasAlreadyApplied,
  });

  final QueuePlan plan;

  /// Number moved by today's automatic Smart Postpone pass.
  final int automaticallyPostponed;

  /// True once today's one-shot automatic sort has already been recorded.
  final bool wasAlreadyApplied;
}

final class QueueCommandRunner {
  QueueCommandRunner({
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
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final DiagnosticSink _diagnostics;

  Future<Result<AdmissionOutcome>> runDailyAdmission(
    RunDailyAdmission command,
  ) async {
    try {
      return await _transactions.run<Result<AdmissionOutcome>>(() async {
        var settings = await _context.settings();
        final Sm20CollectionState before = await _context.runtimeState();
        final Sm20RandomNumberGenerator randomNumbers =
            Sm20RandomNumberGenerator(seed: before.randomNumberSeed);
        var candidates = await loadCandidates(command.day);
        var byRef = <ElementRef, QueueCandidate>{
          for (final QueueCandidate candidate in candidates)
            candidate.ref: candidate,
        };

        final List<QueueCandidate> dueBeforePostpone = <QueueCandidate>[
          for (final QueueCandidate candidate in candidates)
            if (!candidate.isPending &&
                candidate.isDue(
                  nowUtc: command.timestampUtc,
                  today: command.day,
                ))
              candidate,
        ];
        final List<ElementRef> outstandingBeforePostpone = _orderedRefs(
          before.outstanding,
          dueBeforePostpone,
          byRef: byRef,
          accept: (QueueCandidate value) => !value.isPending,
        );
        final AutoPostponeResult automatic = await _runAutomaticPostpone(
          command: command,
          settings: settings,
          runtime: before,
          candidates: candidates,
          outstanding: outstandingBeforePostpone,
          randomNumbers: randomNumbers,
        );
        if (automatic.shouldDisableAutoPostpone) {
          settings = settings.copyWith(
            postpone: settings.postpone.copyWith(
              isAutomaticPostponeEnabled: false,
            ),
          );
        }
        final Set<ElementRef> automaticallyPostponed =
            automatic.smartPostpone?.postponed.toSet() ?? <ElementRef>{};
        final Sm20CollectionState runtime = before.copyWith(
          randomNumberSeed: randomNumbers.state.seed,
          lastAutomaticPostponeDay: automatic.lastAutoRunDay,
          outstanding: <ElementRef>[
            for (final ElementRef ref in before.outstanding)
              if (!automaticallyPostponed.contains(ref)) ref,
          ],
          outstandingItems: <ElementRef>[
            for (final ElementRef ref in before.outstandingItems)
              if (!automaticallyPostponed.contains(ref)) ref,
          ],
          outstandingTopics: <ElementRef>[
            for (final ElementRef ref in before.outstandingTopics)
              if (!automaticallyPostponed.contains(ref)) ref,
          ],
        );
        if (automaticallyPostponed.isNotEmpty) {
          // Rescheduling changed canonical due state; all queue calculations
          // below must observe the replacements written by the same
          // transaction.
          candidates = await loadCandidates(command.day);
          byRef = <ElementRef, QueueCandidate>{
            for (final QueueCandidate candidate in candidates)
              candidate.ref: candidate,
          };
        }

        final List<ElementRef> pending = _orderedRefs(
          runtime.pending,
          candidates.where((QueueCandidate value) => value.isPending),
          byRef: byRef,
          accept: (QueueCandidate value) => value.isPending,
        );
        final List<ElementRef> finalDrill = <ElementRef>[
          for (final ElementRef ref in runtime.finalDrill)
            if (byRef.containsKey(ref)) ref,
        ];

        final List<QueueCandidate> newlyDue = <QueueCandidate>[
          for (final QueueCandidate candidate in candidates)
            if (!candidate.isPending &&
                candidate.isDue(nowUtc: _clock.nowUtc(), today: command.day))
              candidate,
        ];
        final List<ElementRef> outstanding = _orderedRefs(
          runtime.outstanding,
          newlyDue,
          byRef: byRef,
          accept: (QueueCandidate value) => !value.isPending,
        );

        final Set<ElementRef> itemMembership = <ElementRef>{
          for (final ElementRef ref in runtime.outstandingItems)
            if (outstanding.contains(ref) && byRef.containsKey(ref)) ref,
          for (final ElementRef ref in outstanding)
            if (byRef[ref]?.isCard ?? false) ref,
        };
        final bool wasAlreadySorted =
            runtime.lastAutomaticSortDay == command.day;
        final bool shouldSort =
            settings.queue.shouldSortAutomatically &&
            !wasAlreadySorted &&
            outstanding.isNotEmpty;
        final QueuePolicy policy = await _context.queuePolicy();
        final QueuePlan outstandingPlan = policy.build(
          candidates: candidates,
          nowUtc: _clock.nowUtc(),
          today: command.day,
          randomNumbers: randomNumbers,
          combinedOrder: outstanding,
          outstandingItemMembership: itemMembership,
          shouldSort: shouldSort,
        );

        StudyDay? lastSort = runtime.lastAutomaticSortDay;
        List<ElementRef> storedOutstanding = outstanding;
        List<ElementRef> storedItems = <ElementRef>[
          for (final ElementRef ref in runtime.outstandingItems)
            if (outstanding.contains(ref)) ref,
        ];
        List<ElementRef> storedTopics = <ElementRef>[
          for (final ElementRef ref in runtime.outstandingTopics)
            if (outstanding.contains(ref)) ref,
        ];
        if (shouldSort && outstanding.length >= 2) {
          lastSort = command.day;
          storedOutstanding = <ElementRef>[
            for (final QueueCandidate value in outstandingPlan.entries)
              value.ref,
          ];
          storedItems = <ElementRef>[
            for (final QueueCandidate value
                in outstandingPlan.prioritySortedItems)
              value.ref,
          ];
          storedTopics = <ElementRef>[
            for (final QueueCandidate value
                in outstandingPlan.prioritySortedTopics)
              value.ref,
          ];
        } else {
          final Set<ElementRef> storedItemSet = storedItems.toSet();
          final Set<ElementRef> storedTopicSet = storedTopics.toSet();
          for (final ElementRef ref in outstanding) {
            if (storedItemSet.contains(ref) || storedTopicSet.contains(ref)) {
              continue;
            }
            if (byRef[ref]?.isCard ?? false) {
              storedItems.add(ref);
              storedItemSet.add(ref);
            } else {
              storedTopics.add(ref);
              storedTopicSet.add(ref);
            }
          }
        }

        var learningMode = 0;
        QueuePlan visible = outstandingPlan;
        // A stage the user entered by hand outranks the automatic chain and
        // survives reloads. It lapses on its own once its queue is empty,
        // which is what returns the user to Outstanding without a command.
        final bool hasHeldDrill =
            runtime.learningMode == 1 && finalDrill.isNotEmpty;
        final bool hasHeldPending =
            runtime.learningMode == 2 && pending.isNotEmpty;
        if (hasHeldDrill || (visible.isEmpty && finalDrill.isNotEmpty)) {
          learningMode = 1;
          final List<QueueCandidate> drill = <QueueCandidate>[
            for (final ElementRef ref in finalDrill)
              if (byRef[ref] case final QueueCandidate candidate) candidate,
          ];
          if (settings.queue.shouldRandomizeFinalDrill &&
              runtime.learningMode != 1) {
            QueuePolicy.randomizeFixedSize<QueueCandidate>(
              drill,
              randomNumbers,
            );
            finalDrill
              ..clear()
              ..addAll(drill.map((QueueCandidate value) => value.ref));
          }
          visible = QueuePlan.stage(
            candidates: drill,
            lane: QueueLane.finalDrill,
            randomNumberState: randomNumbers.state,
          );
        } else if (hasHeldPending || (visible.isEmpty && pending.isNotEmpty)) {
          learningMode = 2;
          visible = QueuePlan.stage(
            candidates: <QueueCandidate>[
              for (final ElementRef ref in pending)
                if (byRef[ref] case final QueueCandidate candidate) candidate,
            ],
            lane: QueueLane.pending,
            randomNumberState: randomNumbers.state,
          );
        }

        final Sm20CollectionState after = runtime.copyWith(
          randomNumberSeed: randomNumbers.state.seed,
          learningStartDay: runtime.learningStartDay ?? command.day,
          lastAutomaticSortDay: lastSort,
          lastCollectionUseUtc: command.timestampUtc,
          learningMode: learningMode,
          outstanding: storedOutstanding,
          outstandingItems: storedItems,
          outstandingTopics: storedTopics,
          pending: pending,
          finalDrill: finalDrill,
        );
        await _context.saveRuntimeState(after);

        final bool logged = await _learning.hasActivity(
          command.operationId.value,
          kDailyAdmissionType,
        );
        if (!logged) {
          await _learning.appendActivity(
            ActivityRecord(
              id: _ids.newId(),
              operationId: command.operationId.value,
              type: kDailyAdmissionType,
              atUtc: command.timestampUtc,
              metadata: <String, Object?>{
                'day': command.day.toString(),
                'stage': learningMode,
                'sorted': shouldSort && outstanding.length >= 2,
                'auto_postpone_outcome': automatic.outcome.name,
                'automatically_postponed': automaticallyPostponed.length,
                'auto_postpone_overdue': automatic.overdueCount,
                ...visible.counters.toMetadata(),
              },
            ),
          );
          await _transfer.advanceGeneration();
        }
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kDailyAdmissionType,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: <String, Object?>{
              'stage': learningMode,
              'outstanding': storedOutstanding.length,
              'final_drill': finalDrill.length,
              'pending': pending.length,
              'auto_postpone_outcome': automatic.outcome.name,
              'automatically_postponed': automaticallyPostponed.length,
              'prng_seed': randomNumbers.state.seed,
            },
          ),
        );
        return Ok<AdmissionOutcome>(
          AdmissionOutcome(
            plan: visible,
            automaticallyPostponed: automaticallyPostponed.length,
            wasAlreadyApplied: wasAlreadySorted,
          ),
        );
      });
    } on Object catch (error, stackTrace) {
      return Err<AdmissionOutcome>(
        _fail(command, kDailyAdmissionType, error, stackTrace),
      );
    }
  }

  /// Enters Final Drill or Pending on demand, ahead of the automatic chain.
  ///
  /// The stage is stored rather than derived, so the next queue load presents
  /// it even while Outstanding still has elements. Nothing is scheduled,
  /// created, or graded: this only chooses which existing queue is shown.
  Future<Result<Sm20QueueCommandOutcome>> enterLearningStage(
    EnterLearningStage command,
  ) async {
    try {
      return await _transactions.run<Result<Sm20QueueCommandOutcome>>(() async {
        final Sm20CollectionState runtime = await _context.runtimeState();
        final List<ElementRef> queue = switch (command.stage) {
          Sm20StageRequest.outstanding => runtime.outstanding,
          Sm20StageRequest.finalDrill => runtime.finalDrill,
          Sm20StageRequest.newMaterial => runtime.pending,
        };
        if (queue.isEmpty) {
          // The executable greys out a stage whose queue is empty. Refusing
          // here is the same rule stated as an outcome, so a caller that has
          // not disabled the control still cannot land on a blank queue.
          return Err<Sm20QueueCommandOutcome>(
            ValidationFailure(switch (command.stage) {
              Sm20StageRequest.outstanding =>
                'nothing is outstanding right now',
              Sm20StageRequest.finalDrill =>
                'nothing is scheduled for the final drill',
              Sm20StageRequest.newMaterial =>
                'there are no pending elements to learn',
            }),
          );
        }
        await _context.saveRuntimeState(
          runtime.copyWith(learningMode: command.stage.learningMode),
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            type: kEnterStageType,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'stage': command.stage.name,
              'learning_mode': command.stage.learningMode,
              'queue_size': queue.length,
            },
          ),
        );
        return Ok<Sm20QueueCommandOutcome>(
          Sm20QueueCommandOutcome(
            affected: queue.length,
            learningMode: command.stage.learningMode,
          ),
        );
      });
    } on Object catch (error, stackTrace) {
      return Err<Sm20QueueCommandOutcome>(
        _fail(command, kEnterStageType, error, stackTrace),
      );
    }
  }

  /// Cut drills: empties the Final Drill queue.
  ///
  /// Membership is all that goes. Every element keeps its due date, interval,
  /// A, priority and counters, because being in the drill never changed any of
  /// them in the first place.
  Future<Result<Sm20QueueCommandOutcome>> cutDrills(CutDrills command) async {
    try {
      return await _transactions.run<Result<Sm20QueueCommandOutcome>>(() async {
        final Sm20CollectionState runtime = await _context.runtimeState();
        final int removed = runtime.finalDrill.length;
        if (removed == 0) {
          return const Ok<Sm20QueueCommandOutcome>(
            Sm20QueueCommandOutcome(affected: 0, learningMode: 0),
          );
        }
        // Leaving the drill stage selected would present an empty queue, so a
        // cut that empties the current stage falls back to Outstanding.
        final int mode = runtime.learningMode == 1 ? 0 : runtime.learningMode;
        await _context.saveRuntimeState(
          runtime.copyWith(
            finalDrill: const <ElementRef>[],
            learningMode: mode,
          ),
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            type: kCutDrillsType,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{'removed': removed},
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<Sm20QueueCommandOutcome>(
          Sm20QueueCommandOutcome(affected: removed, learningMode: mode),
        );
      });
    } on Object catch (error, stackTrace) {
      return Err<Sm20QueueCommandOutcome>(
        _fail(command, kCutDrillsType, error, stackTrace),
      );
    }
  }

  /// Reorders one stored queue with the section 9.6 fixed-size swap.
  Future<Result<Sm20QueueCommandOutcome>> randomizeQueue(
    RandomizeQueue command,
  ) async {
    try {
      return await _transactions.run<Result<Sm20QueueCommandOutcome>>(() async {
        final Sm20CollectionState runtime = await _context.runtimeState();
        final List<ElementRef> queue = <ElementRef>[
          ...switch (command.queue) {
            Sm20RandomizableQueue.outstanding => runtime.outstanding,
            Sm20RandomizableQueue.finalDrill => runtime.finalDrill,
            Sm20RandomizableQueue.pending => runtime.pending,
          },
        ];
        if (queue.length < 2) {
          return Ok<Sm20QueueCommandOutcome>(
            Sm20QueueCommandOutcome(
              affected: queue.length,
              learningMode: runtime.learningMode,
            ),
          );
        }
        // One shared stream: a manual reshuffle advances it exactly as the
        // automatic randomizations do, and every later draw moves with it.
        final Sm20RandomNumberGenerator randomNumbers =
            Sm20RandomNumberGenerator(seed: runtime.randomNumberSeed);
        QueuePolicy.randomizeFixedSize<ElementRef>(queue, randomNumbers);
        final Sm20CollectionState next = switch (command.queue) {
          // The combined order is what the user sees; the per-type lists stay
          // as they are, exactly as the daily sort leaves them.
          Sm20RandomizableQueue.outstanding => runtime.copyWith(
            outstanding: queue,
          ),
          Sm20RandomizableQueue.finalDrill => runtime.copyWith(
            finalDrill: queue,
          ),
          Sm20RandomizableQueue.pending => runtime.copyWith(pending: queue),
        };
        await _context.saveRuntimeState(
          next.copyWith(randomNumberSeed: randomNumbers.state.seed),
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            type: kRandomizeQueueType,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'queue': command.queue.name,
              'count': queue.length,
              'prng_seed': randomNumbers.state.seed,
            },
          ),
        );
        return Ok<Sm20QueueCommandOutcome>(
          Sm20QueueCommandOutcome(
            affected: queue.length,
            learningMode: runtime.learningMode,
          ),
        );
      });
    } on Object catch (error, stackTrace) {
      return Err<Sm20QueueCommandOutcome>(
        _fail(command, kRandomizeQueueType, error, stackTrace),
      );
    }
  }

  /// Runs manual Smart Postpone or its write-free simulation.
  Future<Result<AppliedSmartPostpone>> runSmartPostpone(
    RunSmartPostpone command,
  ) async {
    try {
      return await _transactions.run<Result<AppliedSmartPostpone>>(() async {
        final AppSettings settings = await _context.settings();
        final Sm20CollectionState runtime = await _context.runtimeState();
        var profile = command.profile ?? settings.postpone.defaultProfile;
        List<ElementRef> sourceRefs;
        if (profile.scope == SmartPostponeScope.global) {
          sourceRefs = runtime.outstanding;
        } else if (command.sourcePopulation != null) {
          sourceRefs = command.sourcePopulation!;
        } else if (profile.scope == SmartPostponeScope.browser) {
          // The executable changes a browser scope with no current browser
          // back to global Outstanding before dispatch.
          profile = profile.copyWith(scope: SmartPostponeScope.global);
          sourceRefs = runtime.outstanding;
        } else {
          final List<ElementSchedule> schedules = await _learning.listSchedules(
            types: ElementType.values.toSet(),
          );
          sourceRefs = <ElementRef>[
            for (final ElementSchedule schedule in schedules)
              if (schedule.rootId == profile.rootElementId.toString())
                schedule.ref,
          ];
        }

        final List<QueueCandidate> candidates = await _loadCandidatesForRefs(
          sourceRefs,
        );
        final Set<ElementRef> outstanding = runtime.outstanding.toSet();
        final List<Sm20PostponeCandidate> source = await _postponeCandidates(
          candidates: candidates,
          outstanding: outstanding,
          atUtc: command.timestampUtc,
        );
        final Sm20RandomNumberGenerator randomNumbers =
            Sm20RandomNumberGenerator(seed: runtime.randomNumberSeed);
        final SmartPostponeResult result = const SmartPostponeEngine().run(
          source: source,
          profile: profile,
          priorityScale: await _context.priorityScale(),
          today: command.day,
          randomNumbers: randomNumbers,
          applicableSubbranchProfiles: command.applicableSubbranchProfiles,
        );
        if (result.profile.isSimulationOnly) {
          return Ok<AppliedSmartPostpone>(
            AppliedSmartPostpone(result: result, written: 0),
          );
        }

        final int written = await _applySmartPostpone(
          operationId: command.operationId.value,
          atUtc: command.timestampUtc,
          today: command.day,
          candidates: candidates,
          result: result,
          eventType: ReviewLogEventType.postpone,
        );
        final Set<ElementRef> moved = result.postponed.toSet();
        await _context.saveRuntimeState(
          runtime.copyWith(
            randomNumberSeed: randomNumbers.state.seed,
            outstanding: runtime.outstanding
                .where((ElementRef ref) => !moved.contains(ref))
                .toList(),
            outstandingItems: runtime.outstandingItems
                .where((ElementRef ref) => !moved.contains(ref))
                .toList(),
            outstandingTopics: runtime.outstandingTopics
                .where((ElementRef ref) => !moved.contains(ref))
                .toList(),
          ),
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            type: kSmartPostponeType,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'profile': result.profile.profileName,
              'scope': result.profile.scope.name,
              'source_count': result.sourceOrder.length,
              'postponed': result.postponed.length,
              'unpostponed': result.unpostponed.length,
              'forced_pass': result.didForcedPassRun,
              'random_draws': result.randomDraws,
              'warning_count': result.warningCount,
            },
          ),
        );
        if (written > 0) await _transfer.advanceGeneration();
        return Ok<AppliedSmartPostpone>(
          AppliedSmartPostpone(result: result, written: written),
        );
      });
    } on Object catch (error, stackTrace) {
      return Err<AppliedSmartPostpone>(
        _fail(command, kSmartPostponeType, error, stackTrace),
      );
    }
  }

  /// Runs the executable's one-shot automatic Smart Postpone entry point and
  /// applies every selected low-level reschedule inside the queue transaction.
  Future<AutoPostponeResult> _runAutomaticPostpone({
    required RunDailyAdmission command,
    required AppSettings settings,
    required Sm20CollectionState runtime,
    required List<QueueCandidate> candidates,
    required List<ElementRef> outstanding,
    required Sm20RandomNumberGenerator randomNumbers,
  }) async {
    final PriorityScale priorityScale = await _context.priorityScale();
    final List<Sm20PostponeCandidate> scheduled = await _postponeCandidates(
      candidates: candidates,
      outstanding: outstanding.toSet(),
      atUtc: command.timestampUtc,
    );

    final AutoPostponeResult automatic = const AutoPostponeEngine().run(
      AutoPostponeRequest(
        today: command.day,
        nowUtc: command.timestampUtc,
        isAutomaticPostponeEnabled:
            settings.postpone.isAutomaticPostponeEnabled,
        lastAutoRunDay: runtime.lastAutomaticPostponeDay,
        isCollectionNonEmpty: candidates.isNotEmpty,
        lastCollectionUseUtc: runtime.lastCollectionUseUtc,
        isForced: false,
        combinedOutstandingCount: outstanding.length,
        collectionLearningStartDay: runtime.learningStartDay ?? command.day,
        scheduledElements: scheduled,
        defaultProfile: settings.postpone.defaultProfile,
        priorityScale: priorityScale,
      ),
      randomNumbers,
    );

    if (automatic.shouldDisableAutoPostpone) {
      final Result<AppSettings> saved = await _context.saveSettings(
        settings.copyWith(
          postpone: settings.postpone.copyWith(
            isAutomaticPostponeEnabled: false,
          ),
        ),
      );
      if (saved case Err<AppSettings>(:final failure)) {
        throw StateError(failure.message);
      }
    }

    final SmartPostponeResult? result = automatic.smartPostpone;
    if (result == null || result.decisions.isEmpty) return automatic;
    await _applySmartPostpone(
      operationId: command.operationId.value,
      atUtc: command.timestampUtc,
      today: command.day,
      candidates: candidates,
      result: result,
      eventType: ReviewLogEventType.autoPostpone,
    );
    return automatic;
  }

  /// All active topic records and card memories. Due filtering belongs to the
  /// queue transaction because existing queue membership can intentionally
  /// contain a future repetition added by a browser command.
  Future<List<QueueCandidate>> loadCandidates(StudyDay day) async {
    final List<ElementSchedule> topicSchedules = await _learning.listSchedules(
      types: const <ElementType>{
        ElementType.source,
        ElementType.extract,
        ElementType.video,
      },
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
    return <QueueCandidate>[
      for (final ElementSchedule schedule in topicSchedules)
        if (topics[schedule.ref] case final TopicState topic)
          if (topic.status != Sm20ElementStatus.dismissed &&
              topic.status != Sm20ElementStatus.deleted)
            QueueCandidate.topic(topic, rootId: schedule.rootId),
      for (final CardState card in cards)
        QueueCandidate.card(card, rootId: card.schedule.rootId),
    ];
  }

  /// Resolves an explicit source population, preserving the caller's order.
  ///
  /// Unlike [loadCandidates] this keeps non-Active records: a branch or
  /// browser Smart Postpone source legitimately contains dismissed, suspended,
  /// and pending elements, and the postpone engine — not this loader — is what
  /// decides they are ineligible.
  Future<List<QueueCandidate>> _loadCandidatesForRefs(
    List<ElementRef> refs,
  ) async {
    final List<ElementRef> topicRefs = <ElementRef>[];
    final List<String> cardIds = <String>[];
    final Set<ElementRef> seen = <ElementRef>{};
    final List<ElementRef> ordered = <ElementRef>[];
    for (final ElementRef ref in refs) {
      if (!seen.add(ref)) continue;
      ordered.add(ref);
      if (ref.type == ElementType.card) {
        cardIds.add(ref.id);
      } else {
        topicRefs.add(ref);
      }
    }
    final Map<ElementRef, TopicState> topics = await _learning.findTopics(
      topicRefs,
    );
    final Map<String, CardState> cards = await _learning.findCardStates(
      cardIds,
    );
    final List<QueueCandidate> candidates = <QueueCandidate>[];
    for (final ElementRef ref in ordered) {
      if (ref.type == ElementType.card) {
        final CardState? card = cards[ref.id];
        if (card != null) {
          candidates.add(
            QueueCandidate.card(card, rootId: card.schedule.rootId),
          );
        }
      } else {
        final TopicState? topic = topics[ref];
        if (topic != null) {
          candidates.add(
            QueueCandidate.topic(topic, rootId: topic.schedule.rootId),
          );
        }
      }
    }
    return candidates;
  }

  /// Projects live records onto the postpone engine's input record.
  ///
  /// Both the automatic and the manual entry points build their population
  /// here so a profile cannot mean two different things depending on which
  /// button ran it.
  Future<List<Sm20PostponeCandidate>> _postponeCandidates({
    required List<QueueCandidate> candidates,
    required Set<ElementRef> outstanding,
    required DateTime atUtc,
  }) async {
    final StudyDayCalendar calendar = await _context.calendar();
    final CardScheduler cardScheduler = await _context.cardScheduler();
    final List<Sm20PostponeCandidate> source = <Sm20PostponeCandidate>[];
    for (final QueueCandidate candidate in candidates) {
      final ElementRef ref = candidate.ref;
      if (candidate.isCard) {
        final CardState card = candidate.card!;
        final CardMemory memory = card.memory;
        // Reps, not the FSRS learning state, decide memorization: FSRS calls a
        // never-reviewed card Learning, and SM20 treats that record as Pending.
        final bool isMemorized = memory.repetitionCount > 0;
        source.add(
          Sm20PostponeCandidate(
            ref: ref,
            priority: card.schedule.priority,
            storedInterval: memory.scheduledDays == null
                ? 0
                : math.max(memory.scheduledDays!.round(), 0),
            lastReviewDay: memory.lastReviewAtUtc == null
                ? null
                : calendar.dayOf(memory.lastReviewAtUtc!),
            totalPostponements: memory.postponeCount,
            isOutstanding: outstanding.contains(ref),
            isMemorized: isMemorized,
            scheduledDay: calendar.dayOf(memory.dueAtUtc),
            // A never-reviewed card has no measurable retrievability, and the
            // executable evaluates such a record against the fixed default
            // forgetting index rather than skipping it.
            forgettingIndex: isMemorized
                ? 100 * (1 - cardScheduler.retrievability(memory, atUtc: atUtc))
                : 10,
            isDeleted: card.schedule.lifecycle == ElementLifecycle.deleted,
          ),
        );
      } else {
        final TopicState topic = candidate.topic!;
        source.add(
          Sm20PostponeCandidate(
            ref: ref,
            priority: topic.schedule.priority,
            storedInterval: math.max(topic.storedInterval, 0),
            lastReviewDay: topic.lastReviewDay,
            totalPostponements: topic.totalPostponementCount,
            isOutstanding: outstanding.contains(ref),
            isMemorized: topic.status == Sm20ElementStatus.memorized,
            scheduledDay: topic.schedule.algorithmicDueDay,
            aFactor: topic.aFactor,
            isDeleted: topic.status == Sm20ElementStatus.deleted,
          ),
        );
      }
    }
    return source;
  }

  /// Writes every real decision as a low-level reschedule.
  ///
  /// This is not a repetition: A, priority, repetitions, and lapses are left
  /// alone, and the only last-review movement is the target-at-or-before
  /// correction the section 8.1 rescheduler performs itself. A simulation
  /// never reaches here, so nothing it computed can leak into storage.
  Future<int> _applySmartPostpone({
    required String operationId,
    required DateTime atUtc,
    required StudyDay today,
    required List<QueueCandidate> candidates,
    required SmartPostponeResult result,
    required ReviewLogEventType eventType,
  }) async {
    final List<SmartPostponeDecision> writes = <SmartPostponeDecision>[
      for (final SmartPostponeDecision decision in result.decisions)
        if (decision.writesRecord) decision,
    ];
    if (writes.isEmpty) return 0;

    final Map<ElementRef, QueueCandidate> byRef = <ElementRef, QueueCandidate>{
      for (final QueueCandidate candidate in candidates)
        candidate.ref: candidate,
    };
    final StudyDayCalendar calendar = await _context.calendar();
    final PriorityScale scale = await _context.priorityScale();
    final TopicScheduler topicScheduler = await _context.topicScheduler();
    final CardScheduler cardScheduler = await _context.cardScheduler();
    final SchedulingJournal journal = SchedulingJournal(
      learning: _learning,
      ids: _ids,
    );
    final List<ReviewLogEntry> reviewLog = <ReviewLogEntry>[];
    var written = 0;

    for (final SmartPostponeDecision decision in writes) {
      final QueueCandidate? candidate = byRef[decision.ref];
      if (candidate == null) continue;
      final String itemOperation =
          '$operationId:${decision.ref.type.name}:${decision.ref.id}';
      final Map<String, Object?> metadata = <String, Object?>{
        'pass': decision.pass.name,
        'delay_days': decision.delayDays,
        'factor': decision.factor,
        'new_interval_days': decision.newIntervalDays,
        'target_day': decision.targetDay.toString(),
        'priority_percent': decision.priorityPercent,
        'age_days': decision.ageDays,
        'warns_above_two_hundred_days': decision.warnsAboveTwoHundredDays,
        'profile': result.profile.profileName,
      };
      if (candidate.isCard) {
        final CardState before = candidate.card!;
        final CardState moved = cardScheduler.rescheduleElement(
          before,
          targetDay: decision.targetDay,
          today: today,
        );
        final CardState after = moved.copyWith(
          schedule: moved.schedule.copyWith(updatedAtUtc: atUtc),
        );
        await _learning.saveCardState(after);
        reviewLog.add(
          journal.build(
            operationId: itemOperation,
            ref: decision.ref,
            eventType: eventType,
            atUtc: atUtc,
            before: journal.cardSnapshot(
              before,
              pressure: scale.pressureOf(before.schedule.priority),
            ),
            after: journal.cardSnapshot(
              after,
              pressure: scale.pressureOf(after.schedule.priority),
            ),
            scheduledDays: after.memory.scheduledDays,
            postponeCount: after.memory.postponeCount,
            schedulerVersion: after.memory.schedulerVersion,
            parametersVersion: after.memory.parametersVersion,
            metadata: metadata,
          ),
        );
      } else {
        final TopicState before = candidate.topic!;
        final TopicTransition moved = topicScheduler.rescheduleElement(
          before,
          targetDay: decision.targetDay,
          today: today,
        );
        final TopicState after = moved.state.copyWith(
          schedule: moved.state.schedule.copyWith(updatedAtUtc: atUtc),
        );
        await _learning.saveTopic(after);
        reviewLog.add(
          journal.build(
            operationId: itemOperation,
            ref: decision.ref,
            eventType: eventType,
            atUtc: atUtc,
            before: journal.topicSnapshot(
              before,
              calendar: calendar,
              pressure: scale.pressureOf(before.schedule.priority),
            ),
            after: journal.topicSnapshot(
              after,
              calendar: calendar,
              pressure: scale.pressureOf(after.schedule.priority),
            ),
            scheduledDays: after.intervalDays,
            postponeCount: after.totalPostponementCount,
            schedulerVersion: after.schedulerVersion,
            metadata: metadata,
          ),
        );
      }
      written += 1;
    }

    if (reviewLog.isNotEmpty) await _learning.appendReviewLogBatch(reviewLog);
    return written;
  }

  ContentRepository get content => _content;

  List<ElementRef> _orderedRefs(
    Iterable<ElementRef> existing,
    Iterable<QueueCandidate> additions, {
    required Map<ElementRef, QueueCandidate> byRef,
    required bool Function(QueueCandidate) accept,
  }) {
    final Set<ElementRef> seen = <ElementRef>{};
    final List<ElementRef> result = <ElementRef>[];
    for (final ElementRef ref in existing) {
      // Existing queue membership is retained only while a live schedule
      // still exists. It need not be due: Add to Outstanding can put a future
      // repetition here deliberately.
      final QueueCandidate? candidate = byRef[ref];
      if (candidate != null && accept(candidate) && seen.add(ref)) {
        result.add(ref);
      }
    }
    // Remove stale refs by consulting all active schedules through additions
    // when additions represents the full accepted population. The caller
    // performs a second safety filter below for the due-only Outstanding set.
    for (final QueueCandidate candidate in additions) {
      if (accept(candidate) && seen.add(candidate.ref)) {
        result.add(candidate.ref);
      }
    }
    return result;
  }

  UnexpectedFailure _fail(
    AppCommand command,
    String type,
    Object error,
    StackTrace stackTrace,
  ) {
    final UnexpectedFailure failure = UnexpectedFailure(
      'command $type failed',
      cause: error,
      stackTrace: stackTrace,
    );
    _diagnostics.record(
      DiagnosticEvent(
        level: DiagnosticLevel.error,
        name: type,
        timestampUtc: _clock.nowUtc(),
        operationId: command.operationId,
        failure: failure,
      ),
    );
    return failure;
  }
}
