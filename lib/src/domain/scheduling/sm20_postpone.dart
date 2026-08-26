/// SuperMemo 20 Smart Postpone and automatic-postpone policy.
///
/// This module is deliberately side-effect free. It identifies the exact
/// candidates and target dates that the executable would pass to its low-level
/// rescheduler. Application code persists those mutations for topics and cards
/// in one transaction, while sharing the one application-wide [Sm20Prng].
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../settings/app_settings.dart';
import 'element.dart';
import 'priority_rank.dart';
import 'sm20_numeric.dart';
import 'study_day.dart';
import 'topic_scheduler.dart' show kSm20MaximumStoredInterval;

/// The executable record type used by Smart Postpone.
///
/// Type 1 is an item/card. Types 0, 2 and 4 use topic settings. Type 3 is a
/// deleted record. Other values take the executable's generic 1.01-factor
/// branch.
@immutable
final class Sm20PostponeCandidate {
  Sm20PostponeCandidate({
    required this.ref,
    required this.priority,
    required this.storedInterval,
    required this.lastReviewDay,
    required this.totalPostponements,
    required this.isOutstanding,
    required this.isMemorized,
    this.scheduledDay,
    this.typeCode,
    this.aFactor = 1.2,
    this.forgettingIndex = 10,
    this.isDeleted = false,
  }) {
    if (storedInterval < 0) {
      throw RangeError.value(storedInterval, 'storedInterval');
    }
    if (totalPostponements < 0) {
      throw RangeError.value(totalPostponements, 'totalPostponements');
    }
    if (!aFactor.isFinite || !forgettingIndex.isFinite) {
      throw ArgumentError('A-factor and forgetting index must be finite');
    }
    final int code = effectiveTypeCode;
    if (code < 0 || code > 0xff) {
      throw RangeError.range(code, 0, 0xff, 'typeCode');
    }
  }

  final ElementRef ref;
  final PriorityRank priority;
  final int storedInterval;
  final StudyDay? lastReviewDay;
  final int totalPostponements;
  final bool isOutstanding;
  final bool isMemorized;

  /// Current scheduled repetition, used by automatic-postpone gathering.
  final StudyDay? scheduledDay;

  /// Optional raw executable type. Inference maps cards to 1, extracts to 2,
  /// and sources to 0.
  final int? typeCode;
  final double aFactor;
  final double forgettingIndex;
  final bool isDeleted;

  int get effectiveTypeCode =>
      typeCode ??
      switch (ref.type) {
        ElementType.card => 1,
        ElementType.source => 0,
        ElementType.extract => 2,
      };

  bool get deleted => isDeleted || effectiveTypeCode == 3;
  bool get isItem => effectiveTypeCode == 1;
  bool get isTopicFamily =>
      effectiveTypeCode == 0 ||
      effectiveTypeCode == 2 ||
      effectiveTypeCode == 4;

  int ageOn(StudyDay today) {
    _requireSameZone(today, lastReviewDay, 'lastReviewDay');
    _requireSameZone(today, scheduledDay, 'scheduledDay');
    final int elapsed = lastReviewDay == null
        ? 0
        : lastReviewDay!.daysUntil(today);
    return math.max(math.max(elapsed, storedInterval), 1);
  }
}

enum SmartPostponePass { ordinary, forced }

/// One candidate selected by Smart Postpone.
@immutable
final class SmartPostponeDecision {
  const SmartPostponeDecision({
    required this.candidate,
    required this.pass,
    required this.priorityPercent,
    required this.ageDays,
    required this.delayDays,
    required this.factor,
    required this.newIntervalDays,
    required this.targetDay,
    required this.simulation,
    required this.warnsAboveTwoHundredDays,
    required this.randomDraws,
  });

  final Sm20PostponeCandidate candidate;
  final SmartPostponePass pass;
  final double priorityPercent;
  final int ageDays;

  /// Final dispersed delay, except in simulation (where it is undisposed).
  final int delayDays;
  final double factor;

  /// Interval and target produced by Delay Element before the general
  /// rescheduler applies its memorized/nonmemorized branch.
  final int newIntervalDays;
  final StudyDay targetDay;
  final bool simulation;
  final bool warnsAboveTwoHundredDays;
  final int randomDraws;

  ElementRef get ref => candidate.ref;
  bool get writesRecord => !simulation;
}

/// Complete output of one Smart Postpone pass (or simulation).
@immutable
final class SmartPostponeResult {
  const SmartPostponeResult({
    required this.profile,
    required this.sourceOrder,
    required this.decisions,
    required this.postponed,
    required this.unpostponed,
    required this.forcedPassRan,
    required this.stoppedAtProtectedCount,
    required this.randomDraws,
    required this.prngState,
  });

  final SmartPostponeSettings profile;
  final List<ElementRef> sourceOrder;
  final List<SmartPostponeDecision> decisions;
  final List<ElementRef> postponed;
  final List<ElementRef> unpostponed;
  final bool forcedPassRan;
  final bool stoppedAtProtectedCount;
  final int randomDraws;
  final Sm20PrngState prngState;

  int get warningCount => decisions
      .where((SmartPostponeDecision value) => value.warnsAboveTwoHundredDays)
      .length;
}

/// Exact Smart Postpone evaluator and protected-count outer pass.
final class SmartPostponeEngine {
  const SmartPostponeEngine();

  SmartPostponeResult run({
    required Iterable<Sm20PostponeCandidate> source,
    required SmartPostponeSettings profile,
    required PriorityScale priorityScale,
    required StudyDay today,
    required Sm20Prng prng,
    Iterable<SmartPostponeSettings> applicableSubbranchProfiles =
        const <SmartPostponeSettings>[],
  }) {
    final SmartPostponeSettings effective = mergeSmartPostponeProfiles(
      profile,
      applicableSubbranchProfiles,
    );
    _validateProfile(effective);

    final List<Sm20PostponeCandidate> ordered = source.toList();
    for (final Sm20PostponeCandidate candidate in ordered) {
      _requireSameZone(today, candidate.lastReviewDay, 'lastReviewDay');
      _requireSameZone(today, candidate.scheduledDay, 'scheduledDay');
    }
    if (effective.method == SmartPostponeMethod.topCount) {
      sm20HeapSortDescendingInPlace<Sm20PostponeCandidate>(
        ordered,
        keyOf: (Sm20PostponeCandidate candidate) =>
            priorityScale.positionOf(candidate.priority)?.displayPosition ?? 0,
      );
    }

    final int drawsBefore = prng.drawCount;
    final List<SmartPostponeDecision> decisions = <SmartPostponeDecision>[];
    final Set<ElementRef> postponed = <ElementRef>{};
    var stopped = false;

    bool protectedRemainderReached() =>
        effective.method == SmartPostponeMethod.topCount &&
        ordered.length - postponed.length <= effective.protectedCount;

    for (final Sm20PostponeCandidate candidate in ordered) {
      if (protectedRemainderReached()) {
        stopped = true;
        break;
      }
      if (_outerExcluded(candidate, effective, postponed)) continue;
      final SmartPostponeDecision? decision = _ordinaryDecision(
        candidate: candidate,
        profile: effective,
        priorityScale: priorityScale,
        today: today,
        prng: prng,
      );
      if (decision == null) continue;
      decisions.add(decision);
      postponed.add(candidate.ref);
    }

    var forcedPassRan = false;
    if (effective.method == SmartPostponeMethod.topCount &&
        ordered.length - postponed.length > effective.protectedCount) {
      forcedPassRan = true;
      for (final Sm20PostponeCandidate candidate in ordered) {
        if (protectedRemainderReached()) {
          stopped = true;
          break;
        }
        if (_outerExcluded(candidate, effective, postponed)) continue;
        final SmartPostponeDecision decision = _forcedDecision(
          candidate: candidate,
          profile: effective,
          priorityScale: priorityScale,
          today: today,
        );
        decisions.add(decision);
        postponed.add(candidate.ref);
      }
    }

    final List<ElementRef> sourceOrder = <ElementRef>[
      for (final Sm20PostponeCandidate candidate in ordered) candidate.ref,
    ];
    final List<ElementRef> postponedOrder = <ElementRef>[
      for (final SmartPostponeDecision decision in decisions) decision.ref,
    ];
    final List<ElementRef> unpostponed = <ElementRef>[
      for (final Sm20PostponeCandidate candidate in ordered)
        if (!postponed.contains(candidate.ref)) candidate.ref,
    ];
    return SmartPostponeResult(
      profile: effective,
      sourceOrder: List<ElementRef>.unmodifiable(sourceOrder),
      decisions: List<SmartPostponeDecision>.unmodifiable(decisions),
      postponed: List<ElementRef>.unmodifiable(postponedOrder),
      unpostponed: List<ElementRef>.unmodifiable(unpostponed),
      forcedPassRan: forcedPassRan,
      stoppedAtProtectedCount: stopped,
      randomDraws: prng.drawCount - drawsBefore,
      prngState: prng.state,
    );
  }

  bool _outerExcluded(
    Sm20PostponeCandidate candidate,
    SmartPostponeSettings profile,
    Set<ElementRef> postponed,
  ) =>
      candidate.deleted ||
      (!profile.includeNonOutstanding && !candidate.isOutstanding) ||
      postponed.contains(candidate.ref);

  SmartPostponeDecision? _ordinaryDecision({
    required Sm20PostponeCandidate candidate,
    required SmartPostponeSettings profile,
    required PriorityScale priorityScale,
    required StudyDay today,
    required Sm20Prng prng,
  }) {
    final int age = candidate.ageOn(today);
    final double priority = priorityScale.percentageOf(candidate.priority);

    // Types outside the item/topic families bypass the parameter gates and
    // configured clamps, but still run the common priority scaling and Spread
    // path with the evaluator's default 1.01 factor.
    final bool generic = !candidate.isItem && !candidate.isTopicFamily;

    if (candidate.isItem) {
      if (profile.skipItems ||
          age >= profile.itemAgeCutoffDays ||
          candidate.forgettingIndex < profile.itemForgettingIndexCutoff ||
          candidate.totalPostponements >= profile.itemPostponeCountCutoff ||
          priority < profile.itemPriorityThreshold) {
        return null;
      }
    } else if (!generic) {
      if (profile.skipTopics ||
          age >= profile.topicAgeCutoffDays ||
          candidate.aFactor <= profile.topicAFactorCutoff ||
          candidate.totalPostponements >= profile.topicPostponeCountCutoff ||
          priority < profile.topicPriorityThreshold) {
        return null;
      }
    }

    final int delayPercent = generic
        ? 1
        : candidate.isItem
        ? profile.itemDelayPercent
        : profile.topicDelayPercent;
    final double baseFactor = 1 + delayPercent / 100;
    final int rawDelay = sm20RoundEven(age * baseFactor) - age;
    var delay = sm20RoundEven(2 * rawDelay * math.sqrt(priority / 100));
    delay = math.max(delay, 1);
    if (!generic) {
      final int minimum = candidate.isItem
          ? profile.itemMinimumDelayDays
          : profile.topicMinimumDelayDays;
      final int maximum = candidate.isItem
          ? profile.itemMaximumDelayDays
          : profile.topicMaximumDelayDays;
      delay = delay.clamp(minimum, maximum);
    }
    final bool warns = delay > 200;
    var randomDraws = 0;
    if (!profile.simulate) {
      delay = sm20RoundEven(
        sm20Spread(center: delay.toDouble(), width: delay / 2, prng: prng),
      );
      randomDraws = 2;
    }
    delay = math.max(delay, 1);
    final double factor = (age + delay) / age;
    return _buildDecision(
      candidate: candidate,
      pass: SmartPostponePass.ordinary,
      priority: priority,
      age: age,
      factor: factor,
      today: today,
      simulation: profile.simulate,
      warnsAboveTwoHundredDays: warns,
      randomDraws: randomDraws,
      exactDelay: delay,
    );
  }

  SmartPostponeDecision _forcedDecision({
    required Sm20PostponeCandidate candidate,
    required SmartPostponeSettings profile,
    required PriorityScale priorityScale,
    required StudyDay today,
  }) {
    final int age = candidate.ageOn(today);
    final double priority = priorityScale.percentageOf(candidate.priority);
    final int minimum = candidate.isItem
        ? profile.itemMinimumDelayDays
        : profile.topicMinimumDelayDays;
    final int maximum = candidate.isItem
        ? profile.itemMaximumDelayDays
        : profile.topicMaximumDelayDays;
    final int delay =
        minimum + sm20RoundEven((maximum - minimum) * priority / 100);
    return _buildDecision(
      candidate: candidate,
      pass: SmartPostponePass.forced,
      priority: priority,
      age: age,
      factor: (age + delay) / age,
      today: today,
      simulation: profile.simulate,
      warnsAboveTwoHundredDays: false,
      randomDraws: 0,
      exactDelay: delay,
    );
  }

  SmartPostponeDecision _buildDecision({
    required Sm20PostponeCandidate candidate,
    required SmartPostponePass pass,
    required double priority,
    required int age,
    required double factor,
    required StudyDay today,
    required bool simulation,
    required bool warnsAboveTwoHundredDays,
    required int randomDraws,
    int? exactDelay,
  }) {
    // Delay Element recomputes age without the evaluator's absolute floor of
    // one. This differs only for pending/nonmemorized records reviewed Today,
    // and is what makes that edge case enter memorization at interval one.
    final StudyDay last = candidate.lastReviewDay ?? today;
    final int delayElementAge = math.max(
      last.daysUntil(today),
      candidate.storedInterval,
    );
    var newInterval = sm20RoundEven(delayElementAge * factor);
    if (newInterval <= delayElementAge) newInterval = delayElementAge + 1;
    newInterval = math.min(newInterval, kSm20MaximumStoredInterval);
    final int delay = exactDelay ?? math.max(newInterval - delayElementAge, 1);
    return SmartPostponeDecision(
      candidate: candidate,
      pass: pass,
      priorityPercent: priority,
      ageDays: age,
      delayDays: delay,
      factor: factor,
      newIntervalDays: newInterval,
      targetDay: last.addDays(newInterval),
      simulation: simulation,
      warnsAboveTwoHundredDays: warnsAboveTwoHundredDays,
      randomDraws: randomDraws,
    );
  }
}

/// Applies the executable's nested-profile merge directions.
///
/// [nestedProfiles] must be ordered from the outermost applicable branch to
/// the most specific. Respect copies the most-specific profile exactly.
SmartPostponeSettings mergeSmartPostponeProfiles(
  SmartPostponeSettings base,
  Iterable<SmartPostponeSettings> nestedProfiles,
) {
  final List<SmartPostponeSettings> nested = nestedProfiles.toList();
  if (nested.isEmpty ||
      base.subbranchMode == SmartPostponeSubbranchMode.ignore) {
    return base;
  }
  if (base.subbranchMode == SmartPostponeSubbranchMode.respect) {
    return nested.last;
  }

  var merged = base;
  for (final SmartPostponeSettings child in nested) {
    final bool conservative =
        base.subbranchMode == SmartPostponeSubbranchMode.conservative;
    int mergeDelay(int left, int right) =>
        conservative ? math.min(left, right) : math.max(left, right);
    double mergeThreshold(double left, double right) =>
        conservative ? math.min(left, right) : math.max(left, right);
    int mergeGate(int left, int right) =>
        conservative ? math.max(left, right) : math.min(left, right);
    double mergeGateDouble(double left, double right) =>
        conservative ? math.max(left, right) : math.min(left, right);

    merged = merged.copyWith(
      itemDelayPercent: mergeDelay(
        merged.itemDelayPercent,
        child.itemDelayPercent,
      ),
      topicDelayPercent: mergeDelay(
        merged.topicDelayPercent,
        child.topicDelayPercent,
      ),
      itemMaximumDelayDays: mergeDelay(
        merged.itemMaximumDelayDays,
        child.itemMaximumDelayDays,
      ),
      topicMaximumDelayDays: mergeDelay(
        merged.topicMaximumDelayDays,
        child.topicMaximumDelayDays,
      ),
      itemMinimumDelayDays: mergeDelay(
        merged.itemMinimumDelayDays,
        child.itemMinimumDelayDays,
      ),
      topicMinimumDelayDays: mergeDelay(
        merged.topicMinimumDelayDays,
        child.topicMinimumDelayDays,
      ),
      itemAgeCutoffDays: mergeDelay(
        merged.itemAgeCutoffDays,
        child.itemAgeCutoffDays,
      ),
      topicAgeCutoffDays: mergeDelay(
        merged.topicAgeCutoffDays,
        child.topicAgeCutoffDays,
      ),
      itemPostponeCountCutoff: mergeDelay(
        merged.itemPostponeCountCutoff,
        child.itemPostponeCountCutoff,
      ),
      topicPostponeCountCutoff: mergeDelay(
        merged.topicPostponeCountCutoff,
        child.topicPostponeCountCutoff,
      ),
      itemPriorityThreshold: mergeThreshold(
        merged.itemPriorityThreshold,
        child.itemPriorityThreshold,
      ),
      topicPriorityThreshold: mergeThreshold(
        merged.topicPriorityThreshold,
        child.topicPriorityThreshold,
      ),
      itemForgettingIndexCutoff: mergeGate(
        merged.itemForgettingIndexCutoff,
        child.itemForgettingIndexCutoff,
      ),
      topicAFactorCutoff: mergeGateDouble(
        merged.topicAFactorCutoff,
        child.topicAFactorCutoff,
      ),
      skipItems: conservative
          ? merged.skipItems || child.skipItems
          : merged.skipItems && child.skipItems,
      skipTopics: conservative
          ? merged.skipTopics || child.skipTopics
          : merged.skipTopics && child.skipTopics,
    );
  }
  return merged;
}

enum AutoPostponeOutcome {
  disabled,
  alreadyRanToday,
  staleCollectionDisabled,
  outstandingGate,
  overdueGate,
  ran,
}

/// Inputs read by the executable's automatic-postpone entry point.
@immutable
final class AutoPostponeRequest {
  AutoPostponeRequest({
    required this.today,
    required this.nowUtc,
    required this.autoEnabled,
    required this.lastAutoRunDay,
    required this.collectionNonempty,
    required this.lastCollectionUseUtc,
    required this.force,
    required this.combinedOutstandingCount,
    required this.collectionLearningStartDay,
    required this.scheduledElements,
    required this.defaultProfile,
    required this.priorityScale,
  }) {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
    }
    if (lastCollectionUseUtc != null && !lastCollectionUseUtc!.isUtc) {
      throw ArgumentError.value(
        lastCollectionUseUtc,
        'lastCollectionUseUtc',
        'must be UTC',
      );
    }
    if (combinedOutstandingCount < 0) {
      throw RangeError.value(
        combinedOutstandingCount,
        'combinedOutstandingCount',
      );
    }
    _requireSameZone(today, lastAutoRunDay, 'lastAutoRunDay');
    _requireSameZone(
      today,
      collectionLearningStartDay,
      'collectionLearningStartDay',
    );
  }

  final StudyDay today;
  final DateTime nowUtc;
  final bool autoEnabled;
  final StudyDay? lastAutoRunDay;
  final bool collectionNonempty;
  final DateTime? lastCollectionUseUtc;
  final bool force;
  final int combinedOutstandingCount;
  final StudyDay collectionLearningStartDay;
  final List<Sm20PostponeCandidate> scheduledElements;
  final SmartPostponeSettings defaultProfile;
  final PriorityScale priorityScale;
}

@immutable
final class AutoPostponeResult {
  const AutoPostponeResult({
    required this.outcome,
    required this.lastAutoRunDay,
    required this.disableAutoPostpone,
    required this.overdueCount,
    required this.smartPostpone,
  });

  final AutoPostponeOutcome outcome;
  final StudyDay? lastAutoRunDay;
  final bool disableAutoPostpone;
  final int overdueCount;
  final SmartPostponeResult? smartPostpone;
}

/// The count/profile-driven automatic postponement entry point.
final class AutoPostponeEngine {
  const AutoPostponeEngine({this.smart = const SmartPostponeEngine()});

  final SmartPostponeEngine smart;

  AutoPostponeResult run(AutoPostponeRequest request, Sm20Prng prng) {
    if (!request.autoEnabled) {
      return AutoPostponeResult(
        outcome: AutoPostponeOutcome.disabled,
        lastAutoRunDay: request.lastAutoRunDay,
        disableAutoPostpone: false,
        overdueCount: 0,
        smartPostpone: null,
      );
    }
    if (request.lastAutoRunDay == request.today) {
      return AutoPostponeResult(
        outcome: AutoPostponeOutcome.alreadyRanToday,
        lastAutoRunDay: request.lastAutoRunDay,
        disableAutoPostpone: false,
        overdueCount: 0,
        smartPostpone: null,
      );
    }

    final DateTime? lastUse = request.lastCollectionUseUtc;
    if (!request.force &&
        request.collectionNonempty &&
        lastUse != null &&
        request.nowUtc.difference(lastUse) > const Duration(days: 10)) {
      return AutoPostponeResult(
        outcome: AutoPostponeOutcome.staleCollectionDisabled,
        lastAutoRunDay: request.lastAutoRunDay,
        disableAutoPostpone: true,
        overdueCount: 0,
        smartPostpone: null,
      );
    }

    // The executable records Today before either count gate.
    final StudyDay recordedRunDay = request.today;
    if (request.combinedOutstandingCount <= 10) {
      return AutoPostponeResult(
        outcome: AutoPostponeOutcome.outstandingGate,
        lastAutoRunDay: recordedRunDay,
        disableAutoPostpone: false,
        overdueCount: 0,
        smartPostpone: null,
      );
    }

    final StudyDay yesterday = request.today.addDays(-1);
    final List<Sm20PostponeCandidate> overdue = <Sm20PostponeCandidate>[
      for (final Sm20PostponeCandidate candidate in request.scheduledElements)
        if (candidate.scheduledDay != null &&
            candidate.scheduledDay! >= request.collectionLearningStartDay &&
            candidate.scheduledDay! <= yesterday)
          candidate,
    ];
    if (overdue.length <= 10) {
      return AutoPostponeResult(
        outcome: AutoPostponeOutcome.overdueGate,
        lastAutoRunDay: recordedRunDay,
        disableAutoPostpone: false,
        overdueCount: overdue.length,
        smartPostpone: null,
      );
    }

    final SmartPostponeSettings profile = request.defaultProfile.copyWith(
      includeNonOutstanding: false,
      profileName: '',
      simulate: false,
    );
    final SmartPostponeResult result = smart.run(
      source: overdue,
      profile: profile,
      priorityScale: request.priorityScale,
      today: request.today,
      prng: prng,
    );
    return AutoPostponeResult(
      outcome: AutoPostponeOutcome.ran,
      lastAutoRunDay: recordedRunDay,
      disableAutoPostpone: false,
      overdueCount: overdue.length,
      smartPostpone: result,
    );
  }
}

void _validateProfile(SmartPostponeSettings value) {
  RangeError.checkValueInInterval(
    value.rootElementId,
    0,
    0xffffffff,
    'rootElementId',
  );
  if (value.protectedCount < 1 || value.protectedCount > 20000) {
    throw RangeError.range(value.protectedCount, 1, 20000, 'protectedCount');
  }
  if (value.itemMinimumDelayDays > value.itemMaximumDelayDays ||
      value.topicMinimumDelayDays > value.topicMaximumDelayDays) {
    throw ArgumentError('minimum Smart Postpone delay exceeds maximum');
  }
  RangeError.checkValueInInterval(
    value.itemDelayPercent,
    1,
    400,
    'itemDelayPercent',
  );
  RangeError.checkValueInInterval(
    value.topicDelayPercent,
    1,
    1900,
    'topicDelayPercent',
  );
  RangeError.checkValueInInterval(
    value.itemMaximumDelayDays,
    1,
    300,
    'itemMaximumDelayDays',
  );
  RangeError.checkValueInInterval(
    value.topicMaximumDelayDays,
    1,
    500,
    'topicMaximumDelayDays',
  );
  RangeError.checkValueInInterval(
    value.itemMinimumDelayDays,
    1,
    30,
    'itemMinimumDelayDays',
  );
  RangeError.checkValueInInterval(
    value.topicMinimumDelayDays,
    1,
    100,
    'topicMinimumDelayDays',
  );
  RangeError.checkValueInInterval(
    value.itemAgeCutoffDays,
    2,
    4000,
    'itemAgeCutoffDays',
  );
  RangeError.checkValueInInterval(
    value.topicAgeCutoffDays,
    2,
    4000,
    'topicAgeCutoffDays',
  );
  RangeError.checkValueInInterval(
    value.itemForgettingIndexCutoff,
    3,
    20,
    'itemForgettingIndexCutoff',
  );
  _checkFiniteRange(value.topicAFactorCutoff, 1.01, 6, 'topicAFactorCutoff');
  RangeError.checkValueInInterval(
    value.itemPostponeCountCutoff,
    1,
    255,
    'itemPostponeCountCutoff',
  );
  RangeError.checkValueInInterval(
    value.topicPostponeCountCutoff,
    1,
    255,
    'topicPostponeCountCutoff',
  );
  _checkFiniteRange(
    value.itemPriorityThreshold,
    0.01,
    100,
    'itemPriorityThreshold',
  );
  _checkFiniteRange(
    value.topicPriorityThreshold,
    0.0001,
    100,
    'topicPriorityThreshold',
  );
}

void _checkFiniteRange(
  double value,
  double minimum,
  double maximum,
  String name,
) {
  if (!value.isFinite || value < minimum || value > maximum) {
    throw ArgumentError.value(
      value,
      name,
      'must be finite and in [$minimum, $maximum]',
    );
  }
}

void _requireSameZone(StudyDay expected, StudyDay? actual, String name) {
  if (actual != null && actual.zoneId != expected.zoneId) {
    throw ArgumentError.value(
      actual.zoneId,
      name,
      'must use ${expected.zoneId}',
    );
  }
}
