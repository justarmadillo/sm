/// Manual Smart Postpone through the real application transaction.
///
/// The gate this suite covers: a simulation is inert — it writes nothing and
/// consumes no randomness from the one global stream — while a real run moves
/// the calendar without touching anything a repetition owns.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_postpone.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

const String _markdown = '''
# Chapter

A paragraph that is long enough to be parsed into a readable block.
''';

extension _Fixtures on AppHarness {
  /// Imports [count] articles and completes one encounter on each.
  ///
  /// The completion is what memorizes the topic: a freshly imported source is
  /// Pending, and Pending is a separate stage that Outstanding never contains.
  Future<List<Source>> memorizedSources(int count) async {
    final List<Source> sources = <Source>[];
    for (var i = 0; i < count; i++) {
      final Result<Source> imported = await reader.importSource(
        ImportSource(
          operation(),
          title: 'Article ${i.toString().padLeft(2, '0')}',
          markdown: _markdown,
          priorityPercent: 100,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(imported.isOk, isTrue, reason: '${imported.failureOrNull}');
      final Source source = imported.unwrap();
      final Result<TopicState> completed = await reader.completeEncounter(
        CompleteTopicEncounter(
          operation(),
          ref: ElementRef(id: source.id, type: ElementType.source),
          wordsRead: 40,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(completed.isOk, isTrue, reason: '${completed.failureOrNull}');
      sources.add(source);
    }
    return sources;
  }

  ElementRef refOf(Source source) =>
      ElementRef(id: source.id, type: ElementType.source);

  /// Everything a postpone must not touch, in one comparable value.
  ///
  /// [TopicState] has identity equality, so a whole-object expectation would
  /// pass or fail for the wrong reason.
  Future<List<Object?>> topicFingerprint(ElementRef ref) async {
    final TopicState topic = (await learning.findTopic(ref))!;
    return <Object?>[
      topic.schedule.algorithmicDueDay.toString(),
      topic.storedInterval,
      topic.aFactorRaw.bytes.join(','),
      topic.lastIntervalRatioRaw.bytes.join(','),
      topic.lastReviewDay?.toString(),
      topic.repetitionCount,
      topic.lapseCount,
      topic.totalPostponementCount,
      topic.status,
      topic.schedule.priority.orderKey,
    ];
  }

  Future<TopicState> topicOf(Source source) async =>
      (await learning.findTopic(refOf(source)))!;

  /// One card, graded once so it leaves the new-card Pending stage.
  Future<CardState> memorizedCard(String sourceId) async {
    final List<Card> cards = (await formulation.formulate(
      FormulateCards(
        operation(),
        parent: CardParent.source(sourceId),
        drafts: const <CardDraft>[
          ClozeCardDraft('Working memory holds {{c1::four items}}.'),
        ],
        timestampUtc: clock.nowUtc(),
      ),
    )).unwrap();
    final Result<ReviewOutcome> graded = await review.review(
      ReviewCard(
        operation(),
        cardId: cards.single.id,
        rating: CardRating.easy,
        elapsedMs: 1500,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(graded.isOk, isTrue, reason: '${graded.failureOrNull}');
    return (await learning.findCardState(cards.single.id))!;
  }
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
    await harness.tuneSettings(
      (AppSettings settings) => settings.copyWith(
        postpone: settings.postpone.copyWith(
          // Automatic postponement would move the same backlog before the
          // manual run could see it, which is a different code path.
          isAutomaticPostponeEnabled: false,
          defaultProfile: settings.postpone.defaultProfile.copyWith(
            protectedCount: 2,
          ),
        ),
      ),
    );
  });

  tearDown(() => harness.close());

  /// Builds today's queue so Outstanding membership exists, then returns it.
  Future<Sm20CollectionState> openQueue() async {
    await harness.queueQuery.load();
    return harness.context.runtimeState();
  }

  group('simulation', () {
    test('decides without writing anything or drawing randomness', () async {
      final List<Source> sources = await harness.memorizedSources(6);
      clock.advance(const Duration(days: 40));
      final Sm20CollectionState before = await openQueue();
      final Map<ElementRef, List<Object?>> topicsBefore =
          <ElementRef, List<Object?>>{
            for (final Source source in sources)
              harness.refOf(source): await harness.topicFingerprint(
                harness.refOf(source),
              ),
          };

      final Result<AppliedSmartPostpone> result = await harness.queue
          .runSmartPostpone(
            RunSmartPostpone(
              harness.operation(),
              day: await harness.today(),
              profile: (await harness.settingsStore.load())
                  .postpone
                  .defaultProfile
                  .copyWith(isSimulationOnly: true),
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final AppliedSmartPostpone applied = result.unwrap();
      expect(applied.written, 0);
      expect(applied.result.decisions, isNotEmpty);
      expect(
        applied.result.decisions.every(
          (SmartPostponeDecision decision) => decision.isSimulationOnly,
        ),
        isTrue,
      );
      expect(
        applied.result.randomDraws,
        0,
        reason: 'a simulation must not consume the one global PRNG stream',
      );

      final Sm20CollectionState after = await harness.context.runtimeState();
      expect(after.randomNumberSeed, before.randomNumberSeed);
      expect(after.outstanding, before.outstanding);
      for (final Source source in sources) {
        final ElementRef ref = harness.refOf(source);
        expect(await harness.topicFingerprint(ref), topicsBefore[ref]);
        expect(
          (await harness.learning.listReviewLogForElement(
            ref,
          )).map((ReviewLogEntry entry) => entry.eventType),
          isNot(contains(ReviewLogEventType.postpone)),
          reason: 'only the memorizing encounter should be logged',
        );
      }
    });
  });

  group('a real run', () {
    test('moves the calendar and logs a postpone, not a repetition', () async {
      final List<Source> sources = await harness.memorizedSources(6);
      clock.advance(const Duration(days: 40));
      final Sm20CollectionState before = await openQueue();
      final Map<ElementRef, List<Object?>> topicsBefore =
          <ElementRef, List<Object?>>{
            for (final Source source in sources)
              harness.refOf(source): await harness.topicFingerprint(
                harness.refOf(source),
              ),
          };
      final Map<ElementRef, TopicState> statesBefore = <ElementRef, TopicState>{
        for (final Source source in sources)
          harness.refOf(source): await harness.topicOf(source),
      };
      final StudyDay today = await harness.today();

      final Result<AppliedSmartPostpone> result = await harness.queue
          .runSmartPostpone(
            RunSmartPostpone(
              harness.operation(),
              day: today,
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final AppliedSmartPostpone applied = result.unwrap();
      expect(applied.result.postponed, isNotEmpty);
      expect(applied.written, applied.result.postponed.length);

      for (final ElementRef ref in applied.result.postponed) {
        final TopicState after = (await harness.learning.findTopic(ref))!;
        final TopicState prior = statesBefore[ref]!;
        expect(
          after.schedule.algorithmicDueDay,
          greaterThan(prior.schedule.algorithmicDueDay),
        );
        expect(
          after.aFactorRaw.bytes,
          prior.aFactorRaw.bytes,
          reason: 'a calendar move is never a repetition',
        );
        expect(after.repetitionCount, prior.repetitionCount);
        expect(after.lapseCount, prior.lapseCount);
        expect(after.schedule.priority, prior.schedule.priority);
        expect(after.status, Sm20ElementStatus.memorized);

        final List<ReviewLogEntry> log = await harness.learning
            .listReviewLogForElement(ref);
        expect(log.last.eventType, ReviewLogEventType.postpone);
        expect(log.last.grade, isNull);
      }

      // Everything left behind is untouched, including its last-review day.
      for (final ElementRef ref in applied.result.unpostponed) {
        expect(await harness.topicFingerprint(ref), topicsBefore[ref]);
      }

      final Sm20CollectionState after = await harness.context.runtimeState();
      expect(
        after.randomNumberSeed,
        isNot(before.randomNumberSeed),
        reason: 'the dispersion draws advance the one persisted stream',
      );
      for (final ElementRef ref in applied.result.postponed) {
        expect(after.outstanding, isNot(contains(ref)));
        expect(after.outstandingTopics, isNot(contains(ref)));
      }
    });

    test('moves a card without touching its FSRS memory', () async {
      final List<Source> sources = await harness.memorizedSources(1);
      final CardState card = await harness.memorizedCard(sources.single.id);
      clock.advance(const Duration(days: 60));
      await openQueue();
      final CardState before = (await harness.learning.findCardState(
        card.memory.cardId,
      ))!;

      final Result<AppliedSmartPostpone> result = await harness.queue
          .runSmartPostpone(
            RunSmartPostpone(
              harness.operation(),
              day: await harness.today(),
              profile: (await harness.settingsStore.load())
                  .postpone
                  .defaultProfile
                  .copyWith(protectedCount: 1, shouldSkipTopics: true),
              timestampUtc: clock.nowUtc(),
            ),
          );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull?.cause}');
      final AppliedSmartPostpone applied = result.unwrap();
      final ElementRef ref = ElementRef(
        id: card.memory.cardId,
        type: ElementType.card,
      );
      expect(applied.result.postponed, contains(ref));

      final CardState after = (await harness.learning.findCardState(
        card.memory.cardId,
      ))!;
      expect(after.memory.dueAtUtc.isAfter(before.memory.dueAtUtc), isTrue);
      expect(after.memory.stability, before.memory.stability);
      expect(after.memory.difficulty, before.memory.difficulty);
      expect(after.memory.repetitionCount, before.memory.repetitionCount);
      expect(after.memory.lapses, before.memory.lapses);
      expect(after.memory.state, before.memory.state);
      expect(
        after.memory.postponeCount,
        greaterThan(before.memory.postponeCount),
      );
      expect(after.schedule.priority, before.schedule.priority);

      final List<ReviewLogEntry> log = await harness.learning
          .listReviewLogForElement(ref);
      expect(log.last.eventType, ReviewLogEventType.postpone);
      expect(log.last.grade, isNull);
    });

    test('leaves the protected remainder unpostponed', () async {
      await harness.memorizedSources(6);
      clock.advance(const Duration(days: 40));
      await openQueue();

      final Result<AppliedSmartPostpone> result = await harness.queue
          .runSmartPostpone(
            RunSmartPostpone(
              harness.operation(),
              day: await harness.today(),
              timestampUtc: clock.nowUtc(),
            ),
          );

      final AppliedSmartPostpone applied = result.unwrap();
      expect(
        applied.result.unpostponed.length,
        greaterThanOrEqualTo(applied.result.profile.protectedCount),
      );
    });

    test(
      'an explicit population restricts the run to those elements',
      () async {
        final List<Source> sources = await harness.memorizedSources(6);
        clock.advance(const Duration(days: 40));
        await openQueue();
        final List<ElementRef> subset = <ElementRef>[
          harness.refOf(sources[0]),
          harness.refOf(sources[1]),
          harness.refOf(sources[2]),
        ];

        final Result<AppliedSmartPostpone> result = await harness.queue
            .runSmartPostpone(
              RunSmartPostpone(
                harness.operation(),
                day: await harness.today(),
                profile: (await harness.settingsStore.load())
                    .postpone
                    .defaultProfile
                    .copyWith(
                      scope: SmartPostponeScope.browser,
                      protectedCount: 1,
                    ),
                sourcePopulation: subset,
                timestampUtc: clock.nowUtc(),
              ),
            );

        final AppliedSmartPostpone applied = result.unwrap();
        expect(applied.result.sourceOrder.toSet(), subset.toSet());
        for (final Source source in sources.sublist(3)) {
          expect(
            (await harness.learning.listReviewLogForElement(
              harness.refOf(source),
            )).map((ReviewLogEntry entry) => entry.eventType),
            isNot(contains(ReviewLogEventType.postpone)),
          );
        }
      },
    );
  });
}
