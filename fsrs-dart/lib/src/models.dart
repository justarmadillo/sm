/// The data model of FSRS: card lifecycle state, ratings, the card itself, its
/// review log, and the tunable parameter set.
///
/// Field names are Dart-idiomatic camelCase; the JSON encodings keep the
/// snake_case keys of ts-fsrs and py-fsrs so serialized cards move between the
/// three implementations unchanged.
library;

import 'error.dart';

/// Lifecycle state of a card.
///
/// The integer [value] is the persisted encoding and matches ts-fsrs/py-fsrs.
enum State {
  /// Never studied.
  newState(0, 'New'),

  /// Inside the learning steps.
  learning(1, 'Learning'),

  /// Graduated to day-scale intervals.
  review(2, 'Review'),

  /// Lapsed out of [review] and back onto the relearning steps.
  relearning(3, 'Relearning');

  const State(this.value, this.label);

  /// Stable persisted encoding.
  final int value;

  /// The name ts-fsrs uses in its string form (`New`, `Learning`, ...).
  final String label;

  /// Decodes [value]; throws [FSRSValidationError] if it names no state.
  static State fromValue(int value) {
    for (final state in State.values) {
      if (state.value == value) return state;
    }
    throw FSRSValidationError('Invalid state:[$value]');
  }
}

/// The rating a user gives a card, plus the pseudo-rating [Rating.manual] used
/// for scheduler-external changes.
enum Rating {
  /// Not a review: a manual reschedule recorded in the history.
  manual(0, 'Manual'),

  /// Forgotten.
  again(1, 'Again'),

  /// Recalled with serious difficulty.
  hard(2, 'Hard'),

  /// Recalled.
  good(3, 'Good'),

  /// Recalled effortlessly.
  easy(4, 'Easy');

  const Rating(this.value, this.label);

  /// Stable persisted encoding.
  final int value;

  /// The name ts-fsrs uses in its string form (`Again`, `Hard`, ...).
  final String label;

  /// Whether this is a real grade, i.e. anything but [Rating.manual].
  bool get isGrade => this != Rating.manual;

  /// Decodes [value]; throws [FSRSValidationError] if it names no rating.
  static Rating fromValue(int value) {
    for (final rating in Rating.values) {
      if (rating.value == value) return rating;
    }
    throw FSRSValidationError('Invalid rating:[$value]');
  }
}

/// The four real grades, in the order ts-fsrs iterates them.
const List<Rating> grades = <Rating>[
  Rating.again,
  Rating.hard,
  Rating.good,
  Rating.easy,
];

/// A card: the scheduling state FSRS owns for one piece of material.
///
/// Mutable, because the reference implementation mutates freshly copied cards
/// while building the four candidate outcomes of a review.
class Card {
  /// Creates a card with an explicit state. Use [Card.empty] for a new card.
  Card({
    required this.due,
    this.stability = 0,
    this.difficulty = 0,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    this.learningSteps = 0,
    this.reps = 0,
    this.lapses = 0,
    this.state = State.newState,
    this.lastReview,
  });

  /// An unstudied card due at [now].
  factory Card.empty([DateTime? now]) => Card(due: now ?? DateTime.now());

  /// Decodes the snake_case JSON shape shared with ts-fsrs.
  factory Card.fromJson(Map<String, Object?> json) => Card(
        due: DateTime.parse(json['due']! as String),
        stability: (json['stability']! as num).toDouble(),
        difficulty: (json['difficulty']! as num).toDouble(),
        elapsedDays: (json['elapsed_days']! as num).toInt(),
        scheduledDays: (json['scheduled_days']! as num).toInt(),
        learningSteps: (json['learning_steps'] as num?)?.toInt() ?? 0,
        reps: (json['reps']! as num).toInt(),
        lapses: (json['lapses']! as num).toInt(),
        state: State.fromValue((json['state']! as num).toInt()),
        lastReview: json['last_review'] == null
            ? null
            : DateTime.parse(json['last_review']! as String),
      );

  /// When the card is next scheduled.
  DateTime due;

  /// Memory stability: the interval at which retrievability is 90%.
  double stability;

  /// Difficulty in `[1, 10]`.
  double difficulty;

  /// Days since the previous review at the time of the last review.
  ///
  /// Deprecated upstream (slated for removal in ts-fsrs 6.0.0); kept for parity
  /// because rollback reads it back out of the log.
  int elapsedDays;

  /// Interval in days that produced [due], or 0 for an intraday step.
  int scheduledDays;

  /// Index of the current (re)learning step.
  int learningSteps;

  /// Total number of reviews.
  int reps;

  /// Number of times the card lapsed out of [State.review].
  int lapses;

  /// Lifecycle state.
  State state;

  /// Instant of the last review, or null while the card is new.
  DateTime? lastReview;

  /// A field-by-field copy; the scheduler builds one per candidate grade.
  Card copy() => Card(
        due: due,
        stability: stability,
        difficulty: difficulty,
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        learningSteps: learningSteps,
        reps: reps,
        lapses: lapses,
        state: state,
        lastReview: lastReview,
      );

  /// Encodes to the snake_case JSON shape shared with ts-fsrs.
  Map<String, Object?> toJson() => <String, Object?>{
        'due': due.toUtc().toIso8601String(),
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'learning_steps': learningSteps,
        'reps': reps,
        'lapses': lapses,
        'state': state.value,
        'last_review': lastReview?.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is Card &&
      due.isAtSameMomentAs(other.due) &&
      stability == other.stability &&
      difficulty == other.difficulty &&
      elapsedDays == other.elapsedDays &&
      scheduledDays == other.scheduledDays &&
      learningSteps == other.learningSteps &&
      reps == other.reps &&
      lapses == other.lapses &&
      state == other.state &&
      (lastReview == null
          ? other.lastReview == null
          : other.lastReview != null &&
              lastReview!.isAtSameMomentAs(other.lastReview!));

  @override
  int get hashCode => Object.hash(
        due.millisecondsSinceEpoch,
        stability,
        difficulty,
        elapsedDays,
        scheduledDays,
        learningSteps,
        reps,
        lapses,
        state,
        lastReview?.millisecondsSinceEpoch,
      );

  @override
  String toString() => 'Card(${toJson()})';
}

/// The record of one review, sufficient to roll the review back.
class ReviewLog {
  /// Creates a review log entry.
  ReviewLog({
    required this.rating,
    required this.state,
    required this.due,
    required this.stability,
    required this.difficulty,
    required this.elapsedDays,
    required this.lastElapsedDays,
    required this.scheduledDays,
    required this.learningSteps,
    required this.review,
  });

  /// Decodes the snake_case JSON shape shared with ts-fsrs.
  factory ReviewLog.fromJson(Map<String, Object?> json) => ReviewLog(
        rating: Rating.fromValue((json['rating']! as num).toInt()),
        state: State.fromValue((json['state']! as num).toInt()),
        due: DateTime.parse(json['due']! as String),
        stability: (json['stability']! as num).toDouble(),
        difficulty: (json['difficulty']! as num).toDouble(),
        elapsedDays: (json['elapsed_days']! as num).toInt(),
        lastElapsedDays: (json['last_elapsed_days']! as num).toInt(),
        scheduledDays: (json['scheduled_days']! as num).toInt(),
        learningSteps: (json['learning_steps'] as num?)?.toInt() ?? 0,
        review: DateTime.parse(json['review']! as String),
      );

  /// The grade given.
  final Rating rating;

  /// The state the card moved into as a result of this review.
  final State state;

  /// The card's previous `lastReview` (or its due date, for a new card).
  final DateTime due;

  /// Stability after the review.
  final double stability;

  /// Difficulty after the review.
  final double difficulty;

  /// Days between this review and the previous one.
  final int elapsedDays;

  /// The card's `elapsedDays` before this review.
  final int lastElapsedDays;

  /// Interval in days scheduled by this review.
  final int scheduledDays;

  /// The (re)learning step index after the review.
  final int learningSteps;

  /// Instant of the review.
  final DateTime review;

  /// Encodes to the snake_case JSON shape shared with ts-fsrs.
  Map<String, Object?> toJson() => <String, Object?>{
        'rating': rating.value,
        'state': state.value,
        'due': due.toUtc().toIso8601String(),
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'last_elapsed_days': lastElapsedDays,
        'scheduled_days': scheduledDays,
        'learning_steps': learningSteps,
        'review': review.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is ReviewLog &&
      rating == other.rating &&
      state == other.state &&
      due.isAtSameMomentAs(other.due) &&
      stability == other.stability &&
      difficulty == other.difficulty &&
      elapsedDays == other.elapsedDays &&
      lastElapsedDays == other.lastElapsedDays &&
      scheduledDays == other.scheduledDays &&
      learningSteps == other.learningSteps &&
      review.isAtSameMomentAs(other.review);

  @override
  int get hashCode => Object.hash(
        rating,
        state,
        due.millisecondsSinceEpoch,
        stability,
        difficulty,
        elapsedDays,
        lastElapsedDays,
        scheduledDays,
        learningSteps,
        review.millisecondsSinceEpoch,
      );

  @override
  String toString() => 'ReviewLog(${toJson()})';
}

/// One outcome of a review: the resulting card plus the log that produced it.
class RecordLogItem {
  /// Pairs a scheduled card with its review log.
  const RecordLogItem({required this.card, required this.log});

  /// The card after the review.
  final Card card;

  /// The log of the review.
  final ReviewLog log;

  @override
  String toString() => 'RecordLogItem(card: $card, log: $log)';
}

/// The memory state FSRS carries between reviews.
class FSRSState {
  /// Creates a memory state.
  const FSRSState({required this.stability, required this.difficulty});

  /// Memory stability.
  final double stability;

  /// Difficulty in `[1, 10]`.
  final double difficulty;

  @override
  bool operator ==(Object other) =>
      other is FSRSState &&
      stability == other.stability &&
      difficulty == other.difficulty;

  @override
  int get hashCode => Object.hash(stability, difficulty);

  @override
  String toString() =>
      'FSRSState(stability: $stability, difficulty: $difficulty)';
}

/// A single historical review, as consumed by the rescheduler.
///
/// A [Rating.manual] entry must also carry [due] and [state]; a graded entry
/// needs only [rating] and [review].
class FSRSHistory {
  /// Creates a history entry.
  FSRSHistory({
    required this.rating,
    required this.review,
    this.due,
    this.state,
    this.stability,
    this.difficulty,
    this.elapsedDays,
    this.lastElapsedDays,
    this.scheduledDays,
    this.learningSteps,
  });

  /// The grade, or [Rating.manual].
  final Rating rating;

  /// Instant of the review. Accepts a [DateTime], epoch milliseconds, or an
  /// ISO-8601 string, like every other date input in this package.
  Object review;

  /// Manual entries only: the due date being forced.
  final Object? due;

  /// Manual entries only: the state being forced.
  final State? state;

  /// Manual entries only: an override for stability.
  final double? stability;

  /// Manual entries only: an override for difficulty.
  final double? difficulty;

  /// Manual entries only: days elapsed at the time of the entry.
  final int? elapsedDays;

  /// Manual entries only: the previous `elapsedDays`.
  final int? lastElapsedDays;

  /// Manual entries only: the interval in days.
  final int? scheduledDays;

  /// Manual entries only: the step index.
  final int? learningSteps;
}

/// A `(rating, delta_t)` pair, the compact review shape used by optimizers.
class FSRSReview {
  /// Creates a review record.
  const FSRSReview({required this.rating, required this.deltaT});

  /// The grade given.
  final Rating rating;

  /// Days that passed before this review.
  final int deltaT;
}

/// The tunable parameter set of the scheduler.
class FSRSParameters {
  /// Creates a parameter set. Prefer `generatorParameters`, which fills in
  /// defaults and migrates shorter parameter vectors.
  FSRSParameters({
    required this.requestRetention,
    required this.maximumInterval,
    required this.w,
    required this.enableFuzz,
    required this.enableShortTerm,
    required this.learningSteps,
    required this.relearningSteps,
  });

  /// Target retention in `(0, 1]`.
  double requestRetention;

  /// Hard ceiling on any scheduled interval, in days.
  int maximumInterval;

  /// The 21 FSRS-6 weights.
  List<double> w;

  /// Whether to jitter intervals.
  bool enableFuzz;

  /// When false the (re)learning steps are skipped entirely and every review
  /// is scheduled on a day scale.
  bool enableShortTerm;

  /// Learning steps such as `1m`, `10m`.
  List<String> learningSteps;

  /// Relearning steps such as `10m`.
  List<String> relearningSteps;

  /// A copy with the same values.
  FSRSParameters copy() => FSRSParameters(
        requestRetention: requestRetention,
        maximumInterval: maximumInterval,
        w: List<double>.of(w),
        enableFuzz: enableFuzz,
        enableShortTerm: enableShortTerm,
        learningSteps: List<String>.of(learningSteps),
        relearningSteps: List<String>.of(relearningSteps),
      );

  @override
  String toString() => 'FSRSParameters(requestRetention: $requestRetention, '
      'maximumInterval: $maximumInterval, w: $w, enableFuzz: $enableFuzz, '
      'enableShortTerm: $enableShortTerm, learningSteps: $learningSteps, '
      'relearningSteps: $relearningSteps)';
}
