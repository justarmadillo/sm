/// Canonical preview, apply, and undo transactions for SM20 Mercy.
library;

import 'dart:math' as math;

import 'package:incremental_reader/features/daily_queue/queue_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/mercy/mercy.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kMercyPreviewedKind = 'mercy.previewed';
const String kMercyAppliedKind = 'mercy.applied';
const String kMercyUndoneKind = 'mercy.undone';

/// Handles the app's durable confirmation wrapper around SM20 Mercy.
final class MercyCommandRunner {
  MercyCommandRunner({
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required QueueCommandRunner queue,
    required IdGenerator ids,
  }) : _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _queue = queue,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids);

  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final QueueCommandRunner _queue;
  final IdGenerator _ids;
  final SchedulingJournal _journal;

  /// Computes and stores the exact assignment list. No element is changed.
  Future<Result<StoredMercyBatch>> preview(PreviewMercy command) async {
    try {
      return await _transactions.run<Result<StoredMercyBatch>>(() async {
        final StoredMercyBatch? replayed = await _learning
            .findMercyBatchByPreviewOperation(command.operationId.value);
        if (replayed != null) return Ok<StoredMercyBatch>(replayed);

        final AppSettings app = await _context.settings();
        final MercySettings settings = app.mercy;
        // A collection that has never customized its matrix falls back to
        // SM20's own starting table rather than refusing to run.
        final Sm20MercyMatrix matrix = Sm20MercyMatrix.fromSettings(settings);

        final StudyDayCalendar calendar = await _context.calendar();
        final PriorityScale priorityScale = await _context.priorityScale();
        final Sm20CollectionState runtime = await _context.runtimeState();
        final StudyDay learningStart = runtime.learningStartDay ?? command.day;
        final List<QueueCandidate> loaded = await _queue.loadCandidates(
          command.day,
        );
        final Map<ElementRef, QueueCandidate> byRef =
            <ElementRef, QueueCandidate>{
              for (final QueueCandidate value in loaded) value.ref: value,
            };

        final bool shouldIncludeFuture =
            command.shouldIncludeFuture ?? settings.shouldIncludeFuture;
        var reschedulingDays =
            command.reschedulingDays ?? settings.reschedulingDays;
        var gatheringDays = command.gatheringDays ?? settings.gatheringDays;
        final Sm20ScheduledCounts scheduledCounts = Sm20ScheduledCounts(
          <StudyDay, int>{
            for (final QueueCandidate value in loaded)
              _scheduledDay(value, calendar): 0,
          }..updateAll(
            (StudyDay day, int _) => loaded
                .where(
                  (QueueCandidate value) =>
                      _isScheduled(value) &&
                      _scheduledDay(value, calendar) == day,
                )
                .length,
          ),
        );
        final Sm20MercyCapacity capacity =
            !command.shouldSolveFromDailyCap || command.elementsPerDay == null
            ? const Sm20MercyCapacityPlanner().afterHorizonEdit(
                today: command.day,
                collectionLearningStartDay: learningStart,
                reschedulingDays: reschedulingDays,
                gatheringDays: gatheringDays,
                shouldIncludeFuture: shouldIncludeFuture,
                scheduledCounts: scheduledCounts,
                subsetCandidateCount: command.subset?.length,
              )
            : const Sm20MercyCapacityPlanner().afterDailyCapEdit(
                today: command.day,
                collectionLearningStartDay: learningStart,
                elementsPerDay: command.elementsPerDay!,
                gatheringDays: gatheringDays,
                shouldIncludeFuture: shouldIncludeFuture,
                scheduledCounts: scheduledCounts,
                subsetCandidateCount: command.subset?.length,
              );
        if (capacity.reschedulingDays < 1) {
          return const Err<StoredMercyBatch>(
            ValidationFailure('there is nothing for Mercy to redistribute'),
          );
        }
        reschedulingDays = capacity.reschedulingDays;
        gatheringDays = capacity.gatheringDays;

        final Map<ElementRef, String> canonical = <ElementRef, String>{};
        final List<Sm20MercyCandidate> candidates = <Sm20MercyCandidate>[];
        if (command.subset case final List<ElementRef> subset) {
          for (final ElementRef ref in subset) {
            final QueueCandidate? value = byRef[ref];
            if (value == null) {
              candidates.add(
                Sm20MercyCandidate(
                  ref: ref,
                  priority: PriorityRank.middle,
                  scheduledDay: command.day,
                  lastReviewDay: null,
                  repetitionCount: 0,
                  lapseCount: 0,
                  isScheduled: false,
                  isDeleted: true,
                ),
              );
              continue;
            }
            candidates.add(
              _candidate(value, calendar: calendar, canonical: canonical),
            );
          }
        } else {
          for (final QueueCandidate value in loaded) {
            candidates.add(
              _candidate(value, calendar: calendar, canonical: canonical),
            );
          }
        }

        final Sm20Prng prng = Sm20Prng(seed: runtime.prngSeed);
        final Sm20MercyPlan plan = const Sm20MercyEngine().plan(
          candidates: candidates,
          gatherMode: command.subset == null
              ? Sm20MercyGatherMode.collection
              : Sm20MercyGatherMode.subset,
          today: command.day,
          collectionLearningStartDay: learningStart,
          gatheringDays: gatheringDays,
          reschedulingDays: reschedulingDays,
          mode: command.mode ?? settings.mode,
          matrix: matrix,
          weights: Sm20MercyWeights.fromSettings(settings),
          priorityScale: priorityScale,
          prng: prng,
        );
        final MercyPreview preview = MercyPreview.fromPlan(
          plan: plan,
          today: command.day,
          collectionLearningStartDay: learningStart,
          gatheringDays: gatheringDays,
          mode: command.mode ?? settings.mode,
          gatherMode: command.subset == null
              ? Sm20MercyGatherMode.collection
              : Sm20MercyGatherMode.subset,
          prngSeedBefore: runtime.prngSeed,
          canonicalStates: canonical,
        );
        final StoredMercyBatch batch = StoredMercyBatch(
          batchId: _ids.newId(),
          previewOperationId: command.operationId.value,
          policyVersion: kSm20MercyPolicyVersion,
          previewJson: preview.toJson(),
          createdAtUtc: command.timestampUtc,
        );
        await _learning.saveMercyBatch(batch);
        await _context.saveRuntimeState(
          runtime.copyWith(
            prngSeed: plan.prngState.seed,
            learningStartDay: runtime.learningStartDay ?? command.day,
          ),
        );
        await _learning.appendSchedulerEvent(
          SchedulerEvent(
            id: _ids.newId(),
            operationId: command.operationId.value,
            eventType: SchedulerEventType.mercyPreviewed,
            occurredAtUtc: command.timestampUtc,
            studyDay: command.day,
            policyVersion: kSm20MercyPolicyVersion,
            batchId: batch.batchId,
            metadata: <String, Object?>{
              'selected': preview.selectedCount,
              'gathered': preview.gatheredCount,
              'rescheduling_days': preview.reschedulingDays,
              'gathering_days': preview.gatheringDays,
              'mode': preview.mode.index,
              'random_draws': preview.randomDraws,
            },
          ),
        );
        await _activity(
          command.operationId.value,
          kMercyPreviewedKind,
          command.timestampUtc,
          <String, Object?>{
            'batch_id': batch.batchId,
            'selected': preview.selectedCount,
            'gathered': preview.gatheredCount,
          },
        );
        await _transfer.advanceGeneration();
        return Ok<StoredMercyBatch>(batch);
      });
    } on RangeError catch (error) {
      return Err<StoredMercyBatch>(ValidationFailure('$error'));
    } on ArgumentError catch (error) {
      return Err<StoredMercyBatch>(ValidationFailure('$error'));
    } on StateError catch (error) {
      return Err<StoredMercyBatch>(ValidationFailure(error.message));
    } on Object catch (error, stackTrace) {
      return Err<StoredMercyBatch>(
        UnexpectedFailure(
          'Mercy preview failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Applies every assignment through the canonical low-level rescheduler.
  Future<Result<int>> apply(ApplyMercy command) async {
    try {
      return await _transactions.run<Result<int>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kMercyAppliedKind,
        )) {
          return const Err<int>(
            ConflictFailure('that Mercy operation was already applied'),
          );
        }
        final StoredMercyBatch? stored = await _learning.findMercyBatch(
          command.batchId,
        );
        if (stored == null) {
          return Err<int>(
            NotFoundFailure(
              'that Mercy preview is no longer available',
              entity: 'mercy_batch',
              id: command.batchId,
            ),
          );
        }
        if (stored.appliedAtUtc != null) {
          return const Err<int>(
            ConflictFailure('that Mercy batch was already applied'),
          );
        }
        final MercyPreview preview = stored.preview;
        if (preview.today != command.day) {
          return const Err<int>(
            ConflictFailure('that Mercy preview belongs to another study day'),
          );
        }

        final Map<ElementRef, TopicState> topics = await _learning
            .findTopics(<ElementRef>[
              for (final MercyPreviewItem item in preview.items)
                if (item.ref.type.isTopic) item.ref,
            ]);
        final Map<String, CardState> cards = await _learning
            .findCardStates(<String>[
              for (final MercyPreviewItem item in preview.items)
                if (item.ref.type == ElementType.card) item.ref.id,
            ]);
        final List<ElementRef> changedRefs = <ElementRef>[];
        for (final MercyPreviewItem item in preview.items) {
          String? current;
          if (item.ref.type == ElementType.card) {
            final CardState? value = cards[item.ref.id];
            if (value != null) current = encodeMercyCardState(value);
          } else {
            final TopicState? value = topics[item.ref];
            if (value != null) current = encodeMercyTopicState(value);
          }
          if (current != item.canonicalBefore) changedRefs.add(item.ref);
        }
        if (changedRefs.isNotEmpty) {
          throw StaleMercyPreview(
            'elements changed after the Mercy preview',
            changedRefs: changedRefs,
          );
        }

        final StudyDayCalendar calendar = await _context.calendar();
        final PriorityScale scale = await _context.priorityScale();
        final TopicScheduler topicScheduler = await _context.topicScheduler();
        final CardScheduler cardScheduler = await _context.cardScheduler();
        final String batchEventId = _ids.newId();
        final List<SchedulerEvent> events = <SchedulerEvent>[];
        final List<RevlogEntry> revlog = <RevlogEntry>[];
        final List<MercyAppliedItemSnapshot> snapshots =
            <MercyAppliedItemSnapshot>[];

        for (final MercyPreviewItem item in preview.items) {
          final String itemOperation =
              '${command.operationId.value}:item:${item.ref.type.name}:${item.ref.id}';
          final String eventId = _ids.newId();
          if (item.ref.type == ElementType.card) {
            final CardState before = cards[item.ref.id]!;
            final CardState moved = cardScheduler.rescheduleElement(
              before,
              targetDay: item.toDay,
              today: command.day,
            );
            final CardState after = moved.copyWith(
              schedule: moved.schedule.copyWith(
                updatedAtUtc: command.timestampUtc,
              ),
            );
            if (!await _learning.compareAndSwapCardState(
              expected: before,
              replacement: after,
            )) {
              throw StaleMercyPreview('card changed during Mercy apply');
            }
            final String beforeJson = encodeMercyCardState(before);
            final String afterJson = encodeMercyCardState(after);
            snapshots.add(
              MercyAppliedItemSnapshot(
                ref: item.ref,
                beforeState: beforeJson,
                afterState: afterJson,
                fromDay: item.fromDay,
                toDay: item.toDay,
                appliedEventId: eventId,
              ),
            );
            events.add(
              _itemEvent(
                id: eventId,
                operationId: itemOperation,
                type: SchedulerEventType.mercyApplied,
                command: command,
                stored: stored,
                ref: item.ref,
                schedulerName: after.memory.schedulerName,
                schedulerVersion: after.memory.schedulerVersion,
                beforeState: beforeJson,
                afterState: afterJson,
                dueBefore: SchedulerEvent.encodeUtcDue(before.memory.dueAtUtc),
                dueAfter: SchedulerEvent.encodeUtcDue(after.memory.dueAtUtc),
                item: item,
              ),
            );
            revlog.add(
              _journal.build(
                operationId: itemOperation,
                ref: item.ref,
                eventType: RevlogEventType.mercy,
                atUtc: command.timestampUtc,
                before: _journal.cardSnapshot(
                  before,
                  pressure: scale.pressureOf(before.schedule.priority),
                ),
                after: _journal.cardSnapshot(
                  after,
                  pressure: scale.pressureOf(after.schedule.priority),
                ),
                scheduledDays: after.memory.scheduledDays,
                postponeCount: after.memory.postponeCount,
                schedulerVersion: after.memory.schedulerVersion,
                parametersVersion: after.memory.parametersVersion,
                metadata: _itemMetadata(item),
              ),
            );
          } else {
            final TopicState before = topics[item.ref]!;
            final TopicTransition moved = topicScheduler.rescheduleElement(
              before,
              targetDay: item.toDay,
              today: command.day,
            );
            final TopicState after = moved.state.copyWith(
              schedule: moved.state.schedule.copyWith(
                updatedAtUtc: command.timestampUtc,
              ),
            );
            if (!await _learning.compareAndSwapTopic(
              expected: before,
              replacement: after,
            )) {
              throw StaleMercyPreview('topic changed during Mercy apply');
            }
            final String beforeJson = encodeMercyTopicState(before);
            final String afterJson = encodeMercyTopicState(after);
            snapshots.add(
              MercyAppliedItemSnapshot(
                ref: item.ref,
                beforeState: beforeJson,
                afterState: afterJson,
                fromDay: item.fromDay,
                toDay: item.toDay,
                appliedEventId: eventId,
              ),
            );
            events.add(
              _itemEvent(
                id: eventId,
                operationId: itemOperation,
                type: SchedulerEventType.mercyApplied,
                command: command,
                stored: stored,
                ref: item.ref,
                schedulerName: after.schedulerName,
                schedulerVersion: after.schedulerVersion,
                beforeState: beforeJson,
                afterState: afterJson,
                dueBefore: SchedulerEvent.encodeStudyDayDue(
                  before.schedule.algorithmicDueDay,
                ),
                dueAfter: SchedulerEvent.encodeStudyDayDue(
                  after.schedule.algorithmicDueDay,
                ),
                item: item,
              ),
            );
            revlog.add(
              _journal.build(
                operationId: itemOperation,
                ref: item.ref,
                eventType: RevlogEventType.mercy,
                atUtc: command.timestampUtc,
                before: _journal.topicSnapshot(
                  before,
                  calendar: calendar,
                  pressure: scale.pressureOf(before.schedule.priority),
                ),
                after: _journal.topicSnapshot(
                  after,
                  calendar: calendar,
                  pressure: scale.pressureOf(after.schedule.priority),
                ),
                scheduledDays: after.intervalDays,
                postponeCount: after.totalPostponementCount,
                schedulerVersion: after.schedulerVersion,
                metadata: _itemMetadata(item),
              ),
            );
          }
        }

        events.insert(
          0,
          SchedulerEvent(
            id: batchEventId,
            operationId: command.operationId.value,
            eventType: SchedulerEventType.mercyApplied,
            occurredAtUtc: command.timestampUtc,
            studyDay: command.day,
            policyVersion: stored.policyVersion,
            batchId: stored.batchId,
            metadata: <String, Object?>{
              'item_count': snapshots.length,
              'rescheduling_days': preview.reschedulingDays,
              'gathering_days': preview.gatheringDays,
              'mode': preview.mode.index,
            },
          ),
        );
        await _learning.appendSchedulerEvents(events);
        await _journal.appendAll(revlog);

        final Sm20CollectionState runtime = await _context.runtimeState();
        await _context.saveRuntimeState(
          _runtimeAfterMercy(runtime, preview.items, today: command.day),
        );
        final MercyAppliedBatchSnapshot undo = MercyAppliedBatchSnapshot(
          batchId: stored.batchId,
          appliedEventId: batchEventId,
          policyVersion: stored.policyVersion,
          studyDay: command.day,
          items: List<MercyAppliedItemSnapshot>.unmodifiable(snapshots),
        );
        await _learning.saveMercyBatch(
          stored.copyWith(
            applyOperationId: command.operationId.value,
            appliedSnapshotJson: encodeMercyAppliedBatch(undo),
            appliedAtUtc: command.timestampUtc,
          ),
        );
        await _activity(
          command.operationId.value,
          kMercyAppliedKind,
          command.timestampUtc,
          <String, Object?>{
            'batch_id': stored.batchId,
            'moved': snapshots.length,
          },
        );
        await _transfer.advanceGeneration();
        return Ok<int>(snapshots.length);
      });
    } on StaleMercyPreview catch (error) {
      return Err<int>(
        ConflictFailure('${error.message}. Preview Mercy again.'),
      );
    } on ArgumentError catch (error) {
      return Err<int>(ValidationFailure('$error'));
    } on StateError catch (error) {
      return Err<int>(ValidationFailure(error.message));
    } on Object catch (error, stackTrace) {
      return Err<int>(
        UnexpectedFailure(
          'Mercy apply failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Restores the exact canonical states replaced by the most recent batch.
  Future<Result<int>> undo(UndoMercy command) async {
    try {
      return await _transactions.run<Result<int>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kMercyUndoneKind,
        )) {
          return const Err<int>(
            ConflictFailure('that undo was already applied'),
          );
        }
        final StoredMercyBatch? stored = await _learning.findMercyBatch(
          command.batchId,
        );
        if (stored == null || stored.appliedSnapshotJson == null) {
          return Err<int>(
            NotFoundFailure(
              'no applied Mercy batch with that id',
              entity: 'mercy_batch',
              id: command.batchId,
            ),
          );
        }
        if (stored.undoneAtUtc != null) {
          return const Err<int>(
            ConflictFailure('that Mercy batch was already undone'),
          );
        }
        final MercyAppliedBatchSnapshot applied = stored.appliedSnapshot;
        final Map<ElementRef, TopicState> topics = await _learning
            .findTopics(<ElementRef>[
              for (final MercyAppliedItemSnapshot item in applied.items)
                if (item.ref.type.isTopic) item.ref,
            ]);
        final Map<String, CardState> cards = await _learning
            .findCardStates(<String>[
              for (final MercyAppliedItemSnapshot item in applied.items)
                if (item.ref.type == ElementType.card) item.ref.id,
            ]);
        final List<ElementRef> changedRefs = <ElementRef>[];
        for (final MercyAppliedItemSnapshot item in applied.items) {
          String? current;
          if (item.ref.type == ElementType.card) {
            final CardState? value = cards[item.ref.id];
            if (value != null) current = encodeMercyCardState(value);
          } else {
            final TopicState? value = topics[item.ref];
            if (value != null) current = encodeMercyTopicState(value);
          }
          if (current != item.afterState) changedRefs.add(item.ref);
        }
        if (changedRefs.isNotEmpty) {
          throw StaleMercyPreview(
            'elements changed after Mercy was applied',
            changedRefs: changedRefs,
          );
        }

        final StudyDayCalendar calendar = await _context.calendar();
        final PriorityScale scale = await _context.priorityScale();
        final List<SchedulerEvent> events = <SchedulerEvent>[];
        final List<RevlogEntry> revlog = <RevlogEntry>[];
        for (final MercyAppliedItemSnapshot item in applied.items) {
          final String itemOperation =
              '${command.operationId.value}:item:${item.ref.type.name}:${item.ref.id}';
          if (item.ref.type == ElementType.card) {
            final CardState current = cards[item.ref.id]!;
            final CardState prior = decodeMercyCardState(item.beforeState);
            final CardState restored = CardState(
              schedule: prior.schedule.copyWith(
                revision: current.schedule.revision + 1,
                updatedAtUtc: command.timestampUtc,
              ),
              memory: _memoryWithRevision(
                prior.memory,
                current.memory.revision + 1,
              ),
            );
            if (!await _learning.compareAndSwapCardState(
              expected: current,
              replacement: restored,
            )) {
              throw StaleMercyPreview('card changed during Mercy undo');
            }
            final String restoredJson = encodeMercyCardState(restored);
            events.add(
              SchedulerEvent(
                id: _ids.newId(),
                operationId: itemOperation,
                element: item.ref,
                eventType: SchedulerEventType.mercyUndone,
                occurredAtUtc: command.timestampUtc,
                studyDay: command.day,
                schedulerName: restored.memory.schedulerName,
                schedulerVersion: restored.memory.schedulerVersion,
                policyVersion: applied.policyVersion,
                stateBefore: item.afterState,
                stateAfter: restoredJson,
                algorithmicDueBefore: SchedulerEvent.encodeUtcDue(
                  current.memory.dueAtUtc,
                ),
                algorithmicDueAfter: SchedulerEvent.encodeUtcDue(
                  restored.memory.dueAtUtc,
                ),
                undoesEventId: item.appliedEventId,
                batchId: applied.batchId,
              ),
            );
            revlog.add(
              _journal.build(
                operationId: itemOperation,
                ref: item.ref,
                eventType: RevlogEventType.undo,
                atUtc: command.timestampUtc,
                before: _journal.cardSnapshot(
                  current,
                  pressure: scale.pressureOf(current.schedule.priority),
                ),
                after: _journal.cardSnapshot(
                  restored,
                  pressure: scale.pressureOf(restored.schedule.priority),
                ),
                scheduledDays: restored.memory.scheduledDays,
                postponeCount: restored.memory.postponeCount,
                schedulerVersion: restored.memory.schedulerVersion,
                parametersVersion: restored.memory.parametersVersion,
                metadata: <String, Object?>{
                  'undoes_mercy_batch': applied.batchId,
                },
              ),
            );
          } else {
            final TopicState current = topics[item.ref]!;
            final TopicState prior = decodeMercyTopicState(item.beforeState);
            final TopicState restored = prior.copyWith(
              revision: current.revision + 1,
              schedule: prior.schedule.copyWith(
                revision: current.schedule.revision + 1,
                updatedAtUtc: command.timestampUtc,
              ),
            );
            if (!await _learning.compareAndSwapTopic(
              expected: current,
              replacement: restored,
            )) {
              throw StaleMercyPreview('topic changed during Mercy undo');
            }
            final String restoredJson = encodeMercyTopicState(restored);
            events.add(
              SchedulerEvent(
                id: _ids.newId(),
                operationId: itemOperation,
                element: item.ref,
                eventType: SchedulerEventType.mercyUndone,
                occurredAtUtc: command.timestampUtc,
                studyDay: command.day,
                schedulerName: restored.schedulerName,
                schedulerVersion: restored.schedulerVersion,
                policyVersion: applied.policyVersion,
                stateBefore: item.afterState,
                stateAfter: restoredJson,
                algorithmicDueBefore: SchedulerEvent.encodeStudyDayDue(
                  current.schedule.algorithmicDueDay,
                ),
                algorithmicDueAfter: SchedulerEvent.encodeStudyDayDue(
                  restored.schedule.algorithmicDueDay,
                ),
                undoesEventId: item.appliedEventId,
                batchId: applied.batchId,
              ),
            );
            revlog.add(
              _journal.build(
                operationId: itemOperation,
                ref: item.ref,
                eventType: RevlogEventType.undo,
                atUtc: command.timestampUtc,
                before: _journal.topicSnapshot(
                  current,
                  calendar: calendar,
                  pressure: scale.pressureOf(current.schedule.priority),
                ),
                after: _journal.topicSnapshot(
                  restored,
                  calendar: calendar,
                  pressure: scale.pressureOf(restored.schedule.priority),
                ),
                scheduledDays: restored.intervalDays,
                postponeCount: restored.totalPostponementCount,
                schedulerVersion: restored.schedulerVersion,
                metadata: <String, Object?>{
                  'undoes_mercy_batch': applied.batchId,
                },
              ),
            );
          }
        }
        events.insert(
          0,
          SchedulerEvent(
            id: _ids.newId(),
            operationId: command.operationId.value,
            eventType: SchedulerEventType.mercyUndone,
            occurredAtUtc: command.timestampUtc,
            studyDay: command.day,
            policyVersion: applied.policyVersion,
            undoesEventId: applied.appliedEventId,
            batchId: applied.batchId,
            metadata: <String, Object?>{'item_count': applied.items.length},
          ),
        );
        await _learning.appendSchedulerEvents(events);
        await _journal.appendAll(revlog);

        final Sm20CollectionState runtime = await _context.runtimeState();
        final List<MercyPreviewItem> original = <MercyPreviewItem>[
          for (var index = 0; index < applied.items.length; index += 1)
            MercyPreviewItem(
              ref: applied.items[index].ref,
              fromDay: applied.items[index].toDay,
              toDay: applied.items[index].fromDay,
              score: 0,
              sourceIndex: index,
              orderedIndex: index,
              scheduleRevision: 0,
              schedulerRevision: 0,
              canonicalBefore: '',
            ),
        ];
        await _context.saveRuntimeState(
          _runtimeAfterMercy(runtime, original, today: command.day),
        );
        await _learning.saveMercyBatch(
          stored.copyWith(
            undoOperationId: command.operationId.value,
            undoneAtUtc: command.timestampUtc,
          ),
        );
        await _activity(
          command.operationId.value,
          kMercyUndoneKind,
          command.timestampUtc,
          <String, Object?>{
            'batch_id': applied.batchId,
            'restored': applied.items.length,
          },
        );
        await _transfer.advanceGeneration();
        return Ok<int>(applied.items.length);
      });
    } on StaleMercyPreview catch (error) {
      return Err<int>(ConflictFailure(error.message));
    } on ArgumentError catch (error) {
      return Err<int>(ValidationFailure('$error'));
    } on StateError catch (error) {
      return Err<int>(ValidationFailure(error.message));
    } on Object catch (error, stackTrace) {
      return Err<int>(
        UnexpectedFailure(
          'Mercy undo failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<StoredMercyBatch?> lastAppliedBatch() =>
      _learning.findLastAppliedMercyBatch();

  Sm20MercyCandidate _candidate(
    QueueCandidate value, {
    required StudyDayCalendar calendar,
    required Map<ElementRef, String> canonical,
  }) {
    if (value.card case final CardState card) {
      canonical[value.ref] = encodeMercyCardState(card);
      final StudyDay? last = card.memory.lastReviewAtUtc == null
          ? null
          : calendar.dayOf(card.memory.lastReviewAtUtc!);
      return Sm20MercyCandidate(
        ref: value.ref,
        priority: card.schedule.priority,
        scheduledDay: calendar.dayOf(card.memory.dueAtUtc),
        lastReviewDay: last,
        repetitionCount: card.memory.reps,
        lapseCount: card.memory.lapses,
        storedInterval: math.max(
          0,
          sm20RoundEven(card.memory.scheduledDays ?? 0),
        ),
        isScheduled: card.memory.reps > 0,
        isDeleted: card.schedule.lifecycle == ElementLifecycle.deleted,
        revision: math.max(card.schedule.revision, card.memory.revision),
      );
    }
    final TopicState topic = value.topic!;
    canonical[value.ref] = encodeMercyTopicState(topic);
    return Sm20MercyCandidate(
      ref: value.ref,
      priority: topic.schedule.priority,
      scheduledDay: topic.schedule.algorithmicDueDay,
      lastReviewDay: topic.lastReviewDay,
      repetitionCount: topic.repetitionCount,
      lapseCount: topic.lapseCount,
      storedInterval: topic.storedInterval,
      isScheduled: topic.status == Sm20ElementStatus.memorized,
      isDeleted:
          topic.status == Sm20ElementStatus.deleted ||
          topic.schedule.lifecycle == ElementLifecycle.deleted,
      revision: math.max(topic.schedule.revision, topic.revision),
    );
  }

  Future<void> _activity(
    String operationId,
    String kind,
    DateTime atUtc,
    Map<String, Object?> metadata,
  ) => _learning.appendActivity(
    ActivityRecord(
      id: _ids.newId(),
      operationId: operationId,
      kind: kind,
      atUtc: atUtc,
      metadata: metadata,
    ),
  );
}

bool _isScheduled(QueueCandidate value) => value.card != null
    ? value.card!.memory.reps > 0
    : value.topic!.status == Sm20ElementStatus.memorized;

StudyDay _scheduledDay(QueueCandidate value, StudyDayCalendar calendar) =>
    value.card != null
    ? calendar.dayOf(value.card!.memory.dueAtUtc)
    : value.topic!.schedule.algorithmicDueDay;

SchedulerEvent _itemEvent({
  required String id,
  required String operationId,
  required SchedulerEventType type,
  required ApplyMercy command,
  required StoredMercyBatch stored,
  required ElementRef ref,
  required String schedulerName,
  required String schedulerVersion,
  required String beforeState,
  required String afterState,
  required String dueBefore,
  required String dueAfter,
  required MercyPreviewItem item,
}) => SchedulerEvent(
  id: id,
  operationId: operationId,
  element: ref,
  eventType: type,
  occurredAtUtc: command.timestampUtc,
  studyDay: command.day,
  schedulerName: schedulerName,
  schedulerVersion: schedulerVersion,
  policyVersion: stored.policyVersion,
  stateBefore: beforeState,
  stateAfter: afterState,
  algorithmicDueBefore: dueBefore,
  algorithmicDueAfter: dueAfter,
  batchId: stored.batchId,
  metadata: _itemMetadata(item),
);

Map<String, Object?> _itemMetadata(MercyPreviewItem item) => <String, Object?>{
  'from_study_day': item.fromDay.epochDay,
  'to_study_day': item.toDay.epochDay,
  'zone_id': item.toDay.zoneId,
  'score': item.score,
  'source_index': item.sourceIndex,
  'ordered_index': item.orderedIndex,
};

Sm20CollectionState _runtimeAfterMercy(
  Sm20CollectionState runtime,
  Iterable<MercyPreviewItem> assignments, {
  required StudyDay today,
}) {
  final List<MercyPreviewItem> values = assignments.toList();
  final Set<ElementRef> scope = <ElementRef>{
    for (final MercyPreviewItem value in values) value.ref,
  };
  final List<ElementRef> dueNow = <ElementRef>[
    for (final MercyPreviewItem value in values)
      if (value.toDay <= today) value.ref,
  ];
  final Set<ElementRef> dueItems = <ElementRef>{
    for (final ElementRef ref in dueNow)
      if (ref.type == ElementType.card) ref,
  };
  final Set<ElementRef> dueTopics = dueNow.toSet()..removeAll(dueItems);
  return runtime.copyWith(
    outstanding: <ElementRef>[
      ...dueNow,
      for (final ElementRef ref in runtime.outstanding)
        if (!scope.contains(ref)) ref,
    ],
    outstandingItems: <ElementRef>[
      for (final ElementRef ref in dueNow)
        if (dueItems.contains(ref)) ref,
      for (final ElementRef ref in runtime.outstandingItems)
        if (!scope.contains(ref)) ref,
    ],
    outstandingTopics: <ElementRef>[
      for (final ElementRef ref in dueNow)
        if (dueTopics.contains(ref)) ref,
      for (final ElementRef ref in runtime.outstandingTopics)
        if (!scope.contains(ref)) ref,
    ],
    finalDrill: <ElementRef>[
      for (final ElementRef ref in runtime.finalDrill)
        if (!scope.contains(ref)) ref,
    ],
    pending: <ElementRef>[
      for (final ElementRef ref in runtime.pending)
        if (!scope.contains(ref)) ref,
    ],
  );
}

CardMemory _memoryWithRevision(CardMemory value, int revision) => CardMemory(
  cardId: value.cardId,
  state: value.state,
  step: value.step,
  stability: value.stability,
  difficulty: value.difficulty,
  reps: value.reps,
  lapses: value.lapses,
  lastReviewAtUtc: value.lastReviewAtUtc,
  dueAtUtc: value.dueAtUtc,
  originalDueAtUtc: value.originalDueAtUtc,
  schedulerVersion: value.schedulerVersion,
  parametersVersion: value.parametersVersion,
  postponeCount: value.postponeCount,
  scheduledDays: value.scheduledDays,
  schedulerName: value.schedulerName,
  revision: revision,
);
