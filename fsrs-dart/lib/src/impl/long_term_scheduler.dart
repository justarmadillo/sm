/// The long-term scheduler: used when `enableShortTerm` is false, so that every
/// grade — including Again — is scheduled on a day scale with no learning steps.
library;

import '../abstract_scheduler.dart';
import '../algorithm.dart';
import '../convert.dart';
import '../help.dart';
import '../models.dart';
import '../strategies/types.dart';

/// Schedules purely in days, skipping the (re)learning steps.
class LongTermScheduler extends AbstractScheduler {
  /// Prepares a review of [card] at [now].
  LongTermScheduler(
    super.card,
    super.now,
    super.algorithm, [
    super.strategies,
  ]);

  @override
  RecordLogItem newState(Rating grade) {
    final exist = next[grade];
    if (exist != null) return exist;

    current.scheduledDays = 0;
    // Retained for parity; deprecated upstream.
    current.elapsedDays = 0;

    const firstInterval = 0.0;
    final nextAgain = _nextDs(firstInterval, Rating.again);
    final nextHard = _nextDs(firstInterval, Rating.hard);
    final nextGood = _nextDs(firstInterval, Rating.good);
    final nextEasy = _nextDs(firstInterval, Rating.easy);

    _nextInterval(nextAgain, nextHard, nextGood, nextEasy, firstInterval);
    _nextState(nextAgain, nextHard, nextGood, nextEasy);
    _updateNext(nextAgain, nextHard, nextGood, nextEasy);
    return next[grade]!;
  }

  /// A learning card is scheduled exactly like a review card here.
  ///
  /// See https://github.com/open-spaced-repetition/ts-fsrs/issues/98
  @override
  RecordLogItem learningState(Rating grade) => reviewState(grade);

  @override
  RecordLogItem reviewState(Rating grade) {
    final exist = next[grade];
    if (exist != null) return exist;

    final interval = elapsedDays.toDouble();
    final retrievability =
        algorithm.forgettingCurve(interval, current.stability);
    final nextAgain = _nextDs(interval, Rating.again, retrievability);
    final nextHard = _nextDs(interval, Rating.hard, retrievability);
    final nextGood = _nextDs(interval, Rating.good, retrievability);
    final nextEasy = _nextDs(interval, Rating.easy, retrievability);

    _nextInterval(nextAgain, nextHard, nextGood, nextEasy, interval);
    _nextState(nextAgain, nextHard, nextGood, nextEasy);
    nextAgain.lapses += 1;

    _updateNext(nextAgain, nextHard, nextGood, nextEasy);
    return next[grade]!;
  }

  Card _nextDs(double t, Rating g, [double? r]) {
    final nextState = algorithm.nextState(
      FSRSState(difficulty: current.difficulty, stability: current.stability),
      t,
      g,
      r,
    );

    final card = TypeConvert.card(current);
    card.difficulty = nextState.difficulty;
    card.stability = nextState.stability;
    return card;
  }

  /// Orders all four intervals so they strictly increase with the grade.
  void _nextInterval(
    Card nextAgain,
    Card nextHard,
    Card nextGood,
    Card nextEasy,
    double interval,
  ) {
    var againInterval = algorithm.nextInterval(nextAgain.stability, interval);
    var hardInterval = algorithm.nextInterval(nextHard.stability, interval);
    var goodInterval = algorithm.nextInterval(nextGood.stability, interval);
    var easyInterval = algorithm.nextInterval(nextEasy.stability, interval);

    againInterval = againInterval < hardInterval ? againInterval : hardInterval;
    hardInterval =
        hardInterval > againInterval + 1 ? hardInterval : againInterval + 1;
    goodInterval =
        goodInterval > hardInterval + 1 ? goodInterval : hardInterval + 1;
    easyInterval =
        easyInterval > goodInterval + 1 ? easyInterval : goodInterval + 1;

    nextAgain.scheduledDays = againInterval;
    nextAgain.due = dateScheduler(reviewTime, againInterval, isDay: true);

    nextHard.scheduledDays = hardInterval;
    nextHard.due = dateScheduler(reviewTime, hardInterval, isDay: true);

    nextGood.scheduledDays = goodInterval;
    nextGood.due = dateScheduler(reviewTime, goodInterval, isDay: true);

    nextEasy.scheduledDays = easyInterval;
    nextEasy.due = dateScheduler(reviewTime, easyInterval, isDay: true);
  }

  void _nextState(
    Card nextAgain,
    Card nextHard,
    Card nextGood,
    Card nextEasy,
  ) {
    nextAgain.state = State.review;
    nextAgain.learningSteps = 0;

    nextHard.state = State.review;
    nextHard.learningSteps = 0;

    nextGood.state = State.review;
    nextGood.learningSteps = 0;

    nextEasy.state = State.review;
    nextEasy.learningSteps = 0;
  }

  void _updateNext(
    Card nextAgain,
    Card nextHard,
    Card nextGood,
    Card nextEasy,
  ) {
    next[Rating.again] =
        RecordLogItem(card: nextAgain, log: buildLog(Rating.again));
    next[Rating.hard] =
        RecordLogItem(card: nextHard, log: buildLog(Rating.hard));
    next[Rating.good] =
        RecordLogItem(card: nextGood, log: buildLog(Rating.good));
    next[Rating.easy] =
        RecordLogItem(card: nextEasy, log: buildLog(Rating.easy));
  }
}

/// Builds a [LongTermScheduler]; used when short-term scheduling is off.
IScheduler longTermSchedulerBuilder(
  Card card,
  Object now,
  FSRSAlgorithm algorithm,
  Map<StrategyMode, Object> strategies,
) =>
    LongTermScheduler(card, now, algorithm, strategies);
