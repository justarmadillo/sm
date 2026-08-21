/// ViewModel for one reveal-and-grade recall interaction.
///
/// Three affordances live here that are not part of grading itself and must
/// not behave as if they were: undoing the last grade, editing the card's
/// wording without rescheduling it, and jumping to the passage a failing card
/// came from.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/review/review_commands.dart';
import '../../../application/review/review_handlers.dart';
import '../../../core/result.dart';
import '../../../core/tracing.dart';
import '../../../domain/content/card.dart';
import '../../../domain/scheduling/card_scheduler.dart';
import '../../library/presentation/library_view_model.dart';

@immutable
final class ReviewUiState {
  const ReviewUiState({
    required this.card,
    required this.cardState,
    this.answerRevealed = false,
    this.message,
    this.isBusy = false,
    this.isDone = false,
    this.isLeech = false,
    this.buriedSiblings = 0,
    this.canUndo = false,
    this.isEditing = false,
  });

  final Card card;
  final CardState cardState;
  final bool answerRevealed;
  final UiMessage? message;
  final bool isBusy;
  final bool isDone;

  /// Whether this card has failed often enough to deserve rewriting.
  ///
  /// Surfaced, never auto-suspended: most repeated failures are badly written
  /// cards rather than hard facts, and the fix is to open the source passage.
  final bool isLeech;

  /// How many same-parent cards the last grade pushed off today.
  final int buriedSiblings;

  /// Whether a grade has been applied that can still be taken back.
  final bool canUndo;

  /// Whether the inline editor is open.
  final bool isEditing;

  String get question => switch (card.kind) {
    CardKind.qa => card.front,
    CardKind.cloze => renderClozeQuestion(card.front, card.clozeOrdinal!),
  };

  String get answer => switch (card.kind) {
    CardKind.qa => card.back,
    CardKind.cloze => renderClozeAnswer(card.front),
  };

  /// The element this card was formulated from, when it has one.
  CardParent? get parent => card.parent;

  int get lapses => cardState.memory.lapses;

  ReviewUiState copyWith({
    Card? card,
    CardState? cardState,
    bool? answerRevealed,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
    bool? isDone,
    bool? isLeech,
    int? buriedSiblings,
    bool? canUndo,
    bool? isEditing,
  }) => ReviewUiState(
    card: card ?? this.card,
    cardState: cardState ?? this.cardState,
    answerRevealed: answerRevealed ?? this.answerRevealed,
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
    isDone: isDone ?? this.isDone,
    isLeech: isLeech ?? this.isLeech,
    buriedSiblings: buriedSiblings ?? this.buriedSiblings,
    canUndo: canUndo ?? this.canUndo,
    isEditing: isEditing ?? this.isEditing,
  );
}

final class ReviewViewModel extends FamilyAsyncNotifier<ReviewUiState, String> {
  DateTime? _startedAt;

  @override
  Future<ReviewUiState> build(String arg) async {
    _startedAt = ref.read(clockProvider).nowUtc();
    final Card? card = await ref.read(contentRepositoryProvider).findCard(arg);
    if (card == null) throw StateError('card $arg is not in the library');
    final CardState? cardState = await ref
        .read(learningRepositoryProvider)
        .findCardState(arg);
    if (cardState == null) throw StateError('card $arg has no memory state');

    final int leechLapses = (await ref
            .read(schedulingContextProvider)
            .settings())
        .cards
        .leechLapses;
    return ReviewUiState(
      card: card,
      cardState: cardState,
      isLeech: leechLapses > 0 && cardState.memory.lapses >= leechLapses,
    );
  }

  void revealAnswer() {
    final ReviewUiState? current = state.valueOrNull;
    if (current == null || current.answerRevealed || current.isBusy) return;
    state = AsyncValue<ReviewUiState>.data(
      current.copyWith(answerRevealed: true),
    );
  }

  Future<void> grade(CardRating rating) async {
    final ReviewUiState? current = state.valueOrNull;
    if (current == null ||
        !current.answerRevealed ||
        current.isBusy ||
        current.isDone ||
        current.isEditing) {
      return;
    }
    state = AsyncValue<ReviewUiState>.data(current.copyWith(isBusy: true));
    final DateTime now = ref.read(clockProvider).nowUtc();
    final Result<ReviewOutcome> result = await ref
        .read(reviewHandlersProvider)
        .review(
          ReviewCard(
            OperationId(ref.read(idGeneratorProvider).newId()),
            cardId: current.card.id,
            rating: rating,
            elapsedMs: _elapsedMs(now),
            timestampUtc: now,
          ),
        );
    final ReviewUiState latest = state.valueOrNull ?? current;
    state = AsyncValue<ReviewUiState>.data(
      result.fold(
        (ReviewOutcome outcome) => latest.copyWith(
          cardState: outcome.state,
          isBusy: false,
          isDone: true,
          isLeech: outcome.isLeech,
          buriedSiblings: outcome.buriedSiblings,
          canUndo: true,
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Takes back the grade just applied and returns the card to the session.
  Future<void> undoLastGrade() async {
    final ReviewUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<ReviewUiState>.data(current.copyWith(isBusy: true));

    final Result<CardState> result = await ref
        .read(reviewHandlersProvider)
        .undoLastReview(
          UndoLastReview(
            OperationId(ref.read(idGeneratorProvider).newId()),
            cardId: current.card.id,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    final ReviewUiState latest = state.valueOrNull ?? current;
    state = AsyncValue<ReviewUiState>.data(
      result.fold(
        (CardState restored) => latest.copyWith(
          cardState: restored,
          isBusy: false,
          // Back to before the grade, answer still showing: the user undid a
          // misclick and should be able to grade again immediately.
          isDone: false,
          canUndo: false,
          answerRevealed: true,
          message: const UiMessage('Grade taken back'),
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Opens or closes the inline editor.
  void setEditing(bool editing) {
    final ReviewUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<ReviewUiState>.data(
      current.copyWith(isEditing: editing),
    );
  }

  /// Rewrites the card's text. Never reschedules it.
  Future<void> edit({String? front, String? back}) async {
    final ReviewUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<ReviewUiState>.data(current.copyWith(isBusy: true));

    final Result<Card> result = await ref
        .read(reviewHandlersProvider)
        .editCard(
          EditCard(
            OperationId(ref.read(idGeneratorProvider).newId()),
            cardId: current.card.id,
            front: front,
            back: back,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    final ReviewUiState latest = state.valueOrNull ?? current;
    state = AsyncValue<ReviewUiState>.data(
      result.fold(
        (Card card) => latest.copyWith(
          card: card,
          isBusy: false,
          isEditing: false,
          message: const UiMessage('Card updated'),
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Moves the card out of today without reviewing it.
  Future<void> postpone({int? days}) async {
    final ReviewUiState? current = state.valueOrNull;
    if (current == null || current.isBusy || current.isDone) return;
    state = AsyncValue<ReviewUiState>.data(current.copyWith(isBusy: true));

    final DateTime now = ref.read(clockProvider).nowUtc();
    final Result<CardState> result = await ref
        .read(reviewHandlersProvider)
        .postpone(
          PostponeCard(
            OperationId(ref.read(idGeneratorProvider).newId()),
            cardId: current.card.id,
            until: days == null
                ? null
                : (await ref.read(schedulingContextProvider).today()).addDays(
                    days,
                  ),
            timestampUtc: now,
          ),
        );
    final ReviewUiState latest = state.valueOrNull ?? current;
    state = AsyncValue<ReviewUiState>.data(
      result.fold(
        (CardState deferred) => latest.copyWith(
          cardState: deferred,
          isBusy: false,
          isDone: true,
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  void clearMessage() {
    final ReviewUiState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<ReviewUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }

  int? _elapsedMs(DateTime now) {
    final DateTime? started = _startedAt;
    if (started == null) return null;
    return now.difference(started).inMilliseconds;
  }
}

final AsyncNotifierProviderFamily<ReviewViewModel, ReviewUiState, String>
reviewViewModelProvider =
    AsyncNotifierProvider.family<ReviewViewModel, ReviewUiState, String>(
      ReviewViewModel.new,
    );
