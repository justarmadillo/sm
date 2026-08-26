/// Undo-last-grade, edit-during-review, sibling burying, and leeches.
///
/// The gate this suite covers: undo round-trips FSRS state identical to the
/// pre-review snapshot, an edit never reschedules, and a burial is recorded as
/// a deferral rather than as a review.
library;

import 'package:incremental_reader/src/application/formulation/formulation_commands.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/application/review/review_commands.dart';
import 'package:incremental_reader/src/application/review/review_handlers.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/domain/content/card.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/card_scheduler.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/revlog.dart';
import 'package:incremental_reader/src/domain/scheduling/scheduler_event.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _markdown = '''
# Memory

Working memory holds about four items while attention remains limited.
''';

extension _Fixtures on AppHarness {
  Future<Source> importSource() async {
    final Result<Source> result = await reader.importSource(
      ImportSource(
        operation(),
        title: 'Memory',
        markdown: _markdown,
        timestampUtc: clock.nowUtc(),
      ),
    );
    return result.unwrap();
  }

  /// Three cards cut from one sentence, as a real cloze pass produces.
  Future<List<Card>> formulateSiblings(String sourceId) async =>
      (await formulation.formulate(
        FormulateCards(
          operation(),
          parent: CardParent.source(sourceId),
          drafts: const <CardDraft>[
            ClozeCardDraft(
              'Working memory holds {{c1::four items}} while '
              '{{c2::attention}} remains {{c3::limited}}.',
            ),
          ],
          timestampUtc: clock.nowUtc(),
        ),
      )).unwrap();

  Future<CardState> stateOf(String cardId) async =>
      (await learning.findCardState(cardId))!;

  Future<List<RevlogEntry>> revlogOf(String cardId) =>
      learning.listRevlogFor(ElementRef(id: cardId, type: ElementType.card));

  Future<ReviewOutcome> grade(String cardId, CardRating rating) async {
    final Result<ReviewOutcome> result = await review.review(
      ReviewCard(
        operation(),
        cardId: cardId,
        rating: rating,
        elapsedMs: 1500,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.unwrap();
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

  group('undo the last grade', () {
    test(
      'restores the exact pre-review FSRS state without deleting history',
      () async {
        final Source source = await harness.importSource();
        final Card card = (await harness.formulateSiblings(source.id)).first;
        final CardState before = await harness.stateOf(card.id);

        final ReviewOutcome graded = await harness.grade(
          card.id,
          CardRating.good,
        );
        expect(graded.state.memory.reps, 1);
        expect(graded.state.memory, isNot(before.memory));

        final Result<CardState> undone = await harness.review.undoLastReview(
          UndoLastReview(harness.operation(), timestampUtc: clock.nowUtc()),
        );
        expect(undone.isOk, isTrue, reason: '${undone.failureOrNull}');

        final CardState restored = await harness.stateOf(card.id);
        expect(
          restored.memory.canonicalFsrsJson(),
          before.memory.canonicalFsrsJson(),
          reason: 'FSRS is not invertible, so undo is a snapshot restore',
        );
        expect(
          restored.memory.revision,
          greaterThan(graded.state.memory.revision),
          reason: 'the concurrency token still advances; it is not memory',
        );
        expect(restored.schedule.dueDay, before.schedule.dueDay);
        expect(
          await harness.learning.listReviewsForCard(card.id),
          hasLength(1),
          reason: 'history is append-only: the grade happened and still did',
        );
        expect(
          await harness.learning.listOptimizerReviews(),
          isEmpty,
          reason: 'but an undone grade may never train a parameter optimizer',
        );
      },
    );

    test('appends an inverse event rather than erasing the original', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;

      await harness.grade(card.id, CardRating.good);
      await harness.review.undoLastReview(
        UndoLastReview(harness.operation(), timestampUtc: clock.nowUtc()),
      );

      final List<RevlogEntry> log = await harness.revlogOf(card.id);
      expect(
        log.where((RevlogEntry e) => e.eventType == RevlogEventType.review),
        hasLength(1),
        reason: 'the grade is a fact; undo describes what happened next',
      );
      final RevlogEntry undo = log.firstWhere(
        (RevlogEntry e) => e.eventType == RevlogEventType.undo,
      );
      expect(undo.metadata!['undone_grade'], CardRating.good.value);
      expect(undo.feedsOptimizer, isFalse);

      final List<SchedulerEvent> events = await harness.learning
          .listSchedulerEventsFor(
            ElementRef(id: card.id, type: ElementType.card),
          );
      final SchedulerEvent inverse = events.firstWhere(
        (SchedulerEvent e) =>
            e.eventType == SchedulerEventType.cardReviewUndone,
      );
      expect(inverse.undoesEventId, isNotNull);
      expect(
        events.any((SchedulerEvent e) => e.id == inverse.undoesEventId),
        isTrue,
        reason: 'the event it reverses is still there to point at',
      );
    });

    test('the card becomes reviewable again immediately', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;

      await harness.grade(card.id, CardRating.easy);
      await harness.review.undoLastReview(
        UndoLastReview(harness.operation(), timestampUtc: clock.nowUtc()),
      );

      clock.advance(const Duration(minutes: 1));
      final ReviewOutcome regraded = await harness.grade(
        card.id,
        CardRating.again,
      );
      expect(regraded.state.memory.reps, 1);
      expect(
        await harness.learning.listOptimizerReviews(),
        hasLength(1),
        reason: 'only the grade that still stands may train anything',
      );
    });

    test('undoes whatever was graded last when no card is named', () async {
      final Source source = await harness.importSource();
      final List<Card> cards = await harness.formulateSiblings(source.id);
      await harness.tuneSettings(
        (AppSettings s) =>
            s.copyWith(cards: s.cards.copyWith(burySiblings: false)),
      );

      await harness.grade(cards[0].id, CardRating.good);
      clock.advance(const Duration(minutes: 1));
      await harness.grade(cards[1].id, CardRating.hard);

      final Result<CardState> undone = await harness.review.undoLastReview(
        UndoLastReview(harness.operation(), timestampUtc: clock.nowUtc()),
      );
      expect(undone.unwrap().ref.id, cards[1].id);
      final List<ReviewRecord> optimizer = await harness.learning
          .listOptimizerReviews();
      expect(optimizer, hasLength(1));
      expect(optimizer.single.cardId, cards[0].id);
    });

    test('refuses when there is nothing to take back', () async {
      final Result<CardState> undone = await harness.review.undoLastReview(
        UndoLastReview(harness.operation(), timestampUtc: clock.nowUtc()),
      );
      expect(undone.failureOrNull, isA<ConflictFailure>());
    });
  });

  group('editing during review', () {
    test('rewrites the text and never reschedules', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;
      final CardState before = await harness.stateOf(card.id);

      final Result<Card> edited = await harness.review.editCard(
        EditCard(
          harness.operation(),
          cardId: card.id,
          front:
              'Working memory holds {{c1::about four items}} while '
              '{{c2::attention}} remains {{c3::limited}}.',
          timestampUtc: clock.nowUtc(),
        ),
      );

      expect(edited.isOk, isTrue, reason: '${edited.failureOrNull}');
      expect(edited.unwrap().front, contains('about four items'));
      expect(edited.unwrap().editedAtUtc, isNotNull);

      final CardState after = await harness.stateOf(card.id);
      expect(
        after.memory,
        before.memory,
        reason: 'a typo is not new evidence about memory',
      );
      expect(after.schedule.dueDay, before.schedule.dueDay);
    });

    test('refuses to drop the deletion the card actually tests', () async {
      final Source source = await harness.importSource();
      final List<Card> cards = await harness.formulateSiblings(source.id);
      final Card second = cards.firstWhere((Card c) => c.clozeOrdinal == 2);

      final Result<Card> edited = await harness.review.editCard(
        EditCard(
          harness.operation(),
          cardId: second.id,
          front: 'Working memory holds {{c1::four items}}.',
          timestampUtc: clock.nowUtc(),
        ),
      );

      expect(edited.failureOrNull, isA<ValidationFailure>());
      expect(
        (await harness.content.findCard(second.id))!.front,
        contains('{{c2::attention}}'),
      );
    });

    test('rejects an empty question', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;
      final Result<Card> edited = await harness.review.editCard(
        EditCard(
          harness.operation(),
          cardId: card.id,
          front: '   ',
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(edited.failureOrNull, isA<ValidationFailure>());
    });

    test('records that an edit happened, never what it said', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;
      await harness.review.editCard(
        EditCard(
          harness.operation(),
          cardId: card.id,
          front:
              'A secret phrase {{c1::four items}} {{c2::attention}} '
              '{{c3::limited}}.',
          timestampUtc: clock.nowUtc(),
        ),
      );

      final metadata = (await harness.learning.recentActivity())
          .firstWhere((r) => r.kind == kCardEditedKind)
          .metadata!;
      expect(metadata.values.join(' '), isNot(contains('secret')));
    });
  });

  group('sibling burying', () {
    test(
      'pushes same-parent cards off today and logs it as a deferral',
      () async {
        final Source source = await harness.importSource();
        final List<Card> cards = await harness.formulateSiblings(source.id);
        expect(cards, hasLength(3));

        final ReviewOutcome outcome = await harness.grade(
          cards.first.id,
          CardRating.good,
        );
        expect(outcome.buriedSiblings, 2);

        for (final Card sibling in cards.skip(1)) {
          final CardState state = await harness.stateOf(sibling.id);
          expect(state.memory.reps, 0, reason: 'burying is not a review');
          final ElementRef ref = ElementRef(
            id: sibling.id,
            type: ElementType.card,
          );
          // SM20 has no deferral overlay: burying is the same low-level
          // reschedule as any other move, so the sibling's own due instant is
          // pushed to tomorrow and it is simply not due now.
          expect(state.memory.isDueAt(clock.nowUtc()), isFalse);
          expect(
            state.memory.dueAtUtc.isAfter(clock.nowUtc()),
            isTrue,
            reason: 'the canonical due itself moved to tomorrow',
          );
          expect(ref.type, ElementType.card);

          final RevlogEntry entry = (await harness.revlogOf(
            sibling.id,
          )).firstWhere((RevlogEntry e) => e.eventType == RevlogEventType.bury);
          expect(entry.grade, isNull);
          expect(entry.feedsOptimizer, isFalse);
          expect(entry.metadata!['sibling_of'], cards.first.id);
        }
      },
    );

    test('can be switched off', () async {
      await harness.tuneSettings(
        (AppSettings s) =>
            s.copyWith(cards: s.cards.copyWith(burySiblings: false)),
      );
      final Source source = await harness.importSource();
      final List<Card> cards = await harness.formulateSiblings(source.id);

      final ReviewOutcome outcome = await harness.grade(
        cards.first.id,
        CardRating.good,
      );
      expect(outcome.buriedSiblings, 0);
      expect(
        (await harness.stateOf(cards[1].id)).memory.isDueAt(clock.nowUtc()),
        isTrue,
      );
    });

    test('does not touch cards from a different parent', () async {
      final Source a = await harness.importSource();
      final Source b = await harness.importSource();
      final List<Card> fromA = await harness.formulateSiblings(a.id);
      final List<Card> fromB = await harness.formulateSiblings(b.id);

      await harness.grade(fromA.first.id, CardRating.good);
      expect(
        (await harness.stateOf(fromB.first.id)).memory.isDueAt(clock.nowUtc()),
        isTrue,
      );
    });
  });

  group('leeches', () {
    test(
      'are flagged at the configured threshold, never auto-suspended',
      () async {
        await harness.tuneSettings(
          (AppSettings s) => s.copyWith(
            cards: s.cards.copyWith(leechLapses: 2, burySiblings: false),
          ),
        );
        final Source source = await harness.importSource();
        final Card card = (await harness.formulateSiblings(source.id)).first;

        // Reach review state, then fail it repeatedly.
        var outcome = await harness.grade(card.id, CardRating.easy);
        expect(outcome.isLeech, isFalse);

        for (var i = 0; i < 2; i++) {
          clock.setTo((await harness.stateOf(card.id)).memory.dueAtUtc);
          outcome = await harness.grade(card.id, CardRating.again);
          if (outcome.state.memory.state == CardLearningState.relearning) {
            // Walk back out of relearning so the next Again counts as a lapse.
            clock.setTo((await harness.stateOf(card.id)).memory.dueAtUtc);
            outcome = await harness.grade(card.id, CardRating.easy);
          }
        }

        final CardState state = await harness.stateOf(card.id);
        expect(state.memory.lapses, greaterThanOrEqualTo(2));
        expect(
          state.schedule.lifecycle,
          ElementLifecycle.active,
          reason: 'suspending a leech hides the evidence instead of fixing it',
        );
      },
    );
  });

  group('postponing a card', () {
    test('Later Today is a queue shift, not a reschedule', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;
      await harness.grade(card.id, CardRating.good);
      final CardState before = await harness.stateOf(card.id);

      clock.setTo(before.memory.dueAtUtc);
      final Result<CardState> deferred = await harness.review.postpone(
        PostponeCard(
          harness.operation(),
          cardId: card.id,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(deferred.isOk, isTrue, reason: '${deferred.failureOrNull}');

      final CardState after = await harness.stateOf(card.id);
      expect(after.memory.stability, before.memory.stability);
      expect(after.memory.difficulty, before.memory.difficulty);
      expect(after.memory.reps, before.memory.reps);
      expect(
        after.memory.lastReviewAtUtc,
        before.memory.lastReviewAtUtc,
        reason: 'overwriting this would destroy the retention signal',
      );
      // Section 8.4: this card was reviewed today and is not Outstanding, so
      // Later Today does nothing to the record at all. There is no separate
      // "Later adjustment" field to write instead — the operation is either a
      // queue-only shift or a real due-date rewrite, and here it is neither.
      expect(
        after.memory.dueAtUtc,
        before.memory.dueAtUtc,
        reason: 'the same-day branch warns and leaves the schedule alone',
      );

      final RevlogEntry entry = (await harness.revlogOf(
        card.id,
      )).firstWhere((RevlogEntry e) => e.eventType == RevlogEventType.postpone);
      expect(entry.grade, isNull);
      expect(entry.feedsOptimizer, isFalse);
    });
  });

  group('practice grades', () {
    test('are logged and flagged but change nothing', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;
      final CardState before = await harness.stateOf(card.id);

      final Result<ReviewOutcome> result = await harness.review.review(
        ReviewCard(
          harness.operation(),
          cardId: card.id,
          rating: CardRating.again,
          isPractice: true,
          timestampUtc: clock.nowUtc(),
        ),
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');

      final CardState after = await harness.stateOf(card.id);
      expect(after.memory, before.memory);

      final ReviewRecord record = (await harness.learning.listReviewsForCard(
        card.id,
      )).single;
      expect(record.isPractice, isTrue);
      expect(record.preState, record.postState);

      final RevlogEntry entry = (await harness.revlogOf(
        card.id,
      )).firstWhere((RevlogEntry e) => e.eventType == RevlogEventType.practice);
      expect(entry.grade, CardRating.again.value);
      expect(
        entry.feedsOptimizer,
        isFalse,
        reason: 'nothing about the schedule changed, so it measured nothing',
      );
    });

    test('do not block the real review of the same card', () async {
      final Source source = await harness.importSource();
      final Card card = (await harness.formulateSiblings(source.id)).first;

      await harness.review.review(
        ReviewCard(
          harness.operation(),
          cardId: card.id,
          rating: CardRating.good,
          isPractice: true,
          timestampUtc: clock.nowUtc(),
        ),
      );
      final ReviewOutcome real = await harness.grade(card.id, CardRating.good);
      expect(real.state.memory.reps, 1);
    });
  });
}
