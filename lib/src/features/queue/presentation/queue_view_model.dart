/// Presentation state for the minimal heterogeneous daily queue.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/queue/queue_query.dart';

@immutable
final class QueueUiState {
  const QueueUiState({required this.entries, this.completedThisSession = 0});

  final List<QueueEntry> entries;
  final int completedThisSession;

  QueueEntry? get next => entries.firstOrNull;

  QueueUiState copyWith({
    List<QueueEntry>? entries,
    int? completedThisSession,
  }) => QueueUiState(
    entries: entries ?? this.entries,
    completedThisSession: completedThisSession ?? this.completedThisSession,
  );
}

final class QueueViewModel extends AsyncNotifier<QueueUiState> {
  @override
  Future<QueueUiState> build() async =>
      QueueUiState(entries: await ref.read(queueQueryProvider).load());

  /// Rebuilds from canonical schedules after a terminal route commits.
  Future<void> refreshAfterCommit() async {
    final completed = (state.valueOrNull?.completedThisSession ?? 0) + 1;
    state = const AsyncLoading<QueueUiState>();
    state = await AsyncValue.guard(
      () async => QueueUiState(
        entries: await ref.read(queueQueryProvider).load(),
        completedThisSession: completed,
      ),
    );
  }

  /// Refreshes without counting an encounter, for example after returning
  /// from a canceled child route or when the user presses Refresh.
  Future<void> refresh() async {
    final completed = state.valueOrNull?.completedThisSession ?? 0;
    state = const AsyncLoading<QueueUiState>();
    state = await AsyncValue.guard(
      () async => QueueUiState(
        entries: await ref.read(queueQueryProvider).load(),
        completedThisSession: completed,
      ),
    );
  }
}

final AsyncNotifierProvider<QueueViewModel, QueueUiState>
queueViewModelProvider = AsyncNotifierProvider<QueueViewModel, QueueUiState>(
  QueueViewModel.new,
);
