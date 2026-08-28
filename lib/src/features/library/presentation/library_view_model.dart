/// Element commands shared by the Contents tree and the reader.
///
/// Holds no scheduling logic and no projection: the tree renders from
/// `ContentTreeQuery`, so all this owns is turning user intentions into named
/// commands and surfacing failures as ephemeral effects.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:incremental_reader/src/app/providers.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';

/// A one-shot thing for the view to do, not durable state.
@immutable
final class UiMessage {
  const UiMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// What the shared command surface exposes to a view.
@immutable
final class LibraryUiState {
  const LibraryUiState({this.message, this.isBusy = false});

  /// Ephemeral: shown once, then cleared.
  final UiMessage? message;

  final bool isBusy;

  LibraryUiState copyWith({
    UiMessage? message,
    bool? isBusy,
    bool clearMessage = false,
  }) => LibraryUiState(
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
  );
}

/// The shared element-command ViewModel.
final class LibraryViewModel extends AsyncNotifier<LibraryUiState> {
  @override
  Future<LibraryUiState> build() async => _load();

  Future<LibraryUiState> _load() async => const LibraryUiState();

  /// Imports pasted or opened markdown as a new source.
  Future<String?> importMarkdown({
    required String title,
    required String markdown,
  }) async {
    final result = await _command<Source>(
      (OperationId operation) => ref
          .read(readerHandlersProvider)
          .importSource(
            ImportSource(operation, title: title, markdown: markdown),
          ),
      success: (Source source) => 'Imported "${source.title}"',
    );
    return result?.id;
  }

  /// Renames a source.
  Future<void> rename(String sourceId, String title) => _command<Source>(
    (OperationId operation) => ref
        .read(readerHandlersProvider)
        .renameSource(
          RenameSource(operation, sourceId: sourceId, title: title),
        ),
  );

  /// Changes how quickly a source comes back.
  /// Undismiss: returns a dismissed source to the pending store.
  ///
  /// It does not restore the schedule or the priority Dismiss cleared, so the
  /// message deliberately does not promise a due date.
  Future<void> undismiss(ElementRef ref_) => _command<Object>(
    (OperationId operation) => ref
        .read(readerHandlersProvider)
        .undismiss(UndismissSource(operation, ref: ref_)),
    success: (_) => 'Undismissed, back in the pending store',
  );

  /// Stops scheduling a source without deleting it.
  Future<void> dismiss(ElementRef ref_) => _command<Object>(
    (OperationId operation) => ref
        .read(readerHandlersProvider)
        .dismiss(DismissElement(operation, ref: ref_)),
    success: (_) => 'Dismissed. The content is still here.',
  );

  /// Soft-deletes a source while retaining it and every descendant.
  Future<void> deleteSource(String sourceId) => _command<Object>(
    (OperationId operation) => ref
        .read(readerHandlersProvider)
        .deleteSource(DeleteSource(operation, sourceId: sourceId)),
    success: (_) => 'Deleted. You can restore it from the Library.',
  );

  /// Reloads the projection, for example after returning from the Reader.
  Future<void> refresh() async {
    state = AsyncValue<LibraryUiState>.data(await _load());
  }

  /// Clears the one-shot message after the view has shown it.
  void clearMessage() {
    final current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<LibraryUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }

  /// Runs one command, refreshes the projection, and reports the outcome.
  Future<T?> _command<T>(
    Future<Result<T>> Function(OperationId operation) run, {
    String Function(T value)? success,
  }) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue<LibraryUiState>.data(current.copyWith(isBusy: true));
    }

    // A fresh operation id per user action: that is what makes a retry after a
    // failure distinguishable from a duplicate of the same action.
    final result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
    );
    final reloaded = await _load();

    state = AsyncValue<LibraryUiState>.data(
      reloaded.copyWith(
        message: result.fold(
          (T value) => success == null ? null : UiMessage(success(value)),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
    return result.valueOrNull;
  }
}

/// The Library ViewModel provider.
final AsyncNotifierProvider<LibraryViewModel, LibraryUiState>
libraryViewModelProvider =
    AsyncNotifierProvider<LibraryViewModel, LibraryUiState>(
      LibraryViewModel.new,
    );
