/// The scheduler skeleton: bookkeeping shared by the short-term and long-term
/// implementations, plus the review log they both emit.
library;

import 'algorithm.dart';
import 'convert.dart';
import 'error.dart';
import 'help.dart';
import 'models.dart';
import 'strategies/seed.dart';
import 'strategies/types.dart';

/// Common scheduling state: the card as it was, the card as it is being
/// reviewed, and the memoised outcome per grade.
abstract class AbstractScheduler implements IScheduler, SchedulerContext {
  /// Prepares a review of [card] at [now].
  AbstractScheduler(
    Card card,
    Object now,
    this.algorithm, [
    this.strategies,
  ])  : last = TypeConvert.card(card),
        current = TypeConvert.card(card),
        reviewTime = TypeConvert.time(now) {
    _init();
  }

  /// The card as it was before this review.
  final Card last;

  /// The working copy being scheduled.
  @override
  final Card current;

  /// The instant of the review.
  @override
  final DateTime reviewTime;

  /// The algorithm supplying the formulas.
  final FSRSAlgorithm algorithm;

  /// Caller-supplied strategy overrides, if any.
  final Map<StrategyMode, Object>? strategies;

  /// Memoised outcomes, so previewing all four grades runs the maths once.
  final Map<Rating, RecordLogItem> next = <Rating, RecordLogItem>{};

  /// Whole days since the previous review; 0 for a new card.
  int elapsedDays = 0;

  /// Rejects [Rating.manual] and anything outside the four grades.
  void checkGrade(Rating grade) {
    if (grade.value < 1 || grade.value > 4) {
      throw FSRSValidationError('Invalid grade "${grade.value}",expected 1-4');
    }
  }

  void _init() {
    final state = current.state;
    final lastReview = current.lastReview;
    var interval = 0; // A new card has no elapsed time.
    if (state != State.newState && lastReview != null) {
      interval = dateDiffInDays(lastReview, reviewTime);
    }
    current.lastReview = reviewTime;
    elapsedDays = interval;
    // Retained for parity; deprecated upstream.
    current.elapsedDays = interval;
    current.reps += 1;

    var seedStrategy = defaultInitSeedStrategy;
    final custom = strategies?[StrategyMode.seed];
    if (custom != null) {
      seedStrategy = custom as SeedStrategy;
    }
    algorithm.seed = seedStrategy(this);
  }

  @override
  Preview preview() => Preview(<Rating, RecordLogItem>{
        for (final grade in grades) grade: review(grade),
      });

  @override
  RecordLogItem review(Rating grade) {
    final state = last.state;
    checkGrade(grade);
    switch (state) {
      case State.newState:
        return newState(grade);
      case State.learning:
      case State.relearning:
        return learningState(grade);
      case State.review:
        return reviewState(grade);
    }
  }

  /// Schedules a card that has never been studied.
  RecordLogItem newState(Rating grade);

  /// Schedules a card inside the (re)learning steps.
  RecordLogItem learningState(Rating grade);

  /// Schedules a card on day-scale intervals.
  RecordLogItem reviewState(Rating grade);

  /// Builds the log for [rating] from the current working state.
  ///
  /// `due` records where the card was *coming from* — the previous review
  /// instant, or the due date for a card that has never been reviewed — which
  /// is what makes a rollback exact.
  ReviewLog buildLog(Rating rating) => ReviewLog(
        rating: rating,
        state: current.state,
        due: last.lastReview ?? last.due,
        stability: current.stability,
        difficulty: current.difficulty,
        elapsedDays: elapsedDays,
        lastElapsedDays: last.elapsedDays,
        scheduledDays: current.scheduledDays,
        learningSteps: current.learningSteps,
        review: reviewTime,
      );
}
