/// ViewModel for one reveal-and-grade recall interaction.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/review/review_commands.dart';
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
  });

  final Card card;
  final CardState cardState;
  final bool answerRevealed;
  final UiMessage? message;
  final bool isBusy;
  final bool isDone;

  String get question => switch (card.kind) {
    CardKind.qa => card.front,
    CardKind.cloze => renderClozeQuestion(card.front, card.clozeOrdinal!),
  };

  String get answer => switch (card.kind) {
    CardKind.qa => card.back,
    CardKind.cloze => renderClozeAnswer(card.front),
  };

  ReviewUiState copyWith({
    CardState? cardState,
    bool? answerRevealed,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
    bool? isDone,
  }) => ReviewUiState(
    card: card,
    cardState: cardState ?? this.cardState,
    answerRevealed: answerRevealed ?? this.answerRevealed,
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
    isDone: isDone ?? this.isDone,
  );
}

final class ReviewViewModel extends FamilyAsyncNotifier<ReviewUiState, String> {
  DateTime? _startedAt;

  @override
  Future<ReviewUiState> build(String arg) async {
    _startedAt = ref.read(clockProvider).nowUtc();
    final card = await ref.read(contentRepositoryProvider).findCard(arg);
    if (card == null) throw StateError('card $arg is not in the library');
    final cardState = await ref
        .read(learningRepositoryProvider)
        .findCardState(arg);
    if (cardState == null) throw StateError('card $arg has no memory state');
    return ReviewUiState(card: card, cardState: cardState);
  }

  void revealAnswer() {
    final current = state.valueOrNull;
    if (current == null || current.answerRevealed || current.isBusy) return;
    state = AsyncValue<ReviewUiState>.data(
      current.copyWith(answerRevealed: true),
    );
  }

  Future<void> grade(CardRating rating) async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.answerRevealed ||
        current.isBusy ||
        current.isDone) {
      return;
    }
    state = AsyncValue<ReviewUiState>.data(current.copyWith(isBusy: true));
    final now = ref.read(clockProvider).nowUtc();
    final result = await ref
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
    final latest = state.valueOrNull ?? current;
    state = AsyncValue<ReviewUiState>.data(
      result.fold(
        (CardState value) =>
            latest.copyWith(cardState: value, isBusy: false, isDone: true),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  void clearMessage() {
    final current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<ReviewUiState>.data(
      current!.copyWith(clearMessage: true),
    );
  }

  int? _elapsedMs(DateTime now) {
    final started = _startedAt;
    if (started == null) return null;
    return now.difference(started).inMilliseconds;
  }
}

final AsyncNotifierProviderFamily<ReviewViewModel, ReviewUiState, String>
reviewViewModelProvider =
    AsyncNotifierProvider.family<ReviewViewModel, ReviewUiState, String>(
      ReviewViewModel.new,
    );
