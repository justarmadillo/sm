/// Behavioural tests ported from the ts-fsrs suite.
///
/// The golden vectors pin the numbers; these pin the contracts around them —
/// which inputs are rejected, what a strategy override is allowed to change,
/// and the invariants that motivated upstream bug fixes.
library;

import 'package:fsrs_dart/fsrs.dart';
import 'package:test/test.dart';

void main() {
  group('errors', () {
    test('carry a name and a default message', () {
      expect(FSRSError().message, 'FSRS Error');
      expect(FSRSError('Invalid value').name, 'FSRSError');
      expect(FSRSValidationError('Invalid value').name, 'FSRSValidationError');
      expect(
        FSRSOperationError('Invalid operation').name,
        'FSRSOperationError',
      );
      expect(FSRSValidationError('x'), isA<FSRSError>());
    });

    test('reject an unparseable date', () {
      expect(
        () => TypeConvert.time('invalid-date'),
        throwsA(
          isA<FSRSValidationError>().having(
            (FSRSValidationError e) => e.message,
            'message',
            'Invalid date:[invalid-date]',
          ),
        ),
      );
    });

    test('reject a parameter vector of the wrong length', () {
      expect(
        () => checkParameters(<double>[0.40255]),
        throwsA(
          isA<FSRSValidationError>().having(
            (FSRSValidationError e) => e.message,
            'message',
            startsWith('Invalid parameter length'),
          ),
        ),
      );
      expect(
        () => checkParameters(<double>[for (var i = 0; i < 21; i++) double.nan]),
        throwsA(isA<FSRSValidationError>()),
      );
      expect(checkParameters(List<double>.of(defaultW)), defaultW);
    });

    test('reject an impossible memory state', () {
      final algorithm = FSRSAlgorithm(generatorParameters());
      expect(
        () => algorithm.nextState(
          const FSRSState(difficulty: 0.5, stability: 0),
          0,
          Rating.good,
        ),
        throwsA(
          isA<FSRSValidationError>().having(
            (FSRSValidationError e) => e.message,
            'message',
            'Invalid memory state { difficulty: 0.5, stability: 0.0 }',
          ),
        ),
      );
      expect(
        () => algorithm.nextState(
          const FSRSState(difficulty: 5, stability: 5),
          -1,
          Rating.good,
        ),
        throwsA(isA<FSRSValidationError>()),
      );
    });

    test('reject a manual rating where a grade is required', () {
      final scheduler = fsrs();
      final card = createEmptyCard(DateTime.utc(2024));
      expect(
        () => scheduler.next(card, DateTime.utc(2024), Rating.manual),
        throwsA(
          isA<FSRSValidationError>().having(
            (FSRSValidationError e) => e.message,
            'message',
            'Cannot review a manual rating',
          ),
        ),
      );

      final forgotten = scheduler.forget(card, DateTime.utc(2024));
      expect(
        () => scheduler.rollback(forgotten.card, forgotten.log),
        throwsA(
          isA<FSRSValidationError>().having(
            (FSRSValidationError e) => e.message,
            'message',
            'Cannot rollback a manual rating',
          ),
        ),
      );
    });

    test('reject a retention outside (0, 1]', () {
      expect(
        () => FSRSAlgorithm(null).calculateIntervalModifier(0),
        throwsA(isA<FSRSValidationError>()),
      );
      expect(
        () => FSRSAlgorithm(null).calculateIntervalModifier(1.5),
        throwsA(isA<FSRSValidationError>()),
      );
      expect(FSRSAlgorithm(null).calculateIntervalModifier(1), 0);
    });

    test('reject a malformed learning step', () {
      expect(
        () => convertStepUnitToMinutes('10x'),
        throwsA(isA<FSRSValidationError>()),
      );
      expect(
        () => convertStepUnitToMinutes('xm'),
        throwsA(isA<FSRSValidationError>()),
      );
      expect(
        () => convertStepUnitToMinutes('-5m'),
        throwsA(isA<FSRSValidationError>()),
      );
      expect(convertStepUnitToMinutes('90m'), 90);
      expect(convertStepUnitToMinutes('2h'), 120);
      expect(convertStepUnitToMinutes('1d'), 1440);
    });
  });

  group('type conversion', () {
    test('accepts names, numbers and enum values', () {
      expect(TypeConvert.rating('again'), Rating.again);
      expect(TypeConvert.rating('EASY'), Rating.easy);
      expect(TypeConvert.rating(3), Rating.good);
      expect(TypeConvert.rating(Rating.hard), Rating.hard);
      expect(() => TypeConvert.rating('nope'), throwsA(isA<FSRSError>()));

      expect(TypeConvert.state('new'), State.newState);
      expect(TypeConvert.state('Relearning'), State.relearning);
      expect(TypeConvert.state(2), State.review);
      expect(() => TypeConvert.state('nope'), throwsA(isA<FSRSError>()));
    });

    test('reads a bare date as UTC midnight, like JavaScript', () {
      expect(
        TypeConvert.time('2022-11-29').toUtc().toIso8601String(),
        '2022-11-29T00:00:00.000Z',
      );
      expect(
        TypeConvert.time(1669725000000).toUtc().toIso8601String(),
        '2022-11-29T12:30:00.000Z',
      );
    });
  });

  group('models', () {
    test('round-trip through JSON', () {
      final card = Card(
        due: DateTime.utc(2024, 9, 13),
        stability: 21.79,
        difficulty: 5.05,
        elapsedDays: 3,
        scheduledDays: 22,
        learningSteps: 1,
        reps: 4,
        lapses: 1,
        state: State.review,
        lastReview: DateTime.utc(2024, 8, 22),
      );
      expect(Card.fromJson(card.toJson()), card);

      final log = ReviewLog(
        rating: Rating.good,
        state: State.review,
        due: DateTime.utc(2024, 8, 22),
        stability: 10.5,
        difficulty: 5.0,
        elapsedDays: 3,
        lastElapsedDays: 2,
        scheduledDays: 22,
        learningSteps: 0,
        review: DateTime.utc(2024, 9, 13),
      );
      expect(ReviewLog.fromJson(log.toJson()), log);
    });

    test('keep stable persisted encodings', () {
      expect(State.values.map((State s) => s.value), <int>[0, 1, 2, 3]);
      expect(Rating.values.map((Rating r) => r.value), <int>[0, 1, 2, 3, 4]);
      expect(grades, <Rating>[
        Rating.again,
        Rating.hard,
        Rating.good,
        Rating.easy,
      ]);
      expect(Rating.manual.isGrade, isFalse);
      expect(Rating.again.isGrade, isTrue);
    });

    test('an empty card is new and due now', () {
      final now = DateTime.utc(2022, 11, 29, 12, 30);
      final card = createEmptyCard(now);
      expect(card.state, State.newState);
      expect(card.due, now);
      expect(card.stability, 0);
      expect(card.difficulty, 0);
      expect(card.reps, 0);
      expect(card.lapses, 0);
      expect(card.learningSteps, 0);
      expect(card.lastReview, isNull);
    });
  });

  group('scheduling contracts', () {
    final now = DateTime.utc(2022, 11, 29, 12, 30);

    test('a new card has zero retrievability', () {
      final scheduler = fsrs();
      expect(scheduler.getRetrievability(createEmptyCard(now), now), 0);
      expect(
        scheduler.getRetrievabilityFormatted(createEmptyCard(now), now),
        '0.00%',
      );
    });

    test('preview yields the four grades in order', () {
      final scheduler = fsrs();
      final preview = scheduler.repeat(createEmptyCard(now), now);
      expect(
        preview.map((RecordLogItem item) => item.log.rating).toList(),
        grades,
      );
      // Memoised: previewing twice returns the same objects.
      expect(
        identical(preview[Rating.good].card, preview[Rating.good].card),
        isTrue,
      );
    });

    test('the input card is never mutated', () {
      final scheduler = fsrs();
      final card = createEmptyCard(now);
      final before = card.toJson();
      scheduler.repeat(card, now);
      scheduler.next(card, now, Rating.good);
      scheduler.forget(card, now);
      expect(card.toJson(), before);
    });

    test('rollback restores the card the review consumed', () {
      final scheduler = fsrs();
      var card = createEmptyCard(now);
      // Build up some history: graduate, then lapse.
      card = scheduler.next(card, now, Rating.easy).card;
      final beforeLapse = card.copy();
      final lapse = scheduler.next(card, card.due, Rating.again);
      expect(lapse.card.lapses, beforeLapse.lapses + 1);
      expect(lapse.card.state, State.relearning);

      final restored = scheduler.rollback(lapse.card, lapse.log);
      expect(restored.stability, beforeLapse.stability);
      expect(restored.difficulty, beforeLapse.difficulty);
      expect(restored.state, beforeLapse.state);
      expect(restored.lapses, beforeLapse.lapses);
      expect(restored.reps, beforeLapse.reps);
      expect(restored.due, beforeLapse.due);
      expect(restored.lastReview, beforeLapse.lastReview);
    });

    test('forget resets memory but keeps counts unless asked', () {
      final scheduler = fsrs();
      final reviewed = scheduler.next(createEmptyCard(now), now, Rating.good);
      final later = now.add(const Duration(days: 1));

      final kept = scheduler.forget(reviewed.card, later);
      expect(kept.card.state, State.newState);
      expect(kept.card.stability, 0);
      expect(kept.card.difficulty, 0);
      expect(kept.card.reps, reviewed.card.reps);
      expect(kept.log.rating, Rating.manual);

      final reset = scheduler.forget(reviewed.card, later, resetCount: true);
      expect(reset.card.reps, 0);
      expect(reset.card.lapses, 0);
    });
  });

  group('learning steps', () {
    // Fixes https://github.com/open-spaced-repetition/ts-fsrs/issues/311
    final scheduler = fsrs(
      enableFuzz: false,
      enableShortTerm: true,
      learningSteps: <String>['1m', '10m', '30m', '1h', '6h', '12h'],
      relearningSteps: <String>['10m', '1h', '6h'],
    );

    test('exhaust every learning step without skipping', () {
      const goodMinutes = <int>[10, 30, 60, 360, 720];
      final emptyCard = createEmptyCard(DateTime.utc(2024));
      var card = scheduler.next(emptyCard, emptyCard.due, Rating.again).card;
      expect(card.state, State.learning);
      expect(card.learningSteps, 0);

      for (var i = 0; i < goodMinutes.length; i++) {
        final prevDue = card.due;
        card = scheduler.next(card, card.due, Rating.good).card;
        expect(card.learningSteps, i + 1);
        expect(card.state, State.learning);
        expect(
          card.due.difference(prevDue).inMinutes,
          goodMinutes[i],
        );
      }

      expect(card.learningSteps, 5);
      final graduated = scheduler.next(card, card.due, Rating.good).card;
      expect(graduated.state, State.review);
      expect(graduated.learningSteps, 0);
    });

    test('exhaust every relearning step without skipping', () {
      const goodMinutes = <int>[60, 360];
      final emptyCard = createEmptyCard(DateTime.utc(2024));
      var card = scheduler.next(emptyCard, emptyCard.due, Rating.easy).card;
      expect(card.state, State.review);

      card = scheduler.next(card, card.due, Rating.again).card;
      expect(card.state, State.relearning);
      expect(card.learningSteps, 0);

      for (var i = 0; i < goodMinutes.length; i++) {
        final prevDue = card.due;
        card = scheduler.next(card, card.due, Rating.good).card;
        expect(card.learningSteps, i + 1);
        expect(card.state, State.relearning);
        expect(card.due.difference(prevDue).inMinutes, goodMinutes[i]);
      }

      expect(card.learningSteps, 2);
      final graduated = scheduler.next(card, card.due, Rating.good).card;
      expect(graduated.state, State.review);
      expect(graduated.learningSteps, 0);
    });

    test('with no steps configured every grade is day-scale', () {
      final noSteps = fsrs(
        learningSteps: <String>[],
        relearningSteps: <String>[],
      );
      final card = createEmptyCard(DateTime.utc(2024));
      for (final grade in grades) {
        final result = noSteps.next(card, card.due, grade);
        expect(result.card.state, State.review, reason: '$grade');
        expect(result.card.scheduledDays, greaterThanOrEqualTo(1));
      }
    });
  });

  group('parameters', () {
    test('short vectors are migrated to 21 weights', () {
      expect(migrateParameters(null).length, 21);
      expect(migrateParameters(<double>[1, 2, 3]), defaultW);
      expect(
        migrateParameters(List<double>.of(defaultW)).length,
        21,
      );
    });

    test('assignment re-derives the interval modifier', () {
      final scheduler = fsrs();
      final before = scheduler.intervalModifier;
      scheduler.requestRetention = 0.95;
      expect(scheduler.intervalModifier, isNot(before));
      expect(
        scheduler.intervalModifier,
        FSRSAlgorithm(generatorParameters(requestRetention: 0.95))
            .intervalModifier,
      );
    });

    test('toggling short-term scheduling swaps the scheduler', () {
      final scheduler = fsrs();
      final card = createEmptyCard(DateTime.utc(2024));
      expect(
        scheduler.next(card, card.due, Rating.again).card.state,
        State.learning,
      );

      scheduler.enableShortTerm = false;
      final longTerm = scheduler.next(card, card.due, Rating.again).card;
      expect(longTerm.state, State.review);
      expect(longTerm.scheduledDays, greaterThanOrEqualTo(1));

      scheduler.enableShortTerm = true;
      expect(
        scheduler.next(card, card.due, Rating.again).card.state,
        State.learning,
      );
    });

    test('a full replacement resets unspecified fields to defaults', () {
      final scheduler = fsrs(requestRetention: 0.95, maximumInterval: 100);
      scheduler.updateParameters(maximumInterval: 200);
      expect(scheduler.parameters.maximumInterval, 200);
      expect(
        scheduler.parameters.requestRetention,
        defaultRequestRetention,
        reason: 'upstream treats assignment as replacement, not patch',
      );
    });
  });

  group('strategies', () {
    final now = DateTime.utc(2022, 11, 29, 12, 30);

    test('a custom seed changes the fuzzed interval', () {
      final card = Card(
        due: now,
        stability: 100,
        difficulty: 5,
        state: State.review,
        reps: 10,
        lastReview: now.subtract(const Duration(days: 100)),
      );

      final fixed = fsrs(enableFuzz: true)
        ..useStrategy(
          StrategyMode.seed,
          (SchedulerContext context) => 'constant-seed',
        );
      final other = fsrs(enableFuzz: true)
        ..useStrategy(
          StrategyMode.seed,
          (SchedulerContext context) => 'another-seed',
        );

      final a = fixed.next(card, now, Rating.good).card.scheduledDays;
      final b = fixed.next(card, now, Rating.good).card.scheduledDays;
      final c = other.next(card, now, Rating.good).card.scheduledDays;
      expect(a, b, reason: 'the same seed must give the same interval');
      expect(a, isNot(c));

      fixed.clearStrategy(StrategyMode.seed);
      expect(fixed.next(card, now, Rating.good).card.scheduledDays, isNotNull);
    });

    test('a card-id seed keeps two identical cards apart', () {
      final strategy = genSeedStrategyWithCardId((Card card) => 555);
      final scheduler = fsrs(enableFuzz: true)
        ..useStrategy(StrategyMode.seed, strategy);
      final card = Card(
        due: now,
        stability: 100,
        difficulty: 5,
        state: State.review,
        reps: 10,
        lastReview: now.subtract(const Duration(days: 100)),
      );
      final first = scheduler.next(card, now, Rating.good).card.scheduledDays;

      final other = fsrs(enableFuzz: true)
        ..useStrategy(
          StrategyMode.seed,
          genSeedStrategyWithCardId((Card card) => 999),
        );
      expect(
        other.next(card, now, Rating.good).card.scheduledDays,
        isNot(first),
      );
    });

    test('a custom learning-step layout is honoured', () {
      final scheduler = fsrs()
        ..useStrategy(
          StrategyMode.learningSteps,
          (FSRSParameters params, State state, int curStep) =>
              <Rating, LearningStepResult>{
            Rating.again: const LearningStepResult(
              scheduledMinutes: 7,
              nextStep: 0,
            ),
          },
        );
      final card = createEmptyCard(now);
      final again = scheduler.next(card, now, Rating.again).card;
      expect(again.due.difference(now).inMinutes, 7);
      expect(again.state, State.learning);
    });

    test('a custom scheduler replaces the implementation', () {
      final scheduler = fsrs()
        ..useStrategy(
          StrategyMode.scheduler,
          (
            Card card,
            Object at,
            FSRSAlgorithm algorithm,
            Map<StrategyMode, Object> strategies,
          ) =>
              LongTermScheduler(card, at, algorithm, strategies),
        );
      final card = createEmptyCard(now);
      expect(scheduler.next(card, now, Rating.again).card.state, State.review);

      scheduler.clearStrategy();
      expect(
        scheduler.next(card, now, Rating.again).card.state,
        State.learning,
      );
    });
  });

  group('reschedule', () {
    test('replays a history and produces a manual move', () {
      final scheduler = fsrs();
      final reviews = <FSRSHistory>[
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 13)),
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 13)),
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 17)),
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 28)),
      ];
      final result = scheduler.reschedule(
        createEmptyCard(DateTime.utc(2024, 9, 13)),
        reviews: reviews,
        now: DateTime.utc(2024, 10, 25),
        firstCard: createEmptyCard(DateTime.utc(2024, 9, 13)),
      );
      expect(result.collections, hasLength(4));
      expect(result.rescheduleItem, isNotNull);
      expect(result.rescheduleItem!.log.rating, Rating.manual);
      expect(
        result.rescheduleItem!.card.due,
        result.collections.last.card.due,
      );
    });

    test('skips manual entries when asked', () {
      final scheduler = fsrs();
      final reviews = <FSRSHistory>[
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 13)),
        FSRSHistory(
          rating: Rating.manual,
          review: DateTime.utc(2024, 9, 14),
          due: DateTime.utc(2024, 9, 20),
          state: State.review,
        ),
      ];
      final kept = scheduler.reschedule(
        createEmptyCard(DateTime.utc(2024, 9, 13)),
        reviews: reviews,
        skipManual: false,
        now: DateTime.utc(2024, 10, 25),
        firstCard: createEmptyCard(DateTime.utc(2024, 9, 13)),
      );
      expect(kept.collections, hasLength(2));

      final skipped = scheduler.reschedule(
        createEmptyCard(DateTime.utc(2024, 9, 13)),
        reviews: reviews,
        now: DateTime.utc(2024, 10, 25),
        firstCard: createEmptyCard(DateTime.utc(2024, 9, 13)),
      );
      expect(skipped.collections, hasLength(1));
    });

    test('a manual entry without a due date is rejected', () {
      final scheduler = fsrs();
      expect(
        () => scheduler.reschedule(
          createEmptyCard(DateTime.utc(2024, 9, 13)),
          reviews: <FSRSHistory>[
            FSRSHistory(
              rating: Rating.manual,
              review: DateTime.utc(2024, 9, 14),
              state: State.review,
            ),
          ],
          skipManual: false,
          now: DateTime.utc(2024, 10, 25),
        ),
        throwsA(isA<FSRSValidationError>()),
      );
    });

    test('review order can be imposed by the caller', () {
      final scheduler = fsrs();
      final reviews = <FSRSHistory>[
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 28)),
        FSRSHistory(rating: Rating.good, review: DateTime.utc(2024, 9, 13)),
      ];
      final result = scheduler.reschedule(
        createEmptyCard(DateTime.utc(2024, 9, 13)),
        reviews: reviews,
        reviewsOrderBy: (FSRSHistory a, FSRSHistory b) =>
            (a.review as DateTime).compareTo(b.review as DateTime),
        now: DateTime.utc(2024, 10, 25),
        firstCard: createEmptyCard(DateTime.utc(2024, 9, 13)),
      );
      expect(
        result.collections.first.log.review,
        DateTime.utc(2024, 9, 13),
      );
    });
  });

  group('elapsed days', () {
    test('are counted between UTC calendar dates, not durations', () {
      expect(
        dateDiffInDays(
          DateTime.utc(2022, 11, 29, 23, 59, 59),
          DateTime.utc(2022, 11, 30, 0, 0, 1),
        ),
        1,
        reason: 'two seconds apart, but a day apart on the calendar',
      );
      expect(
        dateDiffInDays(
          DateTime.utc(2022, 11, 29, 0, 0, 1),
          DateTime.utc(2022, 11, 29, 23, 59, 59),
        ),
        0,
      );
    });

    test('a same-day review is a short-term review', () {
      final scheduler = fsrs();
      final now = DateTime.utc(2022, 11, 29, 12, 30);
      final graduated =
          scheduler.next(createEmptyCard(now), now, Rating.easy).card;
      final sameDay = scheduler.next(
        graduated,
        now.add(const Duration(hours: 2)),
        Rating.good,
      );
      expect(sameDay.log.elapsedDays, 0);
      expect(
        sameDay.card.stability,
        FSRSAlgorithm(null)
            .nextShortTermStability(graduated.stability, Rating.good),
      );
    });
  });
}
