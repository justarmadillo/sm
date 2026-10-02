/// Which elements the `#cram` tag reaches, and that the answer matches the
/// tags the Browser shows on every row.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';
import '../support/harness_fixtures.dart';

void main() {
  late AppHarness harness;
  late List<Source> sources;
  late Card card;

  ElementRef cardRef() => ElementRef(id: card.id, type: ElementType.card);

  Future<void> markCramOnly(List<ElementRef> refs, {bool isCramOnly = true}) =>
      harness.tagCommands
          .markCramOnly(
            MarkCramOnly(
              harness.operation(),
              refs: refs,
              isCramOnly: isCramOnly,
            ),
          )
          .then((result) => expect(result.isOk, isTrue));

  setUp(() async {
    harness = AppHarness();
    sources = await harness.importSources(2);
    card = (await harness.formulation.formulate(
      FormulateCards(
        harness.operation(),
        parent: CardParent.source(sources.first.id),
        drafts: const <CardDraft>[
          QaCardDraft(question: 'Question?', answer: 'Answer.'),
        ],
      ),
    )).unwrap().single;
  });
  tearDown(() => harness.close());

  test('a collection with no #cram tag has nothing cram-only', () async {
    expect(await harness.cramScope.listCramOnlyRefs(), isEmpty);
  });

  test('a tagged source makes the card written from it cram-only', () async {
    await markCramOnly(<ElementRef>[harness.refOf(sources.first)]);

    expect(await harness.cramScope.listCramOnlyRefs(), <ElementRef>{
      harness.refOf(sources.first),
      cardRef(),
    });
    expect(
      await harness.cramScope.isCramOnly(harness.refOf(sources.last)),
      isFalse,
    );
  });

  test('re-filing a card out of a cram branch frees it', () async {
    await markCramOnly(<ElementRef>[harness.refOf(sources.first)]);
    final ElementSchedule schedule = (await harness.learning.findSchedule(
      cardRef(),
    ))!;
    await harness.learning.saveSchedule(
      schedule.copyWith(parentElementId: sources.last.id),
    );

    expect(await harness.cramScope.isCramOnly(cardRef()), isFalse);
  });

  test('the queue and the Browser agree on every cram-only row', () async {
    await markCramOnly(<ElementRef>[harness.refOf(sources.first)]);
    final Tag cram = (await harness.tags.findTagByLowercaseName(
      Tag.cramLowercaseName,
    ))!;

    final Set<ElementRef> shownAsCram = <ElementRef>{
      for (final BrowserTreeNode node in _flatten(
        await harness.browserTree.load(),
      ))
        if (node.effectiveTagIds.contains(cram.id)) node.ref,
    };

    expect(await harness.cramScope.listCramOnlyRefs(), shownAsCram);
  });
}

Iterable<BrowserTreeNode> _flatten(List<BrowserTreeNode> nodes) sync* {
  for (final BrowserTreeNode node in nodes) {
    yield node;
    yield* _flatten(node.children);
  }
}
