/// The scheduler safety metrics, read from a real collection.
///
/// These numbers are the only way a slow policy failure becomes visible:
/// automatic overflow turning permanent, the protected band losing its
/// guarantee, or tomorrow's load quietly growing while today looks fine. The
/// suite exists to keep them honest — every figure has to come from what the
/// collection actually recorded, not from a recomputation that has forgotten
/// what the day looked like before the valve ran.
library;

import 'package:incremental_reader/src/application/queue/queue_commands.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/application/scheduling/mercy_workflow.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/scheduler_metrics.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph with enough words in it to be worth reading twice over.

A second paragraph, so the document has some shape to it.
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
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
    await harness.tuneSettings(
      (AppSettings s) => s.copyWith(
        queue: s.queue.copyWith(maxTopics: 3, protectedPercentile: 0),
      ),
    );
  });

  tearDown(() => harness.close());

  test('an empty collection reports zeroes rather than failing', () async {
    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(metrics.effectiveOverdueCards, 0);
    expect(metrics.effectiveOverdueTopics, 0);
    expect(metrics.dueWorkCount, 0);
    expect(metrics.automaticOverflowFraction, isNull);
    expect(metrics.protectionInvariantHolds, isTrue);
    expect(metrics.next30Days, hasLength(schedulerDueHorizonDays));
  });

  test('the due forecast separates what is scheduled from what is allowed',
      () async {
    final List<Source> sources = await harness.importSources(4);
    final StudyDay today = await harness.today();

    await harness.reader.postpone(
      PostponeElement(
        harness.operation(),
        ref: ElementRef(id: sources.first.id, type: ElementType.source),
        until: today.addDays(5),
        timestampUtc: clock.nowUtc(),
      ),
    );

    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    // All four are algorithmically due today; one has been pushed away by
    // hand. The gap between the two counts is the whole point: work that is
    // being held back must not read as work that went away.
    expect(metrics.next30Days.first.algorithmicTopics, 4);
    expect(metrics.next30Days.first.effectiveTopics, 3);
    expect(
      metrics.activeAdjustmentLoadByReason[ScheduleAdjustmentReason
          .manualLater]?.distinctElementCount,
      1,
    );
    expect(metrics.manualLaterCount, 1);
  });

  test('automatic overflow is counted against the day it was due', () async {
    await harness.importSources(8);
    clock.advance(const Duration(days: 7));
    await harness.queueQuery.load();

    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(metrics.automaticOverflowCount, greaterThan(0));
    expect(metrics.dueWorkCount, greaterThanOrEqualTo(
      metrics.automaticOverflowCount,
    ));
    expect(metrics.automaticOverflowFraction, isNotNull);
    expect(
      metrics.activeAdjustmentLoadByReason[ScheduleAdjustmentReason
          .autoOverflow],
      isNotNull,
    );
  });

  test('protected elements are never reported as automatically postponed',
      () async {
    await harness.tuneSettings(
      (AppSettings s) => s.copyWith(
        queue: s.queue.copyWith(maxTopics: 1, protectedPercentile: 0.5),
      ),
    );
    await harness.importSources(6);
    clock.advance(const Duration(days: 7));
    await harness.queueQuery.load();

    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(
      metrics.protectedElementViolations,
      0,
      reason: 'this figure existing at all is the guarantee; it must be zero',
    );
    expect(metrics.protectionInvariantHolds, isTrue);
  });

  test('an applied Mercy batch is reported with its size', () async {
    await harness.importSources(6);
    clock.advance(const Duration(days: 14));
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
    final Result<int> applied = await harness.mercy.apply(
      ApplyMercy(
        harness.operation(),
        day: today,
        batchId: batch.batchId,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(applied.isOk, isTrue, reason: '${applied.failureOrNull}');

    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(metrics.mercyCount, 1);
    expect(metrics.mercyBatchSizes, <int>[applied.unwrap()]);
    expect(
      metrics.activeAdjustmentLoadByReason[ScheduleAdjustmentReason.mercy]
          ?.exactOverrideCount,
      applied.unwrap(),
    );
  });

  test('reviews and encounters are counted, deferrals are not', () async {
    final List<Source> sources = await harness.importSources(2);
    final Result<void> done = await harness.reader.completeEncounter(
      CompleteTopicEncounter(
        harness.operation(),
        ref: ElementRef(id: sources.first.id, type: ElementType.source),
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(done.isOk, isTrue, reason: '${done.failureOrNull}');

    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(metrics.topicsCompleted, 1);
    expect(
      metrics.actualCardReviews,
      0,
      reason: 'a topic encounter is not a card review, and never counts as one',
    );
  });

  test('the same collection produces the same snapshot twice', () async {
    await harness.importSources(5);
    clock.advance(const Duration(days: 3));
    await harness.queueQuery.load();

    final SchedulerMetricsSnapshot first = await harness.metrics.collect();
    final SchedulerMetricsSnapshot second = await harness.metrics.collect();
    expect(second.dueWorkCount, first.dueWorkCount);
    expect(second.automaticOverflowCount, first.automaticOverflowCount);
    expect(
      second.next30Days.map((DueLoadMetric d) => d.effectiveTopics),
      first.next30Days.map((DueLoadMetric d) => d.effectiveTopics),
    );
  });
}
