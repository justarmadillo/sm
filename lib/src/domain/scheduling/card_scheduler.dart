/// FSRS-backed scheduling state and pure card-review transitions.
///
/// The package object is deliberately kept behind the values in this file.
/// Persistence and presentation therefore depend on an application-owned,
/// versioned shape rather than on a third-party class whose fields may change.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:meta/meta.dart';

import 'element.dart';
import 'study_day.dart';

/// The exact scheduler implementation used to produce a review.
const String kCardSchedulerVersion = 'dart-fsrs/2.0.1+FSRS-6';

/// The pinned FSRS-6 default parameter set shipped by dart-fsrs 2.0.1.
const String kCardParametersVersion = 'dart-fsrs/2.0.1/defaultParameters';

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
    this.schedulerVersion = kCardSchedulerVersion,
    this.parametersVersion = kCardParametersVersion,
  });

  final List<double> parameters;
  final double desiredRetention;
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final int maximumIntervalDays;
  final bool enableFuzzing;
  final String schedulerVersion;
  final String parametersVersion;
}

/// The complete memory state required to schedule one card again.
///
/// New cards intentionally have null stability and difficulty: FSRS derives
/// both from the first rating. [dueAtUtc] is the algorithmic due instant;
/// deferral is kept separately so overload handling never falsifies it.
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
    required DateTime? deferredUntilUtc,
    required String schedulerVersion,
    required String parametersVersion,
  }) {
    if (cardId.isEmpty) {
      throw ArgumentError.value(cardId, 'cardId', 'must not be empty');
    }
    _requireUtc(dueAtUtc, 'dueAtUtc');
    _requireUtc(originalDueAtUtc, 'originalDueAtUtc');
    if (lastReviewAtUtc != null) {
      _requireUtc(lastReviewAtUtc, 'lastReviewAtUtc');
    }
    if (deferredUntilUtc != null) {
      _requireUtc(deferredUntilUtc, 'deferredUntilUtc');
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
      deferredUntilUtc: deferredUntilUtc,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
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
    required this.deferredUntilUtc,
    required this.schedulerVersion,
    required this.parametersVersion,
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
    deferredUntilUtc: null,
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
    deferredUntilUtc: _instantOrNull(map['deferred_until_utc_ms']),
    schedulerVersion: _required<String>(map, 'scheduler_version'),
    parametersVersion: _required<String>(map, 'parameters_version'),
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
  final DateTime? deferredUntilUtc;
  final String schedulerVersion;
  final String parametersVersion;

  /// A card with no recorded reviews yet.
  bool get isNew => reps == 0;

  /// Learning and relearning steps bypass future admission limits.
  bool get isIntradayStep => state != CardLearningState.review;

  /// The instant at which the card is actually eligible.
  DateTime get effectiveDueAtUtc {
    final DateTime? deferred = deferredUntilUtc;
    if (deferred == null || !deferred.isAfter(dueAtUtc)) return dueAtUtc;
    return deferred;
  }

  /// Whether the card may be reviewed at [instantUtc].
  bool isDueAt(DateTime instantUtc) {
    _requireUtc(instantUtc, 'instantUtc');
    return !effectiveDueAtUtc.isAfter(instantUtc);
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
    'deferred_until_utc_ms': deferredUntilUtc?.millisecondsSinceEpoch,
    'scheduler_version': schedulerVersion,
    'parameters_version': parametersVersion,
  };

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
      other.deferredUntilUtc == deferredUntilUtc &&
      other.schedulerVersion == schedulerVersion &&
      other.parametersVersion == parametersVersion;

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
    deferredUntilUtc,
    schedulerVersion,
    parametersVersion,
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
@immutable
final class CardScheduler {
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
    if (!state.memory.isDueAt(reviewedAtUtc)) {
      throw StateError('a card cannot be reviewed before it is due');
    }

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
      deferredUntilUtc: null,
      schedulerVersion: settings.schedulerVersion,
      parametersVersion: settings.parametersVersion,
    );
    final StudyDay dueDay = calendar.dayOf(memory.dueAtUtc);
    final ElementSchedule schedule = state.schedule.copyWith(
      dueDay: dueDay,
      originalDueDay: dueDay,
      clearDeferral: true,
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

  /// Predicted probability that [memory] is currently recallable.
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
