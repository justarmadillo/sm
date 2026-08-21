/// The universal repetition log: one row for every scheduling event, of every
/// element type.
///
/// This is the highest-value table in the collection, because it is the only
/// thing that cannot be reconstructed later. Card memory, topic intervals, and
/// priority keys are all *current* state — a bug can overwrite them and the
/// history is gone. The log is append-only and records the inputs as well as
/// the outputs of every decision, so six months from now the constants in
/// `AppSettings` can be retuned against what actually happened instead of
/// against the design document's guesses.
///
/// Two rules the log exists to keep straight:
///
/// * **A postpone is not a review.** Only [RevlogEventType.review] carries a
///   grade and only it may ever feed a parameter optimizer. Training on
///   postponements teaches the optimizer that the user's memory is worse than
///   it is, because the elapsed time was never a retention test.
/// * **Practice grades are not reviews either.** They are flagged and
///   excluded for the same reason: nothing about the collection's schedule
///   changed, so the observation is not a measurement of a scheduled recall.
library;

import 'package:meta/meta.dart';

import 'element.dart';

/// What happened to an element.
enum RevlogEventType {
  /// A scheduled recall was graded and FSRS advanced the card.
  review(1, 'review'),

  /// A topic encounter was completed and its interval grew.
  topicRead(2, 'topic_read'),

  /// The user chose Later. Eligibility moved; nothing else did.
  postpone(3, 'postpone'),

  /// The overload valve deferred the element to protect the day's capacity.
  autoPostpone(4, 'auto_postpone'),

  /// The user set an interval or due date by hand.
  manualReschedule(5, 'manual_reschedule'),

  /// Scheduling stopped while the content was kept.
  dismiss(6, 'dismiss'),

  /// A source was declared finished, by the user or by auto-finish.
  finish(7, 'finish'),

  /// Temporary removal from the queue.
  suspend(8, 'suspend'),

  /// Return to the queue from suspension, dismissal, or finishing.
  resume(9, 'resume'),

  /// Relative priority changed.
  priorityChange(10, 'priority_change'),

  /// A sibling item was pushed off today so it would not give itself away.
  bury(11, 'bury'),

  /// A backlog was spread across a horizon in one operation.
  mercy(12, 'mercy'),

  /// A grade was taken back and the pre-review state restored.
  undo(13, 'undo'),

  /// A subset-review grade. Logged, but never allowed to touch state.
  practice(14, 'practice'),

  /// An element was created and given its first schedule.
  created(15, 'created');

  const RevlogEventType(this.value, this.storageName);

  /// Stable on-disk value. Never persist [index].
  final int value;

  /// Stable dotted-free name used in exports and diagnostics.
  final String storageName;

  /// Decodes the stored value, throwing on an unknown one rather than
  /// guessing: a log row that cannot be interpreted must be loud.
  static RevlogEventType fromValue(int value) => switch (value) {
    1 => RevlogEventType.review,
    2 => RevlogEventType.topicRead,
    3 => RevlogEventType.postpone,
    4 => RevlogEventType.autoPostpone,
    5 => RevlogEventType.manualReschedule,
    6 => RevlogEventType.dismiss,
    7 => RevlogEventType.finish,
    8 => RevlogEventType.suspend,
    9 => RevlogEventType.resume,
    10 => RevlogEventType.priorityChange,
    11 => RevlogEventType.bury,
    12 => RevlogEventType.mercy,
    13 => RevlogEventType.undo,
    14 => RevlogEventType.practice,
    15 => RevlogEventType.created,
    _ => throw ArgumentError.value(value, 'value', 'unknown revlog event'),
  };

  /// Whether an FSRS parameter optimizer may learn from this event.
  ///
  /// Exactly one event type qualifies. Everything else either has no grade or
  /// has a grade that was never a scheduled retention test.
  bool get feedsOptimizer => this == RevlogEventType.review;

  /// Whether this event moved a due date without advancing any interval.
  bool get isDeferral =>
      this == RevlogEventType.postpone ||
      this == RevlogEventType.autoPostpone ||
      this == RevlogEventType.bury ||
      this == RevlogEventType.mercy;
}

/// The memory and pacing facts on either side of one event.
///
/// A single shape for cards and topics: the card fields are null on a topic
/// row and the topic fields are null on a card row. One table keeps
/// "everything that happened, in order" a single query rather than a union,
/// which is what makes the log usable for diagnosis at all.
@immutable
final class RevlogSnapshot {
  const RevlogSnapshot({
    this.dueAtUtc,
    this.intervalDays,
    this.aFactor,
    this.stability,
    this.difficulty,
    this.learningState,
    this.reps,
    this.lapses,
    this.priorityKey,
    this.pressure,
    this.readFraction,
    this.lifecycle,
  });

  /// An empty snapshot, for events that have no meaningful "before".
  static const RevlogSnapshot none = RevlogSnapshot();

  /// The instant the element was due.
  final DateTime? dueAtUtc;

  /// Topic interval in days. Fractional because A-factor growth is not
  /// integral until it is applied to a date.
  final double? intervalDays;

  /// The topic's A-factor.
  final double? aFactor;

  /// FSRS stability, in days.
  final double? stability;

  /// FSRS difficulty.
  final double? difficulty;

  /// Stable `CardLearningState` value, kept as an int so the log does not
  /// depend on a card type.
  final int? learningState;

  /// Total repetitions so far.
  final int? reps;

  /// Total lapses so far.
  final int? lapses;

  /// Relative priority order key.
  final String? priorityKey;

  /// Derived priority pressure at the time of the event, `0` at the top.
  ///
  /// Stored rather than recomputed because the collection's order changes:
  /// what mattered to the decision is where the element stood *then*.
  final double? pressure;

  /// How far through a source the reading position had reached, `0` to `1`.
  final double? readFraction;

  /// Stable [ElementLifecycle] index.
  final int? lifecycle;

  RevlogSnapshot copyWith({
    DateTime? dueAtUtc,
    double? intervalDays,
    double? aFactor,
    double? stability,
    double? difficulty,
    int? learningState,
    int? reps,
    int? lapses,
    String? priorityKey,
    double? pressure,
    double? readFraction,
    int? lifecycle,
  }) => RevlogSnapshot(
    dueAtUtc: dueAtUtc ?? this.dueAtUtc,
    intervalDays: intervalDays ?? this.intervalDays,
    aFactor: aFactor ?? this.aFactor,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    learningState: learningState ?? this.learningState,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    priorityKey: priorityKey ?? this.priorityKey,
    pressure: pressure ?? this.pressure,
    readFraction: readFraction ?? this.readFraction,
    lifecycle: lifecycle ?? this.lifecycle,
  );

  @override
  bool operator ==(Object other) =>
      other is RevlogSnapshot &&
      other.dueAtUtc == dueAtUtc &&
      other.intervalDays == intervalDays &&
      other.aFactor == aFactor &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.learningState == learningState &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.priorityKey == priorityKey &&
      other.pressure == pressure &&
      other.readFraction == readFraction &&
      other.lifecycle == lifecycle;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    dueAtUtc,
    intervalDays,
    aFactor,
    stability,
    difficulty,
    learningState,
    reps,
    lapses,
    priorityKey,
    pressure,
    readFraction,
    lifecycle,
  ]);
}

/// One append-only row of the repetition log.
@immutable
final class RevlogEntry {
  /// Builds an entry, validating the invariants the log's usefulness rests on.
  factory RevlogEntry({
    required String id,
    required String operationId,
    required ElementRef ref,
    required RevlogEventType eventType,
    required DateTime atUtc,
    RevlogSnapshot before = RevlogSnapshot.none,
    RevlogSnapshot after = RevlogSnapshot.none,
    int? grade,
    double? elapsedDays,
    double? scheduledDays,
    int? durationMs,
    int? postponeCount,
    String? schedulerVersion,
    String? parametersVersion,
    Map<String, Object?>? metadata,
  }) {
    if (id.isEmpty || operationId.isEmpty) {
      throw ArgumentError('a revlog entry needs an id and an operation id');
    }
    if (!atUtc.isUtc) {
      throw ArgumentError.value(atUtc, 'atUtc', 'must be UTC');
    }
    final bool graded =
        eventType == RevlogEventType.review ||
        eventType == RevlogEventType.practice;
    if (grade != null && !graded) {
      throw ArgumentError('only review and practice events carry a grade');
    }
    if (grade != null && (grade < 1 || grade > 4)) {
      throw ArgumentError.value(grade, 'grade', 'must be 1..4');
    }
    if (durationMs != null && durationMs < 0) {
      throw ArgumentError.value(durationMs, 'durationMs', 'must not be < 0');
    }
    return RevlogEntry._(
      id: id,
      operationId: operationId,
      ref: ref,
      eventType: eventType,
      atUtc: atUtc,
      before: before,
      after: after,
      grade: grade,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      durationMs: durationMs,
      postponeCount: postponeCount,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
      metadata: metadata,
    );
  }

  const RevlogEntry._({
    required this.id,
    required this.operationId,
    required this.ref,
    required this.eventType,
    required this.atUtc,
    required this.before,
    required this.after,
    required this.grade,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.durationMs,
    required this.postponeCount,
    required this.schedulerVersion,
    required this.parametersVersion,
    required this.metadata,
  });

  final String id;

  /// Correlates this row with every other row one user action produced.
  final String operationId;

  final ElementRef ref;
  final RevlogEventType eventType;
  final DateTime atUtc;

  /// State before the event.
  final RevlogSnapshot before;

  /// State after the event.
  final RevlogSnapshot after;

  /// 1–4, on review and practice events only.
  final int? grade;

  /// Days that *actually* passed since the previous repetition.
  ///
  /// Distinct from [scheduledDays] on purpose: the gap between the two is the
  /// signal an optimizer needs, and it only exists if postponements never
  /// overwrite the previous review instant.
  final double? elapsedDays;

  /// Days the interval had been set to.
  final double? scheduledDays;

  /// Foreground time spent on this encounter.
  final int? durationMs;

  /// How many times the element has been postponed in total.
  final int? postponeCount;

  /// Which scheduler produced the outcome, when one did.
  final String? schedulerVersion;

  /// Which parameter set produced the outcome, when one did.
  final String? parametersVersion;

  /// Free-form detail: the A-factor inputs, the delay formula's terms, the
  /// cap that triggered a deferral. Never element content.
  final Map<String, Object?>? metadata;

  /// Whether an FSRS optimizer may train on this row.
  bool get feedsOptimizer => eventType.feedsOptimizer;

  @override
  String toString() =>
      'RevlogEntry(${eventType.storageName} $ref at $atUtc grade=$grade)';
}
