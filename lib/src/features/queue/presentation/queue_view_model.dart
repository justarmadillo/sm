/// Presentation state for the daily heterogeneous queue.
///
/// The ViewModel holds no scheduling logic. Loading the queue runs the day's
/// admission valve inside the application layer, so what the screen shows and
/// what the collection recorded as deferred are one decision rather than two.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:incremental_reader/src/app/providers.dart';
import 'package:incremental_reader/src/application/queue/queue_commands.dart';
import 'package:incremental_reader/src/application/queue/queue_query.dart';
import 'package:incremental_reader/src/application/review/review_commands.dart';
import 'package:incremental_reader/src/application/scheduling/mercy_handlers.dart';
import 'package:incremental_reader/src/application/scheduling/mercy_workflow.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/domain/scheduling/card_scheduler.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/queue_policy.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:incremental_reader/src/features/library/presentation/library_view_model.dart';

@immutable
final class QueueUiState {
  const QueueUiState({
    required this.projection,
    this.completedThisSession = 0,
    this.message,
    this.isBusy = false,
  });

  /// Today's admitted queue and the numbers behind it.
  final QueueProjection projection;

  final int completedThisSession;

  /// Ephemeral: shown once, then cleared.
  final UiMessage? message;

  final bool isBusy;

  List<QueueEntry> get entries => projection.entries;

  QueueEntry? get next => projection.entries.firstOrNull;

  QueueCounters get counters => projection.counters;

  QueueUiState copyWith({
    QueueProjection? projection,
    int? completedThisSession,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
  }) => QueueUiState(
    projection: projection ?? this.projection,
    completedThisSession: completedThisSession ?? this.completedThisSession,
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
  );
}

final class QueueViewModel extends AsyncNotifier<QueueUiState> {
  @override
  Future<QueueUiState> build() async =>
      QueueUiState(projection: await ref.read(queueQueryProvider).load());

  /// Rebuilds from canonical schedules after a terminal route commits.
  Future<void> refreshAfterCommit() => _reload(countEncounter: true);

  /// Refreshes without counting an encounter, for example after returning
  /// from a canceled child route or when the user presses Refresh.
  Future<void> refresh() => _reload(countEncounter: false);

  /// Computes a Mercy proposal without writing anything.
  ///
  /// Returned rather than stored on the state so the screen can show the exact
  /// calendar and let the user walk away from it. Nothing has moved until
  /// [applyMercy] is called with the returned batch.
  Future<StoredMercyBatch?> previewMercy({
    int? reschedulingDays,
    int? gatheringDays,
    int? elementsPerDay,
    bool solveFromDailyCap = false,
    bool? includeFuture,
    MercyMode? mode,
  }) async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return null;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<StoredMercyBatch> result = await ref
        .read(mercyHandlersProvider)
        .preview(
          PreviewMercy(
            OperationId(ref.read(idGeneratorProvider).newId()),
            day: current.projection.today,
            reschedulingDays: reschedulingDays,
            gatheringDays: gatheringDays,
            elementsPerDay: elementsPerDay,
            solveFromDailyCap: solveFromDailyCap,
            includeFuture: includeFuture,
            mode: mode,
          ),
        );

    return result.fold(
      (StoredMercyBatch batch) {
        state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: false));
        return batch;
      },
      (AppFailure failure) {
        state = AsyncValue<QueueUiState>.data(
          current.copyWith(
            isBusy: false,
            message: UiMessage(failure.message, isError: true),
          ),
        );
        return null;
      },
    );
  }

  /// Live Default profile, used to seed the Smart Postpone dialog.
  Future<SmartPostponeSettings> smartPostponeSettings() async =>
      (await ref.read(schedulingContextProvider).settings())
          .postpone
          .defaultProfile;

  /// Runs Smart Postpone, or its write-free simulation.
  ///
  /// Simulation and the real run are the same command with one flag, so what
  /// the confirmation dialog shows is produced by the engine that will write —
  /// not by a second estimate that could disagree with it.
  Future<AppliedSmartPostpone?> smartPostpone({
    required bool simulate,
    SmartPostponeSettings? profile,
    List<ElementRef>? sourcePopulation,
    List<SmartPostponeSettings> applicableSubbranchProfiles =
        const <SmartPostponeSettings>[],
  }) async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return null;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final SmartPostponeSettings base = profile ?? await smartPostponeSettings();
    final Result<AppliedSmartPostpone> result = await ref
        .read(queueHandlersProvider)
        .runSmartPostpone(
          RunSmartPostpone(
            OperationId(ref.read(idGeneratorProvider).newId()),
            day: current.projection.today,
            profile: base.copyWith(simulate: simulate),
            sourcePopulation: sourcePopulation,
            applicableSubbranchProfiles: applicableSubbranchProfiles,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );

    // A simulation wrote nothing, so the projection it was computed from is
    // still current and reloading it would only cost a rebuild.
    final QueueProjection projection = simulate || result.isErr
        ? current.projection
        : await ref.read(queueQueryProvider).load();

    return result.fold(
      (AppliedSmartPostpone applied) {
        state = AsyncValue<QueueUiState>.data(
          current.copyWith(
            projection: projection,
            isBusy: false,
            message: simulate
                ? null
                : UiMessage(
                    applied.written == 0
                        ? 'Nothing was eligible for postponement'
                        : 'Smart Postpone moved ${applied.written} element'
                              '${applied.written == 1 ? '' : 's'}',
                  ),
          ),
        );
        return applied;
      },
      (AppFailure failure) {
        state = AsyncValue<QueueUiState>.data(
          current.copyWith(
            isBusy: false,
            message: UiMessage(failure.message, isError: true),
          ),
        );
        return null;
      },
    );
  }

  /// Enters Final Drill or Pending on demand, as the Learn menu does.
  Future<void> enterStage(Sm20StageRequest stage) => _queueCommand(
    (OperationId operation, StudyDay day, DateTime now) => ref
        .read(queueHandlersProvider)
        .enterLearningStage(
          EnterLearningStage(
            operation,
            day: day,
            stage: stage,
            timestampUtc: now,
          ),
        ),
    success: (Sm20QueueCommandOutcome outcome) => switch (stage) {
      Sm20StageRequest.outstanding =>
        'Outstanding: ${outcome.affected} element'
            '${outcome.affected == 1 ? '' : 's'}',
      Sm20StageRequest.finalDrill =>
        'Final drill: ${outcome.affected} element'
            '${outcome.affected == 1 ? '' : 's'}',
      Sm20StageRequest.newMaterial =>
        'Random learning: ${outcome.affected} pending element'
            '${outcome.affected == 1 ? '' : 's'}',
    },
  );

  /// `Random learning`: the pending stage, reviewed in randomized order.
  ///
  /// The executable keeps this separate from `2. New material`, and the
  /// difference is only the order, so this is a randomization of the pending
  /// queue followed by the same stage entry. The randomization runs first
  /// because entering the stage is what presents the order.
  Future<void> randomLearning() async {
    await randomizeQueue(Sm20RandomizableQueue.pending);
    final QueueUiState? current = state.valueOrNull;
    // A refused randomization has already reported why; entering the stage
    // anyway would replace that message with a less useful one.
    if (current?.message?.isError ?? false) return;
    await enterStage(Sm20StageRequest.newMaterial);
  }

  /// Cut drills: empties the Final Drill queue.
  Future<void> cutDrills() => _queueCommand(
    (OperationId operation, StudyDay day, DateTime now) => ref
        .read(queueHandlersProvider)
        .cutDrills(CutDrills(operation, day: day, timestampUtc: now)),
    success: (Sm20QueueCommandOutcome outcome) => outcome.affected == 0
        ? 'The final drill was already empty'
        : 'Cut ${outcome.affected} element'
              '${outcome.affected == 1 ? '' : 's'} from the final drill',
  );

  /// Reorders one stored queue with the fixed-size swap.
  Future<void> randomizeQueue(Sm20RandomizableQueue queue) => _queueCommand(
    (OperationId operation, StudyDay day, DateTime now) => ref
        .read(queueHandlersProvider)
        .randomizeQueue(
          RandomizeQueue(operation, day: day, queue: queue, timestampUtc: now),
        ),
    success: (Sm20QueueCommandOutcome outcome) => switch (queue) {
      Sm20RandomizableQueue.outstanding => 'Repetitions randomized',
      Sm20RandomizableQueue.finalDrill => 'Final drill randomized',
      Sm20RandomizableQueue.pending => 'Pending queue randomized',
    },
  );

  /// Shared shape for the manual stage and queue commands.
  ///
  /// Each of them changes stored queue state, so the projection is reloaded
  /// rather than patched: the stage that comes back is the one the queue
  /// transaction actually settled on.
  Future<void> _queueCommand(
    Future<Result<Sm20QueueCommandOutcome>> Function(
      OperationId operation,
      StudyDay day,
      DateTime now,
    )
    run, {
    required String Function(Sm20QueueCommandOutcome outcome) success,
  }) async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<Sm20QueueCommandOutcome> result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
      current.projection.today,
      ref.read(clockProvider).nowUtc(),
    );
    final QueueProjection projection = result.isErr
        ? current.projection
        : await ref.read(queueQueryProvider).load();

    state = AsyncValue<QueueUiState>.data(
      current.copyWith(
        projection: projection,
        isBusy: false,
        message: result.fold(
          (Sm20QueueCommandOutcome outcome) => UiMessage(success(outcome)),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Live defaults for the Mercy capacity and ordering dialog.
  Future<MercySettings> mercySettings() async =>
      (await ref.read(schedulingContextProvider).settings()).mercy;

  /// Commits a previewed batch the user confirmed.
  Future<void> applyMercy(StoredMercyBatch batch) async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<int> result = await ref
        .read(mercyHandlersProvider)
        .apply(
          ApplyMercy(
            OperationId(ref.read(idGeneratorProvider).newId()),
            day: current.projection.today,
            batchId: batch.batchId,
          ),
        );
    final QueueProjection projection = await ref
        .read(queueQueryProvider)
        .load();

    state = AsyncValue<QueueUiState>.data(
      current.copyWith(
        projection: projection,
        isBusy: false,
        message: result.fold(
          (int moved) => UiMessage(
            moved == 0
                ? 'No backlog to spread'
                : 'Mercy moved $moved element${moved == 1 ? '' : 's'}',
          ),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Reverses the last applied Mercy batch exactly.
  Future<void> undoMercy() async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    final MercyHandlers handlers = ref.read(mercyHandlersProvider);
    final StoredMercyBatch? batch = await handlers.lastAppliedBatch();
    if (batch == null) {
      state = AsyncValue<QueueUiState>.data(
        current.copyWith(message: const UiMessage('No Mercy batch to undo')),
      );
      return;
    }
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<int> result = await handlers.undo(
      UndoMercy(
        OperationId(ref.read(idGeneratorProvider).newId()),
        day: current.projection.today,
        batchId: batch.batchId,
      ),
    );
    final QueueProjection projection = await ref
        .read(queueQueryProvider)
        .load();

    state = AsyncValue<QueueUiState>.data(
      current.copyWith(
        projection: projection,
        isBusy: false,
        message: result.fold(
          (int restored) => UiMessage(
            'Mercy undone; $restored element'
            '${restored == 1 ? '' : 's'} restored',
          ),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Takes back the most recent grade, whichever card it was on.
  ///
  /// The review screen closes the moment a grade commits, so the session — not
  /// that screen — is where undo has to live. The restored card becomes due
  /// again immediately and reappears at the head of the queue.
  Future<void> undoLastGrade() async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<CardState> result = await ref
        .read(reviewHandlersProvider)
        .undoLastReview(
          UndoLastReview(
            OperationId(ref.read(idGeneratorProvider).newId()),
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    final QueueProjection projection = await ref
        .read(queueQueryProvider)
        .load();

    state = AsyncValue<QueueUiState>.data(
      current.copyWith(
        projection: projection,
        isBusy: false,
        completedThisSession: result.isOk && current.completedThisSession > 0
            ? current.completedThisSession - 1
            : current.completedThisSession,
        message: result.fold(
          (CardState _) => const UiMessage('Grade taken back'),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Clears the one-shot message after the view has shown it.
  void clearMessage() {
    final QueueUiState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<QueueUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }

  Future<void> _reload({required bool countEncounter}) async {
    final QueueUiState? current = state.valueOrNull;
    final int completed =
        (current?.completedThisSession ?? 0) + (countEncounter ? 1 : 0);
    state = const AsyncLoading<QueueUiState>();
    state = await AsyncValue.guard(
      () async => QueueUiState(
        projection: await ref.read(queueQueryProvider).load(),
        completedThisSession: completed,
      ),
    );
  }
}

final AsyncNotifierProvider<QueueViewModel, QueueUiState>
queueViewModelProvider = AsyncNotifierProvider<QueueViewModel, QueueUiState>(
  QueueViewModel.new,
);
