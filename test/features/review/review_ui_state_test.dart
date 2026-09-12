import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/features/review/review_view_model.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';

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
      extra: 'It models stability and difficulty.',
      createdAtUtc: DateTime.utc(2026),
    );
    final ui = ReviewUiState(card: card, cardState: stateFor(card.id));

    expect(ui.question, 'What is FSRS?');
    expect(ui.answer, 'A memory scheduler.');
    expect(ui.extra, 'It models stability and difficulty.');
    expect(ui.isAnswerRevealed, isFalse);
    expect(ui.copyWith(isAnswerRevealed: true).isAnswerRevealed, isTrue);
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
    expect(ui.answer, '**Paris** is in France.');
  });

  test('overlapper reveals only the configured neighbours', () {
    const text = '{{c1::one}}\n{{c2::two}}\n{{c3::three}}\n{{c4::four}}';
    final card = Card.clozeOverlapper(
      id: 'overlap',
      parent: const CardParent.extract('extract'),
      text: text,
      ordinal: 3,
      contextBefore: 1,
      contextAfter: 0,
      createdAtUtc: DateTime.utc(2026),
    );
    final ui = ReviewUiState(card: card, cardState: stateFor(card.id));

    expect(ui.question, '[...]\ntwo\n[...]\n[...]');
    expect(ui.answer, '[...]\ntwo\n**three**\n[...]');
  });

  test('negative overlap windows reveal everything on that side', () {
    const text = '{{c1::one}} {{c2::two}} {{c3::three}}';

    expect(
      renderOverlapQuestion(text, 2, before: -1, after: 0),
      'one [...] [...]',
    );
    expect(
      renderOverlapAnswer('{{c1::only}}', 1, before: 1, after: 1),
      '**only**',
    );
  });
}
