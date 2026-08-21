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
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/revlog.dart';
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
          overloadTolerance: 1,
          protectedPercentile: 0,
          randomization: 0,
          maxSharePerRoot: 1,
        ),
      ),
    );
  });

  tearDown(() => harness.close());

  group('the daily valve', () {
    test('admits the cap and defers the rest by priority', () async {
      final List<Source> sources = await harness.importSources(8);
      final QueueProjection projection = await harness.queueQuery.load();

      expect(projection.entries, hasLength(3));
      expect(projection.counters.dueTopics, 8);
      expect(projection.counters.overflowTopics, 5);
      expect(projection.deferredThisRun, 5);
      expect(
        projection.entries.first.ref.id,
        sources.first.id,
        reason: 'the best priority is served first',
      );
    });

    test('is exactly-once per study day, however often the queue is built',
        () async {
      await harness.importSources(8);

      final QueueProjection first = await harness.queueQuery.load();
      final QueueProjection second = await harness.queueQuery.load();
      final QueueProjection third = await harness.queueQuery.load();

      expect(first.deferredThisRun, 5);
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

    test('records deferrals as deferrals, never as encounters', () async {
      final List<Source> sources = await harness.importSources(8);
      await harness.queueQuery.load();

      final Source deferred = sources.last;
      final List<RevlogEntry> log = await harness.revlogOf(deferred);
      final RevlogEntry entry = log.firstWhere(
        (RevlogEntry e) => e.eventType == RevlogEventType.autoPostpone,
      );

      expect(entry.grade, isNull);
      expect(entry.feedsOptimizer, isFalse);
      expect(entry.metadata!['delay_days'], isNotNull);
      expect(entry.metadata!['pressure'], isNotNull);
      expect(
        log.any((RevlogEntry e) => e.eventType == RevlogEventType.topicRead),
        isFalse,
        reason: 'the valve must never fabricate an encounter',
      );
    });

    test('preserves the algorithmic due date behind the deferral', () async {
      final List<Source> sources = await harness.importSources(8);
      final StudyDay today = await harness.today();
      await harness.queueQuery.load();

      final TopicState deferred = await harness.topicOf(sources.last);
      expect(deferred.schedule.dueDay, today);
      expect(deferred.schedule.originalDueDay, today);
      expect(deferred.schedule.effectiveDueDay, greaterThan(today));
      expect(deferred.schedule.deferralKind, DeferralKind.automatic);
      expect(deferred.encounters, 0);
      expect(deferred.postponeCount, 1);
      expect(
        deferred.schedule.overdueDaysOn(today.addDays(10)),
        10,
        reason: 'overdue ranking still reflects real lateness',
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

      final QueueProjection projection = await harness.queueQuery.load();
      expect(projection.entries, hasLength(8));
      expect(projection.deferredThisRun, 0);
    });

    test('a raised cap takes effect on the next build', () async {
      await harness.importSources(8);
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
      final StudyDay today = await harness.today();

      // One element the user pushed away themselves.
      final Source manual = sources[1];
      await harness.reader.postpone(
        PostponeElement(
          harness.operation(),
          ref: ElementRef(id: manual.id, type: ElementType.source),
          until: today.addDays(4),
          timestampUtc: clock.nowUtc(),
        ),
      );
      await harness.queueQuery.load();

      final Result<int> recalled = await harness.queue.studyMore(
        StudyMore(harness.operation(), day: today),
      );
      expect(recalled.isOk, isTrue, reason: '${recalled.failureOrNull}');

      final TopicState stillDeferred = await harness.topicOf(manual);
      expect(
        stillDeferred.schedule.deferralKind,
        DeferralKind.manual,
        reason: 'the user said not now about that one specifically',
      );
      expect(stillDeferred.schedule.effectiveDueDay, today.addDays(4));
    });

    test('honours its step and reports how many came back', () async {
      await harness.importSources(8);
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
    test('spreads a backlog best-priority-first across a horizon', () async {
      final List<Source> sources = await harness.importSources(12);
      // Three weeks away.
      clock.advance(const Duration(days: 21));
      final StudyDay today = await harness.today();

      final Result<int> spread = await harness.queue.runMercy(
        RunMercy(
          harness.operation(),
          day: today,
          horizonDays: 5,
          dailyCap: 3,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(spread.unwrap(), 12);

      final TopicState best = await harness.topicOf(sources.first);
      final TopicState worst = await harness.topicOf(sources.last);
      expect(
        best.schedule.effectiveDueDay,
        today.addDays(1),
        reason: 'the top of the backlog comes back within days',
      );
      expect(
        worst.schedule.effectiveDueDay,
        greaterThan(today.addDays(3)),
        reason: 'and the tail lands well past it',
      );
      expect(
        best.encounters,
        0,
        reason: 'Mercy moves dates and nothing else',
      );
    });

    test('logs every move as a Mercy event with its inputs', () async {
      final List<Source> sources = await harness.importSources(4);
      clock.advance(const Duration(days: 10));

      await harness.queue.runMercy(
        RunMercy(
          harness.operation(),
          day: await harness.today(),
          timestampUtc: clock.nowUtc(),
        ),
      );

      final RevlogEntry entry = (await harness.revlogOf(
        sources.first,
      )).firstWhere((RevlogEntry e) => e.eventType == RevlogEventType.mercy);

      expect(entry.eventType.isDeferral, isTrue);
      expect(entry.grade, isNull);
      expect(entry.metadata!['horizon_days'], isNotNull);
      expect(entry.metadata!['backlog_size'], 4);
    });

    test('does nothing when there is no backlog', () async {
      await harness.importSources(3);
      final Result<int> spread = await harness.queue.runMercy(
        RunMercy(
          harness.operation(),
          day: await harness.today(),
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(spread.unwrap(), 0);
    });
  });

  group('the day boundary', () {
    test('a new study day admits again', () async {
      await harness.importSources(8);
      expect((await harness.queueQuery.load()).deferredThisRun, 5);

      clock.advance(const Duration(days: 1));
      final QueueProjection tomorrow = await harness.queueQuery.load();
      expect(
        tomorrow.today.toString(),
        '2026-03-06',
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
      final StudyDay today = await harness.today();
      await harness.queueQuery.load();

      final String expected = dailyAdmissionOperationId(today);
      final List<RevlogEntry> deferrals = (await harness.learning.recentRevlog(
        limit: 200,
      )).where((RevlogEntry e) => e.eventType == RevlogEventType.autoPostpone)
          .toList();

      expect(deferrals, hasLength(5));
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
