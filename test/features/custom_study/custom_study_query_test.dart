/// Verifies inherited-tag custom study without admission or random draws.
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
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:test/test.dart';

import '../../support/anchors.dart';
import '../../support/app_harness.dart';

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

  test('all and any use the selected inherited tag predicate', () async {
    final Set<String> selected = <String>{anatomy.id, biology.id};
    final List<CustomStudyEntry> all = await query.load(
      tagIds: selected,
      match: CustomStudyTagMatch.all,
      types: ElementType.values.toSet(),
    );
    final List<CustomStudyEntry> any = await query.load(
      tagIds: selected,
      match: CustomStudyTagMatch.any,
      types: ElementType.values.toSet(),
    );

    expect(all.map((CustomStudyEntry entry) => entry.ref.id), <String>[
      extract.id,
      card.id,
    ]);
    expect(any.map((CustomStudyEntry entry) => entry.ref.id), <String>[
      source.id,
      extract.id,
      card.id,
      secondSource.id,
    ]);
  });

  test('a source tag reaches its extracts and cards', () async {
    final List<CustomStudyEntry> matches = await query.load(
      tagIds: <String>{anatomy.id},
      match: CustomStudyTagMatch.all,
      types: const <ElementType>{ElementType.extract, ElementType.card},
    );

    expect(matches.map((CustomStudyEntry entry) => entry.ref.id), <String>[
      extract.id,
      card.id,
    ]);
    expect(matches.last.tagNames, containsAll(<String>['anatomy', 'biology']));
  });

  test('the type filter keeps only selected element types', () async {
    final List<CustomStudyEntry> matches = await query.load(
      tagIds: <String>{anatomy.id},
      match: CustomStudyTagMatch.all,
      types: const <ElementType>{ElementType.card},
    );

    expect(matches.single.ref, ElementRef(id: card.id, type: ElementType.card));
  });

  test('a card due in the future is still included', () async {
    final ElementRef cardRef = ElementRef(id: card.id, type: ElementType.card);
    final ElementSchedule schedule = (await harness.learning.findSchedule(
      cardRef,
    ))!;
    final future = (await harness.today()).addDays(90);
    await harness.learning.saveSchedule(schedule.copyWith(dueDay: future));

    final List<CustomStudyEntry> matches = await query.load(
      tagIds: <String>{anatomy.id},
      match: CustomStudyTagMatch.all,
      types: const <ElementType>{ElementType.card},
    );

    expect(matches.single.dueDay, future);
  });

  test(
    'ordering is deterministic and leaves the random seed unchanged',
    () async {
      final before = (await harness.runtimeStore.load(
        zoneId: 'UTC',
      )).copyWith(randomNumberSeed: 0x12345678);
      await harness.runtimeStore.save(before);

      final List<CustomStudyEntry> first = await query.load(
        tagIds: <String>{anatomy.id},
        match: CustomStudyTagMatch.all,
        types: ElementType.values.toSet(),
      );
      final List<CustomStudyEntry> second = await query.load(
        tagIds: <String>{anatomy.id},
        match: CustomStudyTagMatch.all,
        types: ElementType.values.toSet(),
      );
      final after = await harness.runtimeStore.load(zoneId: 'UTC');

      expect(
        first.map((CustomStudyEntry entry) => entry.ref),
        second.map((CustomStudyEntry entry) => entry.ref),
      );
      expect(first.map((CustomStudyEntry entry) => entry.ref.id), <String>[
        source.id,
        extract.id,
        card.id,
      ]);
      expect(after.randomNumberSeed, before.randomNumberSeed);
    },
  );
}
