/// Command tests for tag definitions, bulk links, merge, and replay safety.
library;

import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness harness;

  setUp(() => harness = AppHarness());
  tearDown(() => harness.close());

  test('creates, refuses duplicate spelling, and renames capitalization', () async {
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

  test('merge moves links and deleting a tag leaves element storage alone', () async {
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
  });
}
