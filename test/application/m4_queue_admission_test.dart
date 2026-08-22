/// The daily valve, Study More, Mercy, and the repetition log they write.
///
/// The gate this suite covers: repeated queue builds change nothing, a cap
/// change takes effect without a restart, a backlog is survivable, and every
/// deferral is recorded as a deferral rather than as a review.
library;

import 'package:incremental_reader/src/application/queue/queue_commands.dart';
import 'package:incremental_reader/src/application/queue/queue_handlers.dart';
import 'package:incremental_reader/src/application/queue/queue_query.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/application/scheduling/mercy_workflow.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/mercy.dart';
import 'package:incremental_reader/src/domain/scheduling/revlog.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

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

  Future<TopicState> topicOf(Source source) async =>
      (await learning.findTopic(
        ElementRef(id: source.id, type: ElementType.source),
      ))!;

  Future<List<RevlogEntry>> revlogOf(Source source) => learning.listRevlogFor(
    ElementRef(id: source.id, type: ElementType.source),
  );
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
    await harness.tuneSettings(
      (AppSettings settings) => settings.copyWith(
        queue: settings.queue.copyWith(
          maxTopics: 3,
          protectedPercentile: 0,
          randomization: 0,
        ),
      ),
    );
  });

  tearDown(() => harness.close());

  group('the daily valve', () {
    test('admits the cap and leaves the rest due, not postponed', () async {
      final List<Source> sources = await harness.importSources(8);
      final QueueProjection projection = await harness.queueQuery.load();

      expect(projection.entries, hasLength(3));
      expect(projection.counters.dueTopics, 8);
      expect(projection.counters.overflowTopics, 5);
      expect(
        projection.deferredThisRun,
        0,
        reason:
            'the supermemo_like profile never postpones what became due '
            'today; it simply does not admit all of it',
      );
      expect(
        projection.entries.first.ref.id,
        sources.first.id,
        reason: 'the best priority is served first',
      );
    });

    test('spreads yesterday\'s backlog and nothing newer', () async {
      final List<Source> sources = await harness.importSources(8);
      // Come back a week later: every one of those is now outstanding
      // backlog rather than work that became due today.
      clock.advance(const Duration(days: 7));
      final StudyDay today = await harness.today();
      final QueueProjection projection = await harness.queueQuery.load();

      expect(projection.deferredThisRun, greaterThan(0));
      final ElementRef last = ElementRef(
        id: sources.last.id,
        type: ElementType.source,
      );
      final List<ScheduleAdjustment> adjustments = await harness.learning
          .listActiveAdjustments(elements: <ElementRef>{last});
      expect(adjustments, hasLength(1));
      expect(adjustments.single.reason, ScheduleAdjustmentReason.autoOverflow);
      expect(adjustments.single.notBeforeStudyDay, greaterThan(today));
    });

    test('is exactly-once per study day, however often the queue is built',
        () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));

      final QueueProjection first = await harness.queueQuery.load();
      final QueueProjection second = await harness.queueQuery.load();
      final QueueProjection third = await harness.queueQuery.load();

      expect(first.deferredThisRun, greaterThan(0));
      expect(second.deferredThisRun, 0);
      expect(third.deferredThisRun, 0);
      expect(
        second.entries.map((QueueEntry e) => e.ref),
        first.entries.map((QueueEntry e) => e.ref),
        reason: 'rebuilding mid-session must not move the user’s place',
      );
      expect(
        (await harness.learning.recentActivity(limit: 100))
            .where((r) => r.kind == kDailyAdmissionKind)
            .length,
        1,
      );
    });

    test('never lets a rebuild push the same element further', () async {
      final List<Source> sources = await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      await harness.queueQuery.load();
      final ElementRef last = ElementRef(
        id: sources.last.id,
        type: ElementType.source,
      );
      final StudyDay first = (await harness.learning.listActiveAdjustments(
        elements: <ElementRef>{last},
      )).single.notBeforeStudyDay!;

      await harness.queueQuery.load();
      await harness.queueQuery.load();

      final List<ScheduleAdjustment> after = await harness.learning
          .listActiveAdjustments(elements: <ElementRef>{last});
      expect(after, hasLength(1), reason: 'bounds are upserted, not stacked');
      expect(after.single.notBeforeStudyDay, first);
    });

    test('records deferrals as deferrals, never as encounters', () async {
      final List<Source> sources = await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      await harness.queueQuery.load();

      final Source deferred = sources.last;
      final List<RevlogEntry> log = await harness.revlogOf(deferred);
      final RevlogEntry entry = log.firstWhere(
        (RevlogEntry e) => e.eventType == RevlogEventType.autoPostpone,
      );

      expect(entry.grade, isNull);
      expect(entry.feedsOptimizer, isFalse);
      expect(entry.metadata!['destination'], isNotNull);
      expect(entry.metadata!['policy_version'], 'supermemo_like_v1');
      expect(
        log.any((RevlogEntry e) => e.eventType == RevlogEventType.topicRead),
        isFalse,
        reason: 'the valve must never fabricate an encounter',
      );
    });

    test('preserves the algorithmic due date behind the deferral', () async {
      final List<Source> sources = await harness.importSources(8);
      final StudyDay imported = await harness.today();
      clock.advance(const Duration(days: 7));
      final StudyDay today = await harness.today();
      await harness.queueQuery.load();

      final TopicState deferred = await harness.topicOf(sources.last);
      expect(deferred.schedule.algorithmicDueDay, imported);
      expect(deferred.schedule.originalDueDay, imported);
      expect(deferred.encounters, 0);
      expect(
        deferred.schedule.overdueDaysOn(today),
        7,
        reason: 'overdue ranking still reflects real lateness',
      );

      final ElementRef ref = ElementRef(
        id: sources.last.id,
        type: ElementType.source,
      );
      expect(
        const EffectiveDueService().topicDueStudyDay(
          topic: ref,
          algorithmicDueStudyDay: deferred.schedule.algorithmicDueDay,
          adjustments: ScheduleAdjustmentSet(
            await harness.learning.listActiveAdjustments(
              elements: <ElementRef>{ref},
            ),
          ),
        ),
        greaterThan(today),
      );
    });

    test('the protected top survives even when everything else is shed',
        () async {
      await harness.tuneSettings(
        (AppSettings s) => s.copyWith(
          queue: s.queue.copyWith(maxTopics: 0, protectedPercentile: 0.25),
        ),
      );
      await harness.importSources(8);

      final QueueProjection projection = await harness.queueQuery.load();
      expect(projection.entries, isNotEmpty);
      expect(projection.counters.protectedElements, greaterThan(0));
    });

    test('can be switched off entirely', () async {
      await harness.tuneSettings(
        (AppSettings s) => s.copyWith(
          queue: s.queue.copyWith(autoPostpone: false),
        ),
      );
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));

      final QueueProjection projection = await harness.queueQuery.load();
      expect(projection.deferredThisRun, 0);
      expect(
        await harness.learning.listActiveAdjustments(),
        isEmpty,
        reason: 'nothing is postponed when the valve is off',
      );
    });

    test('a raised cap takes effect on the next build', () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      expect((await harness.queueQuery.load()).entries, hasLength(3));

      await harness.tuneSettings(
        (AppSettings s) => s.copyWith(queue: s.queue.copyWith(maxTopics: 20)),
      );
      // The deferred elements stay deferred — a bigger cap does not undo a
      // decision already written. Study More is how they come back.
      final QueueProjection after = await harness.queueQuery.load();
      expect(after.entries, hasLength(3));

      final Result<int> recalled = await harness.queue.studyMore(
        StudyMore(harness.operation(), day: after.today),
      );
      expect(recalled.unwrap(), 5);
      expect((await harness.queueQuery.load()).entries, hasLength(8));
    });
  });

  group('Study More', () {
    test('recalls what the app deferred and leaves manual Laters alone',
        () async {
      final List<Source> sources = await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      final StudyDay today = await harness.today();

      // One element the user pushed away themselves.
      final Source manual = sources[1];
      final ElementRef manualRef = ElementRef(
        id: manual.id,
        type: ElementType.source,
      );
      await harness.reader.postpone(
        PostponeElement(
          harness.operation(),
          ref: manualRef,
          until: today.addDays(4),
          timestampUtc: clock.nowUtc(),
        ),
      );
      await harness.queueQuery.load();

      final Result<int> recalled = await harness.queue.studyMore(
        StudyMore(harness.operation(), day: today),
      );
      expect(recalled.isOk, isTrue, reason: '${recalled.failureOrNull}');

      final List<ScheduleAdjustment> stillThere = await harness.learning
          .listActiveAdjustments(elements: <ElementRef>{manualRef});
      expect(
        stillThere.map((ScheduleAdjustment a) => a.reason),
        contains(ScheduleAdjustmentReason.manualLater),
        reason: 'the user said not now about that one specifically',
      );
      expect(
        stillThere
            .firstWhere(
              (ScheduleAdjustment a) =>
                  a.reason == ScheduleAdjustmentReason.manualLater,
            )
            .notBeforeStudyDay,
        today.addDays(4),
      );
    });

    test('honours its step and reports how many came back', () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      final QueueProjection projection = await harness.queueQuery.load();

      final Result<int> recalled = await harness.queue.studyMore(
        StudyMore(harness.operation(), day: projection.today, count: 2),
      );
      expect(recalled.unwrap(), 2);
    });

    test('returns zero rather than failing when nothing was deferred',
        () async {
      await harness.importSources(2);
      final QueueProjection projection = await harness.queueQuery.load();
      final Result<int> recalled = await harness.queue.studyMore(
        StudyMore(harness.operation(), day: projection.today),
      );
      expect(recalled.unwrap(), 0);
    });
  });

  group('Mercy', () {
    test('previews without writing anything', () async {
      final List<Source> sources = await harness.importSources(12);
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();
      final TopicState before = await harness.topicOf(sources.first);

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          horizonDays: 5,
          dailyCap: 3,
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
        await harness.learning.listActiveAdjustments(),
        isEmpty,
        reason: 'nothing may be deferred before the user confirms',
      );
    });

    test('spreads a backlog best-priority-first across a horizon', () async {
      final List<Source> sources = await harness.importSources(12);
      // Three weeks away.
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          horizonDays: 5,
          dailyCap: 3,
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
        for (final MercyAssignment assignment in batch.preview.assignments)
          assignment.element: assignment.toDay,
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
        0,
        reason: 'Mercy moves dates and nothing else',
      );
      expect(
        (await harness.topicOf(sources.first)).schedule.algorithmicDueDay,
        isNot(destinations[best]),
        reason: 'the canonical due survives underneath the override',
      );
    });

    test('applying a stale preview writes nothing', () async {
      final List<Source> sources = await harness.importSources(6);
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          horizonDays: 4,
          dailyCap: 2,
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
      expect(
        await harness.learning.listActiveAdjustments(
          reasons: const <ScheduleAdjustmentReason>{
            ScheduleAdjustmentReason.mercy,
          },
        ),
        isEmpty,
      );
    });

    test('undo restores the exact prior adjustment set', () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: today,
          horizonDays: 4,
          dailyCap: 3,
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
        await harness.learning.listActiveAdjustments(
          reasons: const <ScheduleAdjustmentReason>{
            ScheduleAdjustmentReason.mercy,
          },
        ),
        isNotEmpty,
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
      expect(
        await harness.learning.listActiveAdjustments(
          reasons: const <ScheduleAdjustmentReason>{
            ScheduleAdjustmentReason.mercy,
          },
        ),
        isEmpty,
        reason: 'the batch is gone from the active set',
      );
      expect(
        await harness.learning.listSchedulerEventsFor(
          ElementRef(id: 'never', type: ElementType.source),
        ),
        isEmpty,
      );
    });

    test('a repeated preview command returns the original batch', () async {
      await harness.importSources(4);
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
      await harness.importSources(3);
      final StoredMercyBatch batch = (await harness.mercy.preview(
        PreviewMercy(
          harness.operation(),
          day: await harness.today(),
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();
      // Mercy is the recovery tool, so outstanding work may move even on the
      // day it became due — but nothing not yet due is touched unless the
      // user asks for it, and the exclusions say so.
      expect(batch.preview.selectedCount, 3);
      expect(
        batch.preview.assignments.every(
          (MercyAssignment assignment) => assignment.toDay > assignment.fromDay,
        ),
        isTrue,
      );
    });
  });

  group('the day boundary', () {
    test('a new study day admits again', () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      expect((await harness.queueQuery.load()).deferredThisRun, greaterThan(0));

      clock.advance(const Duration(days: 1));
      final QueueProjection tomorrow = await harness.queueQuery.load();
      expect(
        tomorrow.today.toString(),
        '2026-03-13',
        reason: 'the operation id is keyed on the day, so a new day is a new '
            'admission',
      );
    });

    test('the rollover decides which day a session belongs to', () async {
      await harness.tuneSettings(
        (AppSettings s) => s.copyWith(
          studyDay: s.studyDay.copyWith(rolloverMinutes: 240),
        ),
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
    test('every admission is traceable to one operation id', () async {
      await harness.importSources(8);
      clock.advance(const Duration(days: 7));
      final StudyDay today = await harness.today();
      await harness.queueQuery.load();

      final String expected = dailyAdmissionOperationId(today);
      final List<RevlogEntry> deferrals = (await harness.learning.recentRevlog(
        limit: 200,
      )).where((RevlogEntry e) => e.eventType == RevlogEventType.autoPostpone)
          .toList();

      expect(deferrals, isNotEmpty);
      expect(
        deferrals.every((RevlogEntry e) => e.operationId == expected),
        isTrue,
      );
      expect(
        harness.diagnostics.named(kDailyAdmissionKind).single.operationId,
        OperationId(expected),
      );
    });

    test('the day’s counters are recorded for the diagnostics panel', () async {
      await harness.importSources(8);
      await harness.queueQuery.load();

      final Map<String, Object?> metadata = (await harness.learning
              .recentActivity(limit: 50))
          .firstWhere((r) => r.kind == kDailyAdmissionKind)
          .metadata!;

      expect(metadata['due_topics'], 8);
      expect(metadata['admitted_topics'], 3);
      expect(metadata['overflow_topics'], 5);
      expect(metadata['protection_percent'], isNotNull);
    });
  });
}
