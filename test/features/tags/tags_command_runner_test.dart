/// Command tests for tag definitions, bulk links, merge, and replay safety.
library;

import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness harness;

  setUp(() => harness = AppHarness());
  tearDown(() => harness.close());

  test(
    'creates, refuses duplicate spelling, and renames capitalization',
    () async {
      final created = await harness.tagCommands.create(
        CreateTag(harness.operation(), name: ' #Cardio  medicine '),
      );
      expect(created.isOk, isTrue);
      expect(created.unwrap().tag.name, 'Cardio medicine');

      final duplicate = await harness.tagCommands.create(
        CreateTag(harness.operation(), name: 'cardio medicine'),
      );
      expect(duplicate.failureOrNull, isA<ValidationFailure>());

      final renamed = await harness.tagCommands.rename(
        RenameTag(
          harness.operation(),
          tagId: created.unwrap().tag.id,
          name: 'CARDIO MEDICINE',
        ),
      );
      expect(renamed.unwrap().tag.name, 'CARDIO MEDICINE');
    },
  );

  test('renaming one tag leaves every other tag untouched', () async {
    final List<String> ids = <String>[
      for (final String name in <String>['anatomy', 'biology', 'chemistry'])
        (await harness.tagCommands.create(
          CreateTag(harness.operation(), name: name),
        )).unwrap().tag.id,
    ];

    final renamed = await harness.tagCommands.rename(
      RenameTag(harness.operation(), tagId: ids[1], name: 'botany'),
    );

    expect(renamed.isOk, isTrue);
    expect((await harness.tags.findTag(ids[0]))!.name, 'anatomy');
    expect((await harness.tags.findTag(ids[1]))!.name, 'botany');
    expect((await harness.tags.findTag(ids[2]))!.name, 'chemistry');
  });

  group('Cram only', () {
    const ElementRef source = ElementRef(
      id: 'source-a',
      type: ElementType.source,
    );
    const ElementRef card = ElementRef(id: 'card-a', type: ElementType.card);

    Future<CramOutcome> mark(
      List<ElementRef> refs, {
      required bool isCramOnly,
    }) async => (await harness.tagCommands.markCramOnly(
      MarkCramOnly(harness.operation(), refs: refs, isCramOnly: isCramOnly),
    )).unwrap();

    test('the first tick creates #cram and later ticks reuse it', () async {
      final CramOutcome first = await mark(<ElementRef>[
        source,
      ], isCramOnly: true);
      final CramOutcome second = await mark(<ElementRef>[
        card,
      ], isCramOnly: true);

      expect(first.tag!.name, 'cram');
      expect(second.tag!.id, first.tag!.id);
      expect((await harness.tags.listTags()).length, 1);
      expect(
        await harness.tags.listElementsWithTag(first.tag!.id),
        <ElementRef>{source, card},
      );
    });

    test('an existing tag spelled "Cram" is the flag', () async {
      final created = (await harness.tagCommands.create(
        CreateTag(harness.operation(), name: 'Cram'),
      )).unwrap().tag;

      final CramOutcome outcome = await mark(<ElementRef>[
        source,
      ], isCramOnly: true);

      expect(outcome.tag!.id, created.id);
    });

    test(
      'unticking with no #cram tag changes nothing and creates nothing',
      () async {
        final CramOutcome outcome = await mark(<ElementRef>[
          source,
        ], isCramOnly: false);

        expect(outcome.tag, isNull);
        expect(outcome.changedRefCount, 0);
        expect(await harness.tags.listTags(), isEmpty);
      },
    );

    test('only elements whose direct link changes are counted', () async {
      await mark(<ElementRef>[source], isCramOnly: true);

      expect(
        (await mark(<ElementRef>[
          source,
          card,
        ], isCramOnly: true)).changedRefCount,
        1,
      );
      expect(
        (await mark(<ElementRef>[source], isCramOnly: false)).changedRefCount,
        1,
      );
    });

    test('a replayed tick applies once', () async {
      final command = MarkCramOnly(
        harness.operation(),
        refs: const <ElementRef>[source],
        isCramOnly: true,
      );
      expect((await harness.tagCommands.markCramOnly(command)).isOk, isTrue);
      expect((await harness.tagCommands.markCramOnly(command)).isErr, isTrue);
      expect((await harness.tags.listTags()).length, 1);
    });

    test('#cram cannot be renamed away, only re-capitalized', () async {
      final Tag cram = (await mark(<ElementRef>[
        source,
      ], isCramOnly: true)).tag!;

      final refused = await harness.tagCommands.rename(
        RenameTag(harness.operation(), tagId: cram.id, name: 'revision'),
      );
      final recapitalized = await harness.tagCommands.rename(
        RenameTag(harness.operation(), tagId: cram.id, name: 'CRAM'),
      );

      expect(refused.failureOrNull, isA<ValidationFailure>());
      expect(recapitalized.unwrap().tag.name, 'CRAM');
    });
  });

  test('bulk inserts, removes, and replays one operation only once', () async {
    final tag = (await harness.tagCommands.create(
      CreateTag(harness.operation(), name: 'biology'),
    )).unwrap().tag;
    const refs = <ElementRef>[
      ElementRef(id: 'source-a', type: ElementType.source),
      ElementRef(id: 'card-a', type: ElementType.card),
    ];
    final operation = harness.operation();
    final command = InsertTagsOnElements(
      operation,
      refs: refs,
      tagIds: <String>{tag.id},
    );
    expect((await harness.tagCommands.insert(command)).isOk, isTrue);
    expect((await harness.tagCommands.insert(command)).isErr, isTrue);
    expect(await harness.tags.countElementsByTag(), <String, int>{tag.id: 2});

    await harness.tagCommands.deleteFromElements(
      DeleteTagsFromElements(
        harness.operation(),
        refs: <ElementRef>[refs.first],
        tagIds: <String>{tag.id},
      ),
    );
    expect(await harness.tags.countElementsByTag(), <String, int>{tag.id: 1});
  });

  test(
    'merge moves links and deleting a tag leaves element storage alone',
    () async {
      final source = (await harness.tagCommands.create(
        CreateTag(harness.operation(), name: 'heart'),
      )).unwrap().tag;
      final target = (await harness.tagCommands.create(
        CreateTag(harness.operation(), name: 'cardiology'),
      )).unwrap().tag;
      const ref = ElementRef(id: 'element', type: ElementType.extract);
      await harness.tags.insertElementTags(
        <ElementRef>[ref],
        <String>{source.id},
        harness.clock.nowUtc(),
      );

      final merged = await harness.tagCommands.merge(
        MergeTags(
          harness.operation(),
          sourceTagIds: <String>{source.id},
          intoTagId: target.id,
        ),
      );
      expect(merged.isOk, isTrue);
      expect(await harness.tags.findTag(source.id), isNull);
      expect(await harness.tags.listTagIdsOfElement(ref), <String>[target.id]);

      await harness.tagCommands.delete(
        DeleteTag(harness.operation(), tagId: target.id),
      );
      expect(await harness.tags.listTagIdsOfElement(ref), isEmpty);
    },
  );
}
