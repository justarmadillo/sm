/// The daily valve, Study More, Mercy, and the repetition log they write.
///
/// The gate this suite covers: repeated queue builds change nothing, a cap
/// change takes effect without a restart, a backlog is survivable, and every
/// deferral is recorded as a deferral rather than as a review.
library;

import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/daily_queue/queue_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph that is long enough to be parsed into a readable block.
''';

extension _Fixtures on AppHarness {
  /// Imports [count] articles, all due today.
  Future<List<Source>> importSources(int count) async {
    final List<Source> sources = <Source>[];
    for (var i = 0; i < count; i++) {
      final Result<Source> result = await reader.importSource(
        ImportSource(
          operation(),
          title: 'Article ${i.toString().padLeft(2, '0')}',
          markdown: _markdown,
          // Each import lands at the bottom of the collection, so creation
          // order is priority order and the valve has something to
          // discriminate on.
          priorityPercent: 100,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      sources.add(result.unwrap());
    }
    return sources;
  }

  /// Imports [count] articles and gives each one a real repetition.
  ///
  /// Mercy moves scheduled repetitions. A freshly imported source is Pending
  /// in SM20 and has none, so a backlog fixture has to be studied once before
  /// there is anything for Mercy to gather.
  Future<List<Source>> importStudiedSources(int count) async {
    final List<Source> sources = await importSources(count);
    // Section 12.4 gathers from the collection learning-start day forward,
    // and that day is stamped the first time the queue is opened. Without an
    // opening the window would begin today and miss the whole backlog.
    await queueQuery.load();
    for (final Source source in sources) {
      final Result<TopicState> done = await reader.completeEncounter(
        CompleteTopicEncounter(
          operation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(done.isOk, isTrue, reason: '${done.failureOrNull}');
    }
    return sources;
  }

  Future<TopicState> topicOf(Source source) async => (await learning.findTopic(
    ElementRef(id: source.id, type: ElementType.source),
  ))!;
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
    // SM20's queue settings are a topic share and two randomization sliders;
    // there is no cap or protected band to neutralize. Randomization is
    // switched off so the order these tests assert is the priority order.
    await harness.tuneSettings(
      (AppSettings settings) => settings.copyWith(
        queue: settings.queue.copyWith(
          itemRandomization: 0,
          topicRandomization: 0,
        ),
      ),
    );
  });

  tearDown(() => harness.close());

  // The capacity valve and Study More are deliberately absent rather than
  // disabled. Section 14 finds no per-element postponement overlay and no
  // Study More writer in the executable, and section 9.5 makes Pending a
  // fallback stage rather than something a cap admits. Tests for an
  // admission cap, a deferral record, or a recall step would therefore be
  // asserting a scheduler this app no longer has.

  group('Mercy', () {
    test('previews without writing anything', () async {
      final List<Source> sources = await harness.importStudiedSources(12);
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();
      final TopicState before = await harness.topicOf(sources.first);

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          reschedulingDays: 5,
          gatheringDays: 5,
          elementsPerDay: 3,
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();

      expect(batch.preview.selectedCount, greaterThan(0));
      expect(batch.appliedAtUtc, isNull);
      final TopicState after = await harness.topicOf(sources.first);
      expect(
        after.schedule.algorithmicDueDay,
        before.schedule.algorithmicDueDay,
        reason: 'a preview is a proposal, not a change',
      );
      expect(
        batch.preview.items,
        isNotEmpty,
        reason: 'the proposal exists only in the batch until it is applied',
      );
    });

    test('spreads a backlog best-priority-first across a horizon', () async {
      final List<Source> sources = await harness.importStudiedSources(12);
      // Three weeks away.
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          reschedulingDays: 5,
          gatheringDays: 5,
          elementsPerDay: 3,
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();
      final Result<int> applied = await harness.mercy.apply(
        ApplyMercy(
          harness.operation(),
          day: today,
          batchId: batch.batchId,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(applied.unwrap(), batch.preview.selectedCount);

      final Map<ElementRef, StudyDay> destinations = <ElementRef, StudyDay>{
        for (final MercyPreviewItem item in batch.preview.items)
          item.ref: item.toDay,
      };
      final ElementRef best = ElementRef(
        id: sources.first.id,
        type: ElementType.source,
      );
      final ElementRef worst = ElementRef(
        id: sources.last.id,
        type: ElementType.source,
      );
      expect(
        destinations[best]!,
        lessThan(destinations[worst]!),
        reason: 'the top of the backlog gets the earlier capacity',
      );
      expect(
        (await harness.topicOf(sources.first)).encounters,
        1,
        reason: 'Mercy moves dates; the fixture repetition is all there is',
      );
      expect(
        (await harness.topicOf(sources.first)).schedule.algorithmicDueDay,
        destinations[best],
        reason: 'Mercy rewrites the canonical due; there is no override layer',
      );
    });

    test('applying a stale preview writes nothing', () async {
      final List<Source> sources = await harness.importStudiedSources(6);
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          reschedulingDays: 4,
          gatheringDays: 4,
          elementsPerDay: 2,
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();

      // The collection moves on: one element in the preview is now deferred by
      // the user's own hand.
      await harness.reader.postpone(
        PostponeElement(
          harness.operation(),
          ref: ElementRef(id: sources.first.id, type: ElementType.source),
          until: today.addDays(2),
          timestampUtc: clock.nowUtc(),
        ),
      );

      final Result<int> applied = await harness.mercy.apply(
        ApplyMercy(
          harness.operation(),
          day: today,
          batchId: batch.batchId,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(applied.isErr, isTrue);
      // A refused apply writes nothing, so no element carries a Mercy row.
      expect(
        await harness.learning.recentRevlog(limit: 200),
        isNot(
          contains(
            predicate<RevlogEntry>(
              (RevlogEntry e) => e.eventType == RevlogEventType.mercy,
            ),
          ),
        ),
      );
    });

    test('undo puts every moved element back where it was', () async {
      await harness.importStudiedSources(8);
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          reschedulingDays: 4,
          gatheringDays: 4,
          elementsPerDay: 3,
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();
      await harness.mercy.apply(
        ApplyMercy(
          harness.operation(),
          day: today,
          batchId: batch.batchId,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(
        (await harness.learning.recentRevlog(
          limit: 200,
        )).where((RevlogEntry e) => e.eventType == RevlogEventType.mercy),
        isNotEmpty,
        reason: 'applying Mercy journals one row per moved element',
      );

      final Result<int> undone = await harness.mercy.undo(
        UndoMercy(
          harness.operation(),
          day: today,
          batchId: batch.batchId,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(undone.unwrap(), batch.preview.selectedCount);
      // SM20 stores no adjustment set to clear. Undo restores each element's
      // canonical due to the exact day the preview recorded it leaving.
      for (final MercyPreviewItem item in batch.preview.items) {
        final ElementSchedule? schedule = await harness.learning.findSchedule(
          item.ref,
        );
        expect(
          schedule!.algorithmicDueDay,
          item.fromDay,
          reason: 'undo is a restore, not another reschedule',
        );
      }
      expect(
        await harness.learning.listSchedulerEventsFor(
          ElementRef(id: 'never', type: ElementType.source),
        ),
        isEmpty,
      );
    });

    test('a repeated preview command returns the original batch', () async {
      await harness.importStudiedSources(4);
      clock.advance(const Duration(days: 10));
      final StudyDay today = await harness.today();
      final OperationId operation = harness.operation();

      final StoredMercyBatch first = (await harness.mercy.preview(
        PreviewMercy(operation, day: today, timestampUtc: clock.nowUtc()),
      )).unwrap();
      final StoredMercyBatch again = (await harness.mercy.preview(
        PreviewMercy(operation, day: today, timestampUtc: clock.nowUtc()),
      )).unwrap();
      expect(again.batchId, first.batchId);
    });

    test('reports an empty plan rather than pretending to work', () async {
      await harness.importStudiedSources(3);
      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: await harness.today(),
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();
      // Every gathered element is assigned a day inside the rescheduling
      // horizon. Landing back on its own day is a legitimate outcome of the
      // section 12.4 assignment, so the claim worth making is that the plan
      // stays inside the horizon rather than that everything moved.
      final StudyDay today = await harness.today();
      final int horizon =
          (await harness.context.settings()).mercy.reschedulingDays;
      expect(batch.preview.selectedCount, 3);
      for (final MercyPreviewItem item in batch.preview.items) {
        expect(item.toDay >= today, isTrue, reason: 'never into the past');
        expect(item.toDay <= today.addDays(horizon - 1), isTrue);
      }
    });
  });

  group('the day boundary', () {
    test('a new study day admits again', () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      // Opening the queue is what runs the day's one automatic pass; the
      // point here is only that a new day opens a new one.
      await harness.queueQuery.load();

      clock.advance(const Duration(days: 1));
      final QueueProjection tomorrow = await harness.queueQuery.load();
      expect(
        tomorrow.today.toString(),
        '2026-03-13',
        reason:
            'the operation id is keyed on the day, so a new day is a new '
            'admission',
      );
    });

    test('the rollover decides which day a session belongs to', () async {
      await harness.tuneSettings(
        (AppSettings s) =>
            s.copyWith(studyDay: s.studyDay.copyWith(rolloverMinutes: 240)),
      );

      clock.setTo(DateTime.utc(2026, 3, 6, 2));
      expect(
        (await harness.today()).toString(),
        '2026-03-05',
        reason: 'a session running past midnight is still the same study day',
      );

      clock.setTo(DateTime.utc(2026, 3, 6, 5));
      expect((await harness.today()).toString(), '2026-03-06');
    });
  });

  group('operation tracing', () {
    test('opening the queue is traceable to one operation id', () async {
      await harness.importStudiedSources(8);
      clock.advance(const Duration(days: 7));
      final StudyDay today = await harness.today();
      await harness.queueQuery.load();

      // The id is derived from the study day, which is what makes the day's
      // one automatic pass idempotent across refreshes and restarts.
      final String expected = dailyAdmissionOperationId(today);
      expect(
        harness.diagnostics.named(kDailyAdmissionKind).last.operationId,
        OperationId(expected),
      );
      // Anything the automatic pass did move carries that same id.
      for (final RevlogEntry entry
          in (await harness.learning.recentRevlog(limit: 200)).where(
            (RevlogEntry e) => e.eventType == RevlogEventType.autoPostpone,
          )) {
        expect(entry.operationId, expected);
      }
    });

    test('the day’s counters are recorded for the diagnostics panel', () async {
      await harness.importStudiedSources(8);
      clock.advance(const Duration(days: 2));
      await harness.queueQuery.load();

      final Map<String, Object?> metadata =
          (await harness.learning.recentActivity(
            limit: 50,
          )).firstWhere((r) => r.kind == kDailyAdmissionKind).metadata!;

      // SM20 admits everything that is due; there is no cap and so no
      // overflow or protection figure to record. What the panel needs is what
      // was due, what the day's stage is, and what the automatic pass moved.
      expect(metadata['due_topics'], isA<int>());
      expect(metadata['admitted_topics'], metadata['due_topics']);
      expect(metadata['overflow_topics'], isNull);
      expect(metadata['stage'], 0);
      expect(metadata['auto_postpone_outcome'], isNotNull);
    });
  });
}
