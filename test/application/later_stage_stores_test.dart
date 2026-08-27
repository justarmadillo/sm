/// Later Today across the stage stores.
///
/// An element belongs to exactly one stage. Later Today on a pending topic
/// takes the section 8.1 nonmemorized branch, which memorizes it, so it has to
/// leave Pending as it joins Outstanding.
library;

import 'package:incremental_reader/src/application/queue/queue_query.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/queue_policy.dart';
import 'package:incremental_reader/src/domain/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

void main() {
  late AppHarness harness;

  setUp(() => harness = AppHarness());
  tearDown(() => harness.close());

  Future<(Source, ElementRef)> importOne() async {
    final Source source = (await harness.reader.importSource(
      ImportSource(
        harness.operation(),
        title: 'Fresh',
        markdown: '# T\n\nA paragraph with enough words to parse.\n',
        timestampUtc: harness.clock.nowUtc(),
      ),
    )).unwrap();
    return (source, ElementRef(id: source.id, type: ElementType.source));
  }

  test('a newly imported topic starts in Pending', () async {
    final (_, ElementRef ref) = await importOne();
    final QueueProjection projection = await harness.queueQuery.load();
    expect(projection.lane, QueueLane.pending);
    expect((await harness.learning.findTopic(ref))!.status,
        Sm20ElementStatus.pending);
  });

  test('Later Today memorizes it and moves it out of Pending', () async {
    final (_, ElementRef ref) = await importOne();
    await harness.queueQuery.load();

    await harness.reader.postpone(
      PostponeElement(harness.operation(), ref: ref),
    );

    final Sm20CollectionState runtime = await harness.context.runtimeState();
    expect(
      runtime.pending,
      isNot(contains(ref)),
      reason: 'it is no longer pending, so it may not stay in that store',
    );
    expect(runtime.outstanding, contains(ref));

    final TopicState after = (await harness.learning.findTopic(ref))!;
    expect(after.status, Sm20ElementStatus.memorized);
    // Section 8.1's nonmemorized branch computes max(target - today, 0), and
    // Later Today targets today, so the stored interval is zero and the
    // element stays due today. Later Today means later *today*.
    expect(after.storedInterval, 0);
    expect(after.schedule.algorithmicDueDay, await harness.today());
  });

  test('a dated postpone moves it off today instead', () async {
    final (_, ElementRef ref) = await importOne();
    await harness.queueQuery.load();
    final until = (await harness.today()).addDays(3);

    await harness.reader.postpone(
      PostponeElement(harness.operation(), ref: ref, until: until),
    );

    final TopicState after = (await harness.learning.findTopic(ref))!;
    expect(after.schedule.algorithmicDueDay, until);
    final Sm20CollectionState runtime = await harness.context.runtimeState();
    expect(runtime.outstanding, isNot(contains(ref)));
    expect(runtime.pending, isNot(contains(ref)));
  });
}
