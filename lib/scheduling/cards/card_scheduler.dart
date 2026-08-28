/// FSRS-backed scheduling state and pure card-review transitions.
///
/// The package object is deliberately kept behind the values in this file.
/// Persistence and presentation therefore depend on an application-owned,
/// versioned shape rather than on a third-party class whose fields may change.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:fsrs_dart/fsrs.dart' as fsrs;
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/card_settings.dart';
import 'package:meta/meta.dart';

/// The exact scheduler implementation used to produce a review.
///
/// Every review row records this, so a schedule can always be traced back to
/// the code that produced it. Rows written before the move to fsrs_dart still
/// carry `dart-fsrs/2.0.1+FSRS-6`, and that is the point of the field.
const String kCardSchedulerVersion = 'fsrs_dart/5.4.1+FSRS-6';

/// The pinned FSRS-6 default weights shipped by fsrs_dart.
const String kCardParametersVersion = 'fsrs_dart/5.4.1/defaultW';

/// Frozen by the database: it is the default of the `scheduler_name` column and
/// is written by name in the v6 migration, so it names the FSRS engine family
/// rather than the package of the day. Changing it is a migration (RULES 4).
const String kCardSchedulerName = 'dart-fsrs';

/// The four recall outcomes accepted by FSRS.
enum CardRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const CardRating(this.value);

  /// Stable on-disk value. Do not persist [index].
  final int value;

  /// Decodes the stable value persisted in review history.
  static CardRating fromValue(int value) => switch (value) {
    1 => CardRating.again,
    2 => CardRating.hard,
    3 => CardRating.good,
    4 => CardRating.easy,
    _ => throw ArgumentError.value(value, 'value', 'invalid card rating'),
  };
}

/// Which part of the FSRS learning lifecycle a card occupies.
enum CardLearningState {
  learning(1),
  review(2),
  relearning(3);

  const CardLearningState(this.value);

  /// Stable value used by the database and state snapshots.
  final int value;

  /// Decodes the stable value persisted in card memory.
  static CardLearningState fromValue(int value) => switch (value) {
    1 => CardLearningState.learning,
    2 => CardLearningState.review,
    3 => CardLearningState.relearning,
    _ => throw ArgumentError.value(
      value,
      'value',
      'invalid card learning state',
    ),
  };
}

/// Pinned FSRS settings used by [CardScheduler].
@immutable
final class CardSchedulerSettings {
  const CardSchedulerSettings({
    this.parameters = fsrs.defaultW,
    this.desiredRetention = 0.90,
    this.learningSteps = const <Duration>[
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    this.relearningSteps = const <Duration>[Duration(minutes: 10)],
    this.maximumIntervalDays = 36500,
    this.isFuzzingEnabled = true,
    this.leechLapses = 8,
    this.schedulerVersion = kCardSchedulerVersion,
    this.parametersVersion = kCardParametersVersion,
  });

  /// Builds the FSRS settings the user configured.
  ///
  /// The parameter vector itself is not user-editable in v1 — it stays pinned
  /// and versioned, because a hand-edited weight would silently reinterpret
  /// every review already in the log. Retention, steps, and the interval cap
  /// are safe to change at any time and are therefore exposed.
  factory CardSchedulerSettings.fromUserSettings(CardSettings settings) =>
      CardSchedulerSettings(
        desiredRetention: settings.desiredRetention,
        learningSteps: <Duration>[
          for (final int minutes in settings.learningStepMinutes)
            Duration(minutes: minutes),
        ],
        relearningSteps: <Duration>[
          for (final int minutes in settings.relearningStepMinutes)
            Duration(minutes: minutes),
        ],
        maximumIntervalDays: settings.maximumIntervalDays,
        isFuzzingEnabled: settings.isFuzzingEnabled,
        leechLapses: settings.leechLapses,
      );

  final List<double> parameters;
  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumIntervalDays;
  final bool isFuzzingEnabled;

  /// Lapses after which a card is flagged for reformulation.
  final int leechLapses;

  final String schedulerVersion;
  final String parametersVersion;
}

/// The complete memory state required to schedule one card again.
///
/// New cards intentionally have null stability and difficulty: FSRS derives
/// both from the first rating. [dueAtUtc] is the canonical due instant, which
/// a postponement rewrites directly: SM20 keeps no deferral overlay beside it.
@immutable
final class CardMemory {
  factory CardMemory({
    required String cardId,
    required CardLearningState state,
    required int? step,
    required double? stability,
    required double? difficulty,
    required int repetitionCount,
    required int lapses,
    required DateTime? lastReviewAtUtc,
    required DateTime dueAtUtc,
    required DateTime originalDueAtUtc,
    required String schedulerVersion,
    required String parametersVersion,
    int postponeCount = 0,
    double? scheduledDays,
    String schedulerName = kCardSchedulerName,
    int revision = 1,
  }) {
    if (cardId.isEmpty) {
      throw ArgumentError.value(cardId, 'cardId', 'must not be empty');
    }
    _requireUtc(dueAtUtc, 'dueAtUtc');
    _requireUtc(originalDueAtUtc, 'originalDueAtUtc');
    if (lastReviewAtUtc != null) {
      _requireUtc(lastReviewAtUtc, 'lastReviewAtUtc');
    }
    if (repetitionCount < 0 || lapses < 0 || lapses > repetitionCount) {
      throw ArgumentError('review counters are inconsistent');
    }
    if (step != null && step < 0) {
      throw ArgumentError.value(step, 'step', 'must not be negative');
    }
    if (state == CardLearningState.review && step != null) {
      throw ArgumentError('a review-state card cannot have a learning step');
    }
    if (state != CardLearningState.review && step == null) {
      throw ArgumentError('a learning-state card needs a learning step');
    }
    if ((stability == null) != (difficulty == null)) {
      throw ArgumentError(
        'stability and difficulty must either both be null or both be set',
      );
    }
    if (repetitionCount > 0 && (stability == null || difficulty == null)) {
      throw ArgumentError('reviewed cards need stability and difficulty');
    }
    if (schedulerVersion.isEmpty || parametersVersion.isEmpty) {
      throw ArgumentError('scheduler versions must not be empty');
    }
    if (scheduledDays != null &&
        (!scheduledDays.isFinite || scheduledDays < 0)) {
      throw ArgumentError.value(
        scheduledDays,
        'scheduledDays',
        'must be finite and non-negative',
      );
    }
    if (schedulerName.isEmpty || revision < 1) {
      throw ArgumentError('scheduler name and revision must be valid');
    }
    return CardMemory._(
      cardId: cardId,
      state: state,
      step: step,
      stability: stability,
      difficulty: difficulty,
      repetitionCount: repetitionCount,
      lapses: lapses,
      lastReviewAtUtc: lastReviewAtUtc,
      dueAtUtc: dueAtUtc,
      originalDueAtUtc: originalDueAtUtc,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
      postponeCount: postponeCount,
      scheduledDays: scheduledDays,
      schedulerName: schedulerName,
      revision: revision,
    );
  }

  const CardMemory._({
    required this.cardId,
    required this.state,
    required this.step,
    required this.stability,
    required this.difficulty,
    required this.repetitionCount,
    required this.lapses,
    required this.lastReviewAtUtc,
    required this.dueAtUtc,
    required this.originalDueAtUtc,
    required this.schedulerVersion,
    required this.parametersVersion,
    required this.postponeCount,
    required this.scheduledDays,
    required this.schedulerName,
    required this.revision,
  });

  /// Memory for a newly formulated card, eligible immediately.
  factory CardMemory.newCard({
    required String cardId,
    required DateTime dueAtUtc,
    String schedulerVersion = kCardSchedulerVersion,
    String parametersVersion = kCardParametersVersion,
  }) => CardMemory(
    cardId: cardId,
    state: CardLearningState.learning,
    step: 0,
    stability: null,
    difficulty: null,
    repetitionCount: 0,
    lapses: 0,
    lastReviewAtUtc: null,
    dueAtUtc: dueAtUtc,
    originalDueAtUtc: dueAtUtc,
    schedulerVersion: schedulerVersion,
    parametersVersion: parametersVersion,
  );

  /// Restores the exact state emitted by [toMap].
  factory CardMemory.fromMap(Map<String, Object?> map) => CardMemory(
    cardId: _required<String>(map, 'card_id'),
    state: CardLearningState.fromValue(_required<int>(map, 'state')),
    step: map['step'] as int?,
    stability: (map['stability'] as num?)?.toDouble(),
    difficulty: (map['difficulty'] as num?)?.toDouble(),
    repetitionCount: _required<int>(map, 'reps'),
    lapses: _required<int>(map, 'lapses'),
    lastReviewAtUtc: _instantOrNull(map['last_review_at_utc_ms']),
    dueAtUtc: _instant(_required<int>(map, 'due_at_utc_ms')),
    originalDueAtUtc: _instant(_required<int>(map, 'original_due_at_utc_ms')),
    schedulerVersion: _required<String>(map, 'scheduler_version'),
    parametersVersion: _required<String>(map, 'parameters_version'),
    postponeCount: (map['postpone_count'] as int?) ?? 0,
    scheduledDays: (map['scheduled_days'] as num?)?.toDouble(),
    schedulerName: (map['scheduler_name'] as String?) ?? kCardSchedulerName,
    revision: (map['revision'] as int?) ?? 1,
  );

  /// Restores the exact state emitted by [toJson].
  factory CardMemory.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('card memory JSON must be an object');
    }
    return CardMemory.fromMap(decoded);
  }

  final String cardId;
  final CardLearningState state;

  /// Current learning/relearning step; null in review state.
  final int? step;

  final double? stability;
  final double? difficulty;
  final int repetitionCount;
  final int lapses;
  final DateTime? lastReviewAtUtc;
  final DateTime dueAtUtc;
  final DateTime originalDueAtUtc;
  final String schedulerVersion;
  final String parametersVersion;

  /// Deferrals so far. Never a review, so it is counted apart from [repetitionCount].
  final int postponeCount;

  /// Interval produced by the most recent genuine review, when applicable.
  final double? scheduledDays;

  final String schedulerName;

  /// Optimistic-concurrency revision of the canonical card schedule.
  final int revision;

  /// A card with no recorded reviews yet.
  bool get isNew => repetitionCount == 0;

  /// Whether the card is part-way through a learning or relearning run.
  ///
  /// Requires a review to have happened: FSRS represents a brand-new card as
  /// Learning too, but nothing has been started on it, so it is an ordinary
  /// new card that the daily new-card limit applies to. Only a run the user
  /// has actually begun bypasses admission limits and sibling burying.
  bool get isIntradayStep => !isNew && state != CardLearningState.review;

  /// Whether the card may be reviewed at [instantUtc].
  ///
  /// The canonical due instant is the only one there is: SM20 has no deferral
  /// overlay, so a postponement rewrites this value through a low-level
  /// reschedule rather than shadowing it.
  bool isDueAt(DateTime instantUtc) {
    _requireUtc(instantUtc, 'instantUtc');
    return !dueAtUtc.isAfter(instantUtc);
  }

  /// Replaces the canonical item repetition without recording a review.
  ///
  /// This is the item-side projection of SM20's low-level rescheduler. Memory
  /// strength/difficulty and review counters are preserved; the due instant,
  /// stored interval, optional last-review correction, and postponement count
  /// are the only mutable fields.
  CardMemory lowLevelRescheduled({
    required DateTime targetDueAtUtc,
    required double actualIntervalDays,
    required DateTime? adjustedLastReviewAtUtc,
    required bool didIntervalGrow,
  }) {
    _requireUtc(targetDueAtUtc, 'targetDueAtUtc');
    if (adjustedLastReviewAtUtc != null) {
      _requireUtc(adjustedLastReviewAtUtc, 'adjustedLastReviewAtUtc');
    }
    if (!actualIntervalDays.isFinite || actualIntervalDays < 0) {
      throw ArgumentError.value(
        actualIntervalDays,
        'actualIntervalDays',
        'must be finite and non-negative',
      );
    }
    return CardMemory(
      cardId: cardId,
      state: state,
      step: step,
      stability: stability,
      difficulty: difficulty,
      repetitionCount: repetitionCount,
      lapses: lapses,
      lastReviewAtUtc: adjustedLastReviewAtUtc,
      dueAtUtc: targetDueAtUtc,
      originalDueAtUtc: targetDueAtUtc,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
      postponeCount: postponeCount + (didIntervalGrow ? 1 : 0),
      scheduledDays: actualIntervalDays,
      schedulerName: schedulerName,
      revision: revision + 1,
    );
  }

  /// Lossless, JSON-compatible state used in review snapshots.
  Map<String, Object?> toMap() => <String, Object?>{
    'card_id': cardId,
    'state': state.value,
    'step': step,
    'stability': stability,
    'difficulty': difficulty,
    'reps': repetitionCount,
    'lapses': lapses,
    'last_review_at_utc_ms': lastReviewAtUtc?.millisecondsSinceEpoch,
    'due_at_utc_ms': dueAtUtc.millisecondsSinceEpoch,
    'original_due_at_utc_ms': originalDueAtUtc.millisecondsSinceEpoch,
    'scheduler_version': schedulerVersion,
    'parameters_version': parametersVersion,
    'postpone_count': postponeCount,
    'scheduled_days': scheduledDays,
    'scheduler_name': schedulerName,
    'revision': revision,
  };

  /// Exact state consumed and returned by dart-fsrs. Presentation adjustments
  /// and diagnostic counters are deliberately excluded.
  Map<String, Object?> canonicalFsrsMap() => <String, Object?>{
    'state': state.value,
    'step': step,
    'stability': stability,
    'difficulty': difficulty,
    'due_at_utc_ms': dueAtUtc.millisecondsSinceEpoch,
    'last_review_at_utc_ms': lastReviewAtUtc?.millisecondsSinceEpoch,
  };

  String canonicalFsrsJson() => jsonEncode(canonicalFsrsMap());

  /// Canonical snapshot persisted with every review event.
  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) =>
      other is CardMemory &&
      other.cardId == cardId &&
      other.state == state &&
      other.step == step &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.repetitionCount == repetitionCount &&
      other.lapses == lapses &&
      other.lastReviewAtUtc == lastReviewAtUtc &&
      other.dueAtUtc == dueAtUtc &&
      other.originalDueAtUtc == originalDueAtUtc &&
      other.schedulerVersion == schedulerVersion &&
      other.parametersVersion == parametersVersion &&
      other.postponeCount == postponeCount &&
      other.scheduledDays == scheduledDays &&
      other.schedulerName == schedulerName &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(
    cardId,
    state,
    step,
    stability,
    difficulty,
    repetitionCount,
    lapses,
    lastReviewAtUtc,
    dueAtUtc,
    originalDueAtUtc,
    schedulerVersion,
    parametersVersion,
    postponeCount,
    scheduledDays,
    schedulerName,
    revision,
  );
}

/// Generic element facts together with the card's FSRS memory.
@immutable
final class CardState {
  factory CardState({
    required ElementSchedule schedule,
    required CardMemory memory,
  }) {
    if (schedule.ref.type != ElementType.card) {
      throw ArgumentError('a card state needs a card element schedule');
    }
    if (schedule.ref.id != memory.cardId) {
      throw ArgumentError('the schedule and memory identify different cards');
    }
    return CardState._(schedule: schedule, memory: memory);
  }

  const CardState._({required this.schedule, required this.memory});

  final ElementSchedule schedule;
  final CardMemory memory;

  ElementRef get ref => schedule.ref;

  CardState copyWith({ElementSchedule? schedule, CardMemory? memory}) =>
      CardState(
        schedule: schedule ?? this.schedule,
        memory: memory ?? this.memory,
      );

  @override
  bool operator ==(Object other) =>
      other is CardState &&
      other.schedule.ref == schedule.ref &&
      other.schedule.lifecycle == schedule.lifecycle &&
      other.schedule.dueDay == schedule.dueDay &&
      other.schedule.priority == schedule.priority &&
      other.memory == memory;

  @override
  int get hashCode => Object.hash(
    schedule.ref,
    schedule.lifecycle,
    schedule.dueDay,
    schedule.priority,
    memory,
  );

  @override
  String toString() =>
      'CardState(${schedule.ref} ${memory.state.name} '
      'due=${memory.dueAtUtc})';
}

/// Lossless append-only description of one review.
@immutable
final class ReviewRecord {
  factory ReviewRecord({
    required String operationId,
    required String cardId,
    required CardRating rating,
    required DateTime reviewedAtUtc,
    required int? elapsedMs,
    required String preStateJson,
    required String postStateJson,
    required String schedulerVersion,
    required String parametersVersion,
    bool isPractice = false,
  }) {
    _requireUtc(reviewedAtUtc, 'reviewedAtUtc');
    if (operationId.isEmpty || cardId.isEmpty) {
      throw ArgumentError('review identity must not be empty');
    }
    if (elapsedMs != null && elapsedMs < 0) {
      throw ArgumentError.value(elapsedMs, 'elapsedMs', 'must not be negative');
    }
    return ReviewRecord._(
      operationId: operationId,
      cardId: cardId,
      rating: rating,
      reviewedAtUtc: reviewedAtUtc,
      elapsedMs: elapsedMs,
      preStateJson: preStateJson,
      postStateJson: postStateJson,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
      isPractice: isPractice,
    );
  }

  const ReviewRecord._({
    required this.operationId,
    required this.cardId,
    required this.rating,
    required this.reviewedAtUtc,
    required this.elapsedMs,
    required this.preStateJson,
    required this.postStateJson,
    required this.schedulerVersion,
    required this.parametersVersion,
    required this.isPractice,
  });

  final String operationId;
  final String cardId;
  final CardRating rating;
  final DateTime reviewedAtUtc;
  final int? elapsedMs;
  final String preStateJson;
  final String postStateJson;
  final String schedulerVersion;
  final String parametersVersion;
  final bool isPractice;

  CardMemory get preState => CardMemory.fromJson(preStateJson);

  CardMemory get postState => CardMemory.fromJson(postStateJson);
}

/// New state and append-only record produced by a review.
@immutable
final class CardReviewTransition {
  const CardReviewTransition({required this.state, required this.record});

  final CardState state;
  final ReviewRecord record;
}

/// Pure adapter around the pinned dart-fsrs implementation.
abstract interface class FsrsAdapter {
  CardReviewTransition review(
    CardState state, {
    required CardRating rating,
    required DateTime reviewedAtUtc,
    required String operationId,
    int? elapsedMs,
  });

  double retrievability(CardMemory memory, {required DateTime atUtc});
}

/// The sole dart-fsrs integration boundary used by the application.
@immutable
final class CardScheduler implements FsrsAdapter {
  const CardScheduler({
    required this.calendar,
    this.settings = const CardSchedulerSettings(),
  });

  final StudyDayCalendar calendar;
  final CardSchedulerSettings settings;

  /// Applies one scheduled recall grade.
  ///
  /// Fuzzing remains enabled by default, but its random stream is derived from
  /// [operationId]. Retrying one command therefore produces the same due date
  /// and exact state snapshot instead of rolling a second interval.
  @override
  CardReviewTransition review(
    CardState state, {
    required CardRating rating,
    required DateTime reviewedAtUtc,
    required String operationId,
    int? elapsedMs,
  }) {
    _requireUtc(reviewedAtUtc, 'reviewedAtUtc');
    if (operationId.isEmpty) {
      throw ArgumentError.value(
        operationId,
        'operationId',
        'must not be empty',
      );
    }
    if (!state.schedule.lifecycle.isSchedulable) {
      throw StateError('a non-active card cannot be reviewed');
    }
    final DateTime? lastReview = state.memory.lastReviewAtUtc;
    if (lastReview != null && reviewedAtUtc.isBefore(lastReview)) {
      throw ArgumentError('a review cannot predate the previous review');
    }
    if (lastReview != null && !reviewedAtUtc.isAfter(lastReview)) {
      // Zero elapsed time is not a repetition: FSRS would be told that a
      // memory survived an interval that never elapsed. A duplicate grade is
      // the application's to absorb by operation id, not the adapter's to
      // average into stability.
      throw StateError('a review must advance beyond the previous review');
    }
    // Presentation eligibility is evaluated by the application against the
    // canonical due plus typed adjustments. An exact manual/Mercy override
    // may intentionally present a card before its algorithmic due, so the
    // FSRS adapter must not repeat a canonical-only due check here.

    final String preStateJson = state.memory.toJson();
    final fsrs.RecordLogItem result = _engineFor(
      operationId,
    ).next(_toFsrsCard(state.memory), reviewedAtUtc, _toFsrsRating(rating));
    final fsrs.Card reviewed = result.card;
    final DateTime dueAtUtc = reviewed.due.toUtc();

    final CardMemory memory = CardMemory(
      cardId: state.memory.cardId,
      state: _fromFsrsState(reviewed.state),
      // A review-state card holds no learning step. FSRS carries an index
      // there only when a configured step is a whole day or longer, which the
      // database column cannot represent and the previous engine dropped too.
      step: reviewed.state == fsrs.State.review ? null : reviewed.learningSteps,
      stability: reviewed.stability,
      difficulty: reviewed.difficulty,
      // The engine keeps both counters itself, including the lapse a failed
      // review-state card costs, so they are read back rather than recomputed.
      repetitionCount: reviewed.reps,
      lapses: reviewed.lapses,
      lastReviewAtUtc: reviewed.lastReview?.toUtc(),
      dueAtUtc: dueAtUtc,
      originalDueAtUtc: dueAtUtc,
      schedulerVersion: settings.schedulerVersion,
      parametersVersion: settings.parametersVersion,
      postponeCount: state.memory.postponeCount,
      scheduledDays: dueAtUtc.difference(reviewedAtUtc).inMinutes / 1440,
      schedulerName: kCardSchedulerName,
      revision: state.memory.revision + 1,
    );
    final StudyDay dueDay = calendar.dayOf(memory.dueAtUtc);
    final ElementSchedule schedule = state.schedule.copyWith(
      dueDay: dueDay,
      originalDueDay: dueDay,
      revision: state.schedule.revision + 1,
    );
    final CardState next = CardState(schedule: schedule, memory: memory);
    final ReviewRecord record = ReviewRecord(
      operationId: operationId,
      cardId: state.memory.cardId,
      rating: rating,
      reviewedAtUtc: reviewedAtUtc,
      elapsedMs: elapsedMs,
      preStateJson: preStateJson,
      postStateJson: memory.toJson(),
      schedulerVersion: settings.schedulerVersion,
      parametersVersion: settings.parametersVersion,
    );
    return CardReviewTransition(state: next, record: record);
  }

  /// SM20's low-level item reschedule transaction.
  CardState rescheduleElement(
    CardState state, {
    required StudyDay targetDay,
    required StudyDay today,
  }) {
    final DateTime targetUtc = calendar.startOfDayUtc(targetDay);
    final DateTime? priorLast = state.memory.lastReviewAtUtc;
    if (priorLast == null) {
      final int remaining = math.max(today.daysUntil(targetDay), 0);
      return state.copyWith(
        schedule: state.schedule.copyWith(
          dueDay: targetDay,
          originalDueDay: targetDay,
          revision: state.schedule.revision + 1,
        ),
        memory: state.memory.lowLevelRescheduled(
          targetDueAtUtc: targetUtc,
          actualIntervalDays: remaining.toDouble(),
          adjustedLastReviewAtUtc: null,
          didIntervalGrow: false,
        ),
      );
    }

    final StudyDay lastDay = calendar.dayOf(priorLast);
    final int oldInterval = math.max(
      (state.memory.scheduledDays ??
              lastDay.daysUntil(calendar.dayOf(state.memory.dueAtUtc)))
          .round(),
      1,
    );
    late final int actualInterval;
    late final DateTime adjustedLast;
    if (targetDay > lastDay) {
      actualInterval = lastDay.daysUntil(targetDay);
      adjustedLast = priorLast;
    } else {
      actualInterval = 1;
      adjustedLast = calendar.startOfDayUtc(targetDay.addDays(-1));
    }
    return state.copyWith(
      schedule: state.schedule.copyWith(
        dueDay: targetDay,
        originalDueDay: targetDay,
        revision: state.schedule.revision + 1,
      ),
      memory: state.memory.lowLevelRescheduled(
        targetDueAtUtc: targetUtc,
        actualIntervalDays: actualInterval.toDouble(),
        adjustedLastReviewAtUtc: adjustedLast,
        didIntervalGrow: actualInterval > oldInterval,
      ),
    );
  }

  /// Whether [memory] has failed often enough to be worth reformulating.
  ///
  /// Flagged, never auto-suspended. Most repeated failures are not hard
  /// facts, they are badly written cards, and suspending one hides the
  /// evidence instead of fixing the cause. The provenance tree already knows
  /// where the passage came from — that is the affordance worth offering.
  bool isLeech(CardMemory memory) =>
      settings.leechLapses > 0 && memory.lapses >= settings.leechLapses;

  /// Restores the exact state a review was applied on top of.
  ///
  /// Undo is a state restore, not an inverse calculation: FSRS is not
  /// invertible, so the only trustworthy way back is the pre-review snapshot
  /// the review event carries. The caller removes the event in the same
  /// transaction.
  CardState undo(CardState current, ReviewRecord record) {
    if (record.cardId != current.ref.id) {
      throw ArgumentError('that review belongs to a different card');
    }
    final CardMemory prior = record.preState;
    // Revisions are concurrency tokens, not FSRS memory. Preserve the exact
    // prior scheduler fields while advancing the token to avoid ABA writes.
    final CardMemory restored = CardMemory(
      cardId: prior.cardId,
      state: prior.state,
      step: prior.step,
      stability: prior.stability,
      difficulty: prior.difficulty,
      repetitionCount: prior.repetitionCount,
      lapses: prior.lapses,
      lastReviewAtUtc: prior.lastReviewAtUtc,
      dueAtUtc: prior.dueAtUtc,
      originalDueAtUtc: prior.originalDueAtUtc,
      schedulerVersion: prior.schedulerVersion,
      parametersVersion: prior.parametersVersion,
      postponeCount: prior.postponeCount,
      scheduledDays: prior.scheduledDays,
      schedulerName: prior.schedulerName,
      revision: current.memory.revision + 1,
    );
    final StudyDay dueDay = calendar.dayOf(restored.dueAtUtc);
    return CardState(
      schedule: current.schedule.copyWith(
        dueDay: dueDay,
        originalDueDay: calendar.dayOf(restored.originalDueAtUtc),
        revision: current.schedule.revision + 1,
      ),
      memory: restored,
    );
  }

  /// Predicted probability that [memory] is currently recallable.
  ///
  /// A card with no review behind it reads as 0: nothing has been learned yet,
  /// so there is no memory that could have decayed.
  @override
  double retrievability(CardMemory memory, {required DateTime atUtc}) {
    _requireUtc(atUtc, 'atUtc');
    return _engineFor(
      'retrievability',
    ).getRetrievability(_toFsrsCard(memory), atUtc);
  }

  /// The engine, configured for one operation.
  ///
  /// Built per call rather than held as a field, because it carries the fuzz
  /// seed of the operation it was built for.
  fsrs.FSRS _engineFor(String operationId) {
    final fsrs.FSRS engine = fsrs.fsrs(
      requestRetention: settings.desiredRetention,
      maximumInterval: settings.maximumIntervalDays,
      w: settings.parameters,
      enableFuzz: settings.isFuzzingEnabled,
      learningSteps: _toFsrsSteps(settings.learningSteps),
      relearningSteps: _toFsrsSteps(settings.relearningSteps),
    );
    if (!settings.isFuzzingEnabled) {
      return engine;
    }
    // Fuzzing stays on, but its random stream is derived from the operation id
    // rather than from the review instant, so retrying one command lands on the
    // same day again instead of rolling a second interval.
    return engine.useStrategy(
      fsrs.StrategyMode.seed,
      (fsrs.SchedulerContext context) => operationId,
    );
  }
}

/// The step list in the `10m` spelling fsrs_dart parses.
List<String> _toFsrsSteps(List<Duration> steps) => <String>[
  for (final Duration step in steps) '${step.inMinutes}m',
];

/// Rebuilds the card fsrs_dart expects out of our own stored memory.
///
/// Stability and difficulty are 0 rather than null for a card FSRS has not
/// measured yet: that pair of zeroes is how the engine recognises a card whose
/// first memory state is still to be derived from the grade it is about to get.
fsrs.Card _toFsrsCard(CardMemory memory) => fsrs.Card(
  due: memory.dueAtUtc,
  stability: memory.stability ?? 0,
  difficulty: memory.difficulty ?? 0,
  scheduledDays: memory.scheduledDays?.round() ?? 0,
  learningSteps: memory.step ?? 0,
  reps: memory.repetitionCount,
  lapses: memory.lapses,
  state: _toFsrsState(memory),
  lastReview: memory.lastReviewAtUtc,
);

fsrs.Rating _toFsrsRating(CardRating rating) => switch (rating) {
  CardRating.again => fsrs.Rating.again,
  CardRating.hard => fsrs.Rating.hard,
  CardRating.good => fsrs.Rating.good,
  CardRating.easy => fsrs.Rating.easy,
};

/// FSRS's New state means exactly "no review has happened yet".
///
/// The app has no such state: it stores an unreviewed card as Learning at step
/// 0, because that is the shape the database column already holds. The two
/// spellings are bridged here rather than on disk, so nothing is migrated.
fsrs.State _toFsrsState(CardMemory memory) {
  if (memory.isNew || memory.lastReviewAtUtc == null) {
    return fsrs.State.newState;
  }
  return switch (memory.state) {
    CardLearningState.learning => fsrs.State.learning,
    CardLearningState.review => fsrs.State.review,
    CardLearningState.relearning => fsrs.State.relearning,
  };
}

CardLearningState _fromFsrsState(fsrs.State state) => switch (state) {
  fsrs.State.learning => CardLearningState.learning,
  fsrs.State.review => CardLearningState.review,
  fsrs.State.relearning => CardLearningState.relearning,
  // Unreachable: a graded review always leaves New behind.
  fsrs.State.newState => throw ArgumentError.value(
    state,
    'state',
    'a reviewed card cannot be new',
  ),
};

void _requireUtc(DateTime instant, String name) {
  if (!instant.isUtc) {
    throw ArgumentError.value(instant, name, 'must be UTC');
  }
}

DateTime _instant(int epochMilliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(epochMilliseconds, isUtc: true);

DateTime? _instantOrNull(Object? value) =>
    value == null ? null : _instant(value as int);

T _required<T>(Map<String, Object?> map, String key) {
  final Object? value = map[key];
  if (value is! T) throw FormatException('missing or invalid $key');
  return value;
}
