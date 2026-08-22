/// The pluggable strategy surface: which scheduler runs, how learning steps are
/// laid out, and how the fuzz seed is derived.
library;

import '../algorithm.dart';
import '../models.dart';

/// The kinds of behaviour a caller may override.
enum StrategyMode {
  /// Replace the scheduler implementation entirely.
  scheduler('Scheduler'),

  /// Replace the learning-step layout.
  learningSteps('LearningSteps'),

  /// Replace the fuzz seed derivation.
  seed('Seed');

  const StrategyMode(this.label);

  /// The string ts-fsrs uses for this mode.
  final String label;
}

/// What one grade does at one learning step.
class LearningStepResult {
  /// Creates a step outcome.
  const LearningStepResult({
    required this.scheduledMinutes,
    required this.nextStep,
  });

  /// Minutes until the card comes back.
  final num scheduledMinutes;

  /// The step index the card moves to.
  final int nextStep;

  @override
  String toString() => 'LearningStepResult(scheduledMinutes: '
      '$scheduledMinutes, nextStep: $nextStep)';
}

/// Produces the fuzz seed for the review being scheduled.
typedef SeedStrategy = String Function(SchedulerContext context);

/// Lays out the (re)learning steps for [state] at step [curStep].
///
/// Has no effect when `enableShortTerm` is false.
typedef LearningStepsStrategy = Map<Rating, LearningStepResult> Function(
  FSRSParameters params,
  State state,
  int curStep,
);

/// Builds a scheduler for one review.
typedef SchedulerStrategy = IScheduler Function(
  Card card,
  Object now,
  FSRSAlgorithm algorithm,
  Map<StrategyMode, Object> strategies,
);

/// The scheduler state a [SeedStrategy] may read.
///
/// Upstream binds `this` to the scheduler instance; Dart has no dynamic `this`,
/// so the same three fields are passed explicitly.
abstract interface class SchedulerContext {
  /// The card being scheduled, after its review counters were bumped.
  Card get current;

  /// The instant of the review.
  DateTime get reviewTime;
}

/// The four possible outcomes of a review, one per grade.
class Preview extends Iterable<RecordLogItem> {
  /// Wraps the per-grade outcomes.
  const Preview(this._items);

  final Map<Rating, RecordLogItem> _items;

  /// The outcome for [grade].
  RecordLogItem operator [](Rating grade) => _items[grade]!;

  /// The outcomes keyed by grade.
  Map<Rating, RecordLogItem> get items => Map<Rating, RecordLogItem>.of(_items);

  @override
  Iterator<RecordLogItem> get iterator =>
      grades.map((Rating grade) => _items[grade]!).iterator;
}

/// Schedules one review of one card.
abstract interface class IScheduler {
  /// All four outcomes, without committing to one.
  Preview preview();

  /// The outcome for [grade].
  RecordLogItem review(Rating grade);
}

/// The result of a reschedule: the replayed collection plus the manual entry
/// that moves the live card onto the replayed schedule.
class IReschedule<T> {
  /// Creates a reschedule result.
  const IReschedule({required this.collections, required this.rescheduleItem});

  /// One entry per replayed review.
  final List<T> collections;

  /// The manual entry to apply to the live card, or null if it already agrees.
  final T? rescheduleItem;
}
