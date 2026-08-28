/// The Browser's moves: what they rearrange, and what they must leave alone.
///
/// The promise being pinned here is the one the whole design rests on. Filing
/// says where an element is kept; provenance says where it came from. A move
/// rewrites the first and never the second, so an extract dragged under a
/// different article still points at the passage it was cut from and still
/// opens in context.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/browser/browser_commands.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/extract/extract_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
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

  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);

  Future<Source> importSource(String title, String markdown) async =>
      (await harness.reader.importSource(
        ImportSource(harness.operation(), title: title, markdown: markdown),
      )).unwrap();

  /// Cuts the first sentence of [source]'s first paragraph out as an extract.
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

  /// The titles at the top of the tree, in the order the Browser draws them.
  Future<List<String>> rootTitles() async => <String>[
    for (final BrowserTreeNode node in await harness.browserTree.load())
      node.title,
  ];

  Future<BrowserTreeNode> nodeFor(ElementRef ref) async {
    BrowserTreeNode? found;
    void walk(List<BrowserTreeNode> nodes) {
      for (final BrowserTreeNode node in nodes) {
        if (node.ref == ref) found = node;
        walk(node.children);
      }
    }

    walk(await harness.browserTree.load());
    return found!;
  }

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(database: openInMemoryDatabase(), clock: clock);
    alpha = await importSource('Alpha', _alphaMarkdown);
    // A minute apart, because the tree falls back to import order and two
    // articles imported on the same instant have no order to fall back to.
    clock.advance(const Duration(minutes: 1));
    beta = await importSource('Beta', _betaMarkdown);
    alphaExtract = await extractFrom(alpha);
  });

  tearDown(() => harness.database.close());

  group('order within a level', () {
    test('the tree starts in import order, newest first', () async {
      expect(await rootTitles(), <String>['Beta', 'Alpha']);
    });

    test('moving down swaps a row with the one below it', () async {
      final Result<BrowserFilingOutcome> result = await harness.filing.moveDown(
        MoveElementDown(harness.operation(), ref: refOf(beta)),
      );

      expect(result.isOk, isTrue);
      expect(await rootTitles(), <String>['Alpha', 'Beta']);
    });

    test('moving up puts it back', () async {
      await harness.filing.moveDown(
        MoveElementDown(harness.operation(), ref: refOf(beta)),
      );
      await harness.filing.moveUp(
        MoveElementUp(harness.operation(), ref: refOf(beta)),
      );

      expect(await rootTitles(), <String>['Beta', 'Alpha']);
    });

    test('the first row refuses to move up', () async {
      final Result<BrowserFilingOutcome> result = await harness.filing.moveUp(
        MoveElementUp(harness.operation(), ref: refOf(beta)),
      );

      expect(result.isErr, isTrue);
      expect(await rootTitles(), <String>['Beta', 'Alpha']);
    });
  });

  group('nesting', () {
    test('a row nests under the row above it, and lifts back out', () async {
      await harness.filing.nestUnderPreviousSibling(
        NestElementUnderPreviousSibling(harness.operation(), ref: refOf(alpha)),
      );

      expect(await rootTitles(), <String>['Beta']);
      expect(
        (await nodeFor(refOf(alpha))).parentRef,
        refOf(beta),
        reason: 'Alpha is now filed under Beta',
      );

      await harness.filing.liftOutOfParent(
        LiftElementOutOfParent(harness.operation(), ref: refOf(alpha)),
      );

      expect(await rootTitles(), <String>['Beta', 'Alpha']);
      expect((await nodeFor(refOf(alpha))).parentRef, isNull);
    });

    test('an element cannot be filed under its own child', () async {
      final ElementRef extractRef = ElementRef(
        id: alphaExtract.id,
        type: ElementType.extract,
      );

      final Result<BrowserFilingOutcome> result = await harness.filing
          .fileUnder(
            FileElementUnder(
              harness.operation(),
              ref: refOf(alpha),
              parentRef: extractRef,
            ),
          );

      expect(result.isErr, isTrue);
      expect((await nodeFor(extractRef)).parentRef, refOf(alpha));
    });
  });

  group('what a move must not disturb', () {
    test('an extract filed elsewhere keeps the passage it came from', () async {
      final ElementRef extractRef = ElementRef(
        id: alphaExtract.id,
        type: ElementType.extract,
      );

      await harness.filing.fileUnder(
        FileElementUnder(
          harness.operation(),
          ref: extractRef,
          parentRef: refOf(beta),
        ),
      );

      expect(
        (await nodeFor(extractRef)).parentRef,
        refOf(beta),
        reason: 'the Browser shows it where the user put it',
      );

      final Extract stored = (await harness.content.findExtract(
        alphaExtract.id,
      ))!;
      expect(stored.provenance.parentId, alpha.id);
      expect(stored.provenance.sourceId, alpha.id);
      expect(
        stored.provenance.startAnchor,
        alphaExtract.provenance.startAnchor,
      );
      expect(stored.provenance.endAnchor, alphaExtract.provenance.endAnchor);
      expect(stored.provenance.state, alphaExtract.provenance.state);
    });

    test('a move changes no due day, priority, or lifecycle', () async {
      final ElementRef ref = refOf(beta);
      final ElementSchedule before = (await harness.learning.findSchedule(
        ref,
      ))!;

      await harness.filing.moveDown(
        MoveElementDown(harness.operation(), ref: ref),
      );

      final ElementSchedule after = (await harness.learning.findSchedule(ref))!;
      expect(after.dueDay, before.dueDay);
      expect(after.originalDueDay, before.originalDueDay);
      expect(after.priority, before.priority);
      expect(after.lifecycle, before.lifecycle);
      expect(after.rootId, before.rootId);
      expect(
        after.ordinal,
        isNot(before.ordinal),
        reason: 'the filing itself did change',
      );
    });

    test('replaying one move is not two moves', () async {
      final MoveElementDown command = MoveElementDown(
        harness.operation(),
        ref: refOf(beta),
      );

      await harness.filing.moveDown(command);
      await harness.filing.moveDown(command);

      expect(await rootTitles(), <String>['Alpha', 'Beta']);
    });
  });
}
