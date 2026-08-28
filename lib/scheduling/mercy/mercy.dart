/// SuperMemo 20 Mercy scoring, ordering, redistribution, and capacity planner.
///
/// Mercy is a bulk low-level reschedule transaction. It never performs a
/// repetition and therefore never changes topic A, shared priority,
/// repetitions, lapses, or last-review day. The application applies each
/// [Sm20MercyAssignment] through the canonical topic/card rescheduler.
library;

import 'dart:math' as math;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:meta/meta.dart';

const int kSm20MercyMatrixSide = 20;
const int kSm20MercyMatrixLength = 400;
const int kSm20MercyMaximumScore = 1000000;
const int kSm20MercyMaximumDailyCap = 5000;
const int kSm20MercyMaximumHorizonDays = 3650;
const int kSm20MercyLongHorizonWarningDays = 1825;

/// The collection's live 20 by 20 UInt16 interval-factor matrix.
///
/// Values are row-major and scaled by 1000. A collection that has never been
/// customized uses [sm20Default], which is what SM20 itself writes into a
/// brand-new collection; see that member for the evidence.
@immutable
final class Sm20MercyMatrix {
  Sm20MercyMatrix(Iterable<int> values)
    : values = List<int>.unmodifiable(values) {
    if (this.values.length != kSm20MercyMatrixLength) {
      throw ArgumentError.value(
        this.values.length,
        'values.length',
        'must be $kSm20MercyMatrixLength',
      );
    }
    for (var index = 0; index < this.values.length; index += 1) {
      RangeError.checkValueInInterval(
        this.values[index],
        0,
        0xffff,
        'values[$index]',
      );
    }
  }

  /// Uses the collection's own matrix, or SM20's starting matrix when the
  /// collection has never customized one.
  factory Sm20MercyMatrix.fromSettings(MercySettings settings) {
    final List<int>? values = settings.intervalFactorMatrix;
    return values == null ? sm20Default : Sm20MercyMatrix(values);
  }

  /// The matrix SM20 writes into a newly created collection.
  ///
  /// This is not an invented fallback. Two collections created independently
  /// by the executable ship a byte-identical `info/sm8opt.dat` whose first 800
  /// bytes are this table, so it is the program's own starting estimate rather
  /// than state belonging to one collection. Values are UInt16 scaled by 1000.
  ///
  /// Every cell outside column zero satisfies
  /// `sm20RoundEven(1000 * (1.2 + 0.3 * row / column))` exactly, verified
  /// against all 380 of them. The rounding is the same round-half-even rule
  /// section 3.1 gives for the scheduler, and it has to be evaluated in
  /// float64 rather than on the exact rational: three cells that look like
  /// ties arrive just below one — 1537.4999999999998 at [9][8] and [18][16],
  /// 1612.4999999999998 at [11][8] — and so round down, while the twelve
  /// genuine ties all settle on the even value. Generating the cells
  /// rather than pasting 400 literals keeps that rule visible; column zero
  /// follows no such rule and is listed.
  ///
  /// A live collection refines these numbers as it is used. This app does not
  /// yet do that, so Mercy's investment term is a starting estimate — one of
  /// five weighted score inputs, not a precision quantity.
  static final Sm20MercyMatrix sm20Default = Sm20MercyMatrix(<int>[
    for (var row = 0; row < kSm20MercyMatrixSide; row += 1)
      for (var column = 0; column < kSm20MercyMatrixSide; column += 1)
        if (column == 0)
          _sm20DefaultFirstColumn[row]
        else
          sm20RoundEven(1000.0 * (1.2 + 0.3 * row / column)),
  ]);

  /// Column zero of [sm20Default]. It is a falling series, not a formula.
  static const List<int> _sm20DefaultFirstColumn = <int>[
    2484, 2347, 2217, 2094, 1978, 1868, 1765, 1667, 1575, 1487, //
    1405, 1327, 1254, 1184, 1119, 1057, 998, 943, 890, 841,
  ];

  final List<int> values;

  int valueAt(int row, int column) {
    RangeError.checkValueInInterval(row, 0, kSm20MercyMatrixSide - 1, 'row');
    RangeError.checkValueInInterval(
      column,
      0,
      kSm20MercyMatrixSide - 1,
      'column',
    );
    return values[row * kSm20MercyMatrixSide + column];
  }

  double factorAt(int row, int column) => valueAt(row, column) / 1000;

  @override
  bool operator ==(Object other) {
    if (other is! Sm20MercyMatrix || other.values.length != values.length) {
      return false;
    }
    for (var index = 0; index < values.length; index += 1) {
      if (other.values[index] != values[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(values);
}

/// Exact five stored Mercy weights.
///
/// The executable's storage order is Importance, Lateness, Investment,
/// Easiness, Recency. Named fields avoid accidentally treating that order as
/// the score formula's display order.
@immutable
final class Sm20MercyWeights {
  const Sm20MercyWeights({
    this.importance = 10,
    this.lateness = 3,
    this.investment = 4,
    this.easiness = 1,
    this.recency = 1,
  });

  factory Sm20MercyWeights.fromSettings(MercySettings settings) =>
      Sm20MercyWeights(
        importance: settings.importanceWeight,
        lateness: settings.latenessWeight,
        investment: settings.investmentWeight,
        easiness: settings.easinessWeight,
        recency: settings.recencyWeight,
      );

  final double importance;
  final double lateness;
  final double investment;
  final double easiness;
  final double recency;

  double get total => importance + lateness + investment + easiness + recency;

  void validate() {
    final List<double> values = <double>[
      importance,
      lateness,
      investment,
      easiness,
      recency,
    ];
    if (values.any((double value) => !value.isFinite || value < 0)) {
      throw ArgumentError('Mercy weights must be finite and non-negative');
    }
    if (total <= 0) {
      throw ArgumentError('at least one Mercy weight must be positive');
    }
  }
}

/// One scheduled item or topic that Mercy can gather.
@immutable
final class Sm20MercyCandidate {
  Sm20MercyCandidate({
    required this.ref,
    required this.priority,
    required this.scheduledDay,
    required this.lastReviewDay,
    required this.repetitionCount,
    required this.lapseCount,
    this.storedInterval = 0,
    this.isScheduled = true,
    this.isDeleted = false,
    this.revision = 1,
  }) {
    if (repetitionCount < 0 || lapseCount < 0 || storedInterval < 0) {
      throw RangeError('Mercy counters and interval cannot be negative');
    }
    if (revision < 1) {
      throw RangeError.value(revision, 'revision', 'must be positive');
    }
    _requireSameZone(scheduledDay, lastReviewDay, 'lastReviewDay');
  }

  final ElementRef ref;
  final PriorityRank priority;
  final StudyDay scheduledDay;
  final StudyDay? lastReviewDay;
  final int repetitionCount;
  final int lapseCount;
  final int storedInterval;
  final bool isScheduled;
  final bool isDeleted;
  final int revision;

  bool get isItem => ref.type == ElementType.card;

  int ageOn(StudyDay today) {
    _requireSameZone(today, scheduledDay, 'scheduledDay');
    _requireSameZone(today, lastReviewDay, 'lastReviewDay');
    return math.max(lastReviewDay?.daysUntil(today) ?? 1, 1);
  }
}

enum Sm20MercyGatherMode { collection, subset }

/// Full score breakdown retained for diagnostics and exact fixture tests.
@immutable
final class Sm20MercyScore {
  const Sm20MercyScore({
    required this.value,
    required this.recency,
    required this.investment,
    required this.importance,
    required this.lateness,
    required this.easiness,
    required this.investmentBase,
  });

  final int value;
  final double recency;
  final double investment;
  final double importance;
  final double lateness;
  final double easiness;
  final double investmentBase;
}

/// One actual target-day rewrite produced by Mercy.
@immutable
final class Sm20MercyAssignment {
  const Sm20MercyAssignment({
    required this.candidate,
    required this.score,
    required this.sourceIndex,
    required this.orderedIndex,
    required this.targetDay,
  });

  final Sm20MercyCandidate candidate;
  final Sm20MercyScore score;
  final int sourceIndex;
  final int orderedIndex;
  final StudyDay targetDay;

  ElementRef get ref => candidate.ref;
}

/// Side-effect-free Mercy output ready for one persistence transaction.
@immutable
final class Sm20MercyPlan {
  const Sm20MercyPlan({
    required this.gathered,
    required this.ordered,
    required this.assignments,
    required this.scores,
    required this.reschedulingDays,
    required this.blockSize,
    required this.randomDraws,
    required this.prngState,
    required this.deletedPlaceholderCount,
  });

  final List<Sm20MercyCandidate> gathered;

  /// Candidate order after scoring/sorting/randomization. Deleted subset rows
  /// are represented by null, exactly like executable element-zero slots.
  final List<Sm20MercyCandidate?> ordered;
  final List<Sm20MercyAssignment> assignments;
  final Map<ElementRef, Sm20MercyScore> scores;
  final int reschedulingDays;
  final int blockSize;
  final int randomDraws;
  final Sm20PrngState prngState;
  final int deletedPlaceholderCount;
}

final class _MercySlot {
  const _MercySlot({
    required this.candidate,
    required this.sourceIndex,
    required this.score,
  });

  final Sm20MercyCandidate? candidate;
  final int sourceIndex;
  final Sm20MercyScore? score;
}

/// Exact Mercy gather, score, order, and due-date assignment engine.
final class Sm20MercyEngine {
  const Sm20MercyEngine();

  Sm20MercyPlan plan({
    required Iterable<Sm20MercyCandidate> candidates,
    required Sm20MercyGatherMode gatherMode,
    required StudyDay today,
    required StudyDay collectionLearningStartDay,
    required int gatheringDays,
    required int reschedulingDays,
    required MercyMode mode,
    required Sm20MercyMatrix matrix,
    required Sm20MercyWeights weights,
    required PriorityScale priorityScale,
    required Sm20Prng prng,
  }) {
    _validateHorizon(gatheringDays, 'gatheringDays');
    _validateHorizon(reschedulingDays, 'reschedulingDays');
    weights.validate();
    _requireSameZone(
      today,
      collectionLearningStartDay,
      'collectionLearningStartDay',
    );

    final List<Sm20MercyCandidate> supplied = candidates.toList();
    for (final Sm20MercyCandidate candidate in supplied) {
      _requireSameZone(today, candidate.scheduledDay, 'scheduledDay');
      _requireSameZone(today, candidate.lastReviewDay, 'lastReviewDay');
    }
    final List<Sm20MercyCandidate> gathered = switch (gatherMode) {
      Sm20MercyGatherMode.collection => _gatherCollection(
        supplied,
        learningStart: collectionLearningStartDay,
        end: today.addDays(gatheringDays - 1),
      ),
      Sm20MercyGatherMode.subset => supplied,
    };

    final List<_MercySlot> slots = <_MercySlot>[];
    final Map<ElementRef, Sm20MercyScore> scores =
        <ElementRef, Sm20MercyScore>{};
    for (var index = 0; index < gathered.length; index += 1) {
      final Sm20MercyCandidate candidate = gathered[index];
      if (candidate.isDeleted) {
        slots.add(_MercySlot(candidate: null, sourceIndex: index, score: null));
        continue;
      }
      final Sm20MercyScore score = scoreCandidate(
        candidate,
        today: today,
        reschedulingDays: reschedulingDays,
        matrix: matrix,
        weights: weights,
        priorityPercent: priorityScale.percentageOf(candidate.priority),
      );
      scores[candidate.ref] = score;
      slots.add(
        _MercySlot(candidate: candidate, sourceIndex: index, score: score),
      );
    }

    final int drawsBefore = prng.drawCount;
    switch (mode) {
      case MercyMode.highScoreFirst:
        sm20HeapSortDescendingInPlace<_MercySlot>(
          slots,
          keyOf: (_MercySlot slot) => slot.score?.value ?? 0,
        );
      case MercyMode.lowScoreFirst:
        sm20HeapSortDescendingInPlace<_MercySlot>(
          slots,
          keyOf: (_MercySlot slot) => slot.score == null
              ? 0
              : kSm20MercyMaximumScore - slot.score!.value,
        );
      case MercyMode.sourceOrder:
        break;
      case MercyMode.random:
        _fixedSizeRandomize(slots, prng);
    }

    final int count = slots.length;
    final int blockSize = count == 0 ? 0 : (count / reschedulingDays).ceil();
    final List<Sm20MercyAssignment> assignments = <Sm20MercyAssignment>[];
    if (blockSize > 0) {
      for (var day = 1; day <= reschedulingDays; day += 1) {
        for (var position = 1; position <= blockSize; position += 1) {
          final int oneBasedIndex =
              (day - 1) * blockSize + (blockSize - position + 1);
          if (oneBasedIndex > count) continue;
          final _MercySlot slot = slots[oneBasedIndex - 1];
          final Sm20MercyCandidate? candidate = slot.candidate;
          final Sm20MercyScore? score = slot.score;
          if (candidate == null || score == null) continue;
          assignments.add(
            Sm20MercyAssignment(
              candidate: candidate,
              score: score,
              sourceIndex: slot.sourceIndex,
              orderedIndex: oneBasedIndex - 1,
              targetDay: today.addDays(day - 1),
            ),
          );
        }
      }
    }

    return Sm20MercyPlan(
      gathered: List<Sm20MercyCandidate>.unmodifiable(gathered),
      ordered: List<Sm20MercyCandidate?>.unmodifiable(<Sm20MercyCandidate?>[
        for (final _MercySlot slot in slots) slot.candidate,
      ]),
      assignments: List<Sm20MercyAssignment>.unmodifiable(assignments),
      scores: Map<ElementRef, Sm20MercyScore>.unmodifiable(scores),
      reschedulingDays: reschedulingDays,
      blockSize: blockSize,
      randomDraws: prng.drawCount - drawsBefore,
      prngState: prng.state,
      deletedPlaceholderCount: slots
          .where((_MercySlot value) => value.candidate == null)
          .length,
    );
  }

  /// Executable-derived collection-dependent score for one candidate.
  Sm20MercyScore scoreCandidate(
    Sm20MercyCandidate candidate, {
    required StudyDay today,
    required int reschedulingDays,
    required Sm20MercyMatrix matrix,
    required Sm20MercyWeights weights,
    required double priorityPercent,
  }) {
    if (reschedulingDays < 1) {
      throw RangeError.value(reschedulingDays, 'reschedulingDays');
    }
    if (!priorityPercent.isFinite ||
        priorityPercent < 0 ||
        priorityPercent > 100) {
      throw RangeError.range(priorityPercent, 0, 100, 'priorityPercent');
    }
    weights.validate();
    final int repetitions = math.min(candidate.repetitionCount, 20);
    var expectedInterval = matrix.factorAt(0, 0);
    for (var k = 2; k <= repetitions; k += 1) {
      expectedInterval *= matrix.factorAt(6, k - 1);
    }

    final int age = candidate.ageOn(today);
    final double investmentBase = math.min(expectedInterval, age.toDouble());
    final int lapses = candidate.lapseCount;
    final double lapseOrder = lapses / (lapses + 1);
    final double ageOrder = age / (age + 200);

    final double recency = 0.65 * (1 - ageOrder) + 0.35 * (1 - lapseOrder);
    final double investment =
        0.5 * (investmentBase / (investmentBase + 400)) +
        0.5 * (repetitions / (repetitions + 3));
    final double importance = 1 - priorityPercent / 100;

    final StudyDay candidateDay = today.addDays(reschedulingDays - 1);
    final int candidateAge = math.max(
      candidate.lastReviewDay?.daysUntil(candidateDay) ?? 1,
      1,
    );
    final double ratio = investmentBase == 0
        ? 0
        : candidateAge / investmentBase;
    final double ratioOrder = ratio / (ratio + 1.4);
    final double lateness = 0.6 * ratioOrder + 0.4 * ageOrder;
    final double easiness = 0.7 * (1 - lapseOrder) + 0.3 * (1 - lateness);

    final double weighted =
        (weights.recency * recency +
            weights.investment * investment +
            weights.easiness * easiness +
            weights.importance * importance +
            weights.lateness * lateness) /
        weights.total;
    final int value = sm20RoundEven(
      weighted.clamp(0, 1).toDouble() * kSm20MercyMaximumScore,
    );
    return Sm20MercyScore(
      value: value,
      recency: recency,
      investment: investment,
      importance: importance,
      lateness: lateness,
      easiness: easiness,
      investmentBase: investmentBase,
    );
  }

  List<Sm20MercyCandidate> _gatherCollection(
    List<Sm20MercyCandidate> source, {
    required StudyDay learningStart,
    required StudyDay end,
  }) {
    bool admitted(Sm20MercyCandidate value) =>
        value.isScheduled &&
        !value.isDeleted &&
        value.scheduledDay >= learningStart &&
        value.scheduledDay <= end;
    return <Sm20MercyCandidate>[
      for (final Sm20MercyCandidate value in source)
        if (admitted(value) && value.isItem) value,
      for (final Sm20MercyCandidate value in source)
        if (admitted(value) && !value.isItem) value,
    ];
  }

  void _fixedSizeRandomize(List<_MercySlot> slots, Sm20Prng prng) {
    final int count = slots.length;
    for (var index = 0; index < count; index += 1) {
      final int other = prng.nextInt(count);
      final _MercySlot value = slots[index];
      slots[index] = slots[other];
      slots[other] = value;
    }
  }
}

/// Finite scheduled-count input used by the Mercy UI's exact solver.
@immutable
final class Sm20ScheduledCounts {
  Sm20ScheduledCounts(Map<StudyDay, int> counts)
    : _counts = Map<int, int>.unmodifiable(<int, int>{
        for (final MapEntry<StudyDay, int> entry in counts.entries)
          entry.key.epochDay: math.max(entry.value, 0),
      }),
      zoneId = counts.isEmpty ? null : counts.keys.first.zoneId {
    if (counts.values.any((int value) => value < 0)) {
      // ScheduledCount is maxed with zero by the executable, so negative
      // imported values are accepted and normalized above.
    }
    final String? zone = zoneId;
    if (zone != null && counts.keys.any((StudyDay day) => day.zoneId != zone)) {
      throw ArgumentError('scheduled counts span more than one timezone');
    }
  }

  final Map<int, int> _counts;
  final String? zoneId;

  int countOn(StudyDay day) {
    if (zoneId != null && day.zoneId != zoneId) {
      throw ArgumentError.value(day.zoneId, 'day', 'must use $zoneId');
    }
    return math.max(_counts[day.epochDay] ?? 0, 0);
  }
}

/// Values maintained together by the Mercy capacity dialog.
@immutable
final class Sm20MercyCapacity {
  const Sm20MercyCapacity({
    required this.candidateCount,
    required this.elementsPerDay,
    required this.reschedulingDays,
    required this.gatheringDays,
    required this.includeFuture,
  });

  final int candidateCount;
  final int elementsPerDay;
  final int reschedulingDays;
  final int gatheringDays;
  final bool includeFuture;

  bool get warnsAboutLongHorizon =>
      reschedulingDays > kSm20MercyLongHorizonWarningDays ||
      gatheringDays > kSm20MercyLongHorizonWarningDays;
}

/// Which linked horizon control initiated an R/G recomputation.
enum Sm20MercyHorizonField { reschedulingDays, gatheringDays }

/// Exact recomputation paths behind Mercy's R/G/C controls.
final class Sm20MercyCapacityPlanner {
  const Sm20MercyCapacityPlanner();

  /// Called after editing R or G.
  Sm20MercyCapacity afterHorizonEdit({
    required StudyDay today,
    required StudyDay collectionLearningStartDay,
    required int reschedulingDays,
    required int gatheringDays,
    required bool includeFuture,
    required Sm20ScheduledCounts scheduledCounts,
    int? subsetCandidateCount,
    Sm20MercyHorizonField editedField = Sm20MercyHorizonField.reschedulingDays,
  }) {
    _validateHorizon(reschedulingDays, 'reschedulingDays');
    _validateHorizon(gatheringDays, 'gatheringDays');
    _requireSameZone(
      today,
      collectionLearningStartDay,
      'collectionLearningStartDay',
    );
    var adjustedRescheduling = reschedulingDays;
    var adjustedGathering = gatheringDays;
    if (!includeFuture) {
      if (editedField == Sm20MercyHorizonField.reschedulingDays) {
        adjustedGathering = adjustedRescheduling;
      } else {
        adjustedRescheduling = adjustedGathering;
      }
    } else if (adjustedRescheduling > adjustedGathering) {
      if (editedField == Sm20MercyHorizonField.reschedulingDays) {
        adjustedGathering = adjustedRescheduling;
      } else {
        adjustedRescheduling = adjustedGathering;
      }
    }
    final int count =
        subsetCandidateCount ??
        _sum(
          scheduledCounts,
          collectionLearningStartDay,
          today.addDays(adjustedGathering - 1),
        );
    if (count < 0) {
      throw RangeError.value(count, 'subsetCandidateCount');
    }
    final int perDay = count == 0 ? 0 : (count / adjustedRescheduling).ceil();
    return Sm20MercyCapacity(
      candidateCount: count,
      elementsPerDay: perDay,
      reschedulingDays: adjustedRescheduling,
      gatheringDays: adjustedGathering,
      includeFuture: includeFuture,
    );
  }

  /// Called after editing C. [subsetCandidateCount] selects the subset shortcut
  /// used by the executable in nonfuture mode.
  Sm20MercyCapacity afterDailyCapEdit({
    required StudyDay today,
    required StudyDay collectionLearningStartDay,
    required int elementsPerDay,
    required int gatheringDays,
    required bool includeFuture,
    required Sm20ScheduledCounts scheduledCounts,
    int? subsetCandidateCount,
  }) {
    RangeError.checkValueInInterval(
      elementsPerDay,
      1,
      kSm20MercyMaximumDailyCap,
      'elementsPerDay',
    );
    _validateHorizon(gatheringDays, 'gatheringDays');
    _requireSameZone(
      today,
      collectionLearningStartDay,
      'collectionLearningStartDay',
    );
    if (!includeFuture && subsetCandidateCount != null) {
      if (subsetCandidateCount < 0) {
        throw RangeError.value(subsetCandidateCount, 'subsetCandidateCount');
      }
      final int days = subsetCandidateCount == 0
          ? 0
          : (subsetCandidateCount / elementsPerDay).ceil();
      return Sm20MercyCapacity(
        candidateCount: subsetCandidateCount,
        elementsPerDay: elementsPerDay,
        reschedulingDays: days,
        gatheringDays: days,
        includeFuture: false,
      );
    }
    return includeFuture
        ? _solveFuture(
            today: today,
            learningStart: collectionLearningStartDay,
            elementsPerDay: elementsPerDay,
            gatheringDays: gatheringDays,
            counts: scheduledCounts,
          )
        : _solveNonfuture(
            today: today,
            learningStart: collectionLearningStartDay,
            elementsPerDay: elementsPerDay,
            counts: scheduledCounts,
          );
  }

  Sm20MercyCapacity _solveNonfuture({
    required StudyDay today,
    required StudyDay learningStart,
    required int elementsPerDay,
    required Sm20ScheduledCounts counts,
  }) {
    var balance = 0;
    var allocated = 0;
    var day = math.min(learningStart.epochDay - 1, today.epochDay - 1);
    do {
      day += 1;
      final StudyDay current = _fromEpochDay(day, today.zoneId);
      final int count = counts.countOn(current);
      if (day >= today.epochDay) {
        allocated += elementsPerDay;
        balance = balance - elementsPerDay + count;
      } else {
        balance += count;
      }
    } while (day < today.epochDay || balance > 0);

    final int candidateCount = allocated + balance;
    final int days = day - today.epochDay + 1;
    return Sm20MercyCapacity(
      candidateCount: candidateCount,
      elementsPerDay: elementsPerDay,
      reschedulingDays: days,
      gatheringDays: days,
      includeFuture: false,
    );
  }

  Sm20MercyCapacity _solveFuture({
    required StudyDay today,
    required StudyDay learningStart,
    required int elementsPerDay,
    required int gatheringDays,
    required Sm20ScheduledCounts counts,
  }) {
    final int horizonEnd = today.epochDay + gatheringDays - 1;
    var balance = _sum(counts, learningStart, today.addDays(gatheringDays - 1));
    var allocated = 0;
    var day = math.min(learningStart.epochDay - 1, today.epochDay - 1);
    do {
      day += 1;
      final StudyDay current = _fromEpochDay(day, today.zoneId);
      final int count = counts.countOn(current);
      if (day > horizonEnd) balance += count;
      if (day >= today.epochDay) {
        allocated += elementsPerDay;
        balance -= elementsPerDay;
      }
    } while (balance > 0);

    final int candidateCount = allocated + balance;
    final int days = day - today.epochDay + 1;
    return Sm20MercyCapacity(
      candidateCount: candidateCount,
      elementsPerDay: elementsPerDay,
      reschedulingDays: days,
      gatheringDays: math.max(gatheringDays, days),
      includeFuture: true,
    );
  }

  int _sum(Sm20ScheduledCounts counts, StudyDay start, StudyDay end) {
    if (end < start) return 0;
    var result = 0;
    for (var day = start.epochDay; day <= end.epochDay; day += 1) {
      result += counts.countOn(_fromEpochDay(day, start.zoneId));
    }
    return result;
  }
}

void _validateHorizon(int value, String name) {
  RangeError.checkValueInInterval(value, 1, kSm20MercyMaximumHorizonDays, name);
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

StudyDay _fromEpochDay(int epochDay, String zoneId) {
  final DateTime value = DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return StudyDay(
    year: value.year,
    month: value.month,
    day: value.day,
    zoneId: zoneId,
  );
}
