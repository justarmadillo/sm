/// Seeded long-horizon scheduler simulation and release gate.
///
/// The simulator deliberately depends on a small policy interface rather than
/// a concrete queue implementation. Production queue/overflow policies can be
/// adapted to [SchedulerSimulationPolicy] and tested against the same 365-day,
/// 12,000-element workload. The bundled reference policy is a transparent
/// capacity-ledger fixture; it is **[Product decision]**, not a claim about an
/// unpublished SuperMemo algorithm.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'deterministic_random.dart';

const String schedulerSimulationGateVersion = 'scheduler_simulation_gate_v1/1';
const int minimumSimulationDays = 365;
const int minimumSimulationCards = 10000;
const int minimumSimulationTopics = 2000;

/// Workload scenarios required by the authoritative scheduler contract.
enum SchedulerSimulationScenario {
  steadyDailyUse('steady_daily_use'),
  threeWeekAbsence('three_week_absence'),
  largeImport('large_import'),
  cardFormulationBurst('card_formulation_burst'),
  repeatedLater('repeated_later'),
  topPriorityOverload('top_priority_overload'),
  capChanges('cap_increases_and_decreases'),
  repeatedQueueRebuilds('repeated_queue_rebuilds'),
  mercyRecovery('mercy_recovery'),
  dstAndRollover('dst_and_rollover_transitions');

  const SchedulerSimulationScenario(this.wireName);

  final String wireName;
}

/// Several different population shapes are run for every scenario.
enum SimulationPriorityDistribution { uniform, topHeavy, bottomHeavy }

enum SimulationWorkKind { card, topic }

/// Event classes a simulated policy proposes as optimizer input.
enum SimulationOptimizerInputKind {
  genuineCardReview,
  practice,
  undoneReview,
  topicEncounter,
  calendarAdjustment,
}

/// Every contract rejection plus structural gate failures.
enum SimulationViolationCode {
  protectedAutomaticPostponement,
  mandatoryStepAutomaticPostponement,
  nondeterministicRebuild,
  futureLoadSpike,
  newCardAdmissionWithExhaustedDueCapacity,
  cardOrTopicStarvation,
  optimizerContamination,
  higherPriorityRetentionRegression,
  mandatoryStepOmitted,
  protectedWorkOmitted,
  durationDrivenAdmission,
  invalidPolicyOutput,
  policyError,
}

/// Release-scale simulation settings.
@immutable
final class SchedulerSimulationConfig {
  factory SchedulerSimulationConfig({
    int days = minimumSimulationDays,
    int cardCount = minimumSimulationCards,
    int topicCount = minimumSimulationTopics,
    String seed = 'incremental-reader-scheduler-gate-v1',
    int cardDailyCap = 200,
    int newCardDailyCap = 20,
    int topicDailyCap = 50,
    int maximumOrdinaryCardGap = 8,
    Iterable<SchedulerSimulationScenario> scenarios =
        SchedulerSimulationScenario.values,
    Iterable<SimulationPriorityDistribution> priorityDistributions =
        SimulationPriorityDistribution.values,
  }) {
    if (days < minimumSimulationDays) {
      throw ArgumentError.value(
        days,
        'days',
        'the release gate requires at least $minimumSimulationDays days',
      );
    }
    if (cardCount < minimumSimulationCards) {
      throw ArgumentError.value(
        cardCount,
        'cardCount',
        'the release gate requires at least $minimumSimulationCards cards',
      );
    }
    if (topicCount < minimumSimulationTopics) {
      throw ArgumentError.value(
        topicCount,
        'topicCount',
        'the release gate requires at least $minimumSimulationTopics topics',
      );
    }
    if (seed.trim().isEmpty) {
      throw ArgumentError.value(seed, 'seed', 'must not be empty');
    }
    for (final MapEntry<String, int> entry in <String, int>{
      'cardDailyCap': cardDailyCap,
      'newCardDailyCap': newCardDailyCap,
      'topicDailyCap': topicDailyCap,
      'maximumOrdinaryCardGap': maximumOrdinaryCardGap,
    }.entries) {
      if (entry.value <= 0) {
        throw ArgumentError.value(entry.value, entry.key, 'must be positive');
      }
    }
    final List<SchedulerSimulationScenario> scenarioList = scenarios
        .toSet()
        .toList(growable: false);
    final List<SimulationPriorityDistribution> distributionList =
        priorityDistributions.toSet().toList(growable: false);
    if (scenarioList.isEmpty || distributionList.length < 2) {
      throw ArgumentError(
        'the gate needs at least one scenario and several priority '
        'distributions',
      );
    }
    return SchedulerSimulationConfig._(
      days: days,
      cardCount: cardCount,
      topicCount: topicCount,
      seed: seed,
      cardDailyCap: cardDailyCap,
      newCardDailyCap: newCardDailyCap,
      topicDailyCap: topicDailyCap,
      maximumOrdinaryCardGap: maximumOrdinaryCardGap,
      scenarios: List<SchedulerSimulationScenario>.unmodifiable(scenarioList),
      priorityDistributions: List<SimulationPriorityDistribution>.unmodifiable(
        distributionList,
      ),
    );
  }

  const SchedulerSimulationConfig._({
    required this.days,
    required this.cardCount,
    required this.topicCount,
    required this.seed,
    required this.cardDailyCap,
    required this.newCardDailyCap,
    required this.topicDailyCap,
    required this.maximumOrdinaryCardGap,
    required this.scenarios,
    required this.priorityDistributions,
  });

  final int days;
  final int cardCount;
  final int topicCount;
  final String seed;
  final int cardDailyCap;
  final int newCardDailyCap;
  final int topicDailyCap;
  final int maximumOrdinaryCardGap;
  final List<SchedulerSimulationScenario> scenarios;
  final List<SimulationPriorityDistribution> priorityDistributions;
}

/// Aggregate candidate lanes for one simulated StudyDay.
@immutable
final class SimulationDayInput {
  SimulationDayInput({
    required this.scenario,
    required this.priorityDistribution,
    required this.dayIndex,
    required this.seed,
    required this.cardDailyCap,
    required this.newCardDailyCap,
    required this.topicDailyCap,
    required this.mandatoryStepCount,
    required this.protectedOldReviewBacklog,
    required this.protectedNewlyDueReviews,
    required List<int> regularOldReviewBacklogByDecile,
    required List<int> regularNewlyDueReviewsByDecile,
    required List<int> newCardsByDecile,
    required this.protectedOldTopicBacklog,
    required this.protectedNewlyDueTopics,
    required List<int> regularOldTopicBacklogByDecile,
    required List<int> regularNewlyDueTopicsByDecile,
    required List<int> futureCardResidualCapacity,
    required List<int> futureTopicResidualCapacity,
    required this.cardDurationMs,
    required this.topicDurationMs,
    required this.localDayLengthHours,
    required this.rolloverTransition,
    required this.mercyRequested,
    required this.manualLaterFraction,
  }) : regularOldReviewBacklogByDecile = _copyDeciles(
         regularOldReviewBacklogByDecile,
         'regularOldReviewBacklogByDecile',
       ),
       regularNewlyDueReviewsByDecile = _copyDeciles(
         regularNewlyDueReviewsByDecile,
         'regularNewlyDueReviewsByDecile',
       ),
       newCardsByDecile = _copyDeciles(newCardsByDecile, 'newCardsByDecile'),
       regularOldTopicBacklogByDecile = _copyDeciles(
         regularOldTopicBacklogByDecile,
         'regularOldTopicBacklogByDecile',
       ),
       regularNewlyDueTopicsByDecile = _copyDeciles(
         regularNewlyDueTopicsByDecile,
         'regularNewlyDueTopicsByDecile',
       ),
       futureCardResidualCapacity = _copyNonNegative(
         futureCardResidualCapacity,
         'futureCardResidualCapacity',
       ),
       futureTopicResidualCapacity = _copyNonNegative(
         futureTopicResidualCapacity,
         'futureTopicResidualCapacity',
       ) {
    for (final MapEntry<String, int> entry in <String, int>{
      'dayIndex': dayIndex,
      'cardDailyCap': cardDailyCap,
      'newCardDailyCap': newCardDailyCap,
      'topicDailyCap': topicDailyCap,
      'mandatoryStepCount': mandatoryStepCount,
      'protectedOldReviewBacklog': protectedOldReviewBacklog,
      'protectedNewlyDueReviews': protectedNewlyDueReviews,
      'protectedOldTopicBacklog': protectedOldTopicBacklog,
      'protectedNewlyDueTopics': protectedNewlyDueTopics,
      'cardDurationMs': cardDurationMs,
      'topicDurationMs': topicDurationMs,
    }.entries) {
      if (entry.value < 0) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'must be non-negative',
        );
      }
    }
    if (seed.trim().isEmpty) {
      throw ArgumentError.value(seed, 'seed', 'must not be empty');
    }
    if (!localDayLengthHours.isFinite || localDayLengthHours <= 0) {
      throw ArgumentError.value(
        localDayLengthHours,
        'localDayLengthHours',
        'must be finite and positive',
      );
    }
    if (!manualLaterFraction.isFinite ||
        manualLaterFraction < 0 ||
        manualLaterFraction > 1) {
      throw ArgumentError.value(
        manualLaterFraction,
        'manualLaterFraction',
        'must be finite and in 0..1',
      );
    }
  }

  final SchedulerSimulationScenario scenario;
  final SimulationPriorityDistribution priorityDistribution;
  final int dayIndex;
  final String seed;
  final int cardDailyCap;
  final int newCardDailyCap;
  final int topicDailyCap;
  final int mandatoryStepCount;
  final int protectedOldReviewBacklog;
  final int protectedNewlyDueReviews;
  final List<int> regularOldReviewBacklogByDecile;
  final List<int> regularNewlyDueReviewsByDecile;
  final List<int> newCardsByDecile;
  final int protectedOldTopicBacklog;
  final int protectedNewlyDueTopics;
  final List<int> regularOldTopicBacklogByDecile;
  final List<int> regularNewlyDueTopicsByDecile;

  /// Residual capacity after forecast canonical/effective load and a caller's
  /// explicit intraday-step headroom. Index zero is tomorrow.
  final List<int> futureCardResidualCapacity;
  final List<int> futureTopicResidualCapacity;

  /// Seeded realistic duration samples. Policies must report them but cannot
  /// use them to silently replace count-based admission.
  final int cardDurationMs;
  final int topicDurationMs;
  final double localDayLengthHours;
  final bool rolloverTransition;
  final bool mercyRequested;

  /// Seeded user behavior for the repeated-Later stress scenario. This is an
  /// observation, not a queue setting and never changes admission capacity.
  final double manualLaterFraction;

  int get protectedDueReviews =>
      protectedOldReviewBacklog + protectedNewlyDueReviews;
  int get protectedDueTopics =>
      protectedOldTopicBacklog + protectedNewlyDueTopics;
  int get regularOldReviewBacklog => _sum(regularOldReviewBacklogByDecile);
  int get regularNewlyDueReviews => _sum(regularNewlyDueReviewsByDecile);
  int get regularOldTopicBacklog => _sum(regularOldTopicBacklogByDecile);
  int get regularNewlyDueTopics => _sum(regularNewlyDueTopicsByDecile);

  SimulationDayInput withDurations({
    required int cardDurationMs,
    required int topicDurationMs,
  }) => SimulationDayInput(
    scenario: scenario,
    priorityDistribution: priorityDistribution,
    dayIndex: dayIndex,
    seed: seed,
    cardDailyCap: cardDailyCap,
    newCardDailyCap: newCardDailyCap,
    topicDailyCap: topicDailyCap,
    mandatoryStepCount: mandatoryStepCount,
    protectedOldReviewBacklog: protectedOldReviewBacklog,
    protectedNewlyDueReviews: protectedNewlyDueReviews,
    regularOldReviewBacklogByDecile: regularOldReviewBacklogByDecile,
    regularNewlyDueReviewsByDecile: regularNewlyDueReviewsByDecile,
    newCardsByDecile: newCardsByDecile,
    protectedOldTopicBacklog: protectedOldTopicBacklog,
    protectedNewlyDueTopics: protectedNewlyDueTopics,
    regularOldTopicBacklogByDecile: regularOldTopicBacklogByDecile,
    regularNewlyDueTopicsByDecile: regularNewlyDueTopicsByDecile,
    futureCardResidualCapacity: futureCardResidualCapacity,
    futureTopicResidualCapacity: futureTopicResidualCapacity,
    cardDurationMs: cardDurationMs,
    topicDurationMs: topicDurationMs,
    localDayLengthHours: localDayLengthHours,
    rolloverTransition: rolloverTransition,
    mercyRequested: mercyRequested,
    manualLaterFraction: manualLaterFraction,
  );
}

/// One future capacity-ledger allocation made by automatic overflow.
@immutable
final class SimulationOverflowAssignment {
  const SimulationOverflowAssignment({
    required this.kind,
    required this.priorityDecile,
    required this.count,
    required this.destinationDayIndex,
    this.protected = false,
    this.mandatoryStep = false,
  });

  final SimulationWorkKind kind;
  final int priorityDecile;
  final int count;
  final int destinationDayIndex;
  final bool protected;
  final bool mandatoryStep;
}

/// One visible opportunity in a simulated presentation plan.
@immutable
final class SimulationOpportunity {
  const SimulationOpportunity({required this.kind, this.mandatory = false});

  final SimulationWorkKind kind;
  final bool mandatory;
}

/// Complete decision returned by an adapted scheduling policy.
@immutable
final class SimulationDayDecision {
  SimulationDayDecision({
    required this.admittedMandatorySteps,
    required this.admittedProtectedReviews,
    required List<int> admittedRegularReviewsByDecile,
    required List<int> admittedNewCardsByDecile,
    required this.admittedProtectedTopics,
    required List<int> admittedRegularTopicsByDecile,
    required Iterable<SimulationOverflowAssignment> automaticOverflow,
    Iterable<SimulationOverflowAssignment> mercyRedistribution =
        const <SimulationOverflowAssignment>[],
    required Iterable<SimulationOpportunity> presentation,
    required Map<SimulationOptimizerInputKind, int> optimizerInputs,
  }) : admittedRegularReviewsByDecile = _copyDeciles(
         admittedRegularReviewsByDecile,
         'admittedRegularReviewsByDecile',
       ),
       admittedNewCardsByDecile = _copyDeciles(
         admittedNewCardsByDecile,
         'admittedNewCardsByDecile',
       ),
       admittedRegularTopicsByDecile = _copyDeciles(
         admittedRegularTopicsByDecile,
         'admittedRegularTopicsByDecile',
       ),
       automaticOverflow = List<SimulationOverflowAssignment>.unmodifiable(
         automaticOverflow,
       ),
       mercyRedistribution = List<SimulationOverflowAssignment>.unmodifiable(
         mercyRedistribution,
       ),
       presentation = List<SimulationOpportunity>.unmodifiable(presentation),
       optimizerInputs = Map<SimulationOptimizerInputKind, int>.unmodifiable(
         optimizerInputs,
       ) {
    if (admittedMandatorySteps < 0 ||
        admittedProtectedReviews < 0 ||
        admittedProtectedTopics < 0) {
      throw ArgumentError('admission counts must be non-negative');
    }
    for (final MapEntry<SimulationOptimizerInputKind, int> entry
        in optimizerInputs.entries) {
      if (entry.value < 0) {
        throw ArgumentError('optimizer input counts must be non-negative');
      }
    }
  }

  final int admittedMandatorySteps;
  final int admittedProtectedReviews;
  final List<int> admittedRegularReviewsByDecile;
  final List<int> admittedNewCardsByDecile;
  final int admittedProtectedTopics;
  final List<int> admittedRegularTopicsByDecile;
  final List<SimulationOverflowAssignment> automaticOverflow;
  final List<SimulationOverflowAssignment> mercyRedistribution;
  final List<SimulationOpportunity> presentation;
  final Map<SimulationOptimizerInputKind, int> optimizerInputs;

  int get admittedRegularReviews => _sum(admittedRegularReviewsByDecile);
  int get admittedNewCards => _sum(admittedNewCardsByDecile);
  int get admittedRegularTopics => _sum(admittedRegularTopicsByDecile);
  int get ordinaryCardOpportunities =>
      admittedProtectedReviews + admittedRegularReviews + admittedNewCards;
  int get ordinaryTopicOpportunities =>
      admittedProtectedTopics + admittedRegularTopics;

  /// Stable structural form used for rebuild and duration-independence checks.
  String get structuralFingerprint {
    final String assignments = automaticOverflow
        .map(
          (SimulationOverflowAssignment value) =>
              '${value.kind.name}:${value.priorityDecile}:${value.count}:'
              '${value.destinationDayIndex}:${value.protected}:'
              '${value.mandatoryStep}',
        )
        .join(',');
    final String mercy = mercyRedistribution
        .map(
          (SimulationOverflowAssignment value) =>
              '${value.kind.name}:${value.priorityDecile}:${value.count}:'
              '${value.destinationDayIndex}:${value.protected}:'
              '${value.mandatoryStep}',
        )
        .join(',');
    final String opportunities = presentation
        .map(
          (SimulationOpportunity value) =>
              '${value.kind.name}:${value.mandatory}',
        )
        .join(',');
    final String optimizer = SimulationOptimizerInputKind.values
        .map(
          (SimulationOptimizerInputKind kind) =>
              '${kind.name}:${optimizerInputs[kind] ?? 0}',
        )
        .join(',');
    return <String>[
      '$admittedMandatorySteps',
      '$admittedProtectedReviews',
      admittedRegularReviewsByDecile.join(','),
      admittedNewCardsByDecile.join(','),
      '$admittedProtectedTopics',
      admittedRegularTopicsByDecile.join(','),
      assignments,
      mercy,
      opportunities,
      optimizer,
    ].join('|');
  }
}

/// Adapter implemented by a production or experimental scheduling policy.
abstract interface class SchedulerSimulationPolicy {
  String get policyVersion;

  SimulationDayDecision plan(SimulationDayInput input);
}

/// A single contract failure found by the long-horizon gate.
@immutable
final class SimulationViolation {
  const SimulationViolation({
    required this.code,
    required this.scenario,
    required this.priorityDistribution,
    required this.dayIndex,
    required this.detail,
  });

  final SimulationViolationCode code;
  final SchedulerSimulationScenario scenario;
  final SimulationPriorityDistribution priorityDistribution;
  final int dayIndex;
  final String detail;
}

/// Summary for one scenario/distribution run.
@immutable
final class SimulationScenarioReport {
  const SimulationScenarioReport({
    required this.scenario,
    required this.priorityDistribution,
    required this.daysSimulated,
    required this.maximumCardBacklog,
    required this.maximumTopicBacklog,
    required this.cardOpportunities,
    required this.topicOpportunities,
    required this.deterministicDigest,
    required this.violationCount,
  });

  final SchedulerSimulationScenario scenario;
  final SimulationPriorityDistribution priorityDistribution;
  final int daysSimulated;
  final int maximumCardBacklog;
  final int maximumTopicBacklog;
  final int cardOpportunities;
  final int topicOpportunities;
  final int deterministicDigest;
  final int violationCount;
}

/// Reproducible release-gate result with one entry per rejection.
@immutable
final class SchedulerSimulationGateReport {
  const SchedulerSimulationGateReport({
    required this.gateVersion,
    required this.policyVersion,
    required this.seed,
    required this.days,
    required this.cardCount,
    required this.topicCount,
    required this.scenarios,
    required this.violations,
  });

  final String gateVersion;
  final String policyVersion;
  final String seed;
  final int days;
  final int cardCount;
  final int topicCount;
  final List<SimulationScenarioReport> scenarios;
  final List<SimulationViolation> violations;

  bool get accepted => violations.isEmpty;

  Set<SimulationViolationCode> get rejectedInvariants =>
      Set<SimulationViolationCode>.unmodifiable(
        violations.map((SimulationViolation value) => value.code).toSet(),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'gate_version': gateVersion,
    'policy_version': policyVersion,
    'seed': seed,
    'days': days,
    'cards': cardCount,
    'topics': topicCount,
    'accepted': accepted,
    'scenario_runs': <Map<String, Object?>>[
      for (final SimulationScenarioReport report in scenarios)
        <String, Object?>{
          'scenario': report.scenario.wireName,
          'priority_distribution': report.priorityDistribution.name,
          'days': report.daysSimulated,
          'max_card_backlog': report.maximumCardBacklog,
          'max_topic_backlog': report.maximumTopicBacklog,
          'card_opportunities': report.cardOpportunities,
          'topic_opportunities': report.topicOpportunities,
          'digest': report.deterministicDigest,
          'violations': report.violationCount,
        },
    ],
    'violations': <Map<String, Object?>>[
      for (final SimulationViolation violation in violations)
        <String, Object?>{
          'code': violation.code.name,
          'scenario': violation.scenario.wireName,
          'priority_distribution': violation.priorityDistribution.name,
          'day': violation.dayIndex,
          'detail': violation.detail,
        },
    ],
  };
}

/// Executes every configured scenario under every priority distribution.
@immutable
final class SeededSchedulerSimulationGate {
  const SeededSchedulerSimulationGate();

  SchedulerSimulationGateReport run({
    required SchedulerSimulationPolicy policy,
    SchedulerSimulationConfig? config,
  }) {
    final SchedulerSimulationConfig effective =
        config ?? SchedulerSimulationConfig();
    if (policy.policyVersion.trim().isEmpty) {
      throw ArgumentError('policyVersion must not be empty');
    }
    final List<SimulationViolation> violations = <SimulationViolation>[];
    final List<SimulationScenarioReport> reports = <SimulationScenarioReport>[];
    for (final SchedulerSimulationScenario scenario in effective.scenarios) {
      for (final SimulationPriorityDistribution distribution
          in effective.priorityDistributions) {
        final int before = violations.length;
        reports.add(
          _runScenario(
            policy: policy,
            config: effective,
            scenario: scenario,
            distribution: distribution,
            violations: violations,
          ),
        );
        assert(reports.last.violationCount == violations.length - before);
      }
    }
    return SchedulerSimulationGateReport(
      gateVersion: schedulerSimulationGateVersion,
      policyVersion: policy.policyVersion,
      seed: effective.seed,
      days: effective.days,
      cardCount: effective.cardCount,
      topicCount: effective.topicCount,
      scenarios: List<SimulationScenarioReport>.unmodifiable(reports),
      violations: List<SimulationViolation>.unmodifiable(violations),
    );
  }

  SimulationScenarioReport _runScenario({
    required SchedulerSimulationPolicy policy,
    required SchedulerSimulationConfig config,
    required SchedulerSimulationScenario scenario,
    required SimulationPriorityDistribution distribution,
    required List<SimulationViolation> violations,
  }) {
    final _SimulationState state = _SimulationState(config.days);
    final DeterministicRandom random = DeterministicRandom(
      '${config.seed}:${scenario.wireName}:${distribution.name}',
    );
    var digest = 0;
    var maximumCardBacklog = 0;
    var maximumTopicBacklog = 0;
    var cardOpportunities = 0;
    var topicOpportunities = 0;
    final int violationStart = violations.length;

    for (var day = 0; day < config.days; day++) {
      final _GeneratedLoad generated = _generateLoad(
        config: config,
        scenario: scenario,
        distribution: distribution,
        day: day,
        random: random,
        state: state,
      );
      if (_isAbsenceDay(scenario, day)) {
        state.accumulateWithoutStudy(generated);
        maximumCardBacklog = math.max(
          maximumCardBacklog,
          state.totalCardBacklog,
        );
        maximumTopicBacklog = math.max(
          maximumTopicBacklog,
          state.totalTopicBacklog,
        );
        continue;
      }

      final SimulationDayInput input = _buildInput(
        config: config,
        scenario: scenario,
        distribution: distribution,
        day: day,
        random: random,
        state: state,
        generated: generated,
      );
      SimulationDayDecision decision;
      try {
        decision = policy.plan(input);
      } catch (error) {
        violations.add(
          SimulationViolation(
            code: SimulationViolationCode.policyError,
            scenario: scenario,
            priorityDistribution: distribution,
            dayIndex: day,
            detail: '$error',
          ),
        );
        state.accumulateWithoutStudy(generated);
        continue;
      }

      final int rebuildCount =
          scenario == SchedulerSimulationScenario.repeatedQueueRebuilds ? 5 : 2;
      for (var rebuild = 1; rebuild < rebuildCount; rebuild++) {
        try {
          final SimulationDayDecision repeated = policy.plan(input);
          if (repeated.structuralFingerprint !=
              decision.structuralFingerprint) {
            _addViolation(
              violations,
              input,
              SimulationViolationCode.nondeterministicRebuild,
              'identical rebuild $rebuild returned a different plan',
            );
            break;
          }
        } catch (error) {
          _addViolation(
            violations,
            input,
            SimulationViolationCode.policyError,
            'rebuild $rebuild failed: $error',
          );
          break;
        }
      }

      try {
        final SimulationDayDecision durationVariant = policy.plan(
          input.withDurations(
            cardDurationMs: input.cardDurationMs * 3 + 1,
            topicDurationMs: input.topicDurationMs * 3 + 1,
          ),
        );
        if (durationVariant.structuralFingerprint !=
            decision.structuralFingerprint) {
          _addViolation(
            violations,
            input,
            SimulationViolationCode.durationDrivenAdmission,
            'changing only duration samples changed count-based admission',
          );
        }
      } catch (error) {
        _addViolation(
          violations,
          input,
          SimulationViolationCode.policyError,
          'duration-independence rebuild failed: $error',
        );
      }

      final bool structurallyValid = _validateDecision(
        input: input,
        decision: decision,
        maximumOrdinaryCardGap: config.maximumOrdinaryCardGap,
        violations: violations,
      );
      digest = stableHash('$digest:${decision.structuralFingerprint}');
      cardOpportunities +=
          decision.ordinaryCardOpportunities + decision.admittedMandatorySteps;
      topicOpportunities += decision.ordinaryTopicOpportunities;
      if (structurallyValid) {
        state.apply(input, generated, decision);
      } else {
        state.accumulateWithoutStudy(generated);
      }
      maximumCardBacklog = math.max(maximumCardBacklog, state.totalCardBacklog);
      maximumTopicBacklog = math.max(
        maximumTopicBacklog,
        state.totalTopicBacklog,
      );
    }

    return SimulationScenarioReport(
      scenario: scenario,
      priorityDistribution: distribution,
      daysSimulated: config.days,
      maximumCardBacklog: maximumCardBacklog,
      maximumTopicBacklog: maximumTopicBacklog,
      cardOpportunities: cardOpportunities,
      topicOpportunities: topicOpportunities,
      deterministicDigest: digest,
      violationCount: violations.length - violationStart,
    );
  }
}

/// Transparent, capacity-aware fixture policy used to verify gate plumbing.
///
/// It enforces the public invariants but is not the production scheduler and
/// intentionally contains no guessed Mercy weights, SuperMemo drift formula,
/// or undocumented overflow horizon.
@immutable
final class CapacityAwareSimulationReferencePolicy
    implements SchedulerSimulationPolicy {
  const CapacityAwareSimulationReferencePolicy();

  @override
  String get policyVersion => 'capacity_aware_simulation_reference_v1/1';

  @override
  SimulationDayDecision plan(SimulationDayInput input) {
    final _OverflowResult cardOverflow = _allocateOldOverflow(
      kind: SimulationWorkKind.card,
      todayIndex: input.dayIndex,
      oldBacklog: input.regularOldReviewBacklogByDecile,
      newlyDueCount: input.regularNewlyDueReviews,
      protectedCount: input.protectedDueReviews,
      dailyCap: input.cardDailyCap,
      futureResidualCapacity: input.futureCardResidualCapacity,
      moveAll: input.mercyRequested,
    );
    final _OverflowResult topicOverflow = _allocateOldOverflow(
      kind: SimulationWorkKind.topic,
      todayIndex: input.dayIndex,
      oldBacklog: input.regularOldTopicBacklogByDecile,
      newlyDueCount: input.regularNewlyDueTopics,
      protectedCount: input.protectedDueTopics,
      dailyCap: input.topicDailyCap,
      futureResidualCapacity: input.futureTopicResidualCapacity,
      moveAll: input.mercyRequested,
    );

    final List<int> dueReviews = _addDeciles(
      cardOverflow.remainingOld,
      input.regularNewlyDueReviewsByDecile,
    );
    final int reviewCapacity = math.max(
      0,
      input.cardDailyCap - input.protectedDueReviews,
    );
    final List<int> admittedReviews = _takeByPriority(
      dueReviews,
      reviewCapacity,
    );
    final bool dueReviewExcluded = _sum(admittedReviews) < _sum(dueReviews);
    final int remainingCardCapacity = math.max(
      0,
      reviewCapacity - _sum(admittedReviews),
    );
    final List<int> admittedNew = dueReviewExcluded
        ? _zeroDeciles()
        : _takeByPriority(
            input.newCardsByDecile,
            math.min(input.newCardDailyCap, remainingCardCapacity),
          );

    final List<int> dueTopics = _addDeciles(
      topicOverflow.remainingOld,
      input.regularNewlyDueTopicsByDecile,
    );
    final int topicCapacity = math.max(
      0,
      input.topicDailyCap - input.protectedDueTopics,
    );
    final List<int> admittedTopics = _takeByPriority(dueTopics, topicCapacity);

    final int ordinaryCards =
        input.protectedDueReviews + _sum(admittedReviews) + _sum(admittedNew);
    final int ordinaryTopics = input.protectedDueTopics + _sum(admittedTopics);
    final List<SimulationOpportunity> presentation = _mergeOpportunities(
      mandatoryCards: input.mandatoryStepCount,
      ordinaryCards: ordinaryCards,
      ordinaryTopics: ordinaryTopics,
    );
    final int laterCards = (input.manualLaterFraction * _sum(admittedReviews))
        .floor();
    final int genuineReviews =
        input.mandatoryStepCount + ordinaryCards - laterCards;

    return SimulationDayDecision(
      admittedMandatorySteps: input.mandatoryStepCount,
      admittedProtectedReviews: input.protectedDueReviews,
      admittedRegularReviewsByDecile: admittedReviews,
      admittedNewCardsByDecile: admittedNew,
      admittedProtectedTopics: input.protectedDueTopics,
      admittedRegularTopicsByDecile: admittedTopics,
      automaticOverflow: input.mercyRequested
          ? const <SimulationOverflowAssignment>[]
          : <SimulationOverflowAssignment>[
              ...cardOverflow.assignments,
              ...topicOverflow.assignments,
            ],
      mercyRedistribution: input.mercyRequested
          ? <SimulationOverflowAssignment>[
              ...cardOverflow.assignments,
              ...topicOverflow.assignments,
            ]
          : const <SimulationOverflowAssignment>[],
      presentation: presentation,
      optimizerInputs: <SimulationOptimizerInputKind, int>{
        SimulationOptimizerInputKind.genuineCardReview: genuineReviews,
      },
    );
  }
}

final class _OverflowResult {
  const _OverflowResult({
    required this.remainingOld,
    required this.assignments,
  });

  final List<int> remainingOld;
  final List<SimulationOverflowAssignment> assignments;
}

_OverflowResult _allocateOldOverflow({
  required SimulationWorkKind kind,
  required int todayIndex,
  required List<int> oldBacklog,
  required int newlyDueCount,
  required int protectedCount,
  required int dailyCap,
  required List<int> futureResidualCapacity,
  bool moveAll = false,
}) {
  final List<int> remaining = List<int>.from(oldBacklog);
  final int ordinaryCapacity = math.max(0, dailyCap - protectedCount);
  final int oldRoom = moveAll
      ? 0
      : math.max(0, ordinaryCapacity - newlyDueCount);
  var toMove = math.max(0, _sum(oldBacklog) - oldRoom);
  final List<int> selected = _zeroDeciles();
  for (var decile = 9; decile >= 0 && toMove > 0; decile--) {
    final int moved = math.min(remaining[decile], toMove);
    remaining[decile] -= moved;
    selected[decile] += moved;
    toMove -= moved;
  }

  final List<int> residual = List<int>.from(futureResidualCapacity);
  final List<SimulationOverflowAssignment> assignments =
      <SimulationOverflowAssignment>[];
  for (var decile = 0; decile < 10; decile++) {
    var count = selected[decile];
    for (var offset = 0; offset < residual.length && count > 0; offset++) {
      final int assigned = math.min(count, residual[offset]);
      if (assigned == 0) continue;
      residual[offset] -= assigned;
      count -= assigned;
      assignments.add(
        SimulationOverflowAssignment(
          kind: kind,
          priorityDecile: decile + 1,
          count: assigned,
          destinationDayIndex: todayIndex + offset + 1,
        ),
      );
    }
    // No capacity means no postponement: leave it genuinely overdue.
    remaining[decile] += count;
  }
  return _OverflowResult(
    remainingOld: List<int>.unmodifiable(remaining),
    assignments: List<SimulationOverflowAssignment>.unmodifiable(assignments),
  );
}

List<SimulationOpportunity> _mergeOpportunities({
  required int mandatoryCards,
  required int ordinaryCards,
  required int ordinaryTopics,
}) {
  var mandatory = mandatoryCards;
  var cards = ordinaryCards;
  var topics = ordinaryTopics;
  var patternCursor = 0;
  var ordinaryCardGap = 0;
  final List<SimulationOpportunity> result = <SimulationOpportunity>[];
  while (mandatory > 0 || cards > 0 || topics > 0) {
    final bool cardTurn = patternCursor < 4;
    if ((cardTurn && (mandatory > 0 || cards > 0)) || topics == 0) {
      if (mandatory > 0) {
        result.add(
          const SimulationOpportunity(
            kind: SimulationWorkKind.card,
            mandatory: true,
          ),
        );
        mandatory--;
      } else if (cards > 0) {
        result.add(const SimulationOpportunity(kind: SimulationWorkKind.card));
        cards--;
        ordinaryCardGap++;
        patternCursor++;
      } else {
        result.add(const SimulationOpportunity(kind: SimulationWorkKind.topic));
        topics--;
        ordinaryCardGap = 0;
        patternCursor = 0;
      }
    } else if (topics > 0) {
      result.add(const SimulationOpportunity(kind: SimulationWorkKind.topic));
      topics--;
      ordinaryCardGap = 0;
      patternCursor = 0;
    } else {
      patternCursor = 0;
    }
    if (ordinaryCardGap >= 8 && topics > 0) patternCursor = 4;
  }
  return result;
}

bool _validateDecision({
  required SimulationDayInput input,
  required SimulationDayDecision decision,
  required int maximumOrdinaryCardGap,
  required List<SimulationViolation> violations,
}) {
  var valid = true;
  void invalid(String detail) {
    valid = false;
    _addViolation(
      violations,
      input,
      SimulationViolationCode.invalidPolicyOutput,
      detail,
    );
  }

  if (decision.admittedMandatorySteps > input.mandatoryStepCount ||
      decision.admittedProtectedReviews > input.protectedDueReviews ||
      decision.admittedProtectedTopics > input.protectedDueTopics) {
    invalid('admission exceeds an available protected/mandatory lane');
  }
  if (!_fits(
        decision.admittedRegularReviewsByDecile,
        _addDeciles(
          input.regularOldReviewBacklogByDecile,
          input.regularNewlyDueReviewsByDecile,
        ),
      ) ||
      !_fits(decision.admittedNewCardsByDecile, input.newCardsByDecile) ||
      !_fits(
        decision.admittedRegularTopicsByDecile,
        _addDeciles(
          input.regularOldTopicBacklogByDecile,
          input.regularNewlyDueTopicsByDecile,
        ),
      )) {
    invalid('admission exceeds available candidates');
  }

  final List<int> overflowCards = _zeroDeciles();
  final List<int> overflowTopics = _zeroDeciles();
  final Map<int, int> cardDestinationLoad = <int, int>{};
  final Map<int, int> topicDestinationLoad = <int, int>{};
  final List<SimulationOverflowAssignment> allRedistributions =
      <SimulationOverflowAssignment>[
        ...decision.automaticOverflow,
        ...decision.mercyRedistribution,
      ];
  for (final SimulationOverflowAssignment assignment in allRedistributions) {
    if (assignment.count <= 0 ||
        assignment.priorityDecile < 1 ||
        assignment.priorityDecile > 10 ||
        assignment.destinationDayIndex <= input.dayIndex) {
      invalid('automatic-overflow assignment has invalid coordinates');
      continue;
    }
    if (assignment.protected &&
        decision.automaticOverflow.contains(assignment)) {
      _addViolation(
        violations,
        input,
        SimulationViolationCode.protectedAutomaticPostponement,
        'protected work was automatically postponed',
      );
    }
    if (assignment.mandatoryStep &&
        decision.automaticOverflow.contains(assignment)) {
      _addViolation(
        violations,
        input,
        SimulationViolationCode.mandatoryStepAutomaticPostponement,
        'a learning/relearning step was automatically postponed',
      );
    }
    final int index = assignment.priorityDecile - 1;
    if (assignment.kind == SimulationWorkKind.card) {
      overflowCards[index] += assignment.count;
      cardDestinationLoad.update(
        assignment.destinationDayIndex,
        (int value) => value + assignment.count,
        ifAbsent: () => assignment.count,
      );
    } else {
      overflowTopics[index] += assignment.count;
      topicDestinationLoad.update(
        assignment.destinationDayIndex,
        (int value) => value + assignment.count,
        ifAbsent: () => assignment.count,
      );
    }
  }
  if (!_fits(overflowCards, input.regularOldReviewBacklogByDecile) ||
      !_fits(overflowTopics, input.regularOldTopicBacklogByDecile)) {
    invalid('automatic overflow moved work that was not old regular backlog');
  }
  _validateDestinationCapacity(
    input: input,
    loads: cardDestinationLoad,
    residual: input.futureCardResidualCapacity,
    kind: SimulationWorkKind.card,
    violations: violations,
  );
  _validateDestinationCapacity(
    input: input,
    loads: topicDestinationLoad,
    residual: input.futureTopicResidualCapacity,
    kind: SimulationWorkKind.topic,
    violations: violations,
  );
  _validatePriorityAllocation(input, decision, violations);

  if (decision.admittedMandatorySteps != input.mandatoryStepCount) {
    _addViolation(
      violations,
      input,
      SimulationViolationCode.mandatoryStepOmitted,
      'not every due mandatory step was admitted',
    );
  }
  if (decision.admittedProtectedReviews != input.protectedDueReviews ||
      decision.admittedProtectedTopics != input.protectedDueTopics) {
    _addViolation(
      violations,
      input,
      SimulationViolationCode.protectedWorkOmitted,
      'not every protected due element was admitted',
    );
  }

  final int dueReviewAfterOverflow =
      input.regularOldReviewBacklog +
      input.regularNewlyDueReviews -
      _sum(overflowCards);
  final int excludedDueReviews =
      dueReviewAfterOverflow - decision.admittedRegularReviews;
  if (excludedDueReviews > 0 && decision.admittedNewCards > 0) {
    _addViolation(
      violations,
      input,
      SimulationViolationCode.newCardAdmissionWithExhaustedDueCapacity,
      '$excludedDueReviews due reviews were excluded while '
      '${decision.admittedNewCards} new cards were admitted',
    );
  }

  for (final MapEntry<SimulationOptimizerInputKind, int> entry
      in decision.optimizerInputs.entries) {
    if (entry.key != SimulationOptimizerInputKind.genuineCardReview &&
        entry.value > 0) {
      _addViolation(
        violations,
        input,
        SimulationViolationCode.optimizerContamination,
        '${entry.key.name} supplied ${entry.value} optimizer observations',
      );
    }
  }
  final int expectedGenuineReviews =
      decision.admittedMandatorySteps +
      decision.ordinaryCardOpportunities -
      (decision.admittedRegularReviews * input.manualLaterFraction).floor();
  final int reportedGenuineReviews =
      decision.optimizerInputs[SimulationOptimizerInputKind
          .genuineCardReview] ??
      0;
  if (reportedGenuineReviews > expectedGenuineReviews) {
    _addViolation(
      violations,
      input,
      SimulationViolationCode.optimizerContamination,
      'manual Later was counted as a genuine optimizer observation',
    );
  } else if (reportedGenuineReviews < expectedGenuineReviews) {
    invalid('genuine card-review optimizer observations were omitted');
  }
  _validatePresentation(
    input: input,
    decision: decision,
    maximumOrdinaryCardGap: maximumOrdinaryCardGap,
    violations: violations,
  );
  return valid;
}

void _validateDestinationCapacity({
  required SimulationDayInput input,
  required Map<int, int> loads,
  required List<int> residual,
  required SimulationWorkKind kind,
  required List<SimulationViolation> violations,
}) {
  for (final MapEntry<int, int> entry in loads.entries) {
    final int offset = entry.key - input.dayIndex - 1;
    final int available = offset >= 0 && offset < residual.length
        ? residual[offset]
        : 0;
    if (entry.value > available) {
      _addViolation(
        violations,
        input,
        SimulationViolationCode.futureLoadSpike,
        '${kind.name} overflow assigned ${entry.value} to day ${entry.key} '
        'with residual capacity $available',
      );
    }
  }
}

void _validatePriorityAllocation(
  SimulationDayInput input,
  SimulationDayDecision decision,
  List<SimulationViolation> violations,
) {
  for (final SimulationWorkKind kind in SimulationWorkKind.values) {
    final List<SimulationOverflowAssignment> assignments =
        <SimulationOverflowAssignment>[
              ...decision.automaticOverflow,
              ...decision.mercyRedistribution,
            ]
            .where((SimulationOverflowAssignment value) => value.kind == kind)
            .toList();
    for (var left = 0; left < assignments.length; left++) {
      for (var right = left + 1; right < assignments.length; right++) {
        final SimulationOverflowAssignment a = assignments[left];
        final SimulationOverflowAssignment b = assignments[right];
        if (a.priorityDecile < b.priorityDecile &&
            a.destinationDayIndex > b.destinationDayIndex) {
          _addViolation(
            violations,
            input,
            SimulationViolationCode.higherPriorityRetentionRegression,
            '${kind.name} priority decile ${a.priorityDecile} was placed '
            'after lower-priority decile ${b.priorityDecile}',
          );
          return;
        }
        if (b.priorityDecile < a.priorityDecile &&
            b.destinationDayIndex > a.destinationDayIndex) {
          _addViolation(
            violations,
            input,
            SimulationViolationCode.higherPriorityRetentionRegression,
            '${kind.name} priority decile ${b.priorityDecile} was placed '
            'after lower-priority decile ${a.priorityDecile}',
          );
          return;
        }
      }
    }
  }
}

void _validatePresentation({
  required SimulationDayInput input,
  required SimulationDayDecision decision,
  required int maximumOrdinaryCardGap,
  required List<SimulationViolation> violations,
}) {
  final int visibleMandatory = decision.presentation
      .where((SimulationOpportunity value) => value.mandatory)
      .length;
  final int visibleCards = decision.presentation
      .where(
        (SimulationOpportunity value) =>
            value.kind == SimulationWorkKind.card && !value.mandatory,
      )
      .length;
  final int visibleTopics = decision.presentation
      .where(
        (SimulationOpportunity value) =>
            value.kind == SimulationWorkKind.topic && !value.mandatory,
      )
      .length;
  if (visibleMandatory != decision.admittedMandatorySteps ||
      visibleCards != decision.ordinaryCardOpportunities ||
      visibleTopics != decision.ordinaryTopicOpportunities) {
    _addViolation(
      violations,
      input,
      SimulationViolationCode.cardOrTopicStarvation,
      'presentation omitted or duplicated admitted opportunities',
    );
    return;
  }

  var ordinaryCardGap = 0;
  var topicsRemaining = visibleTopics;
  var cardsRemaining = visibleCards;
  for (final SimulationOpportunity opportunity in decision.presentation) {
    if (opportunity.mandatory) continue;
    if (opportunity.kind == SimulationWorkKind.card) {
      cardsRemaining--;
      if (topicsRemaining > 0) ordinaryCardGap++;
      if (topicsRemaining > 0 &&
          cardsRemaining >= 0 &&
          ordinaryCardGap > maximumOrdinaryCardGap) {
        _addViolation(
          violations,
          input,
          SimulationViolationCode.cardOrTopicStarvation,
          'a topic waited behind $ordinaryCardGap ordinary card opportunities',
        );
        return;
      }
    } else {
      topicsRemaining--;
      ordinaryCardGap = 0;
    }
  }
}

void _addViolation(
  List<SimulationViolation> violations,
  SimulationDayInput input,
  SimulationViolationCode code,
  String detail,
) {
  violations.add(
    SimulationViolation(
      code: code,
      scenario: input.scenario,
      priorityDistribution: input.priorityDistribution,
      dayIndex: input.dayIndex,
      detail: detail,
    ),
  );
}

final class _GeneratedLoad {
  const _GeneratedLoad({
    required this.protectedReviews,
    required this.regularReviews,
    required this.newCards,
    required this.protectedTopics,
    required this.regularTopics,
    required this.mandatorySteps,
  });

  final int protectedReviews;
  final List<int> regularReviews;
  final List<int> newCards;
  final int protectedTopics;
  final List<int> regularTopics;
  final int mandatorySteps;
}

final class _SimulationState {
  _SimulationState(int days)
    : scheduledCards = <List<int>>[
        for (var index = 0; index <= days; index++) _zeroDeciles(),
      ],
      scheduledTopics = <List<int>>[
        for (var index = 0; index <= days; index++) _zeroDeciles(),
      ];

  int protectedReviewBacklog = 0;
  List<int> regularReviewBacklog = _zeroDeciles();
  List<int> newCardPool = _zeroDeciles();
  int protectedTopicBacklog = 0;
  List<int> regularTopicBacklog = _zeroDeciles();
  final List<List<int>> scheduledCards;
  final List<List<int>> scheduledTopics;

  int get totalCardBacklog =>
      protectedReviewBacklog + _sum(regularReviewBacklog) + _sum(newCardPool);
  int get totalTopicBacklog =>
      protectedTopicBacklog + _sum(regularTopicBacklog);

  void accumulateWithoutStudy(_GeneratedLoad generated) {
    protectedReviewBacklog += generated.protectedReviews;
    regularReviewBacklog = _addDeciles(
      regularReviewBacklog,
      generated.regularReviews,
    );
    newCardPool = _addDeciles(newCardPool, generated.newCards);
    protectedTopicBacklog += generated.protectedTopics;
    regularTopicBacklog = _addDeciles(
      regularTopicBacklog,
      generated.regularTopics,
    );
  }

  void apply(
    SimulationDayInput input,
    _GeneratedLoad generated,
    SimulationDayDecision decision,
  ) {
    final List<int> overflowCards = _zeroDeciles();
    final List<int> overflowTopics = _zeroDeciles();
    for (final SimulationOverflowAssignment assignment
        in <SimulationOverflowAssignment>[
          ...decision.automaticOverflow,
          ...decision.mercyRedistribution,
        ]) {
      final int index = assignment.priorityDecile - 1;
      if (assignment.kind == SimulationWorkKind.card) {
        overflowCards[index] += assignment.count;
        if (assignment.destinationDayIndex < scheduledCards.length) {
          scheduledCards[assignment.destinationDayIndex][index] +=
              assignment.count;
        }
      } else {
        overflowTopics[index] += assignment.count;
        if (assignment.destinationDayIndex < scheduledTopics.length) {
          scheduledTopics[assignment.destinationDayIndex][index] +=
              assignment.count;
        }
      }
    }

    protectedReviewBacklog =
        input.protectedDueReviews - decision.admittedProtectedReviews;
    final List<int> dueReviews = _addDeciles(
      input.regularOldReviewBacklogByDecile,
      input.regularNewlyDueReviewsByDecile,
    );
    regularReviewBacklog = _subtractDeciles(
      _subtractDeciles(dueReviews, overflowCards),
      decision.admittedRegularReviewsByDecile,
    );
    newCardPool = _subtractDeciles(
      _addDeciles(newCardPool, generated.newCards),
      decision.admittedNewCardsByDecile,
    );

    protectedTopicBacklog =
        input.protectedDueTopics - decision.admittedProtectedTopics;
    final List<int> dueTopics = _addDeciles(
      input.regularOldTopicBacklogByDecile,
      input.regularNewlyDueTopicsByDecile,
    );
    regularTopicBacklog = _subtractDeciles(
      _subtractDeciles(dueTopics, overflowTopics),
      decision.admittedRegularTopicsByDecile,
    );

    if (input.manualLaterFraction > 0) {
      final int laterCards =
          (decision.admittedRegularReviews * input.manualLaterFraction).floor();
      final int laterTopics =
          (decision.admittedRegularTopics * input.manualLaterFraction).floor();
      regularReviewBacklog[9] += laterCards;
      regularTopicBacklog[9] += laterTopics;
    }
  }
}

_GeneratedLoad _generateLoad({
  required SchedulerSimulationConfig config,
  required SchedulerSimulationScenario scenario,
  required SimulationPriorityDistribution distribution,
  required int day,
  required DeterministicRandom random,
  required _SimulationState state,
}) {
  final List<double> weights = _distributionWeights(distribution);
  final int reviewTotal = math.max(1, (config.cardCount / 65).round());
  final int topicTotal = math.max(1, (config.topicCount / 55).round());
  final int protectedReviews = _fractionalCount(
    reviewTotal * 0.01,
    random,
    'protected-reviews:$day',
  );
  final int protectedTopics = _fractionalCount(
    topicTotal * 0.01,
    random,
    'protected-topics:$day',
  );
  final List<int> reviews = _distributedCounts(
    total: reviewTotal - protectedReviews,
    weights: weights,
    random: random,
    key: 'reviews:$day',
  );
  final List<int> topics = _distributedCounts(
    total: topicTotal - protectedTopics,
    weights: weights,
    random: random,
    key: 'topics:$day',
  );
  final List<int> newCards = _distributedCounts(
    total: 8,
    weights: weights,
    random: random,
    key: 'new:$day',
  );

  if (day < state.scheduledCards.length) {
    for (var decile = 0; decile < 10; decile++) {
      reviews[decile] += state.scheduledCards[day][decile];
      topics[decile] += state.scheduledTopics[day][decile];
    }
  }
  if (scenario == SchedulerSimulationScenario.largeImport && day == 90) {
    _addInto(
      newCards,
      _distributedCounts(
        total: config.cardCount ~/ 2,
        weights: weights,
        random: random,
        key: 'large-import-cards',
      ),
    );
    _addInto(
      topics,
      _distributedCounts(
        total: config.topicCount ~/ 2,
        weights: weights,
        random: random,
        key: 'large-import-topics',
      ),
    );
  }
  if (scenario == SchedulerSimulationScenario.cardFormulationBurst &&
      day >= 110 &&
      day < 124) {
    _addInto(
      newCards,
      _distributedCounts(
        total: 160,
        weights: weights,
        random: random,
        key: 'formulation:$day',
      ),
    );
  }
  if (scenario == SchedulerSimulationScenario.topPriorityOverload &&
      day >= 150 &&
      day < 157) {
    reviews[0] += config.cardDailyCap;
    topics[0] += config.topicDailyCap;
  }
  if (scenario == SchedulerSimulationScenario.mercyRecovery && day == 100) {
    reviews[8] += config.cardDailyCap * 12;
    topics[8] += config.topicDailyCap * 12;
  }

  return _GeneratedLoad(
    protectedReviews: protectedReviews,
    regularReviews: reviews,
    newCards: newCards,
    protectedTopics: protectedTopics,
    regularTopics: topics,
    mandatorySteps: 3 + (random.unit('steps:$day') * 8).floor(),
  );
}

SimulationDayInput _buildInput({
  required SchedulerSimulationConfig config,
  required SchedulerSimulationScenario scenario,
  required SimulationPriorityDistribution distribution,
  required int day,
  required DeterministicRandom random,
  required _SimulationState state,
  required _GeneratedLoad generated,
}) {
  var cardCap = config.cardDailyCap;
  var topicCap = config.topicDailyCap;
  var newCap = config.newCardDailyCap;
  if (scenario == SchedulerSimulationScenario.capChanges) {
    if (day >= 100 && day < 150) {
      cardCap = math.max(1, cardCap ~/ 2);
      topicCap = math.max(1, topicCap ~/ 2);
      newCap = math.max(1, newCap ~/ 2);
    } else if (day >= 220 && day < 270) {
      cardCap *= 2;
      topicCap *= 2;
      newCap *= 2;
    }
  }
  final int horizon = math.min(90, config.days - day - 1);
  final List<int> futureCardResidual = <int>[
    for (var offset = 1; offset <= horizon; offset++)
      math
          .max(
            0,
            cardCap -
                generated.mandatorySteps -
                math.max(1, (config.cardCount / 65).round()) -
                _sum(state.scheduledCards[day + offset]),
          )
          .toInt(),
  ];
  final List<int> futureTopicResidual = <int>[
    for (var offset = 1; offset <= horizon; offset++)
      math
          .max(
            0,
            topicCap -
                math.max(1, (config.topicCount / 55).round()) -
                _sum(state.scheduledTopics[day + offset]),
          )
          .toInt(),
  ];
  var dayLength = 24.0;
  var rollover = false;
  if (scenario == SchedulerSimulationScenario.dstAndRollover) {
    if (day == 84) {
      dayLength = 23;
      rollover = true;
    } else if (day == 294) {
      dayLength = 25;
      rollover = true;
    } else if (day % 31 == 0) {
      rollover = true;
    }
  }
  final int cardDuration =
      5000 + (random.unit('card-duration:$day') * 35000).round();
  final int topicDuration =
      30000 + (random.unit('topic-duration:$day') * 330000).round();

  return SimulationDayInput(
    scenario: scenario,
    priorityDistribution: distribution,
    dayIndex: day,
    seed: '${config.seed}:${scenario.wireName}:${distribution.name}:$day',
    cardDailyCap: cardCap,
    newCardDailyCap: newCap,
    topicDailyCap: topicCap,
    mandatoryStepCount: generated.mandatorySteps,
    protectedOldReviewBacklog: state.protectedReviewBacklog,
    protectedNewlyDueReviews: generated.protectedReviews,
    regularOldReviewBacklogByDecile: state.regularReviewBacklog,
    regularNewlyDueReviewsByDecile: generated.regularReviews,
    newCardsByDecile: _addDeciles(state.newCardPool, generated.newCards),
    protectedOldTopicBacklog: state.protectedTopicBacklog,
    protectedNewlyDueTopics: generated.protectedTopics,
    regularOldTopicBacklogByDecile: state.regularTopicBacklog,
    regularNewlyDueTopicsByDecile: generated.regularTopics,
    futureCardResidualCapacity: futureCardResidual,
    futureTopicResidualCapacity: futureTopicResidual,
    cardDurationMs: cardDuration,
    topicDurationMs: topicDuration,
    localDayLengthHours: dayLength,
    rolloverTransition: rollover,
    mercyRequested:
        scenario == SchedulerSimulationScenario.mercyRecovery && day == 101,
    manualLaterFraction:
        scenario == SchedulerSimulationScenario.repeatedLater &&
            day >= 90 &&
            day < 120
        ? 0.2
        : 0,
  );
}

bool _isAbsenceDay(SchedulerSimulationScenario scenario, int day) =>
    scenario == SchedulerSimulationScenario.threeWeekAbsence &&
    day >= 60 &&
    day < 81;

List<double> _distributionWeights(SimulationPriorityDistribution value) =>
    switch (value) {
      SimulationPriorityDistribution.uniform => List<double>.filled(10, 0.1),
      SimulationPriorityDistribution.topHeavy => <double>[
        for (var weight = 10; weight >= 1; weight--) weight / 55,
      ],
      SimulationPriorityDistribution.bottomHeavy => <double>[
        for (var weight = 1; weight <= 10; weight++) weight / 55,
      ],
    };

List<int> _distributedCounts({
  required int total,
  required List<double> weights,
  required DeterministicRandom random,
  required String key,
}) {
  final List<int> result = <int>[
    for (var index = 0; index < 10; index++) (total * weights[index]).floor(),
  ];
  final int remaining = total - _sum(result);
  final List<int> order = <int>[for (var index = 0; index < 10; index++) index]
    ..sort(
      (int left, int right) =>
          random.unit('$key:$left').compareTo(random.unit('$key:$right')),
    );
  for (var index = 0; index < remaining; index++) {
    result[order[index % order.length]]++;
  }
  return result;
}

int _fractionalCount(double expected, DeterministicRandom random, String key) {
  final int whole = expected.floor();
  return whole + (random.unit(key) < expected - whole ? 1 : 0);
}

List<int> _takeByPriority(List<int> available, int capacity) {
  final List<int> result = _zeroDeciles();
  var remaining = math.max(0, capacity);
  for (var index = 0; index < 10 && remaining > 0; index++) {
    result[index] = math.min(available[index], remaining);
    remaining -= result[index];
  }
  return result;
}

List<int> _copyDeciles(List<int> values, String name) {
  if (values.length != 10 || values.any((int value) => value < 0)) {
    throw ArgumentError.value(
      values,
      name,
      'must contain ten non-negative counts',
    );
  }
  return List<int>.unmodifiable(values);
}

List<int> _copyNonNegative(List<int> values, String name) {
  if (values.any((int value) => value < 0)) {
    throw ArgumentError.value(values, name, 'must contain non-negative counts');
  }
  return List<int>.unmodifiable(values);
}

List<int> _zeroDeciles() => List<int>.filled(10, 0);

List<int> _addDeciles(List<int> left, List<int> right) => <int>[
  for (var index = 0; index < 10; index++) left[index] + right[index],
];

List<int> _subtractDeciles(List<int> left, List<int> right) => <int>[
  for (var index = 0; index < 10; index++)
    math.max(0, left[index] - right[index]),
];

void _addInto(List<int> target, List<int> values) {
  for (var index = 0; index < 10; index++) {
    target[index] += values[index];
  }
}

bool _fits(List<int> selected, List<int> available) {
  for (var index = 0; index < 10; index++) {
    if (selected[index] > available[index]) return false;
  }
  return true;
}

int _sum(Iterable<int> values) =>
    values.fold<int>(0, (int total, int value) => total + value);
