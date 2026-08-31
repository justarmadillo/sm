/// Delete, the one command in the app that destroys anything.
///
/// The promise being pinned here is that it finishes the job. A delete that
/// left the schedule behind, or the search rows, or an extract still pointing
/// into text that no longer exists, is the failure this replaces: from the
/// user's side it looked exactly like nothing having happened.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/browser/browser_commands.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/extract/extract_commands.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

import '../../support/anchors.dart';
import '../../support/app_harness.dart';

const String _alphaMarkdown = '''
# Alpha

Spacing beats massing for durable retention, and testing beats rereading.
''';

const String _betaMarkdown = '''
# Beta

Consolidation moves a trace from fragile recall into robust storage.
''';

void main() {
  late AppHarness harness;
  late FakeClock clock;
  late Source alpha;
  late Source beta;
  late Extract alphaExtract;
  late Card alphaCard;

  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);

  Future<Source> importSource(String title, String markdown) async =>
      (await harness.reader.importSource(
        ImportSource(harness.operation(), title: title, markdown: markdown),
      )).unwrap();

  Future<Extract> extractFrom(Source source) async {
    final Document document = (await harness.content.findDocument(source.id))!;
    final Block paragraph = document.blocks.firstWhere(
      (Block block) => block.type == BlockType.paragraph,
    );
    final SelectionRange range = SelectionRange.of(
      startAnchor: anchorAtBlockStart(paragraph),
      endAnchor: anchorIn(paragraph, 7),
      markdown: document.markdownBetween(
        anchorAtBlockStart(paragraph),
        anchorIn(paragraph, 7),
      ),
    );
    return (await harness.extraction.createExtract(
      CreateExtract(
        harness.operation(),
        parentId: source.id,
        hasSourceAsParent: true,
        range: range,
      ),
    )).unwrap();
  }

  Future<Card> formulateFrom(Extract extract) async =>
      (await harness.formulation.formulate(
        FormulateCards(
          harness.operation(),
          parent: CardParent.extract(extract.id),
          drafts: <CardDraft>[const QaCardDraft(question: 'Q?', answer: 'A.')],
        ),
      )).unwrap().single;

  /// The titles at the top of the tree, in the order the Browser draws them.
  Future<List<String>> rootTitles() async => <String>[
    for (final BrowserTreeNode node in await harness.browserTree.load())
      node.title,
  ];

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(database: openInMemoryDatabase(), clock: clock);
    alpha = await importSource('Alpha', _alphaMarkdown);
    clock.advance(const Duration(minutes: 1));
    beta = await importSource('Beta', _betaMarkdown);
    alphaExtract = await extractFrom(alpha);
    alphaCard = await formulateFrom(alphaExtract);
  });

  tearDown(() => harness.database.close());

  test(
    'deleting a source takes its extracts and their cards with it',
    () async {
      final Result<BrowserDeletionOutcome> result = await harness.filing
          .deleteElement(DeleteElement(harness.operation(), ref: refOf(alpha)));

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      expect(result.unwrap().deletedRefs, hasLength(3));

      expect(await harness.content.findSource(alpha.id), isNull);
      expect(await harness.content.findExtract(alphaExtract.id), isNull);
      expect(await harness.content.findCard(alphaCard.id), isNull);
    },
  );

  test('the row disappears from the tree, which is the point', () async {
    await harness.filing.deleteElement(
      DeleteElement(harness.operation(), ref: refOf(alpha)),
    );

    expect(await rootTitles(), <String>['Beta']);
  });

  test('nothing scheduled survives the element it belonged to', () async {
    await harness.filing.deleteElement(
      DeleteElement(harness.operation(), ref: refOf(alpha)),
    );

    for (final ElementRef ref in <ElementRef>[
      refOf(alpha),
      ElementRef(id: alphaExtract.id, type: ElementType.extract),
      ElementRef(id: alphaCard.id, type: ElementType.card),
    ]) {
      expect(await harness.learning.findSchedule(ref), isNull, reason: '$ref');
    }
    expect(await harness.learning.findCardState(alphaCard.id), isNull);
    expect(await harness.learning.listReviewsForCard(alphaCard.id), isEmpty);
  });

  test('a deleted element is no longer findable by its own words', () async {
    await harness.filing.deleteElement(
      DeleteElement(harness.operation(), ref: refOf(alpha)),
    );

    final List<SearchHit> hits = await harness.search.search('massing');
    expect(hits, isEmpty);
  });

  test('an extract filed away from its source still goes with it', () async {
    // The one case a tree walk alone would miss, and the one the database
    // would then refuse: filing moved the extract to the top level, but its
    // provenance still names Alpha.
    await harness.filing.fileUnder(
      FileElementUnder(
        harness.operation(),
        ref: ElementRef(id: alphaExtract.id, type: ElementType.extract),
        parentRef: null,
      ),
    );

    final Result<BrowserDeletionOutcome> result = await harness.filing
        .deleteElement(DeleteElement(harness.operation(), ref: refOf(alpha)));

    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    expect(await harness.content.findExtract(alphaExtract.id), isNull);
    expect(await rootTitles(), <String>['Beta']);
  });

  test(
    'deleting one element leaves the rest of the collection alone',
    () async {
      await harness.filing.deleteElement(
        DeleteElement(harness.operation(), ref: refOf(alpha)),
      );

      expect(await harness.content.findSource(beta.id), isNotNull);
      expect(await harness.learning.findSchedule(refOf(beta)), isNotNull);
    },
  );

  test('deleting an extract leaves the source it came from', () async {
    await harness.filing.deleteElement(
      DeleteElement(
        harness.operation(),
        ref: ElementRef(id: alphaExtract.id, type: ElementType.extract),
      ),
    );

    expect(await harness.content.findExtract(alphaExtract.id), isNull);
    expect(await harness.content.findCard(alphaCard.id), isNull);
    expect(await harness.content.findSource(alpha.id), isNotNull);
  });

  test("a deleted element is taken out of today's queues", () async {
    // The runtime state is a list of ids rather than of rows, so nothing in
    // the database removes them: a stage the user is halfway through would
    // otherwise still offer an element that no longer exists.
    await harness.queue.runDailyAdmission(
      RunDailyAdmission(harness.operation(), day: await harness.today()),
    );
    final ElementRef cardRef = ElementRef(
      id: alphaCard.id,
      type: ElementType.card,
    );
    expect(
      (await harness.context.runtimeState()).pending,
      containsAll(<ElementRef>[refOf(alpha), cardRef]),
      reason: 'the fixture has to reach a queue before this can be tested',
    );

    await harness.filing.deleteElement(
      DeleteElement(harness.operation(), ref: refOf(alpha)),
    );

    final Sm20CollectionState runtime = await harness.context.runtimeState();
    for (final List<ElementRef> queue in <List<ElementRef>>[
      runtime.pending,
      runtime.outstanding,
      runtime.outstandingItems,
      runtime.outstandingTopics,
      runtime.finalDrill,
    ]) {
      expect(queue, isNot(contains(cardRef)));
      expect(queue, isNot(contains(refOf(alpha))));
    }
  });

  test('a resent delete does not report a second removal', () async {
    final DeleteElement command = DeleteElement(
      harness.operation(),
      ref: refOf(alpha),
    );
    await harness.filing.deleteElement(command);

    final Result<BrowserDeletionOutcome> replayed = await harness.filing
        .deleteElement(command);

    expect(replayed.isOk, isTrue);
    expect(replayed.unwrap().deletedRefs, isEmpty);
  });

  test('one batch deletes several selected branches', () async {
    final Result<BrowserDeletionOutcome> result = await harness.filing
        .deleteElements(
          DeleteElements(
            harness.operation(),
            refs: <ElementRef>[refOf(alpha), refOf(beta)],
          ),
        );

    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    expect(result.unwrap().deletedRefs, hasLength(4));
    expect(await rootTitles(), isEmpty);
  });

  test(
    'a selected descendant is counted once with its selected parent',
    () async {
      final Result<BrowserDeletionOutcome> result = await harness.filing
          .deleteElements(
            DeleteElements(
              harness.operation(),
              refs: <ElementRef>[
                refOf(alpha),
                ElementRef(id: alphaExtract.id, type: ElementType.extract),
              ],
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      expect(result.unwrap().deletedRefs, hasLength(3));
      expect(await rootTitles(), <String>['Beta']);
    },
  );

  test(
    'an empty delete selection is refused without changing anything',
    () async {
      final Result<BrowserDeletionOutcome> result = await harness.filing
          .deleteElements(
            DeleteElements(harness.operation(), refs: const <ElementRef>[]),
          );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(await rootTitles(), unorderedEquals(<String>['Alpha', 'Beta']));
    },
  );

  test('deleting something already gone is reported, not thrown', () async {
    await harness.filing.deleteElement(
      DeleteElement(harness.operation(), ref: refOf(alpha)),
    );

    final Result<BrowserDeletionOutcome> again = await harness.filing
        .deleteElement(DeleteElement(harness.operation(), ref: refOf(alpha)));

    expect(again.isErr, isTrue);
    expect(again.failureOrNull, isA<NotFoundFailure>());
  });
}
