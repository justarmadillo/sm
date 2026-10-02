/// Cram-only elements never reach the daily queue and never have their
/// schedule moved; custom decks may grade cards that are not due yet.
library;

import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/priority/priority_browser_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';
import '../support/harness_fixtures.dart';

void main() {
  late AppHarness harness;

  setUp(() => harness = AppHarness());
  tearDown(() => harness.close());

  Future<void> markCramOnly(ElementRef ref, {bool isCramOnly = true}) async {
    final result = await harness.tagCommands.markCramOnly(
      MarkCramOnly(
        harness.operation(),
        refs: <ElementRef>[ref],
        isCramOnly: isCramOnly,
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
  }

  Future<Set<ElementRef>> queuedRefs() async => <ElementRef>{
    for (final QueueEntry entry in (await harness.queueQuery.load()).entries)
      entry.ref,
  };

  group('daily queue', () {
    test('a due cram-only source is left out until it is unticked', () async {
      final List<Source> sources = await harness.importSources(2);
      final ElementRef cram = harness.refOf(sources.first);
      await markCramOnly(cram);

      expect(await queuedRefs(), <ElementRef>{harness.refOf(sources.last)});

      await markCramOnly(cram, isCramOnly: false);
      expect(await queuedRefs(), contains(cram));
    });

    test('an element already admitted today drops out once ticked', () async {
      final List<Source> sources = await harness.importSources(1);
      final ElementRef ref = harness.refOf(sources.single);
      expect(await queuedRefs(), contains(ref));

      await markCramOnly(ref);

      expect(await queuedRefs(), isNot(contains(ref)));
      final Sm20CollectionState runtime = await harness.context.runtimeState();
      expect(runtime.outstanding, isNot(contains(ref)));
    });
  });

  group('cards', () {
    test('a grade on a cram-only card is practice and moves nothing', () async {
      final Source source = (await harness.importSources(1)).single;
      final CardState before = await harness.memorizedCard(source.id);
      await markCramOnly(before.ref);
      harness.clock.advance(const Duration(days: 30));

      final ReviewOutcome outcome = (await harness.review.review(
        ReviewCard(
          harness.operation(),
          cardId: before.ref.id,
          rating: CardRating.again,
          timestampUtc: harness.clock.nowUtc(),
        ),
      )).unwrap();

      expect(outcome.wasPractice, isTrue);
      final CardState after = (await harness.learning.findCardState(
        before.ref.id,
      ))!;
      expect(after.memory.toJson(), before.memory.toJson());
    });

    test('Later is refused on a cram-only card', () async {
      final Source source = (await harness.importSources(1)).single;
      final CardState card = await harness.memorizedCard(source.id);
      await markCramOnly(card.ref);

      final result = await harness.review.postpone(
        PostponeCard(harness.operation(), cardId: card.ref.id),
      );

      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test(
      'a card not due yet is refused unless early review is allowed',
      () async {
        final Source source = (await harness.importSources(1)).single;
        final CardState before = await harness.memorizedCard(source.id);
        harness.clock.advance(const Duration(hours: 1));

        ReviewCard grade({required bool isEarlyReviewAllowed}) => ReviewCard(
          harness.operation(),
          cardId: before.ref.id,
          rating: CardRating.good,
          isEarlyReviewAllowed: isEarlyReviewAllowed,
          customDeckId: 'deck-1',
          timestampUtc: harness.clock.nowUtc(),
        );

        final refused = await harness.review.review(
          grade(isEarlyReviewAllowed: false),
        );
        expect(refused.failureOrNull, isA<ConflictFailure>());

        final ReviewOutcome early = (await harness.review.review(
          grade(isEarlyReviewAllowed: true),
        )).unwrap();
        expect(early.wasPractice, isFalse);
        expect(
          early.state.memory.repetitionCount,
          before.memory.repetitionCount + 1,
        );
        expect(
          early.state.memory.dueAtUtc.isBefore(before.memory.dueAtUtc),
          isFalse,
          reason: 'an early success never brings the card closer',
        );
      },
    );
  });

  group('topics', () {
    test('Done and Later are refused on a cram-only topic', () async {
      final Source source = (await harness.importSources(1)).single;
      final ElementRef ref = harness.refOf(source);
      await markCramOnly(ref);
      final String before = await harness.schedulingSnapshot();
      final int seedBefore =
          (await harness.context.runtimeState()).randomNumberSeed;

      final done = await harness.reader.completeEncounter(
        CompleteTopicEncounter(harness.operation(), ref: ref),
      );
      final later = await harness.reader.postpone(
        PostponeElement(harness.operation(), ref: ref),
      );

      expect(done.failureOrNull, isA<ConflictFailure>());
      expect(later.failureOrNull, isA<ConflictFailure>());
      expect(await harness.schedulingSnapshot(), before);
      expect(
        (await harness.context.runtimeState()).randomNumberSeed,
        seedBefore,
      );
    });

    test(
      'a practice read journals the sitting and keeps the schedule',
      () async {
        final Source source = (await harness.importSources(1)).single;
        final ElementRef ref = harness.refOf(source);
        final TopicState before = await harness.topicOf(source);

        final TopicState after = (await harness.reader.completePractice(
          CompleteTopicPractice(harness.operation(), ref: ref),
        )).unwrap();

        expect(after.toString(), before.toString());
        expect(
          (await harness.topicOf(source)).schedule.dueDay,
          before.schedule.dueDay,
        );
      },
    );
  });

  test(
    'the priority browser will not push cram-only work into the day',
    () async {
      final Source source = (await harness.importSources(1)).single;
      final ElementRef ref = harness.refOf(source);
      await markCramOnly(ref);

      final outcome = (await harness.browser.addToFinalDrill(
        AddToFinalDrill(
          harness.operation(),
          refs: <ElementRef>[ref],
          day: await harness.today(),
        ),
      )).unwrap();

      expect(outcome.skipped, 1);
      expect((await harness.context.runtimeState()).finalDrill, isEmpty);
    },
  );
}
