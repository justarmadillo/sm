/// Relative priority end to end: the slider, the browser's drag, Spread, and
/// what survives a restart.
///
/// The gate items covered here are that a priority change is ordering-only —
/// it never moves a due date or an interval — and that the browser's order
/// survives closing the collection.
library;

import 'dart:io';

import 'package:incremental_reader/src/application/priority/priority_commands.dart';
import 'package:incremental_reader/src/application/priority/priority_query.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/revlog.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph long enough to parse into one readable block.
''';

extension _Fixtures on AppHarness {
  Future<List<Source>> importSources(int count) async {
    final List<Source> sources = <Source>[];
    for (var i = 0; i < count; i++) {
      final Result<Source> result = await reader.importSource(
        ImportSource(
          operation(),
          title: 'Article ${i.toString().padLeft(2, '0')}',
          markdown: _markdown,
          priorityPercent: 100,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      sources.add(result.unwrap());
    }
    return sources;
  }

  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);
}

void main() {
  late Directory workspace;
  late File databaseFile;
  late AppDatabase database;
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ir_m4_priority_');
    databaseFile = File('${workspace.path}/db/$kDatabaseFileName');
    database = openDatabaseAt(databaseFile);
    await database.customSelect('SELECT 1').getSingle();
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(database: database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  group('setting a percent', () {
    test('moves the element and nothing about its schedule', () async {
      final List<Source> sources = await harness.importSources(5);
      final ElementRef ref = harness.refOf(sources.last);
      final TopicState before = (await harness.learning.findTopic(ref))!;

      final Result<ElementSchedule> result = await harness.priority.setPercent(
        SetPriorityPercent(
          harness.operation(),
          ref: ref,
          percent: 0,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

      final TopicState after = (await harness.learning.findTopic(ref))!;
      expect(after.schedule.dueDay, before.schedule.dueDay);
      expect(after.schedule.originalDueDay, before.schedule.originalDueDay);
      expect(after.intervalDays, before.intervalDays);
      expect(after.encounters, before.encounters);
      expect(
        after.schedule.priority,
        lessThan(before.schedule.priority),
        reason: 'ordering changed, and only ordering',
      );

      final PriorityContext context = (await harness.priorityQuery.contextFor(
        ref,
      ))!;
      expect(context.percent, 0);
    });

    test('promoting one element demotes the others, because there is only '
        'one 0%', () async {
      final List<Source> sources = await harness.importSources(4);
      final ElementRef promoted = harness.refOf(sources.last);
      final ElementRef wasFirst = harness.refOf(sources.first);

      expect((await harness.priorityQuery.contextFor(wasFirst))!.percent, 0);
      await harness.priority.setPercent(
        SetPriorityPercent(
          harness.operation(),
          ref: promoted,
          percent: 0,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(
        (await harness.priorityQuery.contextFor(wasFirst))!.percent,
        greaterThan(0),
      );
    });

    test('rejects a percent outside the scale', () async {
      final List<Source> sources = await harness.importSources(2);
      final Result<ElementSchedule> result = await harness.priority.setPercent(
        SetPriorityPercent(
          harness.operation(),
          ref: harness.refOf(sources.first),
          percent: 140,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('logs the change with the percentile it landed on', () async {
      final List<Source> sources = await harness.importSources(4);
      final ElementRef ref = harness.refOf(sources.last);
      await harness.priority.setPercent(
        SetPriorityPercent(
          harness.operation(),
          ref: ref,
          percent: 25,
          timestampUtc: clock.nowUtc(),
        ),
      );

      final RevlogEntry entry = (await harness.learning.listRevlogFor(ref))
          .firstWhere(
            (RevlogEntry e) => e.eventType == RevlogEventType.priorityChange,
          );
      expect(entry.before.priorityKey, isNotNull);
      expect(entry.after.priorityKey, isNotNull);
      expect(entry.before.priorityKey, isNot(entry.after.priorityKey));
      expect(entry.grade, isNull);
    });
  });

  group('stepping and dragging', () {
    test('a step of 0.1 only moves when it crosses a rank', () async {
      // Section 7: the current-element shortcut sets a numerical target of
      // -0.1 or +0.1 and is then subject to the same nearest-even conversion
      // as any other Set Priority. Unlike review-time drift it has no forced
      // one-rank movement, so in a small collection 0.1 percent quantizes
      // straight back to the rank it started on.
      final List<Source> sources = await harness.importSources(5);
      final ElementRef ref = harness.refOf(sources[3]);
      final double before = (await harness.priorityQuery.contextFor(
        ref,
      ))!.percent;

      final Result<ElementSchedule> stepped = await harness.priority.step(
        StepPriority(
          harness.operation(),
          ref: ref,
          increase: true,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(stepped.isOk, isTrue, reason: '${stepped.failureOrNull}');

      expect(
        (await harness.priorityQuery.contextFor(ref))!.percent,
        before,
        reason: 'five elements quantize a 0.1 percent target back to itself',
      );
    });

    test(
      'a drag places the element between the two it was dropped on',
      () async {
        final List<Source> sources = await harness.importSources(5);
        final List<PriorityEntry> rows = await harness.priorityQuery.browse();
        final ElementRef dragged = rows.last.ref;

        final Result<ElementSchedule> result = await harness.priority.reorder(
          ReorderPriority(
            harness.operation(),
            ref: dragged,
            after: rows[0].schedule.priority,
            before: rows[1].schedule.priority,
            timestampUtc: clock.nowUtc(),
          ),
        );
        expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

        final List<PriorityEntry> reordered = await harness.priorityQuery
            .browse();
        expect(reordered[1].ref, dragged);
        expect(reordered, hasLength(sources.length));
      },
    );

    test('refuses neighbours that are not in order', () async {
      final List<Source> sources = await harness.importSources(3);
      final List<PriorityEntry> rows = await harness.priorityQuery.browse();
      final Result<ElementSchedule> result = await harness.priority.reorder(
        ReorderPriority(
          harness.operation(),
          ref: harness.refOf(sources.last),
          after: rows[2].schedule.priority,
          before: rows[0].schedule.priority,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('Spread', () {
    test('lays a range across a branch in its existing order', () async {
      // Section 7.1 rejects a range with fewer slots than selected elements,
      // so the collection has to be wide enough for the requested band.
      final List<Source> sources = await harness.importSources(20);
      final List<PriorityEntry> before = await harness.priorityQuery.browse();

      final Result<int> spread = await harness.priority.batch(
        BatchPriority(
          harness.operation(),
          refs: <ElementRef>[
            for (final PriorityEntry entry in before.take(4)) entry.ref,
          ],
          mode: Sm20BatchPriorityMode.spread,
          lowPercent: 60,
          highPercent: 95,
          changePercent: 0,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(spread.unwrap(), 4);

      final List<PriorityEntry> after = await harness.priorityQuery.browse();
      final List<ElementRef> movedOrder = <ElementRef>[
        for (final PriorityEntry entry in after)
          if (before.take(4).any((PriorityEntry b) => b.ref == entry.ref))
            entry.ref,
      ];
      expect(
        movedOrder,
        before.take(4).map((PriorityEntry e) => e.ref),
        reason: 'Spread reorders the range, not the elements within it',
      );

      double meanPercent(List<PriorityEntry> rows, Iterable<ElementRef> refs) {
        final Iterable<double> percents = rows
            .where((PriorityEntry e) => refs.contains(e.ref))
            .map((PriorityEntry e) => e.percent);
        return percents.reduce((double a, double b) => a + b) / percents.length;
      }

      final List<ElementRef> moved = <ElementRef>[
        for (final PriorityEntry entry in before.take(4)) entry.ref,
      ];
      expect(
        meanPercent(after, moved),
        greaterThan(meanPercent(before, moved)),
        reason: 'the branch was demoted into the range it was spread across',
      );
      expect(sources, hasLength(20));
    });

    test('rejects an empty selection but swaps an inverted range', () async {
      expect(
        (await harness.priority.batch(
          BatchPriority(
            harness.operation(),
            refs: const <ElementRef>[],
            mode: Sm20BatchPriorityMode.spread,
            lowPercent: 10,
            highPercent: 20,
            changePercent: 0,
            timestampUtc: clock.nowUtc(),
          ),
        )).failureOrNull,
        isA<ValidationFailure>(),
      );

      // SM20 orders the two endpoints itself rather than refusing the run,
      // so an inverted range is accepted and behaves as its sorted form.
      final List<Source> sources = await harness.importSources(2);
      final Result<int> inverted = await harness.priority.batch(
        BatchPriority(
          harness.operation(),
          refs: <ElementRef>[harness.refOf(sources.first)],
          mode: Sm20BatchPriorityMode.spread,
          lowPercent: 90,
          highPercent: 10,
          changePercent: 0,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(inverted.unwrap(), 1);
    });

    test('logs one entry per element with its place in the range', () async {
      final List<Source> sources = await harness.importSources(12);
      final List<Source> selected = sources.take(3).toList();
      await harness.priority.batch(
        BatchPriority(
          harness.operation(),
          refs: <ElementRef>[for (final Source s in selected) harness.refOf(s)],
          mode: Sm20BatchPriorityMode.spread,
          lowPercent: 30,
          highPercent: 70,
          changePercent: 0,
          timestampUtc: clock.nowUtc(),
        ),
      );

      for (final Source source in selected) {
        final RevlogEntry entry =
            (await harness.learning.listRevlogFor(
              harness.refOf(source),
            )).firstWhere(
              (RevlogEntry e) => e.eventType == RevlogEventType.priorityChange,
            );
        expect(entry.metadata!['mode'], 'spread');
        expect(entry.metadata!['of'], 3);
        expect(entry.metadata!['low'], 30);
        expect(entry.metadata!['high'], 70);
        // Spread reads the live position as it reinserts, so this is the
        // sequential source position and not a frozen index.
        expect(entry.metadata!['source_position'], isA<int>());
      }
    });
  });

  group('durability', () {
    test('the browser’s order survives closing the collection', () async {
      final List<Source> sources = await harness.importSources(6);
      await harness.priority.setPercent(
        SetPriorityPercent(
          harness.operation(),
          ref: harness.refOf(sources.last),
          percent: 0,
          timestampUtc: clock.nowUtc(),
        ),
      );
      await harness.priority.setPercent(
        SetPriorityPercent(
          harness.operation(),
          ref: harness.refOf(sources.first),
          percent: 100,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final List<ElementRef> before = <ElementRef>[
        for (final PriorityEntry entry in await harness.priorityQuery.browse())
          entry.ref,
      ];
      expect(before.first, harness.refOf(sources.last));
      expect(before.last, harness.refOf(sources.first));

      await database.close();
      database = openDatabaseAt(databaseFile);
      await database.customSelect('SELECT 1').getSingle();
      final AppHarness reopened = AppHarness(
        database: database,
        clock: clock,
        operationPrefix: 'after-restart',
      );

      final List<ElementRef> after = <ElementRef>[
        for (final PriorityEntry entry in await reopened.priorityQuery.browse())
          entry.ref,
      ];
      expect(after, before);
    });
  });

  group('inheritance', () {
    test(
      'a new article starts in the middle when nothing is claimed about it',
      () async {
        final Result<Source> result = await harness.reader.importSource(
          ImportSource(
            harness.operation(),
            title: 'Unranked',
            markdown: _markdown,
            timestampUtc: clock.nowUtc(),
          ),
        );
        final ElementSchedule schedule = (await harness.learning.findSchedule(
          harness.refOf(result.unwrap()),
        ))!;
        expect(schedule.priority, PriorityRank.middle);
      },
    );

    test(
      'the first interval follows A, not where the article was placed',
      () async {
        final Result<Source> urgent = await harness.reader.importSource(
          ImportSource(
            harness.operation(),
            title: 'Urgent',
            markdown: _markdown,
            priorityPercent: 0,
            timestampUtc: clock.nowUtc(),
          ),
        );
        final Result<Source> background = await harness.reader.importSource(
          ImportSource(
            harness.operation(),
            title: 'Background',
            markdown: _markdown,
            priorityPercent: 100,
            timestampUtc: clock.nowUtc(),
          ),
        );

        final TopicState urgentTopic = (await harness.learning.findTopic(
          harness.refOf(urgent.unwrap()),
        ))!;
        final TopicState backgroundTopic = (await harness.learning.findTopic(
          harness.refOf(background.unwrap()),
        ))!;

        final StudyDay today = await harness.today();
        // Creation is introduction eligibility, not a repetition: neither has an
        // interval yet, and a low priority may not hide a new article for weeks
        // before it has ever been opened.
        expect(urgentTopic.intervalDays, 0);
        expect(backgroundTopic.intervalDays, 0);
        expect(
          urgentTopic.schedule.dueDay,
          today,
          reason: 'both are due today; priority decides how far they then go',
        );
        expect(backgroundTopic.schedule.dueDay, today);

        // The first genuine encounter is what writes the first interval. In
        // SM20 its size comes from the section 5.2 formula over A, and A for a
        // new topic comes from the text-length rule in section 5.1. Priority
        // is not an input: section 5.4 drifts priority *after* an interval is
        // chosen, which is the opposite direction.
        for (final Source source in <Source>[
          urgent.unwrap(),
          background.unwrap(),
        ]) {
          final Result<TopicState> done = await harness.reader
              .completeEncounter(
                CompleteTopicEncounter(
                  harness.operation(),
                  ref: harness.refOf(source),
                  timestampUtc: clock.nowUtc(),
                ),
              );
          expect(done.isOk, isTrue, reason: '${done.failureOrNull}');
        }

        final TopicState urgentAfter = (await harness.learning.findTopic(
          harness.refOf(urgent.unwrap()),
        ))!;
        final TopicState backgroundAfter = (await harness.learning.findTopic(
          harness.refOf(background.unwrap()),
        ))!;
        expect(
          urgentAfter.intervalDays,
          backgroundAfter.intervalDays,
          reason: 'same text means same A, and A alone sizes the interval',
        );
        expect(urgentAfter.schedule.dueDay, today.addDays(1));
        expect(backgroundAfter.schedule.dueDay, today.addDays(1));

        // Priority did move, but as a consequence of the repetition rather
        // than as an input to it, and both moved the same way because both
        // saw the same interval change.
        final PriorityScale scale = await harness.context.priorityScale();
        expect(
          scale.percentageOf(urgentAfter.schedule.priority),
          lessThan(scale.percentageOf(backgroundAfter.schedule.priority)),
          reason: 'the urgent article is still ahead of the background one',
        );
      },
    );
  });
}
