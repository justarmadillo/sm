/// Operational scheduler metrics for the canonical SM20 schedule.
///
/// This module is deliberately a pure reporting boundary. Persistence adapters
/// project canonical card instants, topic StudyDays, and append-only events
/// into the samples below; the collector only aggregates those samples. In
/// particular, metrics never feed queue admission and never manufacture
/// reviews.
library;

import 'dart:math' as math;

import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:meta/meta.dart';

/// Version of the reporting definitions in this file.
///
/// **[Product decision]** Versioning the definitions makes later changes to a
/// reporting window or percentile estimator visible instead of rewriting old
/// dashboards in place.
const String schedulerMetricsPolicyVersion = 'scheduler_metrics_sm20/1';

/// Number of StudyDays in the forward-looking due series.
const int schedulerDueHorizonDays = 30;

/// A reporting projection of one schedulable element's canonical due day.
///
/// Card adapters map their exact UTC instant through the configured
/// [StudyDayCalendar]. This reporting projection does not turn a card's
/// canonical instant into a day-based schedule.
@immutable
final class DueMetricSample {
  DueMetricSample({
    required this.element,
    required this.due,
    required this.branchId,
    this.estimatedForegroundMs = 0,
  }) {
    _requireText(element.id, 'element.id');
    _requireText(branchId, 'branchId');
    _requireNonNegative(estimatedForegroundMs, 'estimatedForegroundMs');
  }

  final ElementRef element;
  final StudyDay due;
  final String branchId;

  /// A forecast input for branch workload reporting, never admission.
  final int estimatedForegroundMs;
}

/// Event-derived counters for one StudyDay.
///
/// `actualCardReviews` means genuine, non-practice, non-undone reviews.
/// `topicsCompleted` means idempotent genuine topic encounters. Adapters must
/// apply those event semantics before constructing this value.
@immutable
final class DailySchedulerActivity {
  DailySchedulerActivity({
    required this.day,
    this.manualLaterCount = 0,
    this.actualCardReviews = 0,
    this.topicsCompleted = 0,
    this.cardOpportunities = 0,
    this.topicOpportunities = 0,
    this.cardForegroundMs = 0,
    this.topicForegroundMs = 0,
  }) {
    final Map<String, int> values = <String, int>{
      'manualLaterCount': manualLaterCount,
      'actualCardReviews': actualCardReviews,
      'topicsCompleted': topicsCompleted,
      'cardOpportunities': cardOpportunities,
      'topicOpportunities': topicOpportunities,
      'cardForegroundMs': cardForegroundMs,
      'topicForegroundMs': topicForegroundMs,
    };
    for (final MapEntry<String, int> entry in values.entries) {
      _requireNonNegative(entry.value, entry.key);
    }
  }

  final StudyDay day;
  final int manualLaterCount;
  final int actualCardReviews;
  final int topicsCompleted;
  final int cardOpportunities;
  final int topicOpportunities;
  final int cardForegroundMs;
  final int topicForegroundMs;
}

/// One confirmed Mercy batch in the reporting period.
@immutable
final class MercyBatchMetricSample {
  MercyBatchMetricSample({
    required this.batchId,
    required this.studyDay,
    required this.size,
  }) {
    _requireText(batchId, 'batchId');
    _requireNonNegative(size, 'size');
  }

  final String batchId;
  final StudyDay studyDay;
  final int size;
}

/// One lateness observation and, for a card, its measured recall outcome.
@immutable
final class PriorityOutcomeMetricSample {
  PriorityOutcomeMetricSample({
    required this.elementType,
    required this.priorityDecile,
    required this.latenessDays,
    this.cardRecalled,
  }) {
    if (priorityDecile < 1 || priorityDecile > 10) {
      throw ArgumentError.value(
        priorityDecile,
        'priorityDecile',
        'must be in 1..10',
      );
    }
    if (!latenessDays.isFinite || latenessDays < 0) {
      throw ArgumentError.value(
        latenessDays,
        'latenessDays',
        'must be finite and non-negative',
      );
    }
    if (elementType.isTopic && cardRecalled != null) {
      throw ArgumentError('topic outcomes cannot carry card retention');
    }
  }

  /// Converts a canonical percentile fraction (`0` at the top) to 1..10.
  static int decileForPriorityFraction(double priorityFraction) {
    if (!priorityFraction.isFinite) {
      throw ArgumentError.value(
        priorityFraction,
        'priorityFraction',
        'must be finite',
      );
    }
    final double bounded = priorityFraction.clamp(0, 1).toDouble();
    if (bounded == 1) return 10;
    return (bounded * 10).floor() + 1;
  }

  final ElementType elementType;
  final int priorityDecile;
  final double latenessDays;

  /// `true` for successful recall, `false` for Again, null if not measured.
  final bool? cardRecalled;
}

/// Forecast input for one branch and scheduling domain.
@immutable
final class BranchWorkloadMetricSample {
  BranchWorkloadMetricSample({
    required this.branchId,
    required this.elementType,
    required this.count,
    required this.estimatedForegroundMs,
  }) {
    _requireText(branchId, 'branchId');
    _requireNonNegative(count, 'count');
    _requireNonNegative(estimatedForegroundMs, 'estimatedForegroundMs');
  }

  final String branchId;
  final ElementType elementType;
  final int count;
  final int estimatedForegroundMs;
}

/// The result of one genuine topic encounter, grouped by policy version.
@immutable
final class TopicEncounterMetricSample {
  TopicEncounterMetricSample({
    required this.policyVersion,
    required this.intervalDays,
    this.aFactor,
  }) {
    _requireText(policyVersion, 'policyVersion');
    if (!intervalDays.isFinite || intervalDays <= 0) {
      throw ArgumentError.value(
        intervalDays,
        'intervalDays',
        'must be finite and positive',
      );
    }
    final double? factor = aFactor;
    if (factor != null && (!factor.isFinite || factor <= 0)) {
      throw ArgumentError.value(
        factor,
        'aFactor',
        'must be finite and positive when present',
      );
    }
  }

  final String policyVersion;
  final double intervalDays;

  /// Null is valid when no A-Factor measurement was recorded.
  final double? aFactor;
}

/// Fully normalized input to [SchedulerMetricsCollector].
@immutable
final class SchedulerMetricsInput {
  factory SchedulerMetricsInput({
    required StudyDay asOfStudyDay,
    StudyDay? activityStart,
    StudyDay? activityEnd,
    Iterable<DueMetricSample> due = const <DueMetricSample>[],
    Iterable<DailySchedulerActivity> activity =
        const <DailySchedulerActivity>[],
    Iterable<MercyBatchMetricSample> mercyBatches =
        const <MercyBatchMetricSample>[],
    Iterable<PriorityOutcomeMetricSample> priorityOutcomes =
        const <PriorityOutcomeMetricSample>[],
    Iterable<BranchWorkloadMetricSample> futureWorkload =
        const <BranchWorkloadMetricSample>[],
    Iterable<TopicEncounterMetricSample> topicEncounters =
        const <TopicEncounterMetricSample>[],
  }) {
    final StudyDay start = activityStart ?? asOfStudyDay.addDays(-29);
    final StudyDay end = activityEnd ?? asOfStudyDay;
    _requireSameZone(asOfStudyDay, start);
    _requireSameZone(asOfStudyDay, end);
    if (end < start) {
      throw ArgumentError('activityEnd cannot precede activityStart');
    }

    final List<DueMetricSample> dueList = due.toList(growable: false);
    final Set<ElementRef> dueElements = <ElementRef>{};
    for (final DueMetricSample sample in dueList) {
      _requireSameZone(asOfStudyDay, sample.due);
      if (!dueElements.add(sample.element)) {
        throw ArgumentError('duplicate due sample for ${sample.element}');
      }
    }

    final List<DailySchedulerActivity> activityList = activity.toList(
      growable: false,
    );
    for (final DailySchedulerActivity sample in activityList) {
      _requireSameZone(asOfStudyDay, sample.day);
    }
    final List<MercyBatchMetricSample> mercyList = mercyBatches.toList(
      growable: false,
    );
    final Set<String> mercyIds = <String>{};
    for (final MercyBatchMetricSample sample in mercyList) {
      _requireSameZone(asOfStudyDay, sample.studyDay);
      if (!mercyIds.add(sample.batchId)) {
        throw ArgumentError('duplicate Mercy batch ${sample.batchId}');
      }
    }
    return SchedulerMetricsInput._(
      asOfStudyDay: asOfStudyDay,
      activityStart: start,
      activityEnd: end,
      due: List<DueMetricSample>.unmodifiable(dueList),
      activity: List<DailySchedulerActivity>.unmodifiable(activityList),
      mercyBatches: List<MercyBatchMetricSample>.unmodifiable(mercyList),
      priorityOutcomes: List<PriorityOutcomeMetricSample>.unmodifiable(
        priorityOutcomes,
      ),
      futureWorkload: List<BranchWorkloadMetricSample>.unmodifiable(
        futureWorkload,
      ),
      topicEncounters: List<TopicEncounterMetricSample>.unmodifiable(
        topicEncounters,
      ),
    );
  }

  const SchedulerMetricsInput._({
    required this.asOfStudyDay,
    required this.activityStart,
    required this.activityEnd,
    required this.due,
    required this.activity,
    required this.mercyBatches,
    required this.priorityOutcomes,
    required this.futureWorkload,
    required this.topicEncounters,
  });

  final StudyDay asOfStudyDay;
  final StudyDay activityStart;
  final StudyDay activityEnd;
  final List<DueMetricSample> due;
  final List<DailySchedulerActivity> activity;
  final List<MercyBatchMetricSample> mercyBatches;
  final List<PriorityOutcomeMetricSample> priorityOutcomes;
  final List<BranchWorkloadMetricSample> futureWorkload;
  final List<TopicEncounterMetricSample> topicEncounters;
}

/// Canonical scheduled load for one future StudyDay.
@immutable
final class DueLoadMetric {
  const DueLoadMetric({
    required this.studyDay,
    required this.cards,
    required this.topics,
  });

  final StudyDay studyDay;
  final int cards;
  final int topics;
}

/// A ratio that preserves its raw counts and is null when undefined.
@immutable
final class RatioMetric {
  const RatioMetric({required this.numerator, required this.denominator});

  final int numerator;
  final int denominator;

  double? get value => denominator == 0 ? null : numerator / denominator;
}

/// Stable summary of a numeric distribution.
@immutable
final class DistributionMetric {
  const DistributionMetric._({
    required this.count,
    required this.minimum,
    required this.median,
    required this.p95,
    required this.maximum,
    required this.mean,
  });

  factory DistributionMetric.of(Iterable<double> values) {
    final List<double> sorted = values.toList()..sort();
    if (sorted.any((double value) => !value.isFinite)) {
      throw ArgumentError('distribution samples must be finite');
    }
    if (sorted.isEmpty) {
      return const DistributionMetric._(
        count: 0,
        minimum: null,
        median: null,
        p95: null,
        maximum: null,
        mean: null,
      );
    }
    final double total = sorted.fold<double>(0, (double a, double b) => a + b);
    return DistributionMetric._(
      count: sorted.length,
      minimum: sorted.first,
      median: _linearPercentile(sorted, 0.5),
      p95: _linearPercentile(sorted, 0.95),
      maximum: sorted.last,
      mean: total / sorted.length,
    );
  }

  final int count;
  final double? minimum;
  final double? median;
  final double? p95;
  final double? maximum;
  final double? mean;
}

/// Lateness and measured retention for one canonical priority decile.
@immutable
final class PriorityDecileMetric {
  const PriorityDecileMetric({
    required this.decile,
    required this.allLateness,
    required this.cardLateness,
    required this.topicLateness,
    required this.cardRecallSuccesses,
    required this.cardRecallMeasurements,
  });

  final int decile;
  final DistributionMetric allLateness;
  final DistributionMetric cardLateness;
  final DistributionMetric topicLateness;
  final int cardRecallSuccesses;
  final int cardRecallMeasurements;

  double? get measuredCardRetention => cardRecallMeasurements == 0
      ? null
      : cardRecallSuccesses / cardRecallMeasurements;
}

/// Forecasted element counts and time for a provenance branch.
@immutable
final class BranchWorkloadMetric {
  const BranchWorkloadMetric({
    required this.branchId,
    required this.cardCount,
    required this.topicCount,
    required this.cardForegroundMs,
    required this.topicForegroundMs,
  });

  final String branchId;
  final int cardCount;
  final int topicCount;
  final int cardForegroundMs;
  final int topicForegroundMs;

  int get totalCount => cardCount + topicCount;
  int get totalForegroundMs => cardForegroundMs + topicForegroundMs;
}

/// Encounter-interval and A-Factor distributions for one policy version.
@immutable
final class TopicPolicyMetric {
  const TopicPolicyMetric({
    required this.policyVersion,
    required this.intervals,
    required this.aFactors,
  });

  final String policyVersion;
  final DistributionMetric intervals;
  final DistributionMetric aFactors;
}

/// Complete operational snapshot required by the scheduler contract.
@immutable
final class SchedulerMetricsSnapshot {
  const SchedulerMetricsSnapshot({
    required this.policyVersion,
    required this.asOfStudyDay,
    required this.activityStart,
    required this.activityEnd,
    required this.next30Days,
    required this.overdueCards,
    required this.overdueTopics,
    required this.manualLaterCount,
    required this.mercyCount,
    required this.mercyBatchSizes,
    required this.actualCardReviews,
    required this.topicsCompleted,
    required this.cardTopicOpportunityRatio,
    required this.cardTopicForegroundTimeRatio,
    required this.priorityDeciles,
    required this.futureWorkloadByBranch,
    required this.topicPolicies,
  });

  final String policyVersion;
  final StudyDay asOfStudyDay;
  final StudyDay activityStart;
  final StudyDay activityEnd;
  final List<DueLoadMetric> next30Days;
  final int overdueCards;
  final int overdueTopics;
  final int manualLaterCount;
  final int mercyCount;
  final List<int> mercyBatchSizes;
  final int actualCardReviews;
  final int topicsCompleted;
  final RatioMetric cardTopicOpportunityRatio;
  final RatioMetric cardTopicForegroundTimeRatio;
  final List<PriorityDecileMetric> priorityDeciles;
  final List<BranchWorkloadMetric> futureWorkloadByBranch;
  final List<TopicPolicyMetric> topicPolicies;
}

/// Pure, deterministic metrics aggregator.
@immutable
final class SchedulerMetricsCollector {
  const SchedulerMetricsCollector();

  SchedulerMetricsSnapshot collect(SchedulerMetricsInput input) {
    final List<_MutableDueLoad> horizon = <_MutableDueLoad>[
      for (var offset = 0; offset < schedulerDueHorizonDays; offset++)
        _MutableDueLoad(input.asOfStudyDay.addDays(offset)),
    ];
    var overdueCards = 0;
    var overdueTopics = 0;
    for (final DueMetricSample sample in input.due) {
      final bool card = sample.element.type == ElementType.card;
      final int offset = input.asOfStudyDay.daysUntil(sample.due);
      if (offset < 0) {
        if (card) {
          overdueCards++;
        } else {
          overdueTopics++;
        }
      } else if (offset < schedulerDueHorizonDays) {
        if (card) {
          horizon[offset].cards++;
        } else {
          horizon[offset].topics++;
        }
      }
    }

    final Iterable<DailySchedulerActivity> activity = input.activity.where(
      (DailySchedulerActivity value) =>
          value.day >= input.activityStart && value.day <= input.activityEnd,
    );
    var manualLaterCount = 0;
    var actualCardReviews = 0;
    var topicsCompleted = 0;
    var cardOpportunities = 0;
    var topicOpportunities = 0;
    var cardForegroundMs = 0;
    var topicForegroundMs = 0;
    for (final DailySchedulerActivity value in activity) {
      manualLaterCount += value.manualLaterCount;
      actualCardReviews += value.actualCardReviews;
      topicsCompleted += value.topicsCompleted;
      cardOpportunities += value.cardOpportunities;
      topicOpportunities += value.topicOpportunities;
      cardForegroundMs += value.cardForegroundMs;
      topicForegroundMs += value.topicForegroundMs;
    }

    final List<MercyBatchMetricSample> mercy =
        input.mercyBatches
            .where(
              (MercyBatchMetricSample value) =>
                  value.studyDay >= input.activityStart &&
                  value.studyDay <= input.activityEnd,
            )
            .toList()
          ..sort(
            (MercyBatchMetricSample left, MercyBatchMetricSample right) =>
                left.studyDay.compareTo(right.studyDay),
          );

    final List<PriorityDecileMetric> deciles = <PriorityDecileMetric>[
      for (var decile = 1; decile <= 10; decile++)
        _buildDecile(decile, input.priorityOutcomes),
    ];

    final Map<String, _MutableBranchWorkload> branchBuilders =
        <String, _MutableBranchWorkload>{};
    for (final BranchWorkloadMetricSample sample in input.futureWorkload) {
      branchBuilders
          .putIfAbsent(
            sample.branchId,
            () => _MutableBranchWorkload(sample.branchId),
          )
          .add(sample);
    }
    final List<BranchWorkloadMetric> branches =
        branchBuilders.values
            .map((_MutableBranchWorkload value) => value.freeze())
            .toList()
          ..sort(
            (BranchWorkloadMetric left, BranchWorkloadMetric right) =>
                left.branchId.compareTo(right.branchId),
          );

    final Map<String, _MutableTopicPolicy> topicBuilders =
        <String, _MutableTopicPolicy>{};
    for (final TopicEncounterMetricSample sample in input.topicEncounters) {
      topicBuilders
          .putIfAbsent(
            sample.policyVersion,
            () => _MutableTopicPolicy(sample.policyVersion),
          )
          .add(sample);
    }
    final List<TopicPolicyMetric> topicPolicies =
        topicBuilders.values
            .map((_MutableTopicPolicy value) => value.freeze())
            .toList()
          ..sort(
            (TopicPolicyMetric left, TopicPolicyMetric right) =>
                left.policyVersion.compareTo(right.policyVersion),
          );

    return SchedulerMetricsSnapshot(
      policyVersion: schedulerMetricsPolicyVersion,
      asOfStudyDay: input.asOfStudyDay,
      activityStart: input.activityStart,
      activityEnd: input.activityEnd,
      next30Days: List<DueLoadMetric>.unmodifiable(
        horizon.map((_MutableDueLoad value) => value.freeze()),
      ),
      overdueCards: overdueCards,
      overdueTopics: overdueTopics,
      manualLaterCount: manualLaterCount,
      mercyCount: mercy.length,
      mercyBatchSizes: List<int>.unmodifiable(
        mercy.map((MercyBatchMetricSample value) => value.size),
      ),
      actualCardReviews: actualCardReviews,
      topicsCompleted: topicsCompleted,
      cardTopicOpportunityRatio: RatioMetric(
        numerator: cardOpportunities,
        denominator: topicOpportunities,
      ),
      cardTopicForegroundTimeRatio: RatioMetric(
        numerator: cardForegroundMs,
        denominator: topicForegroundMs,
      ),
      priorityDeciles: List<PriorityDecileMetric>.unmodifiable(deciles),
      futureWorkloadByBranch: List<BranchWorkloadMetric>.unmodifiable(branches),
      topicPolicies: List<TopicPolicyMetric>.unmodifiable(topicPolicies),
    );
  }
}

final class _MutableDueLoad {
  _MutableDueLoad(this.studyDay);

  final StudyDay studyDay;
  int cards = 0;
  int topics = 0;

  DueLoadMetric freeze() =>
      DueLoadMetric(studyDay: studyDay, cards: cards, topics: topics);
}

final class _MutableBranchWorkload {
  _MutableBranchWorkload(this.branchId);

  final String branchId;
  int cardCount = 0;
  int topicCount = 0;
  int cardForegroundMs = 0;
  int topicForegroundMs = 0;

  void add(BranchWorkloadMetricSample sample) {
    if (sample.elementType == ElementType.card) {
      cardCount += sample.count;
      cardForegroundMs += sample.estimatedForegroundMs;
    } else {
      topicCount += sample.count;
      topicForegroundMs += sample.estimatedForegroundMs;
    }
  }

  BranchWorkloadMetric freeze() => BranchWorkloadMetric(
    branchId: branchId,
    cardCount: cardCount,
    topicCount: topicCount,
    cardForegroundMs: cardForegroundMs,
    topicForegroundMs: topicForegroundMs,
  );
}

final class _MutableTopicPolicy {
  _MutableTopicPolicy(this.policyVersion);

  final String policyVersion;
  final List<double> intervals = <double>[];
  final List<double> aFactors = <double>[];

  void add(TopicEncounterMetricSample sample) {
    intervals.add(sample.intervalDays);
    final double? factor = sample.aFactor;
    if (factor != null) aFactors.add(factor);
  }

  TopicPolicyMetric freeze() => TopicPolicyMetric(
    policyVersion: policyVersion,
    intervals: DistributionMetric.of(intervals),
    aFactors: DistributionMetric.of(aFactors),
  );
}

PriorityDecileMetric _buildDecile(
  int decile,
  Iterable<PriorityOutcomeMetricSample> samples,
) {
  final List<double> cards = <double>[];
  final List<double> topics = <double>[];
  var measured = 0;
  var recalled = 0;
  for (final PriorityOutcomeMetricSample sample in samples) {
    if (sample.priorityDecile != decile) continue;
    if (sample.elementType == ElementType.card) {
      cards.add(sample.latenessDays);
      final bool? outcome = sample.cardRecalled;
      if (outcome != null) {
        measured++;
        if (outcome) recalled++;
      }
    } else {
      topics.add(sample.latenessDays);
    }
  }
  return PriorityDecileMetric(
    decile: decile,
    allLateness: DistributionMetric.of(<double>[...cards, ...topics]),
    cardLateness: DistributionMetric.of(cards),
    topicLateness: DistributionMetric.of(topics),
    cardRecallSuccesses: recalled,
    cardRecallMeasurements: measured,
  );
}

/// **[Product decision]** Metrics v1 uses linear interpolation between the two
/// surrounding ordered samples. The estimator is versioned above because the
/// executable scheduler contract requires p95 but does not prescribe one of
/// the several conventional finite-sample definitions.
double _linearPercentile(List<double> sorted, double percentile) {
  if (sorted.length == 1) return sorted.single;
  final double position = (sorted.length - 1) * percentile;
  final int lower = position.floor();
  final int upper = math.min(sorted.length - 1, position.ceil());
  if (lower == upper) return sorted[lower];
  final double fraction = position - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
}

void _requireSameZone(StudyDay left, StudyDay right) {
  if (left.zoneId != right.zoneId) {
    throw ArgumentError(
      'StudyDays use different zones: ${left.zoneId} and ${right.zoneId}',
    );
  }
}

void _requireNonNegative(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must be non-negative');
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
