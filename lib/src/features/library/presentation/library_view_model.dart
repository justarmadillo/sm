/// ViewModel for the Library.
///
/// Holds no scheduling logic: every mutation goes out as a named command and
/// comes back as a refreshed projection. The ViewModel's job is to turn user
/// intentions into commands, expose immutable state, and surface failures as
/// ephemeral effects — nothing more.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/ports/repositories.dart';
import '../../../application/reader/reader_commands.dart';
import '../../../core/result.dart';
import '../../../core/tracing.dart';
import '../../../domain/content/source.dart';
import '../../../domain/scheduling/element.dart';
import '../../../domain/scheduling/study_day.dart';
import '../../../domain/scheduling/topic_scheduler.dart';

/// A one-shot thing for the view to do, not durable state.
@immutable
final class UiMessage {
  const UiMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// Everything the Library screen renders.
@immutable
final class LibraryUiState {
  const LibraryUiState({
    required this.entries,
    required this.today,
    this.effectiveDue = const <ElementRef, StudyDay>{},
    this.message,
    this.isBusy = false,
  });

  final List<LibraryEntry> entries;
  final StudyDay today;

  /// When each source may next be read, after Later, automatic overflow, and
  /// any Mercy override. Never the canonical date: showing that would tell the
  /// user their own postponement did not take.
  final Map<ElementRef, StudyDay> effectiveDue;

  /// The day [entry] may next be presented on.
  StudyDay dueDayOf(LibraryEntry entry) =>
      effectiveDue[entry.schedule.ref] ?? entry.schedule.algorithmicDueDay;

  /// Ephemeral: shown once, then cleared.
  final UiMessage? message;

  final bool isBusy;

  bool _isDue(LibraryEntry entry) =>
      entry.schedule.lifecycle.isSchedulable && dueDayOf(entry) <= today;

  /// Sources eligible to be read today.
  List<LibraryEntry> get dueToday => <LibraryEntry>[
    for (final entry in entries)
      if (_isDue(entry)) entry,
  ];

  /// Everything else, including finished and dismissed sources.
  List<LibraryEntry> get later => <LibraryEntry>[
    for (final entry in entries)
      if (!_isDue(entry)) entry,
  ];

  LibraryUiState copyWith({
    List<LibraryEntry>? entries,
    StudyDay? today,
    UiMessage? message,
    Map<ElementRef, StudyDay>? effectiveDue,
    bool clearMessage = false,
    bool? isBusy,
  }) => LibraryUiState(
    entries: entries ?? this.entries,
    today: today ?? this.today,
    effectiveDue: effectiveDue ?? this.effectiveDue,
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
  );
}

/// The Library screen's ViewModel.
final class LibraryViewModel extends AsyncNotifier<LibraryUiState> {
  @override
  Future<LibraryUiState> build() async => _load();

  Future<LibraryUiState> _load() async {
    final entries = await ref.read(libraryQueryProvider).listEntries();
    final today = await ref.read(readerHandlersProvider).today();
    final effectiveDue = await ref
        .read(effectiveDueQueryProvider)
        .forTopics(<TopicState>[for (final entry in entries) entry.topic]);
    return LibraryUiState(
      entries: entries,
      today: today,
      effectiveDue: effectiveDue,
    );
  }

  /// Imports pasted or opened markdown as a new source.
  Future<String?> importMarkdown({
    required String title,
    required String markdown,
    ReadingPace pace = ReadingPace.normal,
  }) async {
    final result = await _command<Source>(
      (OperationId operation) => ref
          .read(readerHandlersProvider)
          .importSource(
            ImportSource(
              operation,
              title: title,
              markdown: markdown,
              pace: pace,
            ),
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
  Future<void> setPace(String sourceId, ReadingPace pace) => _command<Source>(
    (OperationId operation) => ref
        .read(readerHandlersProvider)
        .setReadingPace(
          SetReadingPace(operation, sourceId: sourceId, pace: pace),
        ),
    success: (Source source) => 'Pace set to ${pace.name}',
  );

  /// Returns a finished, dismissed, or suspended source to the queue.
  Future<void> reactivate(ElementRef ref_) => _command<Object>(
    (OperationId operation) => ref
        .read(readerHandlersProvider)
        .reactivate(ReactivateElement(operation, ref: ref_)),
    success: (_) => 'Back in the queue, due today',
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
