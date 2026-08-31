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
      expect(
        () => CardMemory(
          cardId: 'invalid-memory',
          state: CardLearningState.review,
          step: null,
          stability: double.nan,
          difficulty: 11,
          repetitionCount: 1,
          lapses: 0,
          lastReviewAtUtc: start,
          dueAtUtc: start,
          originalDueAtUtc: start,
          schedulerVersion: 'test',
          parametersVersion: 'test',
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
        intervals.add(state.memory.scheduledDays!.round());
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
      expect(
        reviewed.memory.dueAtUtc,
        calendar.startOfDayUtc(reviewed.schedule.dueDay),
      );
    });

    test('elapsed FSRS days follow the configured rollover', () {
      const StudyDayCalendar rolloverCalendar = StudyDayCalendar(
        zone: FixedOffsetZone.utc,
        rollover: Duration(hours: 4),
      );
      const CardScheduler scheduler = CardScheduler(
        calendar: rolloverCalendar,
        settings: CardSchedulerSettings(isFuzzingEnabled: false),
      );
      final DateTime firstReview = DateTime.utc(2026, 3, 5, 23, 30);
      final CardState learned = scheduler
          .review(
            newCard(due: firstReview),
            rating: CardRating.easy,
            reviewedAtUtc: firstReview,
            operationId: 'rollover-first',
          )
          .state;
      final DateTime afterUtcMidnight = DateTime.utc(2026, 3, 6, 3, 30);
      final DateTime beforeUtcMidnight = DateTime.utc(2026, 3, 5, 23, 31);

      final CardReviewTransition afterMidnight = scheduler.review(
        learned,
        rating: CardRating.good,
        reviewedAtUtc: afterUtcMidnight,
        operationId: 'rollover-after',
      );
      final CardReviewTransition beforeMidnight = scheduler.review(
        learned,
        rating: CardRating.good,
        reviewedAtUtc: beforeUtcMidnight,
        operationId: 'rollover-before',
      );

      expect(
        afterMidnight.state.memory.stability,
        beforeMidnight.state.memory.stability,
      );
      expect(
        scheduler.retrievability(learned.memory, atUtc: afterUtcMidnight),
        1,
      );
    });

    test('rescheduling preserves review history and the actual interval', () {
      const CardScheduler scheduler = CardScheduler(
        calendar: calendar,
        settings: CardSchedulerSettings(isFuzzingEnabled: false),
      );
      final CardState reviewed = scheduler
          .review(
            newCard(),
            rating: CardRating.easy,
            reviewedAtUtc: start,
            operationId: 'prepare-reschedule',
          )
          .state;
      final StudyDay lastReviewDay = calendar.dayOf(start);

      final CardState movedLater = scheduler.rescheduleElement(
        reviewed,
        targetDay: lastReviewDay.addDays(20),
        today: lastReviewDay,
      );
      expect(movedLater.memory.lastReviewAtUtc, start);
      expect(movedLater.memory.scheduledDays, 20);
      expect(
        calendar.dayOf(movedLater.memory.dueAtUtc),
        movedLater.schedule.dueDay,
      );

      final CardState movedBeforeLastReview = scheduler.rescheduleElement(
        reviewed,
        targetDay: lastReviewDay.addDays(-2),
        today: lastReviewDay,
      );
      expect(movedBeforeLastReview.memory.lastReviewAtUtc, start);
      expect(movedBeforeLastReview.memory.scheduledDays, 0);
      expect(
        calendar.dayOf(movedBeforeLastReview.memory.dueAtUtc),
        movedBeforeLastReview.schedule.dueDay,
      );
    });

    test('low-level rescheduling refuses to rewrite review history', () {
      final CardMemory memory = CardMemory(
        cardId: 'history-card',
        state: CardLearningState.review,
        step: null,
        stability: 10,
        difficulty: 5,
        repetitionCount: 2,
        lapses: 0,
        lastReviewAtUtc: start,
        dueAtUtc: start.add(const Duration(days: 10)),
        originalDueAtUtc: start.add(const Duration(days: 10)),
        schedulerVersion: kCardSchedulerVersion,
        parametersVersion: kCardParametersVersion,
        scheduledDays: 10,
      );

      expect(
        () => memory.lowLevelRescheduled(
          targetDueAtUtc: start.add(const Duration(days: 5)),
          actualIntervalDays: 5,
          adjustedLastReviewAtUtc: start.subtract(const Duration(days: 1)),
          didIntervalGrow: false,
        ),
        throwsArgumentError,
      );
    });

    test('settings rescheduling changes only eligible interday cards', () {
      final StudyDay lastDay = calendar.dayOf(start);
      final CardState before = CardState(
        schedule: ElementSchedule(
          ref: const ElementRef(id: 'settings-card', type: ElementType.card),
          priority: PriorityRank.middle,
          lifecycle: ElementLifecycle.active,
          dueDay: lastDay.addDays(100),
          originalDueDay: lastDay.addDays(100),
        ),
        memory: CardMemory(
          cardId: 'settings-card',
          state: CardLearningState.review,
          step: null,
          stability: 100,
          difficulty: 5,
          repetitionCount: 5,
          lapses: 0,
          lastReviewAtUtc: start,
          dueAtUtc: calendar.startOfDayUtc(lastDay.addDays(100)),
          originalDueAtUtc: calendar.startOfDayUtc(lastDay.addDays(100)),
          schedulerVersion: kCardSchedulerVersion,
          parametersVersion: kCardParametersVersion,
          scheduledDays: 100,
        ),
      );
      const CardScheduler scheduler = CardScheduler(
        calendar: calendar,
        settings: CardSchedulerSettings(
          desiredRetention: 0.99,
          maximumIntervalDays: 30,
          isFuzzingEnabled: false,
        ),
      );

      final CardState after = scheduler.rescheduleForSettings(
        before,
        today: lastDay.addDays(1),
      );

      expect(after.memory.lastReviewAtUtc, start);
      expect(after.memory.stability, before.memory.stability);
      expect(after.memory.difficulty, before.memory.difficulty);
      expect(after.memory.scheduledDays, lessThanOrEqualTo(30));
      expect(after.schedule.dueDay, calendar.dayOf(after.memory.dueAtUtc));
    });

    test('settings rescheduling never hides an overdue card', () {
      final StudyDay lastDay = calendar.dayOf(start);
      final CardState overdue = CardState(
        schedule: ElementSchedule(
          ref: const ElementRef(id: 'overdue-card', type: ElementType.card),
          priority: PriorityRank.middle,
          lifecycle: ElementLifecycle.active,
          dueDay: lastDay.addDays(1),
          originalDueDay: lastDay.addDays(1),
        ),
        memory: CardMemory(
          cardId: 'overdue-card',
          state: CardLearningState.review,
          step: null,
          stability: 100,
          difficulty: 5,
          repetitionCount: 2,
          lapses: 0,
          lastReviewAtUtc: start,
          dueAtUtc: calendar.startOfDayUtc(lastDay.addDays(1)),
          originalDueAtUtc: calendar.startOfDayUtc(lastDay.addDays(1)),
          schedulerVersion: kCardSchedulerVersion,
          parametersVersion: kCardParametersVersion,
          scheduledDays: 1,
        ),
      );
      const CardScheduler scheduler = CardScheduler(
        calendar: calendar,
        settings: CardSchedulerSettings(
          desiredRetention: 0.7,
          isFuzzingEnabled: false,
        ),
      );

      expect(
        scheduler.rescheduleForSettings(overdue, today: lastDay.addDays(10)),
        overdue,
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
