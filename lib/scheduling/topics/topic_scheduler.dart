/// Executable-derived SuperMemo 20 topic/extract scheduler.
///
/// This is the sole topic scheduler used by the application.  It deliberately
/// separates a repetition (which adapts A, priority, review state, and due
/// state) from a low-level reschedule (which normally changes only the stored
/// interval, ratio, due date, and postponement counters).
library;

import 'dart:math' as math;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:meta/meta.dart';

const String kSm20SchedulerName = 'sm20-aio';
const String kSm20SchedulerVersion = 'sm20-aio/1';
const double kSm20MinimumAFactor = 1.01;
const double kSm20SchedulingMaximumAFactor = 3.0;
const double kSm20StorageMaximumAFactor = 6.0;
const int kSm20MaximumStoredInterval = 44530;
const int kSm20Uint16Maximum = 65535;

/// The four scheduling statuses used by the executable record.
enum Sm20ElementStatus {
  pending,
  memorized,
  dismissed,
  deleted;

  bool get isRankable => this != Sm20ElementStatus.deleted;
}

/// Browser learning modes that select the topic interval branch.
enum Sm20ReviewMode {
  learn(4),
  reviewAll(5),
  reviewTopics(6);

  const Sm20ReviewMode(this.value);
  final int value;

  bool get usesForcedTopicInterval =>
      this == Sm20ReviewMode.reviewAll || this == Sm20ReviewMode.reviewTopics;
}

/// Full persisted SM20 scheduling state of a source or extract.
@immutable
final class TopicState {
  TopicState({
    required this.schedule,
    required this.status,
    required this.aFactorRaw,
    DelphiReal48? lastIntervalRatioRaw,
    this.repetitionCount = 0,
    this.lapseCount = 0,
    this.storedInterval = 0,
    this.lastReviewDay,
    this.historyBlockId = 0,
    this.recentPostponementCount = 0,
    this.totalPostponementCount = 0,
    this.learningControl = 0,
    this.encountersSinceLastCard = 0,
    this.revision = 1,
  }) : lastIntervalRatioRaw =
           lastIntervalRatioRaw ?? DelphiReal48.fromDouble(0) {
    if (!schedule.ref.type.isTopic) {
      throw ArgumentError('topic state requires a source or extract');
    }
    if (repetitionCount < 0 || repetitionCount > kSm20Uint16Maximum) {
      throw RangeError.range(
        repetitionCount,
        0,
        kSm20Uint16Maximum,
        'repetitionCount',
      );
    }
    if (lapseCount < 0 || lapseCount > kSm20Uint16Maximum) {
      throw RangeError.range(lapseCount, 0, kSm20Uint16Maximum, 'lapseCount');
    }
    if (storedInterval < 0 || storedInterval > kSm20Uint16Maximum) {
      throw RangeError.range(
        storedInterval,
        0,
        kSm20Uint16Maximum,
        'storedInterval',
      );
    }
    if (recentPostponementCount < 0 || totalPostponementCount < 0) {
      throw RangeError('postponement counters cannot be negative');
    }
  }

  final ElementSchedule schedule;
  final Sm20ElementStatus status;
  final int repetitionCount;
  final int lapseCount;
  final int storedInterval;
  final StudyDay? lastReviewDay;
  final DelphiReal48 aFactorRaw;
  final DelphiReal48 lastIntervalRatioRaw;
  final int historyBlockId;
  final int recentPostponementCount;
  final int totalPostponementCount;
  final int learningControl;

  /// App-only finish nudge. It does not participate in scheduling.
  final int encountersSinceLastCard;
  final int revision;

  ElementRef get ref => schedule.ref;
  bool get isExtract => ref.type == ElementType.extract;
  double get aFactor => aFactorRaw.value;
  double get lastIntervalRatio => lastIntervalRatioRaw.value;
  double get intervalDays => storedInterval.toDouble();
  int get encounters => repetitionCount;
  int get postponeCount => totalPostponementCount;
  StudyDay? get lastEncounterDay => lastReviewDay;
  String get schedulerVersion => kSm20SchedulerVersion;
  String get schedulerName => kSm20SchedulerName;

  TopicState copyWith({
    ElementSchedule? schedule,
    Sm20ElementStatus? status,
    int? repetitionCount,
    int? lapseCount,
    int? storedInterval,
    Object? lastReviewDay = _keep,
    DelphiReal48? aFactorRaw,
    DelphiReal48? lastIntervalRatioRaw,
    int? historyBlockId,
    int? recentPostponementCount,
    int? totalPostponementCount,
    int? learningControl,
    int? encountersSinceLastCard,
    int? revision,
  }) => TopicState(
    schedule: schedule ?? this.schedule,
    status: status ?? this.status,
    repetitionCount: repetitionCount ?? this.repetitionCount,
    lapseCount: lapseCount ?? this.lapseCount,
    storedInterval: storedInterval ?? this.storedInterval,
    lastReviewDay: identical(lastReviewDay, _keep)
        ? this.lastReviewDay
        : lastReviewDay as StudyDay?,
    aFactorRaw: aFactorRaw ?? this.aFactorRaw,
    lastIntervalRatioRaw: lastIntervalRatioRaw ?? this.lastIntervalRatioRaw,
    historyBlockId: historyBlockId ?? this.historyBlockId,
    recentPostponementCount:
        recentPostponementCount ?? this.recentPostponementCount,
    totalPostponementCount:
        totalPostponementCount ?? this.totalPostponementCount,
    learningControl: learningControl ?? this.learningControl,
    encountersSinceLastCard:
        encountersSinceLastCard ?? this.encountersSinceLastCard,
    revision: revision ?? this.revision,
  );

  @override
  bool operator ==(Object other) =>
      other is TopicState &&
      other.schedule == schedule &&
      other.status == status &&
      other.repetitionCount == repetitionCount &&
      other.lapseCount == lapseCount &&
      other.storedInterval == storedInterval &&
      other.lastReviewDay == lastReviewDay &&
      other.aFactorRaw == aFactorRaw &&
      other.lastIntervalRatioRaw == lastIntervalRatioRaw &&
      other.historyBlockId == historyBlockId &&
      other.recentPostponementCount == recentPostponementCount &&
      other.totalPostponementCount == totalPostponementCount &&
      other.learningControl == learningControl &&
      other.encountersSinceLastCard == encountersSinceLastCard &&
      other.revision == revision;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    schedule,
    status,
    repetitionCount,
    lapseCount,
    storedInterval,
    lastReviewDay,
    aFactorRaw,
    lastIntervalRatioRaw,
    historyBlockId,
    recentPostponementCount,
    totalPostponementCount,
    learningControl,
    encountersSinceLastCard,
    revision,
  ]);
}

const Object _keep = Object();

/// Reader-session facts retained for audit and presentation only.
@immutable
final class TopicEncounter {
  const TopicEncounter({
    this.readFraction,
    this.hasChildItems = false,
    this.wordsRead = 0,
    this.extractsCreated = 0,
    this.hasReachedEnd = false,
    this.hasUnprocessedText = true,
  });

  static const TopicEncounter none = TopicEncounter();
  final double? readFraction;
  final bool hasChildItems;
  final int wordsRead;
  final int extractsCreated;
  final bool hasReachedEnd;
  final bool hasUnprocessedText;
  double get density => wordsRead <= 0 ? 0 : extractsCreated / wordsRead * 1000;
  bool get isExhausted => hasReachedEnd && !hasUnprocessedText;
}

/// Observable consequences of one topic transaction.
@immutable
sealed class TopicEvent {
  const TopicEvent(this.ref);
  final ElementRef ref;
  String get type;
}

final class TopicRepetitionCommitted extends TopicEvent {
  const TopicRepetitionCommitted(
    super.ref, {
    required this.oldInterval,
    required this.selectedInterval,
    required this.storedInterval,
    required this.oldAFactor,
    required this.newAFactor,
    required this.priorityBefore,
    required this.priorityAfter,
    required this.nextDueDay,
    required this.isBulkOperation,
    required this.randomDraws,
  });

  final int oldInterval;
  final int selectedInterval;
  final int storedInterval;
  final double oldAFactor;
  final double newAFactor;
  final double priorityBefore;
  final double priorityAfter;
  final StudyDay nextDueDay;
  final bool isBulkOperation;
  final int randomDraws;

  @override
  String get type => 'topic.repetition_committed';
}

final class TopicRescheduled extends TopicEvent {
  const TopicRescheduled(
    super.ref, {
    required this.oldInterval,
    required this.newInterval,
    required this.targetDay,
  });

  final int oldInterval;
  final int newInterval;
  final StudyDay targetDay;

  @override
  String get type => 'topic.rescheduled';
}

final class TopicLifecycleChanged extends TopicEvent {
  const TopicLifecycleChanged(
    super.ref, {
    required this.from,
    required this.to,
  });

  final Sm20ElementStatus from;
  final Sm20ElementStatus to;

  @override
  String get type => 'topic.status_changed';
}

@immutable
final class TopicTransition {
  const TopicTransition(
    this.state,
    this.events, {
    required this.randomNumberState,
  });

  const TopicTransition.unchanged(
    TopicState state,
    Sm20RandomNumberGeneratorState randomNumberState,
  ) : this(state, const <TopicEvent>[], randomNumberState: randomNumberState);

  final TopicState state;
  final List<TopicEvent> events;
  final Sm20RandomNumberGeneratorState randomNumberState;
  bool get isChange => events.isNotEmpty;
}

/// A text-extraction transaction before the child content row is stored.
@immutable
final class Sm20TextExtraction {
  const Sm20TextExtraction({
    required this.source,
    required this.childAFactor,
    required this.sourcePriorityTarget,
    required this.childPriorityTarget,
    required this.randomNumberState,
  });

  final TopicState source;
  final DelphiReal48 childAFactor;
  final double sourcePriorityTarget;
  final double childPriorityTarget;
  final Sm20RandomNumberGeneratorState randomNumberState;
}

/// A media-extraction transaction before the child content row is stored.
@immutable
final class Sm20MediaExtraction {
  const Sm20MediaExtraction({
    required this.sourcePriorityTarget,
    required this.childPriorityTarget,
    required this.childAFactor,
    required this.randomNumberState,
  });

  final double sourcePriorityTarget;
  final double childPriorityTarget;
  final DelphiReal48 childAFactor;
  final Sm20RandomNumberGeneratorState randomNumberState;
}

/// The executable-derived topic scheduler and reschedule primitives.
final class TopicScheduler {
  TopicScheduler({
    Sm20RandomNumberGenerator? randomNumbers,
    this.extractFinishPromptAfter = 3,
  }) : randomNumbers = randomNumbers ?? Sm20RandomNumberGenerator();

  final Sm20RandomNumberGenerator randomNumbers;
  final int extractFinishPromptAfter;

  Sm20RandomNumberGeneratorState get randomNumberState => randomNumbers.state;

  /// Ordinary allocation: a pending source/extract with raw Real48 A=1.2.
  TopicState createFor({
    required ElementRef ref,
    required StudyDay today,
    required ElementSchedule Function(StudyDay due) buildSchedule,
    DelphiReal48? initialAFactor,
    bool isMemorized = false,
  }) {
    final DelphiReal48 aFactor =
        initialAFactor ??
        DelphiReal48.fromBytes(<int>[0x81, 0x9A, 0x99, 0x99, 0x99, 0x19]);
    final StudyDay due = isMemorized ? today.addDays(1) : today;
    return TopicState(
      schedule: buildSchedule(due),
      status: isMemorized
          ? Sm20ElementStatus.memorized
          : Sm20ElementStatus.pending,
      repetitionCount: isMemorized ? 1 : 0,
      storedInterval: isMemorized ? 1 : 0,
      lastReviewDay: isMemorized ? today : null,
      aFactorRaw: aFactor,
      lastIntervalRatioRaw: DelphiReal48.fromDouble(isMemorized ? 1 : 0),
    );
  }

  /// Explicit text-length override. Dart string length is UTF-16 code units.
  static double textLengthAFactor(int utf16CodeUnits) {
    if (utf16CodeUnits < 0) {
      throw RangeError.value(utf16CodeUnits, 'utf16CodeUnits');
    }
    if (utf16CodeUnits == 0) return 2;
    final double x = 10000 / utf16CodeUnits;
    return 1.25 + (0.75 * x) / (50 + x);
  }

  static DelphiReal48 textLengthAFactorRaw(int utf16CodeUnits) =>
      DelphiReal48.fromDouble(textLengthAFactor(utf16CodeUnits));

  /// Computes the next automatic interval and consumes exactly two draws.
  int nextAutomaticInterval(
    TopicState state, {
    Sm20ReviewMode mode = Sm20ReviewMode.learn,
  }) {
    final int old = state.storedInterval;
    late final double center;
    late final double width;
    if (mode.usesForcedTopicInterval) {
      center = math.max(old ~/ 2, 1).toDouble();
      width = math.max(center / 2, 1);
    } else {
      final double scheduledA = state.aFactor.clamp(
        kSm20MinimumAFactor,
        kSm20SchedulingMaximumAFactor,
      );
      double raw = old == 0
          ? scheduledA * scheduledA * scheduledA
          : old * scheduledA;
      raw = math.min(raw, kSm20MaximumStoredInterval.toDouble());
      center = sm20RoundEven(raw).toDouble();
      width = center - old;
    }
    var candidate = sm20RoundEven(
      sm20Spread(center: center, width: width, randomNumbers: randomNumbers),
    );
    if (candidate <= old) candidate = old + 1;
    return candidate;
  }

  /// Exact Real48-rounded A adaptation.
  static DelphiReal48 adjustAFactorRaw(
    DelphiReal48 rawA,
    int oldInterval,
    int newInterval, {
    required bool isBulkOperation,
  }) {
    final int old = math.max(oldInterval, 1);
    final int next = math.max(newInterval, 1);
    if (old == next) return rawA;
    final double a = rawA.value;
    final double r = math.max(next / old, old / next);
    final int k = isBulkOperation ? 80 : 15;
    final double d = math.max((a - kSm20MinimumAFactor) * r / (r + k), 0.001);
    final double result = (next > old ? a + d : a - d).clamp(
      kSm20MinimumAFactor,
      kSm20StorageMaximumAFactor,
    );
    return DelphiReal48.fromDouble(result);
  }

  /// General Modify A primitive.
  static DelphiReal48 modifyAFactorRaw(DelphiReal48 rawA, double multiplier) =>
      DelphiReal48.fromDouble(
        kSm20MinimumAFactor + multiplier * (rawA.value - kSm20MinimumAFactor),
      );

  TopicState setAFactor(TopicState state, double value) {
    if (value < kSm20MinimumAFactor || value > 3 || !value.isFinite) {
      throw RangeError.value(value, 'value', 'must be from 1.01 through 3');
    }
    return state.copyWith(
      aFactorRaw: DelphiReal48.fromDouble(value),
      revision: state.revision + 1,
    );
  }

  TopicState modifyAFactor(TopicState state, double multiplier) {
    if (multiplier < 0.2 || multiplier > 2 || !multiplier.isFinite) {
      throw RangeError.value(
        multiplier,
        'multiplier',
        'must be from 0.2 through 2',
      );
    }
    return state.copyWith(
      aFactorRaw: modifyAFactorRaw(state.aFactorRaw, multiplier),
      revision: state.revision + 1,
    );
  }

  /// Commits Done/ordinary learning. Pending topics use explicit interval 1;
  /// memorized topics select an automatic interval first.
  TopicTransition complete(
    TopicState state,
    StudyDay today, {
    required PriorityScale priorityScale,
    TopicEncounter encounter = TopicEncounter.none,
    Sm20ReviewMode mode = Sm20ReviewMode.learn,
  }) {
    if (state.status == Sm20ElementStatus.dismissed ||
        state.status == Sm20ElementStatus.deleted) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    final int beforeDraws = randomNumbers.drawCount;
    final int selected = state.status == Sm20ElementStatus.pending
        ? 1
        : nextAutomaticInterval(state, mode: mode);
    return _commitRepetition(
      state,
      today,
      selectedInterval: selected,
      isBulkOperation: false,
      priorityScale: priorityScale,
      randomDraws: randomNumbers.drawCount - beforeDraws,
    );
  }

  /// Browser Remember, including the collection first-interval words.
  TopicTransition remember(
    TopicState state,
    StudyDay today, {
    required int firstIntervalLow,
    required int firstIntervalHigh,
    required PriorityScale priorityScale,
  }) {
    if (state.status == Sm20ElementStatus.memorized ||
        state.status == Sm20ElementStatus.deleted) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    final int beforeDraws = randomNumbers.drawCount;
    final int selected;
    if (firstIntervalHigh == 0) {
      selected = nextAutomaticInterval(state);
    } else if (firstIntervalHigh == firstIntervalLow) {
      selected = firstIntervalHigh;
    } else {
      selected = sm20RoundEven(
        firstIntervalLow +
            randomNumbers.nextDouble() * (firstIntervalHigh - firstIntervalLow),
      ).clamp(1, 365);
    }
    return _commitRepetition(
      state.copyWith(status: Sm20ElementStatus.pending),
      today,
      selectedInterval: selected.clamp(1, kSm20Uint16Maximum),
      isBulkOperation: false,
      priorityScale: priorityScale,
      randomDraws: randomNumbers.drawCount - beforeDraws,
    );
  }

  /// Explicit forced topic repetition. Same-day/future last review is guarded.
  TopicTransition forceRepetition(
    TopicState state,
    StudyDay today, {
    required int interval,
    required bool isBulkOperation,
    required PriorityScale priorityScale,
  }) {
    final StudyDay? last = state.lastReviewDay;
    if (last != null && last >= today) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    if (interval < 0 || interval > kSm20Uint16Maximum) {
      throw RangeError.range(interval, 0, kSm20Uint16Maximum, 'interval');
    }
    return _commitRepetition(
      state,
      today,
      selectedInterval: interval,
      isBulkOperation: isBulkOperation,
      priorityScale: priorityScale,
      randomDraws: 0,
    );
  }

  TopicTransition _commitRepetition(
    TopicState state,
    StudyDay today, {
    required int selectedInterval,
    required bool isBulkOperation,
    required PriorityScale priorityScale,
    required int randomDraws,
  }) {
    final int oldInterval = state.storedInterval;
    final double oldA = state.aFactor;
    final double priorityBefore = priorityScale.percentageOf(
      state.schedule.priority,
    );
    final DelphiReal48 nextA = adjustAFactorRaw(
      state.aFactorRaw,
      oldInterval,
      selectedInterval,
      isBulkOperation: isBulkOperation,
    );
    final PriorityRank nextRank = priorityScale.adjustedForInterval(
      state.schedule.priority,
      oldInterval: oldInterval,
      newInterval: selectedInterval,
      isBulkOperation: isBulkOperation,
    );
    final double ratio = math.max(
      state.repetitionCount == 0 || oldInterval == 0
          ? selectedInterval.toDouble()
          : selectedInterval / oldInterval,
      1,
    );
    final int stored = math.min(selectedInterval, kSm20MaximumStoredInterval);
    final StudyDay due = today.addDays(stored);
    final TopicState next = state.copyWith(
      status: Sm20ElementStatus.memorized,
      repetitionCount: math.min(state.repetitionCount + 1, kSm20Uint16Maximum),
      storedInterval: stored,
      lastReviewDay: today,
      aFactorRaw: nextA,
      lastIntervalRatioRaw: DelphiReal48.fromDouble(ratio),
      encountersSinceLastCard: state.encountersSinceLastCard + 1,
      revision: state.revision + 1,
      schedule: state.schedule.copyWith(
        priority: nextRank,
        lifecycle: ElementLifecycle.active,
        dueDay: due,
        originalDueDay: due,
        revision: state.schedule.revision + 1,
      ),
    );
    final PriorityScale afterScale = priorityScale.replacing(
      state.schedule.priority,
      nextRank,
    );
    return TopicTransition(next, <TopicEvent>[
      TopicRepetitionCommitted(
        state.ref,
        oldInterval: oldInterval,
        selectedInterval: selectedInterval,
        storedInterval: stored,
        oldAFactor: oldA,
        newAFactor: nextA.value,
        priorityBefore: priorityBefore,
        priorityAfter: afterScale.percentageOf(nextRank),
        nextDueDay: due,
        isBulkOperation: isBulkOperation,
        randomDraws: randomDraws,
      ),
    ], randomNumberState: randomNumbers.state);
  }

  /// Low-level reschedule. It never adapts A or priority.
  TopicTransition rescheduleElement(
    TopicState state, {
    required StudyDay targetDay,
    required StudyDay today,
  }) {
    if (state.status != Sm20ElementStatus.memorized) {
      final int interval = math.max(today.daysUntil(targetDay), 0);
      // Pending admission follows the memorization path. It has no priority
      // population input here, so callers that need non-one adaptation use
      // [remember] or [jumpInterval].
      final int selected = interval;
      final StudyDay due = targetDay;
      final TopicState admittedState = state.copyWith(
        status: Sm20ElementStatus.memorized,
        repetitionCount: state.repetitionCount + 1,
        storedInterval: selected,
        lastReviewDay: today,
        lastIntervalRatioRaw: DelphiReal48.fromDouble(
          math.max(selected, 1).toDouble(),
        ),
        revision: state.revision + 1,
        schedule: state.schedule.copyWith(
          lifecycle: ElementLifecycle.active,
          dueDay: due,
          originalDueDay: due,
          revision: state.schedule.revision + 1,
        ),
      );
      return TopicTransition(admittedState, <TopicEvent>[
        TopicRescheduled(
          state.ref,
          oldInterval: state.storedInterval,
          newInterval: selected,
          targetDay: due,
        ),
      ], randomNumberState: randomNumbers.state);
    }

    final int oldInterval = math.max(state.storedInterval, 1);
    final double oldRatio = state.lastIntervalRatio;
    late final int actualNewInterval;
    late final double newRatio;
    late final StudyDay lastReview;
    final StudyDay priorLast =
        state.lastReviewDay ?? today.addDays(-oldInterval);
    if (targetDay > priorLast) {
      actualNewInterval = priorLast.daysUntil(targetDay);
      newRatio = math.max(1, (actualNewInterval / oldInterval) * oldRatio);
      lastReview = priorLast;
    } else {
      actualNewInterval = 1;
      newRatio = 1;
      lastReview = targetDay.addDays(-1);
    }
    final bool didIntervalGrow = actualNewInterval > oldInterval;
    final TopicState next = state.copyWith(
      storedInterval: actualNewInterval.clamp(1, kSm20Uint16Maximum),
      lastReviewDay: lastReview,
      lastIntervalRatioRaw: DelphiReal48.fromDouble(newRatio),
      recentPostponementCount:
          state.recentPostponementCount + (didIntervalGrow ? 1 : 0),
      totalPostponementCount:
          state.totalPostponementCount + (didIntervalGrow ? 1 : 0),
      revision: state.revision + 1,
      schedule: state.schedule.copyWith(
        dueDay: targetDay,
        originalDueDay: targetDay,
        revision: state.schedule.revision + 1,
      ),
    );
    return TopicTransition(next, <TopicEvent>[
      TopicRescheduled(
        state.ref,
        oldInterval: oldInterval,
        newInterval: actualNewInterval,
        targetDay: targetDay,
      ),
    ], randomNumberState: randomNumbers.state);
  }

  /// Delay Element: derive a factor-scaled interval, then low-level reschedule.
  TopicTransition delayElement(
    TopicState state, {
    required StudyDay today,
    required double factor,
  }) {
    final StudyDay last = state.lastReviewDay ?? today;
    final int age = math.max(
      today.epochDay - last.epochDay,
      state.storedInterval,
    );
    var newInterval = sm20RoundEven(age * factor);
    if (newInterval <= age) newInterval = age + 1;
    newInterval = math.min(newInterval, kSm20MaximumStoredInterval);
    return rescheduleElement(
      state,
      targetDay: last.addDays(newInterval),
      today: today,
    );
  }

  /// Manual Reschedule / Jump Interval, including topic A and priority drift.
  TopicTransition jumpInterval(
    TopicState state, {
    required StudyDay today,
    required int remainingInterval,
    required bool shouldModifyPriority,
    required PriorityScale priorityScale,
  }) {
    final int oldInterval = state.storedInterval;
    final TopicTransition moved = rescheduleElement(
      state,
      targetDay: today.addDays(remainingInterval),
      today: today,
    );
    final DelphiReal48 nextA = adjustAFactorRaw(
      state.aFactorRaw,
      oldInterval,
      remainingInterval,
      isBulkOperation: false,
    );
    final PriorityRank rank = shouldModifyPriority
        ? priorityScale.adjustedForInterval(
            state.schedule.priority,
            oldInterval: oldInterval,
            newInterval: remainingInterval,
            isBulkOperation: false,
          )
        : state.schedule.priority;
    final TopicState next = moved.state.copyWith(
      aFactorRaw: nextA,
      revision: moved.state.revision,
      schedule: moved.state.schedule.copyWith(priority: rank),
    );
    return TopicTransition(
      next,
      moved.events,
      randomNumberState: randomNumbers.state,
    );
  }

  /// Later Today. The already-Outstanding branch is queue-only.
  TopicTransition laterToday(
    TopicState state, {
    required StudyDay today,
    required bool isAlreadyOutstanding,
    required PriorityScale priorityScale,
  }) {
    if (isAlreadyOutstanding || state.lastReviewDay == today) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    return jumpInterval(
      state,
      today: today,
      remainingInterval: 0,
      shouldModifyPriority: false,
      priorityScale: priorityScale,
    );
  }

  /// Text extraction A and priority transition. One priority draw.
  Sm20TextExtraction extractText(
    TopicState source, {
    required int utf16CodeUnits,
    required double sourcePriorityPercent,
  }) {
    final double sourceA = source.aFactor;
    final double textA = textLengthAFactor(utf16CodeUnits);
    final double x = math.max(sourceA - kSm20MinimumAFactor, 0);
    final double q = 0.9 * x / (0.29 + x);
    final DelphiReal48 childA = DelphiReal48.fromDouble(
      (1 - q) * sourceA + q * textA,
    );
    final DelphiReal48 nextSourceA = DelphiReal48.fromDouble(
      kSm20MinimumAFactor + 0.95 * (sourceA - kSm20MinimumAFactor),
    );
    final double sourceTarget = sourcePriorityPercent * 0.995;
    final double low0 = 0.7 * sourceTarget;
    var low = low0;
    var high = sourceTarget > 0
        ? math.exp(1.7 * math.exp(0.2 * math.log(sourceTarget)))
        : 0.0;
    if (low > high) {
      low = high;
      high = 1.3 * high;
    }
    high = high.clamp(0, 100);
    final double span = (high - low) * utf16CodeUnits / (utf16CodeUnits + 100);
    final double childTarget = (low + randomNumbers.nextDouble() * span).clamp(
      0,
      100,
    );
    return Sm20TextExtraction(
      source: source.copyWith(
        aFactorRaw: nextSourceA,
        revision: source.revision + 1,
      ),
      childAFactor: childA,
      sourcePriorityTarget: sourceTarget,
      childPriorityTarget: childTarget,
      randomNumberState: randomNumbers.state,
    );
  }

  /// Media/play extraction. One priority draw; source A is unchanged.
  Sm20MediaExtraction extractMedia({required double sourcePriorityPercent}) {
    final double sourceTarget = sourcePriorityPercent * 0.995;
    return Sm20MediaExtraction(
      sourcePriorityTarget: sourceTarget,
      childPriorityTarget:
          3 + sourceTarget * (0.5 + 0.3 * randomNumbers.nextDouble()),
      childAFactor: DelphiReal48.fromDouble(3),
      randomNumberState: randomNumbers.state,
    );
  }

  TopicState notifyCardCreated(TopicState state) =>
      state.copyWith(encountersSinceLastCard: 0);

  bool shouldPromptFinish(TopicState state, {required bool hasChildItems}) =>
      state.isExtract &&
      hasChildItems &&
      state.status == Sm20ElementStatus.memorized &&
      state.encountersSinceLastCard >= extractFinishPromptAfter;

  /// Forget preserves topic A and priority while clearing repetition state.
  TopicTransition forget(TopicState state, StudyDay today) {
    if (state.status == Sm20ElementStatus.dismissed ||
        state.status == Sm20ElementStatus.deleted) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    if (state.status == Sm20ElementStatus.pending) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    return _clearedStatus(
      state,
      today,
      Sm20ElementStatus.pending,
      learningControl: 8,
    );
  }

  /// Dismiss clears repetition state, preserves A, and targets priority 100%.
  TopicTransition dismiss(
    TopicState state,
    StudyDay today, {
    required PriorityScale priorityScale,
  }) {
    if (state.status == Sm20ElementStatus.dismissed ||
        state.status == Sm20ElementStatus.deleted) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    final TopicTransition cleared = _clearedStatus(
      state,
      today,
      Sm20ElementStatus.dismissed,
      learningControl: state.learningControl,
    );
    final PriorityRank bottom = priorityScale.rankForSetPriority(
      state.schedule.priority,
      100,
    );
    return TopicTransition(
      cleared.state.copyWith(
        schedule: cleared.state.schedule.copyWith(
          priority: bottom,
          lifecycle: ElementLifecycle.dismissed,
        ),
      ),
      cleared.events,
      randomNumberState: randomNumbers.state,
    );
  }

  TopicTransition _clearedStatus(
    TopicState state,
    StudyDay today,
    Sm20ElementStatus status, {
    required int learningControl,
  }) {
    final ElementLifecycle lifecycle = switch (status) {
      Sm20ElementStatus.dismissed => ElementLifecycle.dismissed,
      Sm20ElementStatus.deleted => ElementLifecycle.deleted,
      _ => ElementLifecycle.active,
    };
    final TopicState next = state.copyWith(
      status: status,
      repetitionCount: 0,
      lapseCount: 0,
      storedInterval: 0,
      lastReviewDay: today,
      lastIntervalRatioRaw: DelphiReal48.fromDouble(0),
      historyBlockId: 0,
      recentPostponementCount: 0,
      totalPostponementCount: 0,
      learningControl: learningControl,
      revision: state.revision + 1,
      schedule: state.schedule.copyWith(
        lifecycle: lifecycle,
        dueDay: today,
        originalDueDay: today,
        revision: state.schedule.revision + 1,
      ),
    );
    return TopicTransition(next, <TopicEvent>[
      TopicLifecycleChanged(state.ref, from: state.status, to: status),
    ], randomNumberState: randomNumbers.state);
  }

  /// Undismiss restores pending status only; cleared schedule/priority remain.
  TopicTransition undismiss(TopicState state) {
    if (state.status != Sm20ElementStatus.dismissed) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    final TopicState next = state.copyWith(
      status: Sm20ElementStatus.pending,
      revision: state.revision + 1,
      schedule: state.schedule.copyWith(
        lifecycle: ElementLifecycle.active,
        revision: state.schedule.revision + 1,
      ),
    );
    return TopicTransition(next, <TopicEvent>[
      TopicLifecycleChanged(
        state.ref,
        from: Sm20ElementStatus.dismissed,
        to: Sm20ElementStatus.pending,
      ),
    ], randomNumberState: randomNumbers.state);
  }

  /// Scheduler-visible part of Done/deletion.
  TopicTransition delete(TopicState state, StudyDay today) {
    if (state.status == Sm20ElementStatus.deleted) {
      return TopicTransition.unchanged(state, randomNumbers.state);
    }
    return _clearedStatus(
      state,
      today,
      Sm20ElementStatus.deleted,
      learningControl: state.learningControl,
    );
  }

  TopicState resetHistory(TopicState state) => state.historyBlockId == 0
      ? state
      : state.copyWith(historyBlockId: 0, revision: state.revision + 1);
}
