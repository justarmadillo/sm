/// Deterministic, preview-only Mercy calendar redistribution.
///
/// Mercy is an exceptional bulk presentation operation. This module only
/// chooses calendar assignments and builds a confirmation token; it never
/// mutates FSRS memory, topic intervals, algorithmic dues, or persistence.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'element.dart';
import 'schedule_adjustment.dart';
import 'schedule_adjustment_codec.dart';
import 'study_day.dart';

/// [Product decision] Transparent provisional Mercy allocation policy.
///
/// SuperMemo's exact multi-criteria Mercy formula is `Unknown`. Every input
/// that can affect this implementation is therefore visible in the preview,
/// and a different formula must use a different version.
const String kMercyPolicyVersion = 'mercy_balanced_v1/1';

/// A collection, branch, or explicit subset selected for Mercy.
sealed class MercyScope {
  const MercyScope();

  bool contains(MercyCandidate candidate);

  String get stableKey;
}

/// Every candidate supplied by the collection query is in scope.
final class MercyCollectionScope extends MercyScope {
  const MercyCollectionScope();

  @override
  bool contains(MercyCandidate candidate) => true;

  @override
  String get stableKey => 'collection';
}

/// Candidates whose ancestry includes [branchId] are in scope.
@immutable
final class MercyBranchScope extends MercyScope {
  MercyBranchScope(this.branchId) {
    _requireText(branchId, 'branchId');
  }

  final String branchId;

  @override
  bool contains(MercyCandidate candidate) =>
      candidate.branchIds.contains(branchId);

  @override
  String get stableKey => 'branch:$branchId';
}

/// Only the immutable element coordinates in [elements] are in scope.
@immutable
final class MercySubsetScope extends MercyScope {
  MercySubsetScope(Iterable<ElementRef> elements)
    : elements = Set<ElementRef>.unmodifiable(elements) {
    if (this.elements.isEmpty) {
      throw ArgumentError('a Mercy subset must not be empty');
    }
  }

  final Set<ElementRef> elements;

  @override
  bool contains(MercyCandidate candidate) => elements.contains(candidate.ref);

  @override
  String get stableKey {
    final List<ElementRef> ordered = elements.toList()..sort();
    return 'subset:${ordered.join(',')}';
  }
}

/// Inclusive range of current effective presentation dates to collect.
@immutable
final class MercyCollectingPeriod {
  MercyCollectingPeriod({required this.start, required this.end}) {
    _requireSameZone(start, end, 'collecting period');
    if (end < start) {
      throw ArgumentError('collecting period end precedes its start');
    }
  }

  final StudyDay start;
  final StudyDay end;

  bool contains(StudyDay day) {
    _requireSameZone(start, day, 'collecting period candidate');
    return day >= start && day <= end;
  }
}

/// Canonical state copied into item-level audit records during apply/undo.
///
/// [serializedState] and [algorithmicDue] must describe the same schedule row
/// whose optimistic [MercyCandidate.revision] is used by the preview token.
@immutable
final class MercyCanonicalSnapshot {
  MercyCanonicalSnapshot({
    required this.serializedState,
    required this.algorithmicDue,
    required this.schedulerName,
    required this.schedulerVersion,
  }) {
    _requireText(serializedState, 'serializedState');
    _requireText(algorithmicDue, 'algorithmicDue');
    _requireText(schedulerName, 'schedulerName');
    _requireText(schedulerVersion, 'schedulerVersion');
  }

  final String serializedState;
  final String algorithmicDue;
  final String schedulerName;
  final String schedulerVersion;
}

/// Normalized urgency inputs selected for one candidate.
///
/// Each value is in `[0, 1]`, where a larger value means "schedule earlier".
/// Normalization is deliberately a caller responsibility: it keeps collection
/// statistics and undocumented constants out of this policy boundary.
@immutable
final class MercyCriterionValues {
  const MercyCriterionValues({
    this.repetitionLateness = 0,
    this.retrievabilityRisk = 0,
    this.investment = 0,
    this.difficulty = 0,
    this.introductionRecency = 0,
  });

  final double repetitionLateness;
  final double retrievabilityRisk;
  final double investment;
  final double difficulty;
  final double introductionRecency;

  void validate() {
    _requireUnit(repetitionLateness, 'repetitionLateness');
    _requireUnit(retrievabilityRisk, 'retrievabilityRisk');
    _requireUnit(investment, 'investment');
    _requireUnit(difficulty, 'difficulty');
    _requireUnit(introductionRecency, 'introductionRecency');
  }
}

/// One immutable schedule row considered by a Mercy preview.
@immutable
final class MercyCandidate {
  MercyCandidate({
    required this.ref,
    required this.revision,
    required this.currentEffectiveDueDay,
    required this.priorityFraction,
    required this.canonical,
    Set<String> branchIds = const <String>{},
    this.criteria = const MercyCriterionValues(),
    this.isProtected = false,
    this.isDueIntradayStep = false,
    this.isLifecycleEligible = true,
  }) : branchIds = Set<String>.unmodifiable(branchIds) {
    if (revision < 1) {
      throw ArgumentError.value(revision, 'revision', 'must be positive');
    }
    _requireUnit(priorityFraction, 'priorityFraction');
    criteria.validate();
    for (final String branchId in branchIds) {
      _requireText(branchId, 'branchIds');
    }
  }

  final ElementRef ref;
  final int revision;

  /// Effective presentation day before Mercy, including active adjustments.
  final StudyDay currentEffectiveDueDay;

  /// Global priority percentile as a fraction: zero is highest priority.
  final double priorityFraction;
  final MercyCanonicalSnapshot canonical;
  final Set<String> branchIds;
  final MercyCriterionValues criteria;
  final bool isProtected;

  /// Learning/relearning steps are mandatory and never Mercy candidates.
  final bool isDueIntradayStep;
  final bool isLifecycleEligible;
}

/// Visible, testable criteria weights for the provisional policy.
@immutable
final class MercyCriteriaPolicy {
  MercyCriteriaPolicy({
    required this.priorityBandWidth,
    required this.deterministicSeed,
    this.repetitionLatenessWeight = 0,
    this.retrievabilityRiskWeight = 0,
    this.investmentWeight = 0,
    this.difficultyWeight = 0,
    this.introductionRecencyWeight = 0,
    this.stableRandomWeight = 0,
    this.version = kMercyPolicyVersion,
  }) {
    if (!priorityBandWidth.isFinite ||
        priorityBandWidth <= 0 ||
        priorityBandWidth > 1) {
      throw ArgumentError.value(
        priorityBandWidth,
        'priorityBandWidth',
        'must be finite and in (0, 1]',
      );
    }
    _requireText(deterministicSeed, 'deterministicSeed');
    _requireText(version, 'version');
    for (final MapEntry<String, double> entry in weights.entries) {
      if (!entry.value.isFinite || entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'weight must be finite and non-negative',
        );
      }
    }
  }

  final double priorityBandWidth;
  final String deterministicSeed;
  final double repetitionLatenessWeight;
  final double retrievabilityRiskWeight;
  final double investmentWeight;
  final double difficultyWeight;
  final double introductionRecencyWeight;
  final double stableRandomWeight;
  final String version;

  Map<String, double> get weights => <String, double>{
    'repetition_lateness': repetitionLatenessWeight,
    'retrievability_risk': retrievabilityRiskWeight,
    'investment': investmentWeight,
    'difficulty': difficultyWeight,
    'introduction_recency': introductionRecencyWeight,
    'stable_random': stableRandomWeight,
  };

  int priorityBand(double priorityFraction) {
    final int lastBand = (1 / priorityBandWidth).ceil() - 1;
    return math.min(lastBand, (priorityFraction / priorityBandWidth).floor());
  }

  double score(MercyCandidate candidate) {
    final MercyCriterionValues values = candidate.criteria;
    final double weighted =
        repetitionLatenessWeight * values.repetitionLateness +
        retrievabilityRiskWeight * values.retrievabilityRisk +
        investmentWeight * values.investment +
        difficultyWeight * values.difficulty +
        introductionRecencyWeight * values.introductionRecency +
        stableRandomWeight * _stableRandom(candidate.ref);
    final double total = weights.values.fold<double>(
      0,
      (double sum, double value) => sum + value,
    );
    return total == 0 ? 0 : weighted / total;
  }

  double _stableRandom(ElementRef ref) {
    final Digest digest = sha256.convert(
      utf8.encode('$version|$deterministicSeed|${ref.type.name}|${ref.id}'),
    );
    var numerator = 0;
    // Six bytes stay below JavaScript's exact-integer ceiling, keeping web and
    // native previews byte-identical.
    for (var index = 0; index < 6; index++) {
      numerator = numerator * 256 + digest.bytes[index];
    }
    return numerator / 281474976710655;
  }

  Map<String, Object?> toJsonMap() => <String, Object?>{
    'version': version,
    'priority_band_width': priorityBandWidth,
    'deterministic_seed': deterministicSeed,
    'weights': weights,
  };
}

/// User-selected protection behavior for a confirmed preview.
@immutable
final class MercyProtectionRules {
  const MercyProtectionRules({
    this.includeProtected = false,
    this.overrideManualLater = false,
  });

  /// Protected candidates are excluded by default and require an explicit opt
  /// in. Mandatory learning/relearning steps cannot be opted in.
  final bool includeProtected;

  /// Manual Later is preserved by default and may be cleared only by an
  /// explicit confirmation choice.
  final bool overrideManualLater;
}

/// Forecasted load for one possible destination day.
///
/// The before counts are the complete effective-due forecast for their domain,
/// including any supplied candidate currently due on this day. This lets the
/// planner remove selected work before reallocating it without double-counting
/// the slot; an inconsistent nonzero candidate/count relationship fails fast.
@immutable
final class MercyDestinationDay {
  MercyDestinationDay({
    required this.day,
    required this.cardScheduledForAtUtc,
    required this.beforeCardLoad,
    required this.beforeTopicLoad,
  }) {
    if (!cardScheduledForAtUtc.isUtc) {
      throw ArgumentError.value(
        cardScheduledForAtUtc,
        'cardScheduledForAtUtc',
        'must be UTC',
      );
    }
    if (beforeCardLoad < 0 || beforeTopicLoad < 0) {
      throw ArgumentError('forecast load must not be negative');
    }
  }

  final StudyDay day;

  /// Exact UTC instant used for a card assigned to [day].
  final DateTime cardScheduledForAtUtc;
  final int beforeCardLoad;
  final int beforeTopicLoad;
}

/// How the finite forecast window limits destinations.
sealed class MercyDestinationPolicy {
  const MercyDestinationPolicy();

  String get stableKey;
}

/// Apply separate hard daily maxima for cards and topics.
@immutable
final class MercyDailyCapacity extends MercyDestinationPolicy {
  MercyDailyCapacity({required this.cardsPerDay, required this.topicsPerDay}) {
    if (cardsPerDay < 0 || topicsPerDay < 0) {
      throw ArgumentError('daily Mercy capacities must not be negative');
    }
  }

  final int cardsPerDay;
  final int topicsPerDay;

  @override
  String get stableKey => 'capacity:$cardsPerDay:$topicsPerDay';
}

/// Balance each domain across the selected destination horizon.
///
/// This policy derives a per-domain target from the forecast load plus work
/// entering from outside the horizon. It is a transparent product decision,
/// not a reconstruction of SuperMemo's undocumented Mercy formula.
final class MercyDestinationHorizon extends MercyDestinationPolicy {
  const MercyDestinationHorizon();

  @override
  String get stableKey => 'horizon';
}

/// Ordered finite destination calendar and its pre-Mercy forecast.
@immutable
final class MercyDestinationWindow {
  MercyDestinationWindow({required Iterable<MercyDestinationDay> days})
    : days = List<MercyDestinationDay>.unmodifiable(days) {
    if (this.days.isEmpty) {
      throw ArgumentError('a Mercy destination window must not be empty');
    }
    for (var index = 0; index < this.days.length; index++) {
      final MercyDestinationDay current = this.days[index];
      if (index == 0) continue;
      final MercyDestinationDay prior = this.days[index - 1];
      _requireSameZone(prior.day, current.day, 'destination window');
      if (prior.day.addDays(1) != current.day) {
        throw ArgumentError(
          'Mercy destination days must be unique and contiguous',
        );
      }
    }
  }

  final List<MercyDestinationDay> days;

  StudyDay get firstDay => days.first.day;
  StudyDay get lastDay => days.last.day;
}

/// Complete inputs to one side-effect-free preview.
@immutable
final class MercyPreviewRequest {
  MercyPreviewRequest({
    required this.today,
    required this.scope,
    required this.collectingPeriod,
    required this.includeFutureRepetitions,
    required this.destinationPolicy,
    required this.destinationWindow,
    required this.criteriaPolicy,
    required this.protectionRules,
    required Iterable<MercyCandidate> candidates,
    required this.adjustments,
    this.priorMercyBatchCountInPeriod = 0,
  }) : candidates = List<MercyCandidate>.unmodifiable(candidates) {
    if (priorMercyBatchCountInPeriod < 0) {
      throw ArgumentError('prior Mercy batch count must not be negative');
    }
    _requireSameZone(today, collectingPeriod.start, 'preview');
    _requireSameZone(today, destinationWindow.firstDay, 'preview');
    final Set<ElementRef> refs = <ElementRef>{};
    for (final MercyCandidate candidate in this.candidates) {
      _requireSameZone(today, candidate.currentEffectiveDueDay, 'candidate');
      if (!refs.add(candidate.ref)) {
        throw ArgumentError('duplicate Mercy candidate ${candidate.ref}');
      }
    }
  }

  final StudyDay today;
  final MercyScope scope;
  final MercyCollectingPeriod collectingPeriod;
  final bool includeFutureRepetitions;
  final MercyDestinationPolicy destinationPolicy;
  final MercyDestinationWindow destinationWindow;
  final MercyCriteriaPolicy criteriaPolicy;
  final MercyProtectionRules protectionRules;
  final List<MercyCandidate> candidates;
  final ScheduleAdjustmentSet adjustments;
  final int priorMercyBatchCountInPeriod;
}

enum MercyExclusionReason {
  outsideScope,
  lifecycleIneligible,
  outsideCollectingPeriod,
  futureRepetitionNotSelected,
  dueIntradayStep,
  protected,
  preservedLowerBoundBeyondDestination,
  noDestinationCapacity,
}

@immutable
final class MercyExclusion {
  const MercyExclusion({required this.element, required this.reason});

  final ElementRef element;
  final MercyExclusionReason reason;
}

@immutable
final class MercyAssignment {
  const MercyAssignment({
    required this.element,
    required this.candidateRevision,
    required this.fromDay,
    required this.toDay,
    required this.priorityFraction,
    required this.criteriaScore,
    this.scheduledForAtUtc,
    this.scheduledForStudyDay,
  });

  final ElementRef element;
  final int candidateRevision;
  final StudyDay fromDay;
  final StudyDay toDay;
  final double priorityFraction;
  final double criteriaScore;
  final DateTime? scheduledForAtUtc;
  final StudyDay? scheduledForStudyDay;

  bool get movesEarlier => toDay < fromDay;
  bool get movesLater => toDay > fromDay;
  bool get staysOnDay => toDay == fromDay;
}

@immutable
final class MercyDailyLoad {
  const MercyDailyLoad({
    required this.day,
    required this.cards,
    required this.topics,
  });

  final StudyDay day;
  final int cards;
  final int topics;
}

@immutable
final class MercyRevisionStamp implements Comparable<MercyRevisionStamp> {
  const MercyRevisionStamp({required this.element, required this.revision});

  final ElementRef element;
  final int revision;

  @override
  int compareTo(MercyRevisionStamp other) => element.compareTo(other.element);
}

/// Durable confirmation guard. A preview is valid only for this exact input.
@immutable
final class MercyConfirmationToken {
  const MercyConfirmationToken({
    required this.digest,
    required this.policyVersion,
    required this.adjustmentSnapshotDigest,
    required this.candidateRevisions,
  });

  final String digest;
  final String policyVersion;
  final String adjustmentSnapshotDigest;
  final List<MercyRevisionStamp> candidateRevisions;
}

enum MercyWarning { repeatedMercyMayHideChronicOverload }

/// Deterministic, persistable dry-run result. Constructing this writes nothing.
@immutable
final class MercyPreview {
  const MercyPreview({
    required this.policyVersion,
    required this.scope,
    required this.protectionRules,
    required this.criteriaPolicy,
    required this.assignments,
    required this.exclusions,
    required this.beforeLoad,
    required this.afterLoad,
    required this.warnings,
    required this.confirmationToken,
    required this.inputCandidateCount,
  });

  /// Restores a durable preview after navigation or process restart.
  factory MercyPreview.fromJson(String source) {
    final Map<String, Object?> map =
        (jsonDecode(source) as Map<Object?, Object?>).cast<String, Object?>();
    final Map<String, Object?> criteriaMap =
        (map['criteria']! as Map<Object?, Object?>).cast<String, Object?>();
    final Map<String, Object?> weights =
        (criteriaMap['weights']! as Map<Object?, Object?>)
            .cast<String, Object?>();
    final MercyCriteriaPolicy criteria = MercyCriteriaPolicy(
      version: criteriaMap['version']! as String,
      priorityBandWidth: (criteriaMap['priority_band_width']! as num)
          .toDouble(),
      deterministicSeed: criteriaMap['deterministic_seed']! as String,
      repetitionLatenessWeight: (weights['repetition_lateness']! as num)
          .toDouble(),
      retrievabilityRiskWeight: (weights['retrievability_risk']! as num)
          .toDouble(),
      investmentWeight: (weights['investment']! as num).toDouble(),
      difficultyWeight: (weights['difficulty']! as num).toDouble(),
      introductionRecencyWeight: (weights['introduction_recency']! as num)
          .toDouble(),
      stableRandomWeight: (weights['stable_random']! as num).toDouble(),
    );
    final Map<String, Object?> protection =
        (map['protection']! as Map<Object?, Object?>).cast<String, Object?>();
    final Map<String, Object?> confirmation =
        (map['confirmation']! as Map<Object?, Object?>).cast<String, Object?>();
    final List<MercyRevisionStamp> revisions = <MercyRevisionStamp>[
      for (final Object? raw
          in confirmation['candidate_revisions']! as List<Object?>)
        (() {
          final Map<String, Object?> value = (raw! as Map<Object?, Object?>)
              .cast<String, Object?>();
          return MercyRevisionStamp(
            element: ElementRef(
              id: value['element_id']! as String,
              type: ElementType.values.byName(value['element_type']! as String),
            ),
            revision: value['revision']! as int,
          );
        })(),
    ]..sort();
    final String policyVersion = map['policy_version']! as String;
    return MercyPreview(
      policyVersion: policyVersion,
      scope: _scopeFromJson(
        (map['scope_data']! as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      protectionRules: MercyProtectionRules(
        includeProtected: protection['include_protected']! as bool,
        overrideManualLater: protection['override_manual_later']! as bool,
      ),
      criteriaPolicy: criteria,
      assignments: List<MercyAssignment>.unmodifiable(<MercyAssignment>[
        for (final Object? raw in map['assignments']! as List<Object?>)
          _assignmentFromJson(
            (raw! as Map<Object?, Object?>).cast<String, Object?>(),
          ),
      ]),
      exclusions: List<MercyExclusion>.unmodifiable(<MercyExclusion>[
        for (final Object? raw in map['exclusions']! as List<Object?>)
          (() {
            final Map<String, Object?> value = (raw! as Map<Object?, Object?>)
                .cast<String, Object?>();
            return MercyExclusion(
              element: ElementRef(
                id: value['element_id']! as String,
                type: ElementType.values.byName(
                  value['element_type']! as String,
                ),
              ),
              reason: MercyExclusionReason.values.byName(
                value['reason']! as String,
              ),
            );
          })(),
      ]),
      beforeLoad: _loadFromJson(map['before_load']! as List<Object?>),
      afterLoad: _loadFromJson(map['after_load']! as List<Object?>),
      warnings: List<MercyWarning>.unmodifiable(<MercyWarning>[
        for (final Object? value in map['warnings']! as List<Object?>)
          MercyWarning.values.byName(value! as String),
      ]),
      confirmationToken: MercyConfirmationToken(
        digest: confirmation['digest']! as String,
        policyVersion: policyVersion,
        adjustmentSnapshotDigest:
            confirmation['adjustment_snapshot_digest']! as String,
        candidateRevisions: List<MercyRevisionStamp>.unmodifiable(revisions),
      ),
      inputCandidateCount: map['input_candidate_count']! as int,
    );
  }

  final String policyVersion;
  final MercyScope scope;
  final MercyProtectionRules protectionRules;
  final MercyCriteriaPolicy criteriaPolicy;
  final List<MercyAssignment> assignments;
  final List<MercyExclusion> exclusions;
  final List<MercyDailyLoad> beforeLoad;
  final List<MercyDailyLoad> afterLoad;
  final List<MercyWarning> warnings;
  final MercyConfirmationToken confirmationToken;
  final int inputCandidateCount;

  int get selectedCount => assignments.length;
  int get selectedCardCount => assignments
      .where((MercyAssignment value) => value.element.type == ElementType.card)
      .length;
  int get selectedTopicCount => selectedCount - selectedCardCount;

  Map<MercyExclusionReason, int> get exclusionCounts {
    final Map<MercyExclusionReason, int> result = <MercyExclusionReason, int>{};
    for (final MercyExclusion exclusion in exclusions) {
      result.update(
        exclusion.reason,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return Map<MercyExclusionReason, int>.unmodifiable(result);
  }

  /// JSON suitable for the durable `previewJson` batch field.
  String toJson() => jsonEncode(<String, Object?>{
    'policy_version': policyVersion,
    'scope': scope.stableKey,
    'scope_data': _scopeJson(scope),
    'criteria': criteriaPolicy.toJsonMap(),
    'protection': <String, Object?>{
      'include_protected': protectionRules.includeProtected,
      'override_manual_later': protectionRules.overrideManualLater,
    },
    'input_candidate_count': inputCandidateCount,
    'selected_card_count': selectedCardCount,
    'selected_topic_count': selectedTopicCount,
    'assignments': <Map<String, Object?>>[
      for (final MercyAssignment value in assignments)
        <String, Object?>{
          'element_id': value.element.id,
          'element_type': value.element.type.name,
          'revision': value.candidateRevision,
          'from_day': value.fromDay.epochDay,
          'to_day': value.toDay.epochDay,
          'zone_id': value.toDay.zoneId,
          'scheduled_for_at_utc':
              value.scheduledForAtUtc?.millisecondsSinceEpoch,
          'priority_fraction': value.priorityFraction,
          'criteria_score': value.criteriaScore,
        },
    ],
    'exclusions': <Map<String, Object?>>[
      for (final MercyExclusion value in exclusions)
        <String, Object?>{
          'element_id': value.element.id,
          'element_type': value.element.type.name,
          'reason': value.reason.name,
        },
    ],
    'before_load': _loadJson(beforeLoad),
    'after_load': _loadJson(afterLoad),
    'warnings': warnings.map((MercyWarning value) => value.name).toList(),
    'confirmation': <String, Object?>{
      'digest': confirmationToken.digest,
      'adjustment_snapshot_digest': confirmationToken.adjustmentSnapshotDigest,
      'candidate_revisions': <Map<String, Object?>>[
        for (final MercyRevisionStamp stamp
            in confirmationToken.candidateRevisions)
          <String, Object?>{
            'element_id': stamp.element.id,
            'element_type': stamp.element.type.name,
            'revision': stamp.revision,
          },
      ],
    },
  });
}

/// Raised before an apply/undo plan is built. Persistence must write nothing.
final class StaleMercyPreview implements Exception {
  StaleMercyPreview(this.message, {Iterable<ElementRef> changed = const []})
    : changed = List<ElementRef>.unmodifiable(changed);

  final String message;
  final List<ElementRef> changed;

  @override
  String toString() => 'StaleMercyPreview: $message';
}

/// Pure deterministic Mercy preview planner.
final class MercyPlanner {
  const MercyPlanner({required StudyDayCalendar calendar})
    : _calendar = calendar;

  final StudyDayCalendar _calendar;

  MercyPreview preview(MercyPreviewRequest request) {
    _validateCalendar(request);
    final List<MercyExclusion> exclusions = <MercyExclusion>[];
    final List<MercyCandidate> eligible = <MercyCandidate>[];
    for (final MercyCandidate candidate in request.candidates) {
      final MercyExclusionReason? reason = _initialExclusion(
        candidate,
        request,
      );
      if (reason == null) {
        eligible.add(candidate);
      } else {
        exclusions.add(MercyExclusion(element: candidate.ref, reason: reason));
      }
    }

    final Map<ElementRef, double> criteriaScores = <ElementRef, double>{
      for (final MercyCandidate candidate in eligible)
        candidate.ref: request.criteriaPolicy.score(candidate),
    };
    eligible.sort(
      (MercyCandidate left, MercyCandidate right) => _compareCandidates(
        left,
        right,
        request.criteriaPolicy,
        leftScore: criteriaScores[left.ref]!,
        rightScore: criteriaScores[right.ref]!,
      ),
    );

    final Map<ElementRef, StudyDay?> preservedFloors =
        <ElementRef, StudyDay?>{};
    final List<MercyCandidate> allocatable = <MercyCandidate>[];
    for (final MercyCandidate candidate in eligible) {
      final StudyDay? preservedFloor = _preservedLowerBoundDay(
        candidate,
        request,
      );
      if (preservedFloor != null &&
          preservedFloor > request.destinationWindow.lastDay) {
        exclusions.add(
          MercyExclusion(
            element: candidate.ref,
            reason: MercyExclusionReason.preservedLowerBoundBeyondDestination,
          ),
        );
        continue;
      }
      preservedFloors[candidate.ref] = preservedFloor;
      allocatable.add(candidate);
    }

    final _MutableLedger ledger = _MutableLedger.fromRequest(
      request,
      incomingCards: allocatable
          .where(
            (MercyCandidate value) =>
                value.ref.type == ElementType.card &&
                !_isInsideWindow(value.currentEffectiveDueDay, request),
          )
          .length,
      incomingTopics: allocatable
          .where(
            (MercyCandidate value) =>
                value.ref.type.isTopic &&
                !_isInsideWindow(value.currentEffectiveDueDay, request),
          )
          .length,
    );

    // Remove the complete redistributable population before filling slots.
    // Removing one candidate immediately before assigning it would let a
    // lower-priority candidate reclaim an earlier slot vacated later.
    final Map<ElementRef, bool> removedFromWindow = <ElementRef, bool>{
      for (final MercyCandidate candidate in allocatable)
        candidate.ref: ledger.removeCurrent(candidate),
    };
    final List<MercyAssignment> assignments = <MercyAssignment>[];
    for (final MercyCandidate candidate in allocatable) {
      final int destinationIndex = ledger.firstAvailableIndex(
        candidate.ref.type,
        notBefore: preservedFloors[candidate.ref],
      );
      if (destinationIndex < 0) {
        if (removedFromWindow[candidate.ref]!) {
          ledger.restoreCurrent(candidate);
        }
        exclusions.add(
          MercyExclusion(
            element: candidate.ref,
            reason: MercyExclusionReason.noDestinationCapacity,
          ),
        );
        continue;
      }

      ledger.add(candidate.ref.type, destinationIndex);
      final MercyDestinationDay destination =
          request.destinationWindow.days[destinationIndex];
      assignments.add(
        MercyAssignment(
          element: candidate.ref,
          candidateRevision: candidate.revision,
          fromDay: candidate.currentEffectiveDueDay,
          toDay: destination.day,
          priorityFraction: candidate.priorityFraction,
          criteriaScore: criteriaScores[candidate.ref]!,
          scheduledForAtUtc: candidate.ref.type == ElementType.card
              ? destination.cardScheduledForAtUtc
              : null,
          scheduledForStudyDay: candidate.ref.type.isTopic
              ? destination.day
              : null,
        ),
      );
    }

    exclusions.sort((MercyExclusion left, MercyExclusion right) {
      final int byElement = left.element.compareTo(right.element);
      return byElement != 0
          ? byElement
          : left.reason.index.compareTo(right.reason.index);
    });
    final List<MercyRevisionStamp> revisions = <MercyRevisionStamp>[
      for (final MercyCandidate candidate in request.candidates)
        if (request.scope.contains(candidate))
          MercyRevisionStamp(
            element: candidate.ref,
            revision: candidate.revision,
          ),
    ]..sort();
    final Set<ElementRef> revisionScope = <ElementRef>{
      for (final MercyRevisionStamp value in revisions) value.element,
    };
    final String adjustmentDigest = adjustmentSnapshotDigest(
      request.adjustments.snapshotFor(revisionScope),
    );
    final String digest = _previewDigest(
      request: request,
      revisions: revisions,
      adjustmentDigest: adjustmentDigest,
      assignments: assignments,
      exclusions: exclusions,
    );
    return MercyPreview(
      policyVersion: request.criteriaPolicy.version,
      scope: request.scope,
      protectionRules: request.protectionRules,
      criteriaPolicy: request.criteriaPolicy,
      assignments: List<MercyAssignment>.unmodifiable(assignments),
      exclusions: List<MercyExclusion>.unmodifiable(exclusions),
      beforeLoad: ledger.beforeLoad,
      afterLoad: ledger.afterLoad,
      warnings: request.priorMercyBatchCountInPeriod > 0
          ? const <MercyWarning>[
              MercyWarning.repeatedMercyMayHideChronicOverload,
            ]
          : const <MercyWarning>[],
      confirmationToken: MercyConfirmationToken(
        digest: digest,
        policyVersion: request.criteriaPolicy.version,
        adjustmentSnapshotDigest: adjustmentDigest,
        candidateRevisions: List<MercyRevisionStamp>.unmodifiable(revisions),
      ),
      inputCandidateCount: request.candidates.length,
    );
  }

  void _validateCalendar(MercyPreviewRequest request) {
    if (_calendar.zone.zoneId != request.today.zoneId) {
      throw ArgumentError('Mercy planner calendar does not match StudyDay');
    }
    for (final MercyDestinationDay destination
        in request.destinationWindow.days) {
      if (!_calendar.contains(
        destination.day,
        destination.cardScheduledForAtUtc,
      )) {
        throw ArgumentError(
          'card destination instant does not fall in ${destination.day}',
        );
      }
    }
  }

  MercyExclusionReason? _initialExclusion(
    MercyCandidate candidate,
    MercyPreviewRequest request,
  ) {
    if (!request.scope.contains(candidate)) {
      return MercyExclusionReason.outsideScope;
    }
    if (!candidate.isLifecycleEligible) {
      return MercyExclusionReason.lifecycleIneligible;
    }
    if (!request.collectingPeriod.contains(candidate.currentEffectiveDueDay)) {
      return MercyExclusionReason.outsideCollectingPeriod;
    }
    if (!request.includeFutureRepetitions &&
        candidate.currentEffectiveDueDay > request.today) {
      return MercyExclusionReason.futureRepetitionNotSelected;
    }
    if (candidate.isDueIntradayStep) {
      return MercyExclusionReason.dueIntradayStep;
    }
    if (candidate.isProtected && !request.protectionRules.includeProtected) {
      return MercyExclusionReason.protected;
    }
    return null;
  }

  StudyDay? _preservedLowerBoundDay(
    MercyCandidate candidate,
    MercyPreviewRequest request,
  ) {
    StudyDay? floor;
    for (final ScheduleAdjustment adjustment in request.adjustments.activeFor(
      candidate.ref,
    )) {
      if (adjustment.mode != ScheduleAdjustmentMode.lowerBound ||
          adjustment.reason == ScheduleAdjustmentReason.autoOverflow ||
          (adjustment.reason == ScheduleAdjustmentReason.manualLater &&
              request.protectionRules.overrideManualLater)) {
        continue;
      }
      final StudyDay day = candidate.ref.type == ElementType.card
          ? _calendar.dayOf(adjustment.notBeforeAtUtc!)
          : adjustment.notBeforeStudyDay!;
      floor = floor == null || day > floor ? day : floor;
    }
    return floor;
  }
}

/// Stable digest of a semantic active-adjustment snapshot.
String adjustmentSnapshotDigest(ScheduleAdjustmentSnapshot snapshot) =>
    sha256.convert(utf8.encode(encodeAdjustmentSnapshot(snapshot))).toString();

int _compareCandidates(
  MercyCandidate left,
  MercyCandidate right,
  MercyCriteriaPolicy policy, {
  required double leftScore,
  required double rightScore,
}) {
  var comparison = policy
      .priorityBand(left.priorityFraction)
      .compareTo(policy.priorityBand(right.priorityFraction));
  if (comparison != 0) return comparison;
  comparison = rightScore.compareTo(leftScore);
  if (comparison != 0) return comparison;
  comparison = left.priorityFraction.compareTo(right.priorityFraction);
  if (comparison != 0) return comparison;
  return left.ref.compareTo(right.ref);
}

bool _isInsideWindow(StudyDay day, MercyPreviewRequest request) =>
    day >= request.destinationWindow.firstDay &&
    day <= request.destinationWindow.lastDay;

String _previewDigest({
  required MercyPreviewRequest request,
  required List<MercyRevisionStamp> revisions,
  required String adjustmentDigest,
  required List<MercyAssignment> assignments,
  required List<MercyExclusion> exclusions,
}) {
  final Map<String, Object?> payload = <String, Object?>{
    'policy': request.criteriaPolicy.toJsonMap(),
    'scope': request.scope.stableKey,
    'today': request.today.epochDay,
    'zone': request.today.zoneId,
    'collecting_start': request.collectingPeriod.start.epochDay,
    'collecting_end': request.collectingPeriod.end.epochDay,
    'include_future': request.includeFutureRepetitions,
    'destination_policy': request.destinationPolicy.stableKey,
    'destination': <Map<String, Object?>>[
      for (final MercyDestinationDay value in request.destinationWindow.days)
        <String, Object?>{
          'day': value.day.epochDay,
          'card_at': value.cardScheduledForAtUtc.millisecondsSinceEpoch,
          'cards': value.beforeCardLoad,
          'topics': value.beforeTopicLoad,
        },
    ],
    'protection': <String, Object?>{
      'include_protected': request.protectionRules.includeProtected,
      'override_manual_later': request.protectionRules.overrideManualLater,
    },
    'revisions': <List<Object?>>[
      for (final MercyRevisionStamp value in revisions)
        <Object?>[value.element.type.name, value.element.id, value.revision],
    ],
    'adjustments': adjustmentDigest,
    'assignments': <List<Object?>>[
      for (final MercyAssignment value in assignments)
        <Object?>[
          value.element.type.name,
          value.element.id,
          value.toDay.epochDay,
          value.scheduledForAtUtc?.millisecondsSinceEpoch,
        ],
    ],
    'exclusions': <List<Object?>>[
      for (final MercyExclusion value in exclusions)
        <Object?>[value.element.type.name, value.element.id, value.reason.name],
    ],
  };
  return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
}

List<Map<String, Object?>> _loadJson(List<MercyDailyLoad> values) =>
    <Map<String, Object?>>[
      for (final MercyDailyLoad value in values)
        <String, Object?>{
          'day': value.day.epochDay,
          'zone_id': value.day.zoneId,
          'cards': value.cards,
          'topics': value.topics,
        },
    ];

Map<String, Object?> _scopeJson(MercyScope scope) => switch (scope) {
  MercyCollectionScope() => <String, Object?>{'kind': 'collection'},
  final MercyBranchScope branch => <String, Object?>{
    'kind': 'branch',
    'branch_id': branch.branchId,
  },
  final MercySubsetScope subset => <String, Object?>{
    'kind': 'subset',
    'elements': <Map<String, Object?>>[
      for (final ElementRef element in subset.elements.toList()..sort())
        <String, Object?>{'id': element.id, 'type': element.type.name},
    ],
  },
};

MercyScope _scopeFromJson(Map<String, Object?> map) => switch (map['kind']) {
  'collection' => const MercyCollectionScope(),
  'branch' => MercyBranchScope(map['branch_id']! as String),
  'subset' => MercySubsetScope(<ElementRef>{
    for (final Object? raw in map['elements']! as List<Object?>)
      (() {
        final Map<String, Object?> value = (raw! as Map<Object?, Object?>)
            .cast<String, Object?>();
        return ElementRef(
          id: value['id']! as String,
          type: ElementType.values.byName(value['type']! as String),
        );
      })(),
  }),
  final Object? kind => throw FormatException('unknown Mercy scope kind', kind),
};

MercyAssignment _assignmentFromJson(Map<String, Object?> map) {
  final ElementType type = ElementType.values.byName(
    map['element_type']! as String,
  );
  final String zoneId = map['zone_id']! as String;
  final StudyDay from = _dayFromEpoch(map['from_day']! as int, zoneId);
  final StudyDay to = _dayFromEpoch(map['to_day']! as int, zoneId);
  final Object? scheduledAt = map['scheduled_for_at_utc'];
  return MercyAssignment(
    element: ElementRef(id: map['element_id']! as String, type: type),
    candidateRevision: map['revision']! as int,
    fromDay: from,
    toDay: to,
    priorityFraction: (map['priority_fraction']! as num).toDouble(),
    criteriaScore: (map['criteria_score']! as num).toDouble(),
    scheduledForAtUtc: scheduledAt is int
        ? DateTime.fromMillisecondsSinceEpoch(scheduledAt, isUtc: true)
        : null,
    scheduledForStudyDay: type.isTopic ? to : null,
  );
}

List<MercyDailyLoad> _loadFromJson(List<Object?> source) =>
    List<MercyDailyLoad>.unmodifiable(<MercyDailyLoad>[
      for (final Object? raw in source)
        (() {
          final Map<String, Object?> value = (raw! as Map<Object?, Object?>)
              .cast<String, Object?>();
          return MercyDailyLoad(
            day: _dayFromEpoch(
              value['day']! as int,
              value['zone_id']! as String,
            ),
            cards: value['cards']! as int,
            topics: value['topics']! as int,
          );
        })(),
    ]);

StudyDay _dayFromEpoch(int epochDay, String zoneId) {
  final DateTime date = DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return StudyDay(
    year: date.year,
    month: date.month,
    day: date.day,
    zoneId: zoneId,
  );
}

final class _MutableLedger {
  _MutableLedger({
    required this.window,
    required this.cardLoad,
    required this.topicLoad,
    required this.cardLimit,
    required this.topicLimit,
  }) : _beforeCardLoad = List<int>.unmodifiable(cardLoad),
       _beforeTopicLoad = List<int>.unmodifiable(topicLoad);

  factory _MutableLedger.fromRequest(
    MercyPreviewRequest request, {
    required int incomingCards,
    required int incomingTopics,
  }) {
    final List<int> cards = <int>[
      for (final MercyDestinationDay value in request.destinationWindow.days)
        value.beforeCardLoad,
    ];
    final List<int> topics = <int>[
      for (final MercyDestinationDay value in request.destinationWindow.days)
        value.beforeTopicLoad,
    ];
    late final int cardLimit;
    late final int topicLimit;
    switch (request.destinationPolicy) {
      case final MercyDailyCapacity capacity:
        cardLimit = capacity.cardsPerDay;
        topicLimit = capacity.topicsPerDay;
      case MercyDestinationHorizon():
        cardLimit =
            ((cards.fold<int>(0, (int a, int b) => a + b) + incomingCards) /
                    cards.length)
                .ceil();
        topicLimit =
            ((topics.fold<int>(0, (int a, int b) => a + b) + incomingTopics) /
                    topics.length)
                .ceil();
    }
    return _MutableLedger(
      window: request.destinationWindow,
      cardLoad: cards,
      topicLoad: topics,
      cardLimit: cardLimit,
      topicLimit: topicLimit,
    );
  }

  final MercyDestinationWindow window;
  final List<int> cardLoad;
  final List<int> topicLoad;
  final List<int> _beforeCardLoad;
  final List<int> _beforeTopicLoad;
  final int cardLimit;
  final int topicLimit;

  List<MercyDailyLoad> get beforeLoad =>
      List<MercyDailyLoad>.unmodifiable(<MercyDailyLoad>[
        for (var index = 0; index < window.days.length; index++)
          MercyDailyLoad(
            day: window.days[index].day,
            cards: _beforeCardLoad[index],
            topics: _beforeTopicLoad[index],
          ),
      ]);

  List<MercyDailyLoad> get afterLoad =>
      List<MercyDailyLoad>.unmodifiable(<MercyDailyLoad>[
        for (var index = 0; index < window.days.length; index++)
          MercyDailyLoad(
            day: window.days[index].day,
            cards: cardLoad[index],
            topics: topicLoad[index],
          ),
      ]);

  bool removeCurrent(MercyCandidate candidate) {
    final int index = _indexOf(candidate.currentEffectiveDueDay);
    if (index < 0) return false;
    final List<int> load = _loadFor(candidate.ref.type);
    if (load[index] < 1) {
      throw StateError(
        'before-load ledger omits ${candidate.ref} due '
        '${candidate.currentEffectiveDueDay}',
      );
    }
    load[index]--;
    return true;
  }

  void restoreCurrent(MercyCandidate candidate) {
    final int index = _indexOf(candidate.currentEffectiveDueDay);
    if (index >= 0) _loadFor(candidate.ref.type)[index]++;
  }

  int firstAvailableIndex(ElementType type, {StudyDay? notBefore}) {
    final List<int> load = _loadFor(type);
    final int limit = type == ElementType.card ? cardLimit : topicLimit;
    for (var index = 0; index < window.days.length; index++) {
      if (notBefore != null && window.days[index].day < notBefore) continue;
      if (load[index] < limit) return index;
    }
    return -1;
  }

  void add(ElementType type, int index) => _loadFor(type)[index]++;

  List<int> _loadFor(ElementType type) =>
      type == ElementType.card ? cardLoad : topicLoad;

  int _indexOf(StudyDay day) {
    if (day.zoneId != window.firstDay.zoneId ||
        day < window.firstDay ||
        day > window.lastDay) {
      return -1;
    }
    return window.firstDay.daysUntil(day);
  }
}

void _requireSameZone(StudyDay left, StudyDay right, String name) {
  if (left.zoneId != right.zoneId) {
    throw ArgumentError('$name mixes ${left.zoneId} and ${right.zoneId}');
  }
}

void _requireUnit(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError.value(value, name, 'must be finite and in [0, 1]');
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
