/// Preview, apply, and exact undo for one Mercy batch.
///
/// Mercy is the recovery tool, not the daily valve, and the difference is
/// enforced here: nothing is written until the user has seen the exact
/// calendar being proposed and confirmed it, and the confirmation is checked
/// against live revisions before a single row moves. A preview computed
/// against a collection that has since changed is refused rather than applied
/// approximately, because a bulk operation that silently redistributes the
/// wrong material is worse than one that asks again.
///
/// The whole batch is presentation state. Canonical FSRS memory, topic
/// intervals, and last-review instants are read to build the audit envelope
/// and are never written, so a Mercy batch can be reversed exactly and can
/// never contaminate a future parameter optimizer.
library;

import 'dart:math' as math;

import '../../core/ids.dart';
import '../../core/result.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/mercy.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/schedule_adjustment.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/settings/app_settings.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../queue/queue_commands.dart';
import '../queue/queue_handlers.dart';
import 'mercy_workflow.dart';
import 'schedule_adjustment_service.dart';
import 'scheduling_context.dart';

/// Activity kinds, kept distinct so history can tell the three steps apart.
const String kMercyPreviewedKind = 'mercy.previewed';
const String kMercyAppliedKind = 'mercy.applied';
const String kMercyUndoneKind = 'mercy.undone';

/// `[Product decision]` Provisional criteria weights.
///
/// Priority remains dominant — the band width is what stops any criterion
/// from reordering the collection globally — and within a band the most
/// overdue work is placed first. SuperMemo's real multi-criteria formula is
/// undocumented, so these are visible, versioned, and deliberately few.
const double kMercyPriorityBandWidth = 0.10;
const double kMercyLatenessWeight = 1.0;
const double kMercyStableRandomWeight = 0.25;

/// Handles the Mercy conversation end to end.
final class MercyHandlers {
  MercyHandlers({
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required ScheduleAdjustmentService adjustments,
    required QueueHandlers queue,
    required IdGenerator ids,
  }) : _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _adjustments = adjustments,
       _queue = queue,
       _ids = ids;

  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final ScheduleAdjustmentService _adjustments;
  final QueueHandlers _queue;
  final IdGenerator _ids;

  static const MercyWorkflow _workflow = MercyWorkflow();

  /// Computes and durably records a proposal. Writes no adjustment.
  ///
  /// The preview row is persisted rather than held in memory because the user
  /// may close the app between seeing a plan and accepting it, and an apply
  /// that reconstructed the plan from scratch would silently be a different
  /// plan.
  Future<Result<StoredMercyBatch>> preview(PreviewMercy command) async {
    try {
      return await _transactions.run<Result<StoredMercyBatch>>(() async {
        final StoredMercyBatch? replayed = await _learning
            .findMercyBatchByPreviewOperation(command.operationId.value);
        if (replayed != null) return Ok<StoredMercyBatch>(replayed);

        final AppSettings settings = await _context.settings();
        final StudyDayCalendar calendar = await _context.calendar();
        final PriorityScale scale = await _context.priorityScale();
        final int horizon = math.max(
          1,
          command.horizonDays ?? settings.postpone.mercyHorizonDays,
        );
        final int dailyCap = math.max(
          1,
          command.dailyCap ?? settings.postpone.mercyDailyCap,
        );

        final List<QueueCandidate> candidates = await _queue.loadCandidates(
          command.day,
        );
        if (candidates.isEmpty) {
          return const Err<StoredMercyBatch>(
            ValidationFailure('there is nothing for Mercy to redistribute'),
          );
        }

        final List<MercyCandidate> mercyCandidates = <MercyCandidate>[];
        for (final QueueCandidate candidate in candidates) {
          mercyCandidates.add(
            await _toMercyCandidate(
              candidate,
              calendar: calendar,
              scale: scale,
              settings: settings,
              today: command.day,
            ),
          );
        }

        final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
          await _learning.listActiveAdjustments(
            elements: <ElementRef>{
              for (final MercyCandidate candidate in mercyCandidates)
                candidate.ref,
            },
          ),
        );

        final MercyPreviewRequest request = MercyPreviewRequest(
          today: command.day,
          scope: command.branchRootId == null
              ? const MercyCollectionScope()
              : MercyBranchScope(command.branchRootId!),
          collectingPeriod: _collectingPeriod(command, horizon: horizon),
          includeFutureRepetitions: command.includeFutureRepetitions,
          destinationPolicy: MercyDailyCapacity(
            cardsPerDay: dailyCap,
            topicsPerDay: math.min(dailyCap, settings.queue.maxTopics),
          ),
          destinationWindow: _destinationWindow(
            today: command.day,
            horizon: horizon,
            calendar: calendar,
            candidates: mercyCandidates,
          ),
          criteriaPolicy: MercyCriteriaPolicy(
            priorityBandWidth: kMercyPriorityBandWidth,
            deterministicSeed:
                '${(await _transfer.currentIdentity()).datasetId}'
                '|${command.day}',
            repetitionLatenessWeight: kMercyLatenessWeight,
            stableRandomWeight: kMercyStableRandomWeight,
          ),
          protectionRules: MercyProtectionRules(
            includeProtected: command.includeProtected,
            overrideManualLater: command.overrideManualLater,
          ),
          candidates: mercyCandidates,
          adjustments: adjustments,
          priorMercyBatchCountInPeriod: await _learning
              .countAppliedMercyBatchesSince(
                command.day.addDays(-horizon.clamp(1, 90)),
              ),
        );

        final MercyPreview preview = MercyPlanner(
          calendar: calendar,
        ).preview(request);
        final StoredMercyBatch batch = StoredMercyBatch(
          batchId: _ids.newId(),
          previewOperationId: command.operationId.value,
          policyVersion: preview.policyVersion,
          previewJson: preview.toJson(),
          createdAtUtc: command.timestampUtc,
        );
        await _learning.saveMercyBatch(batch);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kMercyPreviewedKind,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'batch_id': batch.batchId,
              'selected': preview.selectedCount,
              'input_candidates': preview.inputCandidateCount,
            },
          ),
        );
        return Ok<StoredMercyBatch>(batch);
      });
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

  /// Commits a previewed batch, or refuses it as stale. Returns the number of
  /// elements moved.
  Future<Result<int>> apply(ApplyMercy command) async {
    try {
      return await _transactions.run<Result<int>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kMercyAppliedKind,
        )) {
          return const Err<int>(
            ConflictFailure('that Mercy batch has already been applied'),
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
            ConflictFailure('that Mercy batch has already been applied'),
          );
        }

        final AppSettings settings = await _context.settings();
        final StudyDayCalendar calendar = await _context.calendar();
        final PriorityScale scale = await _context.priorityScale();
        final List<QueueCandidate> candidates = await _queue.loadCandidates(
          command.day,
        );
        final List<MercyCandidate> current = <MercyCandidate>[];
        for (final QueueCandidate candidate in candidates) {
          current.add(
            await _toMercyCandidate(
              candidate,
              calendar: calendar,
              scale: scale,
              settings: settings,
              today: command.day,
            ),
          );
        }
        final ScheduleAdjustmentSet active = ScheduleAdjustmentSet(
          await _learning.listActiveAdjustments(
            elements: <ElementRef>{
              for (final MercyCandidate candidate in current) candidate.ref,
            },
          ),
        );

        final MercyApplyPlan plan = _workflow.planApply(
          preview: stored.preview,
          currentCandidates: current,
          currentAdjustments: active,
          batchId: stored.batchId,
          operationId: command.operationId.value,
          occurredAtUtc: command.timestampUtc,
          studyDay: command.day,
        );

        await _learning.saveAdjustments(
          plan.adjustmentMutation.after.adjustments.toList(growable: false),
        );
        await _learning.appendSchedulerEvents(plan.auditEvents);
        await _learning.saveMercyBatch(
          stored.copyWith(
            applyOperationId: command.operationId.value,
            appliedSnapshotJson: encodeMercyAppliedBatch(plan.undoSnapshot),
            appliedAtUtc: command.timestampUtc,
          ),
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kMercyAppliedKind,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'batch_id': stored.batchId,
              'moved': plan.preview.selectedCount,
            },
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<int>(plan.preview.selectedCount);
      });
    } on StaleMercyPreview catch (error) {
      return Err<int>(
        ConflictFailure(
          '${error.message}. Preview it again before applying.',
        ),
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

  /// Restores exactly the adjustment set that preceded an applied batch.
  Future<Result<int>> undo(UndoMercy command) async {
    try {
      return await _transactions.run<Result<int>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kMercyUndoneKind,
        )) {
          return const Err<int>(
            ConflictFailure('that undo has already been recorded'),
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
        final ScheduleAdjustmentSet active = ScheduleAdjustmentSet(
          await _learning.listActiveAdjustments(
            elements: applied.appliedAdjustments.elements.toSet(),
          ),
        );
        final MercyUndoPlan plan = _workflow.planUndo(
          applied: applied,
          currentAdjustments: active,
          operationId: command.operationId.value,
          occurredAtUtc: command.timestampUtc,
          studyDay: command.day,
        );

        await _learning.saveAdjustments(
          plan.adjustmentMutation.after.adjustments.toList(growable: false),
        );
        await _learning.appendSchedulerEvents(plan.auditEvents);
        await _learning.saveMercyBatch(
          stored.copyWith(
            undoOperationId: command.operationId.value,
            undoneAtUtc: command.timestampUtc,
          ),
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kMercyUndoneKind,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'batch_id': stored.batchId,
              'restored': applied.items.length,
            },
          ),
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

  /// The batch that could still be undone, if any.
  Future<StoredMercyBatch?> lastAppliedBatch() =>
      _learning.findLastAppliedMercyBatch();

  MercyCollectingPeriod _collectingPeriod(
    PreviewMercy command, {
    required int horizon,
  }) {
    // Collecting backwards from today by default reaches every outstanding
    // repetition; including future work extends the window forward so a
    // repetition can also be pulled earlier, which a lower bound could never
    // express.
    final int back = command.collectingPeriodDays ?? 3650;
    return MercyCollectingPeriod(
      start: command.day.addDays(-math.max(0, back)),
      end: command.includeFutureRepetitions
          ? command.day.addDays(horizon)
          : command.day,
    );
  }

  MercyDestinationWindow _destinationWindow({
    required StudyDay today,
    required int horizon,
    required StudyDayCalendar calendar,
    required List<MercyCandidate> candidates,
  }) {
    final Map<int, int> cardLoad = <int, int>{};
    final Map<int, int> topicLoad = <int, int>{};
    for (final MercyCandidate candidate in candidates) {
      final int key = candidate.currentEffectiveDueDay.epochDay;
      final Map<int, int> target = candidate.ref.type == ElementType.card
          ? cardLoad
          : topicLoad;
      target[key] = (target[key] ?? 0) + 1;
    }
    return MercyDestinationWindow(
      days: <MercyDestinationDay>[
        for (var offset = 1; offset <= horizon; offset++)
          (() {
            final StudyDay day = today.addDays(offset);
            return MercyDestinationDay(
              day: day,
              cardScheduledForAtUtc: calendar.startOfDayUtc(day),
              beforeCardLoad: cardLoad[day.epochDay] ?? 0,
              beforeTopicLoad: topicLoad[day.epochDay] ?? 0,
            );
          })(),
      ],
    );
  }

  Future<MercyCandidate> _toMercyCandidate(
    QueueCandidate candidate, {
    required StudyDayCalendar calendar,
    required PriorityScale scale,
    required AppSettings settings,
    required StudyDay today,
  }) async {
    final ElementSchedule schedule = candidate.schedule;
    final PriorityPosition? position = scale.positionOf(schedule.priority);
    final double priorityFraction = position?.fraction ?? 0.5;
    final bool isProtected =
        position != null &&
        settings.queue.protectedPercentile > 0 &&
        position.index <
            (scale.total * settings.queue.protectedPercentile).ceil();
    final CardState? card = candidate.card;
    final StudyDay effectiveDay = card != null
        ? calendar.dayOf(
            candidate.effectiveCardDueAtUtc ?? card.memory.dueAtUtc,
          )
        : candidate.effectiveTopicDueDay ?? schedule.algorithmicDueDay;

    return MercyCandidate(
      ref: candidate.ref,
      revision: math.max(1, schedule.revision),
      currentEffectiveDueDay: effectiveDay,
      priorityFraction: priorityFraction,
      canonical: await _adjustments.canonicalSnapshotOf(candidate.ref),
      branchIds: <String>{
        if (schedule.rootId != null) schedule.rootId!,
        candidate.ref.id,
      },
      criteria: MercyCriterionValues(
        repetitionLateness: _lateness(candidate, effectiveDay, today),
        investment: card == null
            ? 0
            : math.min(1, card.memory.reps / 20).toDouble(),
      ),
      isProtected: isProtected,
      isDueIntradayStep: candidate.isIntradayStep,
      isLifecycleEligible: schedule.lifecycle.isSchedulable,
    );
  }

  double _lateness(
    QueueCandidate candidate,
    StudyDay effectiveDay,
    StudyDay today,
  ) {
    final int late = effectiveDay.daysUntil(today);
    if (late <= 0) return 0;
    final double interval = math.max(1, candidate.scheduledDays);
    return math.min(1, late / interval).toDouble();
  }
}
