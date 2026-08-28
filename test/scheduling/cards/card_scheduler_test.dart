import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const StudyDayCalendar calendar = StudyDayCalendar(zone: FixedOffsetZone.utc);
  final DateTime start = DateTime.utc(2022, 11, 29, 12, 30);

  CardState newCard({String id = 'card-1', DateTime? due}) {
    final DateTime instant = due ?? start;
    final StudyDay day = calendar.dayOf(instant);
    return CardState(
      schedule: ElementSchedule(
        ref: ElementRef(id: id, type: ElementType.card),
        priority: PriorityRank.middle,
        lifecycle: ElementLifecycle.active,
        dueDay: day,
        originalDueDay: day,
      ),
      memory: CardMemory.newCard(cardId: id, dueAtUtc: instant),
    );
  }

  group('CardMemory', () {
    test('new cards are immediately due with uninitialized memory', () {
      final CardMemory memory = newCard().memory;
      expect(memory.state, CardLearningState.learning);
      expect(memory.step, 0);
      expect(memory.stability, isNull);
      expect(memory.difficulty, isNull);
      expect(memory.repetitionCount, 0);
      expect(memory.lapses, 0);
      expect(memory.isNew, isTrue);
      expect(memory.isDueAt(start), isTrue);
    });

    test('state snapshots round-trip byte-for-byte', () {
      final CardMemory memory = CardMemory(
        cardId: 'c-json',
        state: CardLearningState.relearning,
        step: 0,
        stability: 3.125,
        difficulty: 6.75,
        repetitionCount: 8,
        lapses: 2,
        lastReviewAtUtc: start,
        dueAtUtc: start.add(const Duration(minutes: 10)),
        originalDueAtUtc: start.add(const Duration(minutes: 10)),
        schedulerVersion: kCardSchedulerVersion,
        parametersVersion: kCardParametersVersion,
      );

      final String encoded = memory.toJson();
      final CardMemory decoded = CardMemory.fromJson(encoded);
      expect(decoded, memory);
      expect(decoded.toJson(), encoded);
    });

    test('rejects local instants and impossible learning state', () {
      expect(
        () => CardMemory.newCard(cardId: 'c', dueAtUtc: DateTime(2026)),
        throwsArgumentError,
      );
      expect(
        () => CardMemory(
          cardId: 'c',
          state: CardLearningState.review,
          step: 0,
          stability: 1,
          difficulty: 5,
          repetitionCount: 1,
          lapses: 0,
          lastReviewAtUtc: start,
          dueAtUtc: start,
          originalDueAtUtc: start,
          schedulerVersion: kCardSchedulerVersion,
          parametersVersion: kCardParametersVersion,
        ),
        throwsArgumentError,
      );
    });
  });

  group('CardScheduler', () {
    test('matches the fsrs_dart engine driven directly, grade for grade', () {
      // The same thirteen grades run straight through `fsrs_dart` produce these
      // intervals, so the expectation is the engine's answer and not this
      // adapter's. Fuzzing is off, as it is in the package's own vectors.
      const CardScheduler scheduler = CardScheduler(
        calendar: calendar,
        settings: CardSchedulerSettings(isFuzzingEnabled: false),
      );
      const List<CardRating> ratings = <CardRating>[
        CardRating.good,
        CardRating.good,
        CardRating.good,
        CardRating.good,
        CardRating.good,
        CardRating.good,
        CardRating.again,
        CardRating.again,
        CardRating.good,
        CardRating.good,
        CardRating.good,
        CardRating.good,
        CardRating.good,
      ];
      const List<int> expectedIntervals = <int>[
        0,
        2,
        11,
        46,
        163,
        498,
        0,
        0,
        2,
        4,
        7,
        12,
        21,
      ];

      var state = newCard();
      var reviewedAt = start;
      final List<int> intervals = <int>[];
      for (var i = 0; i < ratings.length; i++) {
        final CardReviewTransition transition = scheduler.review(
          state,
          rating: ratings[i],
          reviewedAtUtc: reviewedAt,
          operationId: 'reference-$i',
        );
        state = transition.state;
        intervals.add(state.memory.dueAtUtc.difference(reviewedAt).inDays);
        reviewedAt = state.memory.dueAtUtc;
      }

      expect(intervals, expectedIntervals);
    });

    test('learning, review, and relearning transitions keep exact history', () {
      const CardScheduler scheduler = CardScheduler(
        calendar: calendar,
        settings: CardSchedulerSettings(isFuzzingEnabled: false),
      );
      final CardState initial = newCard();
      final CardReviewTransition first = scheduler.review(
        initial,
        rating: CardRating.good,
        reviewedAtUtc: start,
        operationId: 'first',
        elapsedMs: 900,
      );
      expect(first.state.memory.state, CardLearningState.learning);
      expect(first.state.memory.step, 1);
      expect(
        first.state.memory.dueAtUtc,
        start.add(const Duration(minutes: 10)),
      );
      expect(first.record.preState, initial.memory);
      expect(first.record.postState, first.state.memory);
      expect(first.record.elapsedMs, 900);

      final CardReviewTransition graduated = scheduler.review(
        first.state,
        rating: CardRating.good,
        reviewedAtUtc: first.state.memory.dueAtUtc,
        operationId: 'graduate',
      );
      expect(graduated.state.memory.state, CardLearningState.review);
      expect(graduated.state.memory.step, isNull);

      final CardReviewTransition hasLapsed = scheduler.review(
        graduated.state,
        rating: CardRating.again,
        reviewedAtUtc: graduated.state.memory.dueAtUtc,
        operationId: 'lapse',
      );
      expect(hasLapsed.state.memory.state, CardLearningState.relearning);
      expect(hasLapsed.state.memory.step, 0);
      expect(hasLapsed.state.memory.lapses, 1);
      expect(hasLapsed.state.memory.repetitionCount, 3);
      expect(
        hasLapsed.state.memory.dueAtUtc,
        graduated.state.memory.dueAtUtc.add(const Duration(minutes: 10)),
      );
    });

    test('fuzz is stable across retries of one operation', () {
      const CardScheduler scheduler = CardScheduler(calendar: calendar);
      final CardReviewTransition first = scheduler.review(
        newCard(),
        rating: CardRating.good,
        reviewedAtUtc: start,
        operationId: 'prepare',
      );

      final CardReviewTransition a = scheduler.review(
        first.state,
        rating: CardRating.good,
        reviewedAtUtc: first.state.memory.dueAtUtc,
        operationId: 'same-operation',
      );
      final CardReviewTransition b = scheduler.review(
        first.state,
        rating: CardRating.good,
        reviewedAtUtc: first.state.memory.dueAtUtc,
        operationId: 'same-operation',
      );

      expect(a.state.memory.toJson(), b.state.memory.toJson());
      expect(a.record.postStateJson, b.record.postStateJson);
    });

    test('review synchronizes the generic due day with the exact due', () {
      const CardScheduler scheduler = CardScheduler(
        calendar: calendar,
        settings: CardSchedulerSettings(isFuzzingEnabled: false),
      );
      // There is no deferral overlay to clear: a card carries one due instant,
      // and the day on the shared schedule row is its projection. They must
      // never disagree, or the queue and the browser would show two dates.
      final CardState reviewed = scheduler
          .review(
            newCard(),
            rating: CardRating.easy,
            reviewedAtUtc: start.add(const Duration(days: 4)),
            operationId: 'sync-due-day',
          )
          .state;

      expect(
        reviewed.schedule.dueDay,
        calendar.dayOf(reviewed.memory.dueAtUtc),
      );
      expect(
        reviewed.schedule.originalDueDay,
        calendar.dayOf(reviewed.memory.originalDueAtUtc),
      );
    });

    test('rejects non-UTC, backwards, and inactive reviews', () {
      const CardScheduler scheduler = CardScheduler(calendar: calendar);
      expect(
        () => scheduler.review(
          newCard(),
          rating: CardRating.good,
          reviewedAtUtc: DateTime(2026),
          operationId: 'local',
        ),
        throwsArgumentError,
      );

      final CardReviewTransition first = scheduler.review(
        newCard(),
        rating: CardRating.good,
        reviewedAtUtc: start,
        operationId: 'first',
      );
      expect(
        () => scheduler.review(
          first.state,
          rating: CardRating.good,
          reviewedAtUtc: start,
          operationId: 'early',
        ),
        throwsStateError,
      );
      expect(
        () => scheduler.review(
          first.state,
          rating: CardRating.good,
          reviewedAtUtc: start.subtract(const Duration(seconds: 1)),
          operationId: 'backwards',
        ),
        throwsArgumentError,
      );

      final CardState active = newCard();
      final CardState dismissed = CardState(
        schedule: active.schedule.copyWith(
          lifecycle: ElementLifecycle.dismissed,
        ),
        memory: active.memory,
      );
      expect(
        () => scheduler.review(
          dismissed,
          rating: CardRating.good,
          reviewedAtUtc: start,
          operationId: 'inactive',
        ),
        throwsStateError,
      );
    });
  });
}
