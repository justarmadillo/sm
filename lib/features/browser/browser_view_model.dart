/// Element commands shared by the Browser tree and the reader.
///
/// Holds no scheduling logic and no projection: the tree renders from
/// `BrowserTreeQuery`, so all this owns is turning user intentions into named
/// commands and surfacing failures as ephemeral effects.
///
/// The moves at the bottom are filing, not scheduling. They change where a row
/// is kept and in what order, and nothing else — an extract that moves still
/// points at the passage it was cut from.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/features/browser/browser_commands.dart';
import 'package:incremental_reader/features/browser/browser_providers.dart';
import 'package:incremental_reader/features/extract/extract_commands.dart';
import 'package:incremental_reader/features/extract/extract_providers.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/priority/learning_commands.dart';
import 'package:incremental_reader/features/priority/priority_browser_commands.dart';
import 'package:incremental_reader/features/priority/priority_providers.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/reader/reader_providers.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/features/review/review_providers.dart';
import 'package:incremental_reader/features/video/video_commands.dart';
import 'package:incremental_reader/features/video/video_providers.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// A one-shot thing for the view to do, not durable state.
@immutable
final class UiMessage {
  const UiMessage(this.text, {this.isError = false});

  final String text;
  final bool isError;
}

/// What the shared command surface exposes to a view.
@immutable
final class BrowserUiState {
  const BrowserUiState({this.message, this.isBusy = false});

  /// Ephemeral: shown once, then cleared.
  final UiMessage? message;

  final bool isBusy;

  BrowserUiState copyWith({
    UiMessage? message,
    bool? isBusy,
    bool shouldClearMessage = false,
  }) => BrowserUiState(
    message: shouldClearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
  );
}

/// The shared element-command ViewModel.
final class BrowserViewModel extends AsyncNotifier<BrowserUiState> {
  @override
  Future<BrowserUiState> build() async => _load();

  Future<BrowserUiState> _load() async => const BrowserUiState();

  /// Imports pasted or opened markdown as a new source.
  Future<String?> importMarkdown({
    required String title,
    required String markdown,
  }) async {
    final result = await _command<Source>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .importSource(
            ImportSource(operation, title: title, markdown: markdown),
          ),
      success: (Source source) => 'Imported "${source.title}"',
    );
    return result?.id;
  }

  /// Adds a video and the range of it worth studying.
  Future<String?> importVideo({
    required String url,
    required String title,
    required int startSeconds,
    required int endSeconds,
    int? durationSeconds,
  }) async {
    final VideoElement? result = await _command<VideoElement>(
      (OperationId operation) => ref
          .read(videoCommandRunnerProvider)
          .importVideo(
            ImportVideo(
              operation,
              url: url,
              title: title,
              startSeconds: startSeconds,
              endSeconds: endSeconds,
              durationSeconds: durationSeconds,
            ),
          ),
      success: (VideoElement element) => 'Added "${element.displayTitle}"',
    );
    return result?.id;
  }

  /// Renames a source.
  Future<void> rename(String sourceId, String title) => _command<Source>(
    (OperationId operation) => ref
        .read(readerCommandRunnerProvider)
        .renameSource(
          RenameSource(operation, sourceId: sourceId, title: title),
        ),
  );

  /// Rewrites an extract's text from the Browser tree.
  ///
  /// The same command the Extract screen uses, so the guard that refuses an
  /// edit under nested extracts applies here too: their coordinates point into
  /// this text.
  Future<void> editExtract(String extractId, String markdown) =>
      _command<Extract>(
        (OperationId operation) => ref
            .read(extractCommandRunnerProvider)
            .editExtract(
              EditExtract(operation, extractId: extractId, markdown: markdown),
            ),
        success: (_) => 'Extract updated',
      );

  /// Rewrites a card's wording from the Browser tree. Never reschedules it.
  Future<void> editCard(String cardId, {String? front, String? back}) =>
      _command<Card>(
        (OperationId operation) => ref
            .read(reviewCommandRunnerProvider)
            .editCard(
              EditCard(operation, cardId: cardId, front: front, back: back),
            ),
        success: (_) => 'Card updated',
      );

  /// Changes how quickly a source comes back.
  /// Undismiss: returns a dismissed source to the pending store.
  ///
  /// It does not restore the schedule or the priority Dismiss cleared, so the
  /// message deliberately does not promise a due date.
  Future<void> undismiss(ElementRef ref_) => _command<Object>(
    (OperationId operation) => ref
        .read(readerCommandRunnerProvider)
        .undismiss(UndismissSource(operation, ref: ref_)),
    success: (_) => 'Undismissed, back in the pending store',
  );

  /// Stops scheduling a source without deleting it.
  Future<void> dismiss(ElementRef ref_) => _command<Object>(
    (OperationId operation) => ref
        .read(readerCommandRunnerProvider)
        .dismiss(DismissElement(operation, ref: ref_)),
    success: (_) => 'Dismissed. The content is still here.',
  );

  /// Runs one Learning command on a single row of the tree.
  ///
  /// The Priority queue offers the same menu over a whole selection. Only the
  /// busy flag and the toast differ between the two, so which command object
  /// each entry builds lives in `learning_commands.dart` rather than twice.
  Future<void> applyLearningCommand(
    LearningCommand command,
    ElementRef ref_, {
    LearningCommandAnswers answers = const LearningCommandAnswers(),
  }) => applyLearningCommandToSelection(command, <ElementRef>[
    ref_,
  ], answers: answers);

  /// Runs one Learning command over the Browser's current selection.
  Future<void> applyLearningCommandToSelection(
    LearningCommand command,
    List<ElementRef> refs, {
    LearningCommandAnswers answers = const LearningCommandAnswers(),
  }) async {
    final StudyDay day = await ref.read(schedulingContextProvider).today();
    await _command<PriorityBrowserCommandOutcome>(
      (OperationId operation) => runLearningCommand(
        command,
        commandRunner: ref.read(priorityBrowserCommandRunnerProvider),
        operation: operation,
        refs: refs,
        day: day,
        timestampUtc: ref.read(clockProvider).nowUtc(),
        answers: answers,
      ),
      // These commands are filters as much as actions, so a row the command's
      // own rules refuse has to say so: silence would read as a failure.
      success: (PriorityBrowserCommandOutcome outcome) =>
          outcome.changedRefCount == 0
          ? 'Nothing was eligible'
          : '${command.successVerb} ${outcome.changedRefCount} element'
                '${outcome.changedRefCount == 1 ? '' : 's'}',
    );
  }

  /// Erases an element and everything below it. There is no undo.
  ///
  /// The message counts what went rather than naming the row: a delete that
  /// took a branch of forty elements and a delete that took one look
  /// identical in a tree that has just redrawn itself without them.
  Future<void> deleteElement(ElementRef ref_) =>
      _command<BrowserDeletionOutcome>(
        (OperationId operation) => ref
            .read(browserCommandRunnerProvider)
            .deleteElement(DeleteElement(operation, ref: ref_)),
        success: (BrowserDeletionOutcome outcome) {
          final int removed = outcome.deletedRefs.length;
          return removed == 1 ? 'Deleted.' : 'Deleted $removed elements.';
        },
      );

  /// Erases every selected branch as one indivisible Browser action.
  Future<void> deleteElements(List<ElementRef> refs) =>
      _command<BrowserDeletionOutcome>(
        (OperationId operation) => ref
            .read(browserCommandRunnerProvider)
            .deleteElements(DeleteElements(operation, refs: refs)),
        success: (BrowserDeletionOutcome outcome) {
          final int removed = outcome.deletedRefs.length;
          return removed == 1 ? 'Deleted.' : 'Deleted $removed elements.';
        },
      );

  /// Writes cards from the Browser, under [parent] or standalone.
  ///
  /// The same command the Extract screen issues, so the cards are scheduled
  /// the way formulated cards always are. A null parent is a card that belongs
  /// to nothing yet, which is the only way to write one before there is
  /// anything to hang it on.
  Future<List<ElementRef>?> createCards({
    required CardParent? parent,
    required List<CardDraft> drafts,
  }) async {
    final List<Card>? created = await _command<List<Card>>(
      (OperationId operation) => ref
          .read(formulationCommandRunnerProvider)
          .formulate(FormulateCards(operation, parent: parent, drafts: drafts)),
      success: (List<Card> cards) =>
          '${cards.length} card${cards.length == 1 ? '' : 's'} added',
    );
    if (created == null) return null;
    return <ElementRef>[
      for (final Card card in created)
        ElementRef(id: card.id, type: ElementType.card),
    ];
  }

  /// Moves an element above the sibling before it.
  Future<void> moveUp(ElementRef ref_) => _filing(
    (OperationId operation) => ref
        .read(browserCommandRunnerProvider)
        .moveUp(MoveElementUp(operation, ref: ref_)),
  );

  /// Moves an element below the sibling after it.
  Future<void> moveDown(ElementRef ref_) => _filing(
    (OperationId operation) => ref
        .read(browserCommandRunnerProvider)
        .moveDown(MoveElementDown(operation, ref: ref_)),
  );

  /// Files an element under the row above it.
  Future<void> nestUnderPreviousSibling(ElementRef ref_) => _filing(
    (OperationId operation) => ref
        .read(browserCommandRunnerProvider)
        .nestUnderPreviousSibling(
          NestElementUnderPreviousSibling(operation, ref: ref_),
        ),
  );

  /// Files an element beside the element it is currently under.
  Future<void> liftOutOfParent(ElementRef ref_) => _filing(
    (OperationId operation) => ref
        .read(browserCommandRunnerProvider)
        .liftOutOfParent(LiftElementOutOfParent(operation, ref: ref_)),
  );

  /// Files an element under [parentRef], in front of [beforeRef].
  ///
  /// This is what a drop reports. A null parent files it at the top of the
  /// tree; a null [beforeRef] puts it last.
  Future<void> fileUnder({
    required ElementRef ref_,
    required ElementRef? parentRef,
    ElementRef? beforeRef,
  }) => _filing(
    (OperationId operation) => ref
        .read(browserCommandRunnerProvider)
        .fileUnder(
          FileElementUnder(
            operation,
            ref: ref_,
            parentRef: parentRef,
            beforeRef: beforeRef,
          ),
        ),
  );

  /// Runs one move.
  ///
  /// A move that cannot happen — the top row asked to go up, an element asked
  /// to move out of nothing — is reported as an ordinary refusal rather than
  /// an error toast, because it is a normal thing to try at the edge of a
  /// list.
  Future<void> _filing(
    Future<Result<BrowserFilingOutcome>> Function(OperationId operation) run,
  ) => _command<BrowserFilingOutcome>(run, isRefusalQuiet: true);

  /// Reloads the projection, for example after returning from the Reader.
  Future<void> refresh() async {
    state = AsyncValue<BrowserUiState>.data(await _load());
  }

  /// Clears the one-shot message after the view has shown it.
  void shouldClearMessage() {
    final current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<BrowserUiState>.data(
      current!.copyWith(shouldClearMessage: true),
    );
  }

  /// Runs one command, refreshes the projection, and reports the outcome.
  Future<T?> _command<T>(
    Future<Result<T>> Function(OperationId operation) run, {
    String Function(T value)? success,
    bool isRefusalQuiet = false,
  }) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue<BrowserUiState>.data(current.copyWith(isBusy: true));
    }

    // A fresh operation id per user action: that is what makes a retry after a
    // failure distinguishable from a duplicate of the same action.
    final result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
    );
    final reloaded = await _load();

    state = AsyncValue<BrowserUiState>.data(
      reloaded.copyWith(
        message: result.fold(
          (T value) => success == null ? null : UiMessage(success(value)),
          (AppFailure failure) => isRefusalQuiet && failure is ValidationFailure
              ? null
              : UiMessage(failure.message, isError: true),
        ),
      ),
    );
    return result.valueOrNull;
  }
}

/// The Browser ViewModel provider.
final AsyncNotifierProvider<BrowserViewModel, BrowserUiState>
browserViewModelProvider =
    AsyncNotifierProvider<BrowserViewModel, BrowserUiState>(
      BrowserViewModel.new,
    );
