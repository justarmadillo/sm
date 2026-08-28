/// FSRS-backed scheduling state and pure card-review transitions.
///
/// The package object is deliberately kept behind the values in this file.
/// Persistence and presentation therefore depend on an application-owned,
/// versioned shape rather than on a third-party class whose fields may change.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/card_settings.dart';
import 'package:meta/meta.dart';

/// The exact scheduler implementation used to produce a review.
const String kCardSchedulerVersion = 'dart-fsrs/2.0.1+FSRS-6';

/// The pinned FSRS-6 default parameter set shipped by dart-fsrs 2.0.1.
const String kCardParametersVersion = 'dart-fsrs/2.0.1/defaultParameters';

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
    this.parameters = fsrs.defaultParameters,
    this.desiredRetention = 0.90,
    this.learningSteps = const <Duration>[
      Duration(minutes: 1),
      Duration(minutes: 10),
    ],
    this.relearningSteps = const <Duration>[Duration(minutes: 10)],
    this.maximumIntervalDays = 36500,
    this.enableFuzzing = true,
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
        enableFuzzing: settings.enableFuzzing,
        leechLapses: settings.leechLapses,
      );

  final List<double> parameters;
  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumIntervalDays;
  final bool enableFuzzing;

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
    required int reps,
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
    if (reps < 0 || lapses < 0 || lapses > reps) {
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
    if (reps > 0 && (stability == null || difficulty == null)) {
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
      reps: reps,
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
    required this.reps,
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
    reps: 0,
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
    reps: _required<int>(map, 'reps'),
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
  final int reps;
  final int lapses;
  final DateTime? lastReviewAtUtc;
  final DateTime dueAtUtc;
  final DateTime originalDueAtUtc;
  final String schedulerVersion;
  final String parametersVersion;

  /// Deferrals so far. Never a review, so it is counted apart from [reps].
  final int postponeCount;

  /// Interval produced by the most recent genuine review, when applicable.
  final double? scheduledDays;

  final String schedulerName;

  /// Optimistic-concurrency revision of the canonical card schedule.
  final int revision;

  /// A card with no recorded reviews yet.
  bool get isNew => reps == 0;

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
    required bool intervalGrew,
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
      reps: reps,
      lapses: lapses,
      lastReviewAtUtc: adjustedLastReviewAtUtc,
      dueAtUtc: targetDueAtUtc,
      originalDueAtUtc: targetDueAtUtc,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
      postponeCount: postponeCount + (intervalGrew ? 1 : 0),
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
    'reps': reps,
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
      other.reps == reps &&
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
    reps,
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
    final fsrs.Card external = _toFsrsCard(state.memory);
    final fsrs.Scheduler engine = _engineFor(operationId);
    final ({fsrs.Card card, fsrs.ReviewLog reviewLog}) result = engine
        .reviewCard(
          external,
          _toFsrsRating(rating),
          reviewDateTime: reviewedAtUtc,
          reviewDuration: elapsedMs,
        );

    final bool lapsed =
        state.memory.state == CardLearningState.review &&
        rating == CardRating.again;
    final CardMemory memory = CardMemory(
      cardId: state.memory.cardId,
      state: _fromFsrsState(result.card.state),
      step: result.card.step,
      stability: result.card.stability,
      difficulty: result.card.difficulty,
      reps: state.memory.reps + 1,
      lapses: state.memory.lapses + (lapsed ? 1 : 0),
      lastReviewAtUtc: result.card.lastReview,
      dueAtUtc: result.card.due,
      originalDueAtUtc: result.card.due,
      schedulerVersion: settings.schedulerVersion,
      parametersVersion: settings.parametersVersion,
      postponeCount: state.memory.postponeCount,
      scheduledDays: result.card.due.difference(reviewedAtUtc).inMinutes / 1440,
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
          intervalGrew: false,
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
        intervalGrew: actualInterval > oldInterval,
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
      reps: prior.reps,
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
  @override
  double retrievability(CardMemory memory, {required DateTime atUtc}) {
    _requireUtc(atUtc, 'atUtc');
    return _engineFor(
      'retrievability',
    ).getCardRetrievability(_toFsrsCard(memory), currentDateTime: atUtc);
  }

  fsrs.Scheduler _engineFor(String operationId) {
    if (!settings.enableFuzzing) {
      return fsrs.Scheduler(
        parameters: settings.parameters,
        desiredRetention: settings.desiredRetention,
        learningSteps: settings.learningSteps,
        relearningSteps: settings.relearningSteps,
        maximumInterval: settings.maximumIntervalDays,
        enableFuzzing: false,
      );
    }
    // dart-fsrs exposes seeded randomness for its own vector tests. A stable
    // operation-derived seed makes production retries deterministic too.
    // ignore: invalid_use_of_visible_for_testing_member
    return fsrs.Scheduler.customRandom(
      math.Random(_stableSeed(operationId)),
      parameters: settings.parameters,
      desiredRetention: settings.desiredRetention,
      learningSteps: settings.learningSteps,
      relearningSteps: settings.relearningSteps,
      maximumInterval: settings.maximumIntervalDays,
      enableFuzzing: true,
    );
  }
}

fsrs.Card _toFsrsCard(CardMemory memory) => fsrs.Card(
  // FSRS does not use this identity in interval calculations. A stable value
  // is still supplied so its review log remains internally coherent.
  cardId: _stableSeed(memory.cardId),
  state: _toFsrsState(memory.state),
  step: memory.step,
  stability: memory.stability,
  difficulty: memory.difficulty,
  due: memory.dueAtUtc,
  lastReview: memory.lastReviewAtUtc,
);

fsrs.Rating _toFsrsRating(CardRating rating) => switch (rating) {
  CardRating.again => fsrs.Rating.again,
  CardRating.hard => fsrs.Rating.hard,
  CardRating.good => fsrs.Rating.good,
  CardRating.easy => fsrs.Rating.easy,
};

fsrs.State _toFsrsState(CardLearningState state) => switch (state) {
  CardLearningState.learning => fsrs.State.learning,
  CardLearningState.review => fsrs.State.review,
  CardLearningState.relearning => fsrs.State.relearning,
};

CardLearningState _fromFsrsState(fsrs.State state) => switch (state) {
  fsrs.State.learning => CardLearningState.learning,
  fsrs.State.review => CardLearningState.review,
  fsrs.State.relearning => CardLearningState.relearning,
};

/// Stable 32-bit FNV-1a hash. Unlike [String.hashCode], it is specified here
/// and therefore stays identical across processes and Dart versions.
int _stableSeed(String value) {
  var hash = 0x811c9dc5;
  for (final int byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

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
