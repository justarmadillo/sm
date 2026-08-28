/// The Learn menu's manual stage and randomization commands.
///
/// SM20 falls through Outstanding, Final Drill and Pending on its own, but the
/// menu also enters the two fallback stages directly and can reorder or empty
/// the stored queues. These are the commands behind
/// `MIFinalDrill2`, `MICutDrills`, `MIRandomLearning` and
/// `MIRandomizeRepetitions`.
library;

import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph long enough to be parsed into a readable block.
''';

extension _Fixtures on AppHarness {
  Future<List<Source>> importStudied(int count) async {
    final List<Source> sources = <Source>[];
    for (var i = 0; i < count; i++) {
      final Result<Source> imported = await reader.importSource(
        ImportSource(
          operation(),
          title: 'Article $i',
          markdown: _markdown,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');
      sources.add(imported.unwrap());
    }
    await queueQuery.load();
    for (final Source source in sources) {
      final Result<Object?> done = await reader.completeEncounter(
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

  Future<Sm20CollectionState> runtime() => context.runtimeState();

  Future<void> putInDrill(Iterable<ElementRef> refs) async {
    final Sm20CollectionState state = await runtime();
    await context.saveRuntimeState(
      state.copyWith(finalDrill: <ElementRef>[...state.finalDrill, ...refs]),
    );
  }

  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
  });

  tearDown(() => harness.close());

  Future<StudyDay> today() => harness.today();

  group('entering a stage by hand', () {
    test('shows the drill even while Outstanding still has work', () async {
      final List<Source> sources = await harness.importStudied(3);
      clock.advance(const Duration(days: 2));
      await harness.queueQuery.load();
      await harness.putInDrill(<ElementRef>[harness.refOf(sources.first)]);

      // Outstanding is deliberately not empty: the automatic chain would
      // never reach the drill here, and the command has to anyway.
      final QueueProjection before = await harness.queueQuery.load();
      expect(before.lane, isNot(QueueLane.finalDrill));

      final Result<Sm20QueueCommandOutcome> entered = await harness.queue
          .enterLearningStage(
            EnterLearningStage(
              harness.operation(),
              day: await today(),
              stage: Sm20StageRequest.finalDrill,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(entered.isOk, isTrue, reason: '${entered.failureOrNull}');
      expect(entered.unwrap().learningMode, 1);

      final QueueProjection after = await harness.queueQuery.load();
      expect(after.lane, QueueLane.finalDrill);
      expect(after.entries.map((QueueEntry e) => e.ref), <ElementRef>[
        harness.refOf(sources.first),
      ]);
    });

    test('the chosen stage survives a reload', () async {
      final List<Source> sources = await harness.importStudied(3);
      clock.advance(const Duration(days: 2));
      await harness.queueQuery.load();
      await harness.putInDrill(<ElementRef>[harness.refOf(sources.first)]);
      await harness.queue.enterLearningStage(
        EnterLearningStage(
          harness.operation(),
          day: await today(),
          stage: Sm20StageRequest.finalDrill,
          timestampUtc: clock.nowUtc(),
        ),
      );

      await harness.queueQuery.load();
      expect((await harness.queueQuery.load()).lane, QueueLane.finalDrill);
    });

    test('refuses an empty stage rather than showing nothing', () async {
      await harness.importStudied(2);
      final Result<Sm20QueueCommandOutcome> entered = await harness.queue
          .enterLearningStage(
            EnterLearningStage(
              harness.operation(),
              day: await today(),
              stage: Sm20StageRequest.finalDrill,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(entered.isErr, isTrue);
    });
  });

  group('returning to Outstanding', () {
    test('leaves a stage the user entered by hand', () async {
      final List<Source> sources = await harness.importStudied(3);
      clock.advance(const Duration(days: 2));
      await harness.queueQuery.load();
      await harness.putInDrill(<ElementRef>[harness.refOf(sources.first)]);
      await harness.queue.enterLearningStage(
        EnterLearningStage(
          harness.operation(),
          day: await today(),
          stage: Sm20StageRequest.finalDrill,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect((await harness.queueQuery.load()).lane, QueueLane.finalDrill);

      // Without stage 1 a user who entered the drill would be held there
      // until it emptied, with no command to leave.
      final Result<Sm20QueueCommandOutcome> back = await harness.queue
          .enterLearningStage(
            EnterLearningStage(
              harness.operation(),
              day: await today(),
              stage: Sm20StageRequest.outstanding,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(back.isOk, isTrue, reason: '${back.failureOrNull}');
      expect(back.unwrap().learningMode, 0);
      expect(
        (await harness.queueQuery.load()).lane,
        isNot(QueueLane.finalDrill),
      );
    });
  });

  group('cut drills', () {
    test('empties the drill and touches nothing else', () async {
      final List<Source> sources = await harness.importStudied(3);
      final ElementRef ref = harness.refOf(sources.first);
      await harness.putInDrill(<ElementRef>[ref]);
      final topicBefore = (await harness.learning.findTopic(ref))!;

      final Result<Sm20QueueCommandOutcome> cut = await harness.queue.cutDrills(
        CutDrills(
          harness.operation(),
          day: await today(),
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(cut.unwrap().affected, 1);
      expect((await harness.runtime()).finalDrill, isEmpty);

      // Drill membership was never part of the schedule, so removing it must
      // leave every scheduling field exactly as it was.
      final topicAfter = (await harness.learning.findTopic(ref))!;
      expect(topicAfter.schedule.dueDay, topicBefore.schedule.dueDay);
      expect(topicAfter.storedInterval, topicBefore.storedInterval);
      expect(topicAfter.aFactorRaw.bytes, topicBefore.aFactorRaw.bytes);
      expect(topicAfter.repetitionCount, topicBefore.repetitionCount);
      expect(topicAfter.schedule.priority, topicBefore.schedule.priority);
    });

    test(
      'leaves the drill stage when it empties the queue behind it',
      () async {
        final List<Source> sources = await harness.importStudied(2);
        await harness.putInDrill(<ElementRef>[harness.refOf(sources.first)]);
        await harness.queue.enterLearningStage(
          EnterLearningStage(
            harness.operation(),
            day: await today(),
            stage: Sm20StageRequest.finalDrill,
            timestampUtc: clock.nowUtc(),
          ),
        );

        final Result<Sm20QueueCommandOutcome> cut = await harness.queue
            .cutDrills(
              CutDrills(
                harness.operation(),
                day: await today(),
                timestampUtc: clock.nowUtc(),
              ),
            );
        // Staying in a stage whose queue was just emptied would present a blank
        // screen with no way back.
        expect(cut.unwrap().learningMode, 0);
      },
    );

    test('an empty drill is a no-op, not a failure', () async {
      await harness.importStudied(1);
      final Result<Sm20QueueCommandOutcome> cut = await harness.queue.cutDrills(
        CutDrills(
          harness.operation(),
          day: await today(),
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(cut.unwrap().affected, 0);
    });
  });

  group('randomizing a stored queue', () {
    test('reorders Outstanding and advances the shared stream', () async {
      await harness.importStudied(8);
      clock.advance(const Duration(days: 2));
      await harness.queueQuery.load();

      final Sm20CollectionState before = await harness.runtime();
      expect(before.outstanding.length, greaterThan(1));

      final Result<Sm20QueueCommandOutcome> shuffled = await harness.queue
          .randomizeQueue(
            RandomizeQueue(
              harness.operation(),
              day: await today(),
              queue: Sm20RandomizableQueue.outstanding,
              timestampUtc: clock.nowUtc(),
            ),
          );
      expect(shuffled.unwrap().affected, before.outstanding.length);

      final Sm20CollectionState after = await harness.runtime();
      // The same elements, and one shared stream that moved with them.
      expect(after.outstanding.toSet(), before.outstanding.toSet());
      expect(after.randomNumberSeed, isNot(before.randomNumberSeed));
    });

    test('a queue shorter than two elements consumes no randomness', () async {
      final List<Source> sources = await harness.importStudied(2);
      await harness.putInDrill(<ElementRef>[harness.refOf(sources.first)]);
      final Sm20CollectionState before = await harness.runtime();

      await harness.queue.randomizeQueue(
        RandomizeQueue(
          harness.operation(),
          day: await today(),
          queue: Sm20RandomizableQueue.finalDrill,
          timestampUtc: clock.nowUtc(),
        ),
      );

      expect(
        (await harness.runtime()).randomNumberSeed,
        before.randomNumberSeed,
      );
    });
  });
}
