/// The short-term scheduler: the default, which honours (re)learning steps.
library;

import '../abstract_scheduler.dart';
import '../algorithm.dart';
import '../convert.dart';
import '../help.dart';
import '../js_compat.dart';
import '../models.dart';
import '../strategies/learning_steps.dart';
import '../strategies/types.dart';

/// Schedules with intraday learning steps in front of day-scale intervals.
class BasicScheduler extends AbstractScheduler {
  /// Prepares a review of [card] at [now].
  BasicScheduler(
    super.card,
    super.now,
    super.algorithm, [
    super.strategies,
  ]) {
    final usesAnkiCompatibility =
        strategies?[StrategyMode.ankiCompatibility] == true;
    var strategy = usesAnkiCompatibility
        ? ankiLearningStepsStrategy
        : basicLearningStepsStrategy;
    final custom = strategies?[StrategyMode.learningSteps];
    if (custom != null) {
      strategy = custom as LearningStepsStrategy;
    }
    _learningStepsStrategy = strategy;
  }

  late final LearningStepsStrategy _learningStepsStrategy;

  ({num scheduledMinutes, int nextSteps}) _getLearningInfo(
    Card card,
    Rating grade,
  ) {
    final parameters = algorithm.parameters;
    final stepsStrategy = _learningStepsStrategy(
      parameters,
      card.state,
      card.learningSteps,
    );
    final entry = stepsStrategy[grade];
    final scheduledMinutes = _max(0, entry?.scheduledMinutes ?? 0);
    final nextSteps = entry?.nextStep ?? 0;
    return (
      scheduledMinutes: scheduledMinutes,
      nextSteps: nextSteps < 0 ? 0 : nextSteps,
    );
  }

  static num _max(num a, num b) => a > b ? a : b;

  /// Applies the step layout to [nextCard], or graduates it to [State.review].
  ///
  /// A step shorter than a day keeps the card intraday. A step of a day or more
  /// still uses the configured minutes, but the card is a review card again —
  /// which is why the day count is derived from the step rather than from
  /// stability. With no step left, the interval comes from the algorithm.
  void _applyLearningSteps(Card nextCard, Rating grade, State toState) {
    final info = _getLearningInfo(current, grade);
    final scheduledMinutes = info.scheduledMinutes;
    final nextSteps = info.nextSteps;
    if (scheduledMinutes > 0 && scheduledMinutes < 1440 /* one day */) {
      nextCard.learningSteps = nextSteps;
      nextCard.scheduledDays = 0;
      nextCard.state = toState;
      nextCard.due = dateScheduler(
        reviewTime,
        jsRound(scheduledMinutes.toDouble()),
      );
    } else {
      nextCard.state = State.review;
      if (scheduledMinutes >= 1440) {
        nextCard.learningSteps = nextSteps;
        nextCard.due = dateScheduler(
          reviewTime,
          jsRound(scheduledMinutes.toDouble()),
        );
        nextCard.scheduledDays = (scheduledMinutes / 1440).floor();
      } else {
        nextCard.learningSteps = 0;
        final interval =
            algorithm.nextInterval(nextCard.stability, elapsedDays);
        nextCard.scheduledDays = interval;
        nextCard.due = dateScheduler(reviewTime, interval, isDay: true);
      }
    }
  }

  @override
  RecordLogItem newState(Rating grade) {
    final exist = next[grade];
    if (exist != null) return exist;

    final nextCard = _nextDs(elapsedDays.toDouble(), grade);
    _applyLearningSteps(nextCard, grade, State.learning);
    final item = RecordLogItem(card: nextCard, log: buildLog(grade));
    next[grade] = item;
    return item;
  }

  @override
  RecordLogItem learningState(Rating grade) {
    final exist = next[grade];
    if (exist != null) return exist;

    final nextCard = _nextDs(elapsedDays.toDouble(), grade);
    _applyLearningSteps(
        nextCard, grade, last.state /* Learning or Relearning */);
    final item = RecordLogItem(card: nextCard, log: buildLog(grade));
    next[grade] = item;
    return item;
  }

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

    _nextInterval(nextHard, nextGood, nextEasy, interval);
    _nextState(nextHard, nextGood, nextEasy);
    _applyLearningSteps(nextAgain, Rating.again, State.relearning);
    nextAgain.lapses += 1;

    next[Rating.again] =
        RecordLogItem(card: nextAgain, log: buildLog(Rating.again));
    next[Rating.hard] =
        RecordLogItem(card: nextHard, log: buildLog(Rating.hard));
    next[Rating.good] =
        RecordLogItem(card: nextGood, log: buildLog(Rating.good));
    next[Rating.easy] =
        RecordLogItem(card: nextEasy, log: buildLog(Rating.easy));
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

  /// Orders passing intervals by grade.
  ///
  /// With Anki compatibility, intervals stay below the configured maximum and
  /// become equal at the ceiling when strict ordering is impossible.
  void _nextInterval(
    Card nextHard,
    Card nextGood,
    Card nextEasy,
    double interval,
  ) {
    final maximumInterval = algorithm.parameters.maximumInterval;
    var hardInterval = algorithm.nextInterval(
      nextHard.stability,
      interval,
      previousInterval: _previousIntervalForAnki,
    );
    var goodInterval = algorithm.nextInterval(
      nextGood.stability,
      interval,
      previousInterval: _previousIntervalForAnki,
    );
    hardInterval = hardInterval < goodInterval ? hardInterval : goodInterval;
    final usesAnkiCompatibility =
        strategies?[StrategyMode.ankiCompatibility] == true;
    final goodMinimum = usesAnkiCompatibility
        ? _min(hardInterval + 1, maximumInterval)
        : hardInterval + 1;
    goodInterval = goodInterval > goodMinimum ? goodInterval : goodMinimum;
    final easyIntervalRaw = algorithm.nextInterval(
      nextEasy.stability,
      interval,
      previousInterval: _previousIntervalForAnki,
    );
    final easyMinimum = usesAnkiCompatibility
        ? _min(goodInterval + 1, maximumInterval)
        : goodInterval + 1;
    final easyInterval =
        easyIntervalRaw > easyMinimum ? easyIntervalRaw : easyMinimum;

    nextHard.scheduledDays = hardInterval;
    nextHard.due = dateScheduler(reviewTime, hardInterval, isDay: true);
    nextGood.scheduledDays = goodInterval;
    nextGood.due = dateScheduler(reviewTime, goodInterval, isDay: true);
    nextEasy.scheduledDays = easyInterval;
    nextEasy.due = dateScheduler(reviewTime, easyInterval, isDay: true);
  }

  static int _min(int first, int second) => first < second ? first : second;

  int? get _previousIntervalForAnki =>
      strategies?[StrategyMode.ankiCompatibility] == true
          ? current.scheduledDays
          : null;

  void _nextState(Card nextHard, Card nextGood, Card nextEasy) {
    nextHard.state = State.review;
    nextHard.learningSteps = 0;

    nextGood.state = State.review;
    nextGood.learningSteps = 0;

    nextEasy.state = State.review;
    nextEasy.learningSteps = 0;
  }
}

/// Builds a [BasicScheduler]; the default [SchedulerStrategy].
IScheduler basicSchedulerBuilder(
  Card card,
  Object now,
  FSRSAlgorithm algorithm,
  Map<StrategyMode, Object> strategies,
) =>
    BasicScheduler(card, now, algorithm, strategies);
