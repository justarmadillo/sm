import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

import '../../support/anchors.dart';

const String _markdown = '''
# Encoding

The **first** paragraph, which carries the idea worth keeping.

The second paragraph, which carries another one.

The third paragraph, which carries a third.
''';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late String sourceId;

  setUp(() async {
    database = openInMemoryDatabase();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 3, 5, 10)),
        ),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );
    await container.read(browserViewModelProvider.future);
    sourceId = (await container
        .read(browserViewModelProvider.notifier)
        .importMarkdown(title: 'Encoding', markdown: _markdown))!;
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  ReaderRequest requestFor(ReaderMode mode) =>
      ReaderRequest(sourceId: sourceId, mode: mode);

  Future<ReaderUiState> openReader(ReaderMode mode) =>
      container.read(readerViewModelProvider(requestFor(mode)).future);

  ReaderViewModel modelFor(ReaderMode mode) =>
      container.read(readerViewModelProvider(requestFor(mode)).notifier);

  ReaderUiState stateOf(ReaderMode mode) =>
      container.read(readerViewModelProvider(requestFor(mode))).requireValue;

  /// A verified selection over rendered text in [block].
  SelectionRange select(ReaderUiState state, Block block, String needle) {
    final start = block.renderedText.indexOf(needle);
    expect(start, isNonNegative, reason: '"$needle" is not in ${block.id}');
    final (int startUtf8, int endUtf8) = block.sourceRangeForRendered(
      start,
      start + needle.length,
    );
    final startAnchor = anchorIn(block, startUtf8);
    final endAnchor = anchorIn(block, endUtf8);
    return SelectionRange.of(
      startAnchor: startAnchor,
      endAnchor: endAnchor,
      markdown: state.document.markdownBetween(startAnchor, endAnchor),
    );
  }

  group('extracting from the Reader', () {
    test('creates an extract and offers Undo', () async {
      final state = await openReader(ReaderMode.scheduled);
      final model = modelFor(ReaderMode.scheduled);

      final created = await model.extractSelection(
        select(state, state.document.blocks[1], 'the idea worth keeping'),
      );

      expect(created, isNotNull);
      expect(created!.markdown, 'the idea worth keeping');

      final after = stateOf(ReaderMode.scheduled);
      expect(after.extracts, hasLength(1));
      expect(after.lastExtractId, created.id);
      expect(after.message!.text, 'Extracted');
      expect(after.message!.isError, isFalse);
    });

    test('leaves the marker, the position, and the schedule alone', () async {
      final state = await openReader(ReaderMode.scheduled);
      final model = modelFor(ReaderMode.scheduled);

      await model.placeMarker(state.document.blocks[1]);
      final beforeMarker = stateOf(ReaderMode.scheduled).marker;
      final beforeTopic = stateOf(ReaderMode.scheduled).topic;

      await model.extractSelection(
        select(state, state.document.blocks[1], 'the idea worth keeping'),
      );

      final after = stateOf(ReaderMode.scheduled);
      expect(after.marker, beforeMarker);
      expect(after.topic.storedInterval, beforeTopic.storedInterval);
      expect(after.topic.repetitionCount, beforeTopic.repetitionCount);
      expect(after.topic.schedule.dueDay, beforeTopic.schedule.dueDay);
      expect(after.source.markdown, state.source.markdown);
    });

    test(
      'is disabled while browsing because it would create a schedule',
      () async {
        final state = await openReader(ReaderMode.browse);
        final model = modelFor(ReaderMode.browse);

        final created = await model.extractSelection(
          select(state, state.document.blocks[2], 'carries another one'),
        );

        expect(created, isNull);
        expect(stateOf(ReaderMode.browse).extracts, isEmpty);
        final stored = await container
            .read(contentRepositoryProvider)
            .findSource(sourceId);
        expect(stored!.resume.marker, isNull);
        expect(stored.resume.softPosition, isNull);
      },
    );

    test(
      'a rejected selection reports the failure and creates nothing',
      () async {
        final state = await openReader(ReaderMode.scheduled);
        final model = modelFor(ReaderMode.scheduled);
        final honest = select(
          state,
          state.document.blocks[1],
          'the idea worth keeping',
        );

        final created = await model.extractSelection(
          SelectionRange(
            startAnchor: honest.startAnchor,
            endAnchor: honest.endAnchor,
            selectedTextHash: hashSelection('not what was selected'),
          ),
        );

        expect(created, isNull);
        final after = stateOf(ReaderMode.scheduled);
        expect(after.message!.isError, isTrue);
        expect(after.extracts, isEmpty);
      },
    );
  });

  group('gutter marks', () {
    test('count the extracts that begin in each block', () async {
      final state = await openReader(ReaderMode.scheduled);
      final model = modelFor(ReaderMode.scheduled);
      final first = state.document.blocks[1];
      final second = state.document.blocks[2];

      await model.extractSelection(select(state, first, 'first'));
      await model.extractSelection(select(state, first, 'idea worth keeping'));
      await model.extractSelection(select(state, second, 'another one'));

      final marks = stateOf(ReaderMode.scheduled).extractMarksByBlock;
      expect(marks[first.id], 2);
      expect(marks[second.id], 1);
      expect(marks[state.document.blocks[3].id], isNull);
    });

    test('list the extracts of one block for the context overlay', () async {
      final state = await openReader(ReaderMode.scheduled);
      final model = modelFor(ReaderMode.scheduled);
      final block = state.document.blocks[1];

      await model.extractSelection(select(state, block, 'first'));
      await model.extractSelection(select(state, block, 'idea worth keeping'));

      final here = stateOf(ReaderMode.scheduled).extractsStartingIn(block.id);
      expect(here, hasLength(2));
      expect(here.map((e) => e.markdown).toSet(), <String>{
        '**first**',
        'idea worth keeping',
      });
      expect(
        stateOf(
          ReaderMode.scheduled,
        ).extractsStartingIn(state.document.blocks[3].id),
        isEmpty,
      );
    });

    test('survive reopening the Reader', () async {
      final state = await openReader(ReaderMode.scheduled);
      await modelFor(ReaderMode.scheduled).extractSelection(
        select(state, state.document.blocks[1], 'idea worth keeping'),
      );

      container.invalidate(
        readerViewModelProvider(requestFor(ReaderMode.scheduled)),
      );
      final reopened = await openReader(ReaderMode.scheduled);

      expect(reopened.extracts, hasLength(1));
      expect(reopened.extractMarksByBlock, hasLength(1));
    });
  });

  group('undo', () {
    test('removes the extract and its gutter mark', () async {
      final state = await openReader(ReaderMode.scheduled);
      final model = modelFor(ReaderMode.scheduled);
      final created = await model.extractSelection(
        select(state, state.document.blocks[1], 'idea worth keeping'),
      );

      await model.undoExtract(created!.id);

      final after = stateOf(ReaderMode.scheduled);
      expect(after.extracts, isEmpty);
      expect(after.extractMarksByBlock, isEmpty);
      expect(after.lastExtractId, isNull);
      expect(after.message!.text, 'Extract removed');
      expect(
        await container
            .read(learningRepositoryProvider)
            .findSchedule(
              ElementRef(id: created.id, type: ElementType.extract),
            ),
        isNull,
      );
    });

    test('leaves the other extracts and the source untouched', () async {
      final state = await openReader(ReaderMode.scheduled);
      final model = modelFor(ReaderMode.scheduled);
      final block = state.document.blocks[1];

      final keep = await model.extractSelection(select(state, block, 'first'));
      final drop = await model.extractSelection(
        select(state, block, 'idea worth keeping'),
      );
      await model.undoExtract(drop!.id);

      final after = stateOf(ReaderMode.scheduled);
      expect(after.extracts.map((e) => e.id), <String>[keep!.id]);
      expect(after.source.markdown, state.source.markdown);
      // Removing an extract leaves the parent's own repetition state alone.
      expect(after.topic.storedInterval, 0);
    });
  });
}
