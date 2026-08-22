/// The public scheduler: card lifecycle operations on top of the FSRS-6
/// formulas.
library;

import 'algorithm.dart';
import 'convert.dart';
import 'default.dart';
import 'error.dart';
import 'help.dart';
import 'impl/basic_scheduler.dart';
import 'impl/long_term_scheduler.dart';
import 'models.dart';
import 'reschedule.dart';
import 'strategies/types.dart';

/// The FSRS scheduler.
///
/// Every operation is pure with respect to its inputs: the card passed in is
/// never mutated, and the card handed back is a new object. Which scheduler
/// runs — [BasicScheduler] or [LongTermScheduler] — follows `enableShortTerm`,
/// and is re-selected whenever that parameter changes.
class FSRS extends FSRSAlgorithm {
  /// Builds a scheduler from a parameter set (null takes every default).
  FSRS(super.params) {
    _scheduler = parameters.enableShortTerm
        ? basicSchedulerBuilder
        : longTermSchedulerBuilder;
  }

  final Map<StrategyMode, Object> _strategyHandler = <StrategyMode, Object>{};
  late SchedulerStrategy _scheduler;

  @override
  set enableShortTerm(bool value) {
    _scheduler = value ? basicSchedulerBuilder : longTermSchedulerBuilder;
    super.enableShortTerm = value;
  }

  /// Installs a strategy override for [mode].
  FSRS useStrategy(StrategyMode mode, Object handler) {
    _strategyHandler[mode] = handler;
    return this;
  }

  /// Removes the override for [mode], or all overrides when [mode] is null.
  FSRS clearStrategy([StrategyMode? mode]) {
    if (mode != null) {
      _strategyHandler.remove(mode);
    } else {
      _strategyHandler.clear();
    }
    return this;
  }

  IScheduler _getScheduler(Card card, Object now) {
    final override = _strategyHandler[StrategyMode.scheduler];
    final builder =
        override == null ? _scheduler : override as SchedulerStrategy;
    return builder(card, now, this, _strategyHandler);
  }

  /// The four outcomes of reviewing [card] at [now], one per grade.
  Preview repeat(Card card, Object now) => _getScheduler(card, now).preview();

  /// [repeat], with the result mapped through [afterHandler].
  R repeatWith<R>(Card card, Object now, R Function(Preview) afterHandler) =>
      afterHandler(repeat(card, now));

  /// The outcome of reviewing [card] at [now] with [grade].
  RecordLogItem next(Card card, Object now, Rating grade) {
    final instance = _getScheduler(card, now);
    final g = TypeConvert.rating(grade);
    if (g == Rating.manual) {
      throw FSRSValidationError('Cannot review a manual rating');
    }
    return instance.review(g);
  }

  /// [next], with the result mapped through [afterHandler].
  R nextWith<R>(
    Card card,
    Object now,
    Rating grade,
    R Function(RecordLogItem) afterHandler,
  ) =>
      afterHandler(next(card, now, grade));

  /// Probability of recalling [card] at [now], in `[0, 1]`.
  ///
  /// A new card has no memory to decay, so its retrievability is 0 rather than
  /// 1: nothing has been learned yet.
  double getRetrievability(Card card, [Object? now]) {
    final processedCard = TypeConvert.card(card);
    final at = now == null ? DateTime.now() : TypeConvert.time(now);
    if (processedCard.state == State.newState) return 0;
    final elapsed = dateDiff(at, processedCard.lastReview, DateDiffUnit.days);
    final t = elapsed > 0 ? elapsed : 0;
    return super.forgettingCurve(
      t.toDouble(),
      double.parse(processedCard.stability.toStringAsFixed(8)),
    );
  }

  /// [getRetrievability] rendered as a percentage with two decimals.
  String getRetrievabilityFormatted(Card card, [Object? now]) =>
      '${(getRetrievability(card, now) * 100).toStringAsFixed(2)}%';

  /// Undoes the review recorded in [log], restoring the card that preceded it.
  ///
  /// The restored card comes entirely from the log's snapshot, which is why the
  /// log records pre-review memory state; a lapse also gives back the lapse it
  /// consumed.
  Card rollback(Card card, ReviewLog log) {
    final processedCard = TypeConvert.card(card);
    final processedLog = TypeConvert.reviewLog(log);
    if (processedLog.rating == Rating.manual) {
      throw FSRSValidationError('Cannot rollback a manual rating');
    }
    final DateTime lastDue;
    final DateTime? lastReview;
    final int lastLapses;
    switch (processedLog.state) {
      case State.newState:
        lastDue = processedLog.due;
        lastReview = null;
        lastLapses = 0;
      case State.learning:
      case State.relearning:
      case State.review:
        lastDue = processedLog.review;
        lastReview = processedLog.due;
        lastLapses = processedCard.lapses -
            (processedLog.rating == Rating.again &&
                    processedLog.state == State.review
                ? 1
                : 0);
    }

    return processedCard.copy()
      ..due = lastDue
      ..stability = processedLog.stability
      ..difficulty = processedLog.difficulty
      ..elapsedDays = processedLog.lastElapsedDays
      ..scheduledDays = processedLog.scheduledDays
      ..reps = processedCard.reps > 1 ? processedCard.reps - 1 : 0
      ..lapses = lastLapses > 0 ? lastLapses : 0
      ..learningSteps = processedLog.learningSteps
      ..state = processedLog.state
      ..lastReview = lastReview;
  }

  /// [rollback], with the result mapped through [afterHandler].
  R rollbackWith<R>(Card card, ReviewLog log, R Function(Card) afterHandler) =>
      afterHandler(rollback(card, log));

  /// Resets [card] to new, as if it had never been studied.
  ///
  /// The result is logged as [Rating.manual]: forgetting is a calendar and
  /// memory-state change, never a repetition, and it must not feed a parameter
  /// optimizer.
  RecordLogItem forget(
    Card card,
    Object now, {
    bool resetCount = false,
  }) {
    final processedCard = TypeConvert.card(card);
    final at = TypeConvert.time(now);
    final scheduledDays = processedCard.state == State.newState
        ? 0
        : dateDiff(at, processedCard.due, DateDiffUnit.days);
    final forgetLog = ReviewLog(
      rating: Rating.manual,
      state: processedCard.state,
      due: processedCard.due,
      stability: processedCard.stability,
      difficulty: processedCard.difficulty,
      elapsedDays: 0,
      lastElapsedDays: processedCard.elapsedDays,
      scheduledDays: scheduledDays,
      learningSteps: processedCard.learningSteps,
      review: at,
    );
    final forgetCard = processedCard.copy()
      ..due = at
      ..stability = 0
      ..difficulty = 0
      ..elapsedDays = 0
      ..scheduledDays = 0
      ..reps = resetCount ? 0 : processedCard.reps
      ..lapses = resetCount ? 0 : processedCard.lapses
      ..learningSteps = 0
      ..state = State.newState
      ..lastReview = processedCard.lastReview;
    return RecordLogItem(card: forgetCard, log: forgetLog);
  }

  /// [forget], with the result mapped through [afterHandler].
  R forgetWith<R>(
    Card card,
    Object now,
    R Function(RecordLogItem) afterHandler, {
    bool resetCount = false,
  }) =>
      afterHandler(forget(card, now, resetCount: resetCount));

  /// Replays [reviews] under the current parameters.
  ///
  /// Returns the replayed collection plus the manual entry that moves
  /// [currentCard] onto the replayed schedule (null when it already agrees).
  IReschedule<RecordLogItem> reschedule(
    Card currentCard, {
    List<FSRSHistory> reviews = const <FSRSHistory>[],
    int Function(FSRSHistory, FSRSHistory)? reviewsOrderBy,
    bool skipManual = true,
    Object? now,
    bool updateMemoryState = false,
    Card? firstCard,
  }) =>
      rescheduleWith<RecordLogItem>(
        currentCard,
        (RecordLogItem item) => item,
        reviews: reviews,
        reviewsOrderBy: reviewsOrderBy,
        skipManual: skipManual,
        now: now,
        updateMemoryState: updateMemoryState,
        firstCard: firstCard,
      );

  /// [reschedule], with every entry mapped through [recordLogHandler].
  IReschedule<T> rescheduleWith<T>(
    Card currentCard,
    T Function(RecordLogItem) recordLogHandler, {
    List<FSRSHistory> reviews = const <FSRSHistory>[],
    int Function(FSRSHistory, FSRSHistory)? reviewsOrderBy,
    bool skipManual = true,
    Object? now,
    bool updateMemoryState = false,
    Card? firstCard,
  }) {
    final at = now == null ? DateTime.now() : TypeConvert.time(now);
    var history = List<FSRSHistory>.of(reviews);
    if (reviewsOrderBy != null) {
      history.sort(reviewsOrderBy);
    }
    if (skipManual) {
      history = history
          .where((FSRSHistory review) => review.rating != Rating.manual)
          .toList();
    }
    final rescheduleSvc = Reschedule(this);

    final collections = rescheduleSvc.reschedule(
      firstCard ?? createEmptyCard(),
      history,
    );
    final manualItem = rescheduleSvc.calculateManualRecord(
      TypeConvert.card(currentCard),
      at,
      collections.isEmpty ? null : collections.last,
      updateMemory: updateMemoryState,
    );

    return IReschedule<T>(
      collections: collections.map(recordLogHandler).toList(),
      rescheduleItem: manualItem == null ? null : recordLogHandler(manualItem),
    );
  }
}

/// Creates a scheduler, filling in every unspecified parameter.
FSRS fsrs({
  double? requestRetention,
  int? maximumInterval,
  List<double>? w,
  bool? enableFuzz,
  bool? enableShortTerm,
  List<String>? learningSteps,
  List<String>? relearningSteps,
}) =>
    FSRS(
      generatorParameters(
        requestRetention: requestRetention,
        maximumInterval: maximumInterval,
        w: w,
        enableFuzz: enableFuzz,
        enableShortTerm: enableShortTerm,
        learningSteps: learningSteps,
        relearningSteps: relearningSteps,
      ),
    );
