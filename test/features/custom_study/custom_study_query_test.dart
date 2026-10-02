/// Inherited-tag custom study: include, exclude, types, due only, order,
/// limit, and cram-only rows, with no admission and no shared random draws.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';
import 'package:incremental_reader/features/extract/extract_commands.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:test/test.dart';

import '../../support/anchors.dart';
import '../../support/app_harness.dart';
import '../../support/harness_fixtures.dart';

void main() {
  late AppHarness harness;
  late CustomStudyQuery query;
  late Source source;
  late Source secondSource;
  late Extract extract;
  late Card card;
  late Tag anatomy;
  late Tag biology;

  Future<Source> importSource(String title) async =>
      (await harness.reader.importSource(
        ImportSource(
          harness.operation(),
          title: title,
          markdown: '# $title\n\nA paragraph for custom study.',
        ),
      )).unwrap();

  Future<Extract> extractFrom(Source parent) async {
    final Document document = (await harness.content.findDocument(parent.id))!;
    final Block paragraph = document.blocks.firstWhere(
      (Block block) => block.type == BlockType.paragraph,
    );
    final ReaderAnchor start = anchorAtBlockStart(paragraph);
    final ReaderAnchor end = anchorIn(paragraph, paragraph.lengthUtf8);
    return (await harness.extraction.createExtract(
      CreateExtract(
        harness.operation(),
        parentId: parent.id,
        hasSourceAsParent: true,
        range: SelectionRange.of(
          startAnchor: start,
          endAnchor: end,
          markdown: document.markdownBetween(start, end),
        ),
      ),
    )).unwrap();
  }

  Future<void> setRank(ElementRef ref, PriorityRank rank) async {
    final ElementSchedule schedule = (await harness.learning.findSchedule(
      ref,
    ))!;
    await harness.learning.saveSchedule(schedule.copyWith(priority: rank));
  }

  setUp(() async {
    harness = AppHarness();
    query = CustomStudyQuery(
      tree: harness.browserTree,
      learning: harness.learning,
      cramScope: harness.cramScope,
      context: harness.context,
      clock: harness.clock,
    );
    source = await importSource('Anatomy source');
    secondSource = await importSource('Biology source');
    extract = await extractFrom(source);
    card = (await harness.formulation.formulate(
      FormulateCards(
        harness.operation(),
        parent: CardParent.extract(extract.id),
        drafts: const <CardDraft>[
          QaCardDraft(question: 'Anatomy question?', answer: 'Anatomy answer.'),
        ],
      ),
    )).unwrap().single;
    anatomy = (await harness.tagCommands.create(
      CreateTag(harness.operation(), name: 'anatomy'),
    )).unwrap().tag;
    biology = (await harness.tagCommands.create(
      CreateTag(harness.operation(), name: 'biology'),
    )).unwrap().tag;
    await harness.tagCommands.save(
      SaveTagsOfElement(
        harness.operation(),
        ref: ElementRef(id: source.id, type: ElementType.source),
        tagIds: <String>{anatomy.id},
      ),
    );
    await harness.tagCommands.save(
      SaveTagsOfElement(
        harness.operation(),
        ref: ElementRef(id: extract.id, type: ElementType.extract),
        tagIds: <String>{biology.id},
      ),
    );
    await harness.tagCommands.save(
      SaveTagsOfElement(
        harness.operation(),
        ref: ElementRef(id: secondSource.id, type: ElementType.source),
        tagIds: <String>{biology.id},
      ),
    );
    await setRank(
      ElementRef(id: source.id, type: ElementType.source),
      const PriorityRank('A'),
    );
    await setRank(
      ElementRef(id: extract.id, type: ElementType.extract),
      const PriorityRank('B'),
    );
    await setRank(
      ElementRef(id: card.id, type: ElementType.card),
      const PriorityRank('C'),
    );
    await setRank(
      ElementRef(id: secondSource.id, type: ElementType.source),
      const PriorityRank('D'),
    );
  });

  tearDown(() => harness.close());

  Future<CustomStudyMatches> load(CustomDeckFilter filter, {int seed = 1}) =>
      query.load(filter: filter, shuffleSeed: seed);

  Future<List<String>> idsOf(CustomDeckFilter filter, {int seed = 1}) async =>
      <String>[
        for (final CustomStudyEntry entry in (await load(
          filter,
          seed: seed,
        )).entries)
          entry.ref.id,
      ];

  Future<void> markCramOnly(ElementRef ref) async {
    final result = await harness.tagCommands.markCramOnly(
      MarkCramOnly(
        harness.operation(),
        refs: <ElementRef>[ref],
        isCramOnly: true,
      ),
    );
    expect(result.isOk, isTrue);
  }

  test('all and any use the selected inherited tag predicate', () async {
    final Set<String> selected = <String>{anatomy.id, biology.id};

    expect(await idsOf(CustomDeckFilter(includeTagIds: selected)), <String>[
      extract.id,
      card.id,
    ]);
    expect(
      await idsOf(
        CustomDeckFilter(
          includeTagIds: selected,
          match: CustomDeckTagMatch.any,
        ),
      ),
      <String>[source.id, extract.id, card.id, secondSource.id],
    );
  });

  test('no included tag means the whole collection', () async {
    expect(await idsOf(CustomDeckFilter()), <String>[
      source.id,
      extract.id,
      card.id,
      secondSource.id,
    ]);
  });

  test('an excluded tag removes everything that inherits it', () async {
    expect(
      await idsOf(
        CustomDeckFilter(
          includeTagIds: <String>{anatomy.id},
          excludeTagIds: <String>{biology.id},
        ),
      ),
      <String>[source.id],
    );
  });

  test('a source tag reaches its extracts and cards', () async {
    final CustomStudyMatches matches = await load(
      CustomDeckFilter(
        includeTagIds: <String>{anatomy.id},
        types: const <ElementType>{ElementType.extract, ElementType.card},
      ),
    );

    expect(
      matches.entries.map((CustomStudyEntry entry) => entry.ref.id),
      <String>[extract.id, card.id],
    );
    expect(
      matches.entries.last.tagNames,
      containsAll(<String>['anatomy', 'biology']),
    );
  });

  test('the type filter keeps only selected element types', () async {
    final CustomStudyMatches matches = await load(
      CustomDeckFilter(
        includeTagIds: <String>{anatomy.id},
        types: const <ElementType>{ElementType.card},
      ),
    );

    expect(
      matches.entries.single.ref,
      ElementRef(id: card.id, type: ElementType.card),
    );
  });

  test('a card due in the future is listed unless Due only is on', () async {
    final ElementRef cardRef = ElementRef(id: card.id, type: ElementType.card);
    final ElementSchedule schedule = (await harness.learning.findSchedule(
      cardRef,
    ))!;
    final future = (await harness.today()).addDays(90);
    await harness.learning.saveSchedule(schedule.copyWith(dueDay: future));
    final CustomDeckFilter cards = CustomDeckFilter(
      includeTagIds: <String>{anatomy.id},
      types: const <ElementType>{ElementType.card},
    );

    expect((await load(cards)).entries.single.dueDay, future);
    expect(await idsOf(cards.copyWith(isDueOnly: true)), isEmpty);
  });

  test(
    'Due only keeps due reviews and leaves out new cards and cram',
    () async {
      final CardState reviewed = await harness.memorizedCard(secondSource.id);
      await harness.learning.saveSchedule(
        reviewed.schedule.copyWith(dueDay: await harness.today()),
      );
      final CustomDeckFilter dueCards = CustomDeckFilter(
        types: const <ElementType>{ElementType.card},
        isDueOnly: true,
      );

      expect(await idsOf(dueCards), <String>[reviewed.ref.id]);

      await markCramOnly(reviewed.ref);
      expect(await idsOf(dueCards), isEmpty);
    },
  );

  test('cram-only rows are marked and still listed', () async {
    await markCramOnly(ElementRef(id: extract.id, type: ElementType.extract));

    final Map<String, bool> isCramOnlyById = <String, bool>{
      for (final CustomStudyEntry entry in (await load(
        CustomDeckFilter(includeTagIds: <String>{anatomy.id}),
      )).entries)
        entry.ref.id: entry.isCramOnly,
    };

    expect(isCramOnlyById, <String, bool>{
      source.id: false,
      extract.id: true,
      card.id: true,
    });
  });

  test('due date order puts the earliest due first', () async {
    final ElementRef secondRef = ElementRef(
      id: secondSource.id,
      type: ElementType.source,
    );
    final ElementSchedule schedule = (await harness.learning.findSchedule(
      secondRef,
    ))!;
    await harness.learning.saveSchedule(
      schedule.copyWith(dueDay: (await harness.today()).addDays(-3)),
    );

    expect(
      await idsOf(
        CustomDeckFilter(
          types: const <ElementType>{ElementType.source},
          order: CustomDeckOrder.dueDate,
        ),
      ),
      <String>[secondSource.id, source.id],
    );
  });

  test(
    'random order repeats for one seed and leaves the collection seed alone',
    () async {
      final before = (await harness.runtimeStore.load(
        zoneId: 'UTC',
      )).copyWith(randomNumberSeed: 0x12345678);
      await harness.runtimeStore.save(before);
      final CustomDeckFilter random = CustomDeckFilter(
        order: CustomDeckOrder.random,
      );

      final List<String> first = await idsOf(random, seed: 42);
      final List<String> second = await idsOf(random, seed: 42);
      final after = await harness.runtimeStore.load(zoneId: 'UTC');

      expect(second, first);
      expect(first.toSet(), <String>{
        source.id,
        extract.id,
        card.id,
        secondSource.id,
      });
      expect(after.randomNumberSeed, before.randomNumberSeed);
    },
  );

  test('the session takes the first matches up to the limit', () async {
    final CustomStudyMatches matches = await load(
      CustomDeckFilter(sessionLimit: 2),
    );

    expect(matches.entries, hasLength(4));
    expect(
      matches.sessionEntries.map((CustomStudyEntry entry) => entry.ref.id),
      <String>[source.id, extract.id],
    );
  });

  test('tag counts include inherited tags for the chosen types', () async {
    final CustomStudyMatches matches = await load(CustomDeckFilter());

    expect(matches.tagCounts[anatomy.id], 3);
    expect(matches.tagCounts[biology.id], 3);
  });
}
