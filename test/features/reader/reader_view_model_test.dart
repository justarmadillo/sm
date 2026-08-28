import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/library/content_tree_query.dart';
import 'package:incremental_reader/features/library/import_sheet.dart';
import 'package:incremental_reader/features/library/library_providers.dart';
import 'package:incremental_reader/features/library/library_view_model.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

import '../../support/anchors.dart';

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

  group('element commands', () {
    test('an imported source enters the knowledge tree', () async {
      await importFixture();
      final List<ContentNode> tree = await container
          .read(contentTreeQueryProvider)
          .load();

      expect(tree, hasLength(1));
      expect(tree.single.title, 'A Chapter');
      expect(tree.single.ref.type, ElementType.source);
      expect(tree.single.children, isEmpty);
    });

    test('a failed import surfaces the failure and imports nothing', () async {
      final library = container.read(libraryViewModelProvider.notifier);
      await container.read(libraryViewModelProvider.future);

      final id = await library.importMarkdown(title: 'x', markdown: '   ');

      expect(id, isNull);
      final state = container.read(libraryViewModelProvider).requireValue;
      expect(state.message!.isError, isTrue);
      expect(await container.read(contentTreeQueryProvider).load(), isEmpty);
    });

    test('dismissing keeps the element in the tree', () async {
      final sourceId = await importFixture();
      final library = container.read(libraryViewModelProvider.notifier);
      await library.dismiss(ElementRef(id: sourceId, type: ElementType.source));

      // Dismissing stops scheduling; it never removes content, so the tree
      // still shows the element and says it is dismissed.
      final List<ContentNode> tree = await container
          .read(contentTreeQueryProvider)
          .load();
      expect(tree.single.ref.id, sourceId);
      expect(tree.single.status, Sm20ElementStatus.dismissed);
    });
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
        anchorIn(state.document.blocks[3], 0),
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

    test('Done, Later, and Dismiss are refused', () async {
      final sourceId = await importFixture();
      await readerFor(sourceId, ReaderMode.browse);
      final model = modelFor(sourceId, ReaderMode.browse);

      await model.done();
      await model.later();
      await model.dismiss();

      final topic = await container
          .read(learningRepositoryProvider)
          .findTopic(ElementRef(id: sourceId, type: ElementType.source));
      expect(topic!.storedInterval, 0);
      expect(topic.schedule.dueDay.toString(), '2026-03-05');
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

      expect(
        reopened.document.blockForAnchor(reopened.openedAt!)?.id,
        target.id,
      );
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

    test('Later reschedules without counting as a repetition', () async {
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
      // Section 8.1: Later is the low-level rescheduler, so it rewrites the
      // canonical due and the stored interval, and there is no second
      // "effective" date that could disagree with them.
      expect(state.topic.schedule.algorithmicDueDay.toString(), '2026-03-08');
      expect(state.effectiveDueDay.toString(), '2026-03-08');
      expect(state.topic.storedInterval, 3);
      // What it is not is a repetition: A and the counters stay put.
      expect(state.topic.repetitionCount, 1);
      expect(state.topic.aFactor, closeTo(1.2, 1e-9));
    });

    test('the reminder line appears only after enough reading', () async {
      final sourceId = await importFixture();
      final state = await readerFor(sourceId, ReaderMode.scheduled);
      final model = modelFor(sourceId, ReaderMode.scheduled);

      expect(state.showReminder, isFalse);

      await model.recordPosition(
        anchorIn(state.document.blocks.last, 0),
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
        anchorIn(state.document.blocks[3], 0),
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
      expect(
        state.document.blockForAnchor(confirmed.marker!)?.id,
        state.document.blocks[3].id,
      );
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
