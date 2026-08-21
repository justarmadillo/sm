import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/src/domain/content/card.dart';
import 'package:incremental_reader/src/domain/scheduling/card_scheduler.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/features/review/presentation/review_view_model.dart';

void main() {
  const day = StudyDay(year: 2026, month: 8, day: 20, zoneId: 'UTC');

  CardState stateFor(String cardId) => CardState(
    schedule: ElementSchedule(
      ref: ElementRef(id: cardId, type: ElementType.card),
      priority: PriorityRank.middle,
      lifecycle: ElementLifecycle.active,
      dueDay: day,
      originalDueDay: day,
    ),
    memory: CardMemory.newCard(
      cardId: cardId,
      dueAtUtc: DateTime.utc(2026, 8, 20, 10),
    ),
  );

  test('Q&A exposes front and back without revealing initially', () {
    final card = Card.qa(
      id: 'qa',
      parent: const CardParent.extract('extract'),
      question: 'What is FSRS?',
      answer: 'A memory scheduler.',
      createdAtUtc: DateTime.utc(2026),
    );
    final ui = ReviewUiState(card: card, cardState: stateFor(card.id));

    expect(ui.question, 'What is FSRS?');
    expect(ui.answer, 'A memory scheduler.');
    expect(ui.answerRevealed, isFalse);
    expect(ui.copyWith(answerRevealed: true).answerRevealed, isTrue);
  });

  test('cloze hides only its own ordinal and reveals every answer', () {
    final card = Card.cloze(
      id: 'cloze',
      parent: const CardParent.extract('extract'),
      text: '{{c1::Paris}} is in {{c2::France}}.',
      ordinal: 1,
      createdAtUtc: DateTime.utc(2026),
    );
    final ui = ReviewUiState(card: card, cardState: stateFor(card.id));

    expect(ui.question, '[...] is in France.');
    expect(ui.answer, 'Paris is in France.');
  });
}
