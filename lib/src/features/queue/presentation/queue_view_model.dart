/// Presentation state for the daily heterogeneous queue.
///
/// The ViewModel holds no scheduling logic. Loading the queue runs the day's
/// admission valve inside the application layer, so what the screen shows and
/// what the collection recorded as deferred are one decision rather than two.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/queue/queue_commands.dart';
import '../../../application/queue/queue_query.dart';
import '../../../application/review/review_commands.dart';
import '../../../core/result.dart';
import '../../../core/tracing.dart';
import '../../../domain/scheduling/card_scheduler.dart';
import '../../../domain/scheduling/queue_policy.dart';
import '../../library/presentation/library_view_model.dart';

@immutable
final class QueueUiState {
  const QueueUiState({
    required this.projection,
    this.completedThisSession = 0,
    this.extraAdmissions = 0,
    this.message,
    this.isBusy = false,
  });

  /// Today's admitted queue and the numbers behind it.
  final QueueProjection projection;

  final int completedThisSession;

  /// Headroom added by Study More, for this session only. Never persisted:
  /// asking for more work today is not the same as raising a daily limit.
  final int extraAdmissions;

  /// Ephemeral: shown once, then cleared.
  final UiMessage? message;

  final bool isBusy;

  List<QueueEntry> get entries => projection.entries;

  QueueEntry? get next => projection.entries.firstOrNull;

  QueueCounters get counters => projection.counters;

  /// Whether the valve shed anything today, so Study More is worth offering.
  bool get hasDeferrals => projection.counters.overflowTotal > 0;

  QueueUiState copyWith({
    QueueProjection? projection,
    int? completedThisSession,
    int? extraAdmissions,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
  }) => QueueUiState(
    projection: projection ?? this.projection,
    completedThisSession: completedThisSession ?? this.completedThisSession,
    extraAdmissions: extraAdmissions ?? this.extraAdmissions,
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

  /// Takes back some of what the valve deferred today.
  ///
  /// Recalls automatic deferrals only: a manual Later stands, because the
  /// user said "not now" about that element specifically.
  Future<void> studyMore() async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<int> result = await ref
        .read(queueHandlersProvider)
        .studyMore(
          StudyMore(
            OperationId(ref.read(idGeneratorProvider).newId()),
            day: current.projection.today,
          ),
        );
    final int step = (await ref.read(schedulingContextProvider).settings())
        .queue
        .studyMoreStep;
    final QueueProjection projection = await ref
        .read(queueQueryProvider)
        .load(extraAdmissions: current.extraAdmissions + step);

    state = AsyncValue<QueueUiState>.data(
      current.copyWith(
        projection: projection,
        extraAdmissions: current.extraAdmissions + step,
        isBusy: false,
        message: result.fold(
          (int recalled) => UiMessage(
            recalled == 0
                ? 'Nothing left to recall today'
                : '$recalled more element${recalled == 1 ? '' : 's'} today',
          ),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Spreads an accumulated backlog across a horizon in one operation.
  Future<void> runMercy({int? horizonDays, int? dailyCap}) async {
    final QueueUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<QueueUiState>.data(current.copyWith(isBusy: true));

    final Result<int> result = await ref
        .read(queueHandlersProvider)
        .runMercy(
          RunMercy(
            OperationId(ref.read(idGeneratorProvider).newId()),
            day: current.projection.today,
            horizonDays: horizonDays,
            dailyCap: dailyCap,
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
          (int spread) => UiMessage(
            spread == 0
                ? 'No backlog to spread'
                : 'Spread $spread overdue element${spread == 1 ? '' : 's'}',
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
        .load(extraAdmissions: current.extraAdmissions);

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
    final int extra = current?.extraAdmissions ?? 0;
    state = const AsyncLoading<QueueUiState>();
    state = await AsyncValue.guard(
      () async => QueueUiState(
        projection: await ref
            .read(queueQueryProvider)
            .load(extraAdmissions: extra),
        completedThisSession: completed,
        extraAdmissions: extra,
      ),
    );
  }
}

final AsyncNotifierProvider<QueueViewModel, QueueUiState>
queueViewModelProvider = AsyncNotifierProvider<QueueViewModel, QueueUiState>(
  QueueViewModel.new,
);
