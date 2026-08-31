/// ViewModel for Settings.
///
/// Edits are held as a draft and written on Save, so a half-typed number never
/// reaches a scheduler. Saving invalidates the providers that captured the old
/// configuration, because an Outstanding order built under the previous merge
/// and randomization settings remains authoritative until it is rebuilt.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/daily_queue/queue_view_model.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/features/settings/fsrs_settings_rescheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/database_maintenance.dart';

@immutable
final class SettingsUiState {
  const SettingsUiState({
    required this.saved,
    required this.draft,
    this.isBusy = false,
    this.message,
  });

  /// What is on disk.
  final AppSettings saved;

  /// What the user is editing.
  final AppSettings draft;

  final bool isBusy;
  final UiMessage? message;

  /// Whether there is anything to save.
  bool get isDirty => draft != saved;

  SettingsUiState copyWith({
    AppSettings? saved,
    AppSettings? draft,
    bool? isBusy,
    UiMessage? message,
    bool shouldClearMessage = false,
  }) => SettingsUiState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    isBusy: isBusy ?? this.isBusy,
    message: shouldClearMessage ? null : (message ?? this.message),
  );
}

final class SettingsViewModel extends AsyncNotifier<SettingsUiState> {
  @override
  Future<SettingsUiState> build() async {
    final AppSettings settings = await ref.read(settingsStoreProvider).reload();
    return SettingsUiState(saved: settings, draft: settings);
  }

  /// Applies an edit to the draft without writing anything.
  void edit(AppSettings Function(AppSettings draft) change) {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(draft: change(current.draft)),
    );
  }

  /// Throws the draft away.
  void revert() {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(draft: current.saved),
    );
  }

  /// Restores every shipped default into the draft.
  ///
  /// Not written until Save, so "what would the defaults do?" is a question
  /// the user can ask and then back out of.
  void loadDefaults() {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(
      current.copyWith(draft: const AppSettings()),
    );
  }

  /// Writes the draft.
  Future<void> save() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy || !current.isDirty) return;
    state = AsyncValue<SettingsUiState>.data(current.copyWith(isBusy: true));

    final FsrsSettingsSaveResult saveResult = await FsrsSettingsRescheduler(
      settings: ref.read(settingsStoreProvider),
      context: ref.read(schedulingContextProvider),
      learning: ref.read(learningRepositoryProvider),
      transactions: ref.read(transactionRunnerProvider),
    ).save(previous: current.saved, replacement: current.draft);
    final Result<AppSettings> result = saveResult.settings;
    if (result.isErr) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          isBusy: false,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return;
    }

    // Everything that captured the old configuration has to be rebuilt: the
    // calendar, the diagnostic sink's limits, today's queue, and the priority
    // projections all read settings at construction time.
    ref.invalidate(studyCalendarProvider);
    ref.invalidate(diagnosticsProvider);
    ref.invalidate(queueViewModelProvider);
    ref.invalidate(priorityBrowserViewModelProvider);

    state = AsyncValue<SettingsUiState>.data(
      SettingsUiState(
        saved: result.unwrap(),
        draft: result.unwrap(),
        message: UiMessage(
          saveResult.cardsUpdated == 0
              ? 'Settings saved'
              : 'Settings saved. ${saveResult.cardsUpdated} card '
                    '${saveResult.cardsUpdated == 1 ? 'schedule was' : 'schedules were'} '
                    'updated.',
        ),
      ),
    );
  }

  /// Compacts and checks the database, then says what it found.
  ///
  /// Not part of the draft, so it does not wait for Save: this changes how the
  /// collection is stored, never what it contains, and there is nothing here
  /// to back out of.
  ///
  /// No backup is taken first. Every step is either transactional (SQLite
  /// rolls a half-finished VACUUM back) or derived (the search index is
  /// rebuilt from rows that are still there), so an interrupted pass leaves
  /// the collection exactly as it was.
  Future<void> optimizeDatabase() async {
    final SettingsUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<SettingsUiState>.data(current.copyWith(isBusy: true));

    try {
      final DatabaseMaintenanceReport report = await ref
          .read(databaseMaintenanceProvider)
          .optimize();
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          isBusy: false,
          message: UiMessage(
            _reportMessage(report),
            isError: !report.isHealthy,
          ),
        ),
      );
    } on Object catch (error) {
      state = AsyncValue<SettingsUiState>.data(
        current.copyWith(
          isBusy: false,
          message: UiMessage('Could not optimize: $error', isError: true),
        ),
      );
    }
  }

  /// The pass in one sentence.
  ///
  /// A problem is reported instead of the saving, not alongside it: how much
  /// space was recovered is irrelevant news next to a collection that has just
  /// reported itself damaged.
  String _reportMessage(DatabaseMaintenanceReport report) {
    if (!report.isHealthy) {
      final String first = report.problems.first;
      final int rest = report.problems.length - 1;
      return rest == 0
          ? 'The collection reported a problem: $first'
          : 'The collection reported ${report.problems.length} problems, '
                'starting with: $first';
    }
    final String repaired = report.wasSearchIndexRebuilt
        ? ', search index rebuilt'
        : '';
    return report.bytesReclaimed == 0
        ? 'Database optimized. There was no space left to reclaim$repaired.'
        : 'Database optimized. ${_formatBytes(report.bytesReclaimed)} '
              'reclaimed$repaired.';
  }

  /// Bytes as something a person reads, since the number is only ever shown to
  /// answer "was that worth doing".
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Clears the one-shot message after the view has shown it.
  void shouldClearMessage() {
    final SettingsUiState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<SettingsUiState>.data(
      current!.copyWith(shouldClearMessage: true),
    );
  }
}

final AsyncNotifierProvider<SettingsViewModel, SettingsUiState>
settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, SettingsUiState>(
      SettingsViewModel.new,
    );
