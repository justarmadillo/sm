/// Scheduler metrics read from a real canonical SM20 collection.
library;

import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/scheduler_metrics.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
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

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
  });

  tearDown(() => harness.close());

  test('an empty collection reports canonical zeroes', () async {
    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(metrics.overdueCards, 0);
    expect(metrics.overdueTopics, 0);
    expect(metrics.next30Days, hasLength(schedulerDueHorizonDays));
    expect(
      metrics.next30Days.every((DueLoadMetric day) => day.cards == 0),
      isTrue,
    );
    expect(
      metrics.next30Days.every((DueLoadMetric day) => day.topics == 0),
      isTrue,
    );
  });

  test('manual postpone changes the canonical due forecast', () async {
    final List<Source> sources = await harness.importSources(4);
    final StudyDay today = await harness.today();

    final result = await harness.reader.postpone(
      PostponeElement(
        harness.operation(),
        ref: ElementRef(id: sources.first.id, type: ElementType.source),
        until: today.addDays(5),
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

    final SchedulerMetricsSnapshot metrics = await harness.metrics.collect();
    expect(metrics.next30Days.first.topics, 3);
    expect(metrics.next30Days[5].topics, 1);
    expect(metrics.manualLaterCount, 1);
  });

  test('genuine topic encounters are counted', () async {
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
    expect(metrics.actualCardReviews, 0);
  });

  test('the same collection produces the same due snapshot twice', () async {
    await harness.importSources(5);
    final SchedulerMetricsSnapshot first = await harness.metrics.collect();
    final SchedulerMetricsSnapshot second = await harness.metrics.collect();
    expect(
      second.next30Days.map((DueLoadMetric day) => (day.cards, day.topics)),
      first.next30Days.map((DueLoadMetric day) => (day.cards, day.topics)),
    );
  });
}
