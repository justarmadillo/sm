/// Setup steps shared by more than one test, on top of [AppHarness].
///
/// Only the incidental ones live here — turning a `Source` into an
/// `ElementRef`, importing a few articles, grading a card once so it leaves
/// the new-card stage. The fixture that *is* the scenario stays in the test
/// that reads it, because a reader should not have to open a second file to
/// learn what is being tested.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import 'app_harness.dart';

/// The three-line article most scheduling tests import when the words on the
/// page are not what is being tested.
const String kPlainArticle = '''
# Working memory

Working memory holds about four items at once.
''';

extension HarnessFixtures on AppHarness {
  /// The source's coordinate, which almost every expectation needs.
  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);

  /// The topic record behind [source].
  Future<TopicState> topicOf(Source source) async =>
      (await learning.findTopic(refOf(source)))!;

  /// Imports [count] articles, all due today.
  ///
  /// Each import lands at the bottom of the collection, so creation order is
  /// priority order and anything that discriminates on priority has something
  /// to discriminate on.
  Future<List<Source>> importSources(int count, {String? markdown}) async {
    final List<Source> sources = <Source>[];
    for (var index = 0; index < count; index++) {
      final Result<Source> result = await reader.importSource(
        ImportSource(
          operation(),
          title: 'Article ${index.toString().padLeft(2, '0')}',
          markdown: markdown ?? kPlainArticle,
          priorityPercent: 100,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      sources.add(result.unwrap());
    }
    return sources;
  }

  /// One card on [sourceId], graded once so it leaves the new-card Pending
  /// stage and becomes something the schedulers will move.
  Future<CardState> memorizedCard(String sourceId) async {
    final List<Card> cards = (await formulation.formulate(
      FormulateCards(
        operation(),
        parent: CardParent.source(sourceId),
        drafts: const <CardDraft>[
          ClozeCardDraft('Working memory holds {{c1::four items}}.'),
        ],
        timestampUtc: clock.nowUtc(),
      ),
    )).unwrap();
    final Result<ReviewOutcome> graded = await review.review(
      ReviewCard(
        operation(),
        cardId: cards.single.id,
        rating: CardRating.easy,
        elapsedMs: 1500,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(graded.isOk, isTrue, reason: '${graded.failureOrNull}');
    return (await learning.findCardState(cards.single.id))!;
  }
}
