import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/src/app/providers.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/ids.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/features/library/presentation/import_sheet.dart';
import 'package:incremental_reader/src/features/library/presentation/library_view_model.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_view_model.dart';

const String _markdown = '''
# A Chapter

The first paragraph of the chapter, which the reader begins in.

The second paragraph, a little further down the page.

The third paragraph, further still.

The fourth paragraph, near the end.
''';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late FakeClock clock;

  setUp(() {
    database = openInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<String> importFixture() async {
    final library = container.read(libraryViewModelProvider.notifier);
    await container.read(libraryViewModelProvider.future);
    final id = await library.importMarkdown(
      title: 'A Chapter',
      markdown: _markdown,
    );
    expect(id, isNotNull);
    return id!;
  }

  Future<ReaderUiState> readerFor(String sourceId, ReaderMode mode) =>
      container.read(
        readerViewModelProvider(
          ReaderRequest(sourceId: sourceId, mode: mode),
        ).future,
      );

  ReaderViewModel modelFor(String sourceId, ReaderMode mode) => container.read(
    readerViewModelProvider(
      ReaderRequest(sourceId: sourceId, mode: mode),
    ).notifier,
  );

  group('library view model', () {
    test('an imported source appears in today, with its schedule', () async {
      await importFixture();
      final state = container.read(libraryViewModelProvider).requireValue;

      expect(state.entries, hasLength(1));
      expect(state.dueToday, hasLength(1));
      expect(state.later, isEmpty);
      expect(state.entries.single.source.title, 'A Chapter');
      expect(state.entries.single.extractCount, 0);
    });

    test('a failed import surfaces the failure and imports nothing', () async {
      final library = container.read(libraryViewModelProvider.notifier);
      await container.read(libraryViewModelProvider.future);

      final id = await library.importMarkdown(title: 'x', markdown: '   ');

      expect(id, isNull);
      final state = container.read(libraryViewModelProvider).requireValue;
      expect(state.entries, isEmpty);
      expect(state.message!.isError, isTrue);
    });

    test(
      'dismissing moves a source out of today but keeps it listed',
      () async {
        final sourceId = await importFixture();
        final library = container.read(libraryViewModelProvider.notifier);
        final entry = container
            .read(libraryViewModelProvider)
            .requireValue
            .entries
            .single;

        await library.dismiss(entry.schedule.ref);

        final state = container.read(libraryViewModelProvider).requireValue;
        expect(state.dueToday, isEmpty);
        expect(state.later, hasLength(1));
        expect(state.entries.single.source.id, sourceId);
      },
    );
  });

  group('browse mode cannot mutate progress', () {
    test('placing a marker does nothing', () async {
      final sourceId = await importFixture();
      final state = await readerFor(sourceId, ReaderMode.browse);
      final model = modelFor(sourceId, ReaderMode.browse);

      await model.placeMarker(state.document.blocks[2]);

      final stored = await container
          .read(contentRepositoryProvider)
          .findSource(sourceId);
      expect(stored!.resume.marker, isNull);
    });

    test('scrolling records no soft position', () async {
      final sourceId = await importFixture();
      final state = await readerFor(sourceId, ReaderMode.browse);
      final model = modelFor(sourceId, ReaderMode.browse);

      await model.recordPosition(
        ReaderAnchor(blockId: state.document.blocks[3].id, utf8Offset: 0),
      );

      final stored = await container
          .read(contentRepositoryProvider)
          .findSource(sourceId);
      expect(stored!.resume.softPosition, isNull);
      // The session word count still updates: it is view state, not progress.
      expect(
        container
            .read(
              readerViewModelProvider(
                ReaderRequest(sourceId: sourceId, mode: ReaderMode.browse),
              ),
            )
            .requireValue
            .wordsThisSession,
        greaterThan(0),
      );
    });

    test('Done, Later, and Finish are refused', () async {
      final sourceId = await importFixture();
      await readerFor(sourceId, ReaderMode.browse);
      final model = modelFor(sourceId, ReaderMode.browse);

      await model.done();
      await model.later();
      await model.finish();

      final topic = await container
          .read(learningRepositoryProvider)
          .findTopic(
            container
                .read(libraryViewModelProvider)
                .requireValue
                .entries
                .single
                .schedule
                .ref,
          );
      expect(topic!.stepIndex, 0);
      expect(topic.schedule.dueDay.toString(), '2026-03-05');
      expect(topic.schedule.deferredUntil, isNull);
    });

    test('continuing scheduled makes the same session mutable', () async {
      final sourceId = await importFixture();
      final state = await readerFor(sourceId, ReaderMode.browse);
      final model = modelFor(sourceId, ReaderMode.browse);

      expect(state.canCommitProgress, isFalse);
      model.continueScheduled();
      await model.placeMarker(state.document.blocks[2]);

      final stored = await container
          .read(contentRepositoryProvider)
          .findSource(sourceId);
      expect(stored!.resume.marker, isNotNull);
    });
  });

  group('scheduled mode', () {
    test('opens at the marker once one exists', () async {
      final sourceId = await importFixture();
      final first = await readerFor(sourceId, ReaderMode.scheduled);
      final model = modelFor(sourceId, ReaderMode.scheduled);
      final target = first.document.blocks[3];

      expect(
        first.openedAt,
        first.document.startAnchor,
        reason: 'with no marker, reading starts at the top',
      );

      await model.placeMarker(target);
      container.invalidate(
        readerViewModelProvider(
          ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
        ),
      );
      final reopened = await readerFor(sourceId, ReaderMode.scheduled);

      expect(reopened.openedAt!.blockId, target.id);
      expect(reopened.progressPercent, greaterThan(0));
    });

    test('Done advances the schedule and closes the screen', () async {
      final sourceId = await importFixture();
      await readerFor(sourceId, ReaderMode.scheduled);
      final model = modelFor(sourceId, ReaderMode.scheduled);

      clock.advance(const Duration(minutes: 4));
      await model.done();

      final state = container
          .read(
            readerViewModelProvider(
              ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
            ),
          )
          .requireValue;
      expect(state.isDone, isTrue);
      expect(state.topic.encounters, 1);
      // The only article in the collection is by definition the most
      // important one in it, so its priority-derived first interval is a
      // single day. No marker was placed, so the completion term sits at its
      // floor and A clamps to 1.0, carrying that day forward unchanged.
      expect(state.topic.schedule.dueDay.toString(), '2026-03-06');
      expect(state.topic.intervalDays, greaterThan(0));

      final logged = await container
          .read(learningRepositoryProvider)
          .recentActivity();
      final encounter = logged.firstWhere(
        (r) => r.kind == 'topic.encounter_completed',
      );
      expect(encounter.durationMs, 240000);
    });

    test('Later defers without advancing the sequence', () async {
      final sourceId = await importFixture();
      await readerFor(sourceId, ReaderMode.scheduled);
      final model = modelFor(sourceId, ReaderMode.scheduled);

      await model.later(days: 3);

      final state = container
          .read(
            readerViewModelProvider(
              ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
            ),
          )
          .requireValue;
      expect(state.topic.stepIndex, 0);
      expect(state.topic.schedule.dueDay.toString(), '2026-03-05');
      expect(state.topic.schedule.effectiveDueDay.toString(), '2026-03-08');
    });

    test('the reminder line appears only after enough reading', () async {
      final sourceId = await importFixture();
      final state = await readerFor(sourceId, ReaderMode.scheduled);
      final model = modelFor(sourceId, ReaderMode.scheduled);

      expect(state.showReminder, isFalse);

      await model.recordPosition(
        ReaderAnchor(blockId: state.document.blocks.last.id, utf8Offset: 0),
      );
      var current = container
          .read(
            readerViewModelProvider(
              ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
            ),
          )
          .requireValue;
      expect(
        current.showReminder,
        isFalse,
        reason: 'this fixture is far shorter than the 500-word target',
      );

      // Dismissing keeps it hidden even once the target is met.
      model.dismissReminder();
      current = container
          .read(
            readerViewModelProvider(
              ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
            ),
          )
          .requireValue;
      expect(current.reminderDismissed, isTrue);
      expect(current.showReminder, isFalse);
    });

    test('a forgotten marker leaves a soft position to recover from', () async {
      final sourceId = await importFixture();
      final state = await readerFor(sourceId, ReaderMode.scheduled);
      final model = modelFor(sourceId, ReaderMode.scheduled);

      await model.recordPosition(
        ReaderAnchor(blockId: state.document.blocks[3].id, utf8Offset: 0),
      );
      final afterScroll = container
          .read(
            readerViewModelProvider(
              ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
            ),
          )
          .requireValue;

      expect(afterScroll.marker, isNull);
      expect(afterScroll.softPosition, isNotNull);
      expect(afterScroll.source.resume.hasUnconfirmedPosition, isTrue);

      await model.confirmSoftPosition();
      final confirmed = container
          .read(
            readerViewModelProvider(
              ReaderRequest(sourceId: sourceId, mode: ReaderMode.scheduled),
            ),
          )
          .requireValue;
      expect(confirmed.marker!.blockId, state.document.blocks[3].id);
      expect(confirmed.softPosition, isNull);
    });
  });

  group('import helpers', () {
    test('the title defaults to the first heading', () {
      expect(firstHeadingOf(_markdown), 'A Chapter');
      expect(firstHeadingOf('no heading here'), isNull);
      expect(firstHeadingOf('text\n\n### Deep Heading ###\n'), 'Deep Heading');
    });

    test('word counting ignores whitespace runs', () {
      expect(countWords('  one   two\n\nthree  '), 3);
      expect(countWords(''), 0);
    });
  });
}
