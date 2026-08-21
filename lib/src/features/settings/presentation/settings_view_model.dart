/// ViewModel for Settings.
///
/// Edits are held as a draft and written on Save, so a half-typed number never
/// reaches a scheduler. Saving invalidates the providers that captured the old
/// configuration, because a queue built under the previous caps would keep
/// showing them until something else happened to rebuild it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result.dart';
import '../../../domain/settings/app_settings.dart';
import '../../library/presentation/library_view_model.dart';
import '../../priority/presentation/priority_view_model.dart';
import '../../queue/presentation/queue_view_model.dart';

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
    bool clearMessage = false,
  }) => SettingsUiState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    isBusy: isBusy ?? this.isBusy,
    message: clearMessage ? null : (message ?? this.message),
  );
}

final class SettingsViewModel extends AsyncNotifier<SettingsUiState> {
  @override
  Future<SettingsUiState> build() async {
    final AppSettings settings = await ref
        .read(settingsStoreProvider)
        .reload();
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

    final Result<AppSettings> result = await ref
        .read(settingsStoreProvider)
        .save(current.draft);
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
    ref.invalidate(priorityBrowserProvider);

    state = AsyncValue<SettingsUiState>.data(
      SettingsUiState(
        saved: result.unwrap(),
        draft: result.unwrap(),
        message: const UiMessage('Settings saved'),
      ),
    );
  }

  /// Clears the one-shot message after the view has shown it.
  void clearMessage() {
    final SettingsUiState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<SettingsUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }
}

final AsyncNotifierProvider<SettingsViewModel, SettingsUiState>
settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, SettingsUiState>(
      SettingsViewModel.new,
    );
