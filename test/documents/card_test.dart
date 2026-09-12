/// Verifies that card questions never project their revealed answers.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:test/test.dart';

void main() {
  final DateTime createdAtUtc = DateTime.utc(2025);

  test('question and answer cards project only the question', () {
    final Card card = Card.qa(
      id: 'card-1',
      parent: null,
      question: 'How many items does working memory hold?',
      answer: 'About four items.',
      createdAtUtc: createdAtUtc,
    );

    expect(cardQuestionText(card), card.front);
    expect(cardQuestionText(card), isNot(contains(card.back)));
  });

  test('cloze questions hide the tested answer', () {
    final Card card = Card.cloze(
      id: 'card-2',
      parent: null,
      text: 'Working memory holds about {{c1::four items}}.',
      ordinal: 1,
      createdAtUtc: createdAtUtc,
    );

    expect(cardQuestionText(card), contains('[...]'));
    expect(cardQuestionText(card), isNot(contains('four items')));
  });
}
