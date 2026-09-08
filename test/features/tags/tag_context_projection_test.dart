/// Verifies tag names projected into collection browsing and study queues.
library;

import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness harness;

  setUp(() {
    harness = AppHarness(clock: FakeClock(DateTime.utc(2026, 3, 5, 10)));
  });

  tearDown(() => harness.close());

  test(
    'browser, priority, and Today rows include assigned tag names',
    () async {
      final Source source = (await harness.reader.importSource(
        ImportSource(
          harness.operation(),
          title: 'Tagged article',
          markdown: '# Context\n\nTags make the current subject visible.',
        ),
      )).unwrap();
      final tag = (await harness.tagCommands.create(
        CreateTag(harness.operation(), name: 'research'),
      )).unwrap().tag;
      final ElementRef sourceRef = ElementRef(
        id: source.id,
        type: ElementType.source,
      );
      await harness.tagCommands.save(
        SaveTagsOfElement(
          harness.operation(),
          ref: sourceRef,
          tagIds: <String>{tag.id},
        ),
      );

      expect((await harness.browserTree.load()).single.tagNames, <String>[
        'research',
      ]);
      expect(
        (await harness.priorityQuery.browse())
            .singleWhere((entry) => entry.ref == sourceRef)
            .tagNames,
        <String>['research'],
      );
      expect(
        (await harness.queueQuery.load()).entries
            .singleWhere((entry) => entry.ref == sourceRef)
            .tagNames,
        <String>['research'],
      );
    },
  );
}
