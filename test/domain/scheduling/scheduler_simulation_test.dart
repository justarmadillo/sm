import 'dart:convert';

import 'package:incremental_reader/src/domain/scheduling/scheduler_simulation.dart';
import 'package:test/test.dart';

void main() {
  test('release configuration enforces the authoritative minimum scale', () {
    expect(() => SchedulerSimulationConfig(days: 364), throwsArgumentError);
    expect(
      () => SchedulerSimulationConfig(cardCount: 9999),
      throwsArgumentError,
    );
    expect(
      () => SchedulerSimulationConfig(topicCount: 1999),
      throwsArgumentError,
    );
  });

  test(
    'runs all required scenarios at release scale and accepts safe policy',
    () {
      const SeededSchedulerSimulationGate gate =
          SeededSchedulerSimulationGate();
      const CapacityAwareSimulationReferencePolicy policy =
          CapacityAwareSimulationReferencePolicy();

      final SchedulerSimulationGateReport result = gate.run(policy: policy);

      expect(result.days, 365);
      expect(result.cardCount, greaterThanOrEqualTo(10000));
      expect(result.topicCount, greaterThanOrEqualTo(2000));
      expect(
        result.scenarios,
        hasLength(
          SchedulerSimulationScenario.values.length *
              SimulationPriorityDistribution.values.length,
        ),
      );
      expect(
        result.scenarios.map(
          (SimulationScenarioReport value) => value.scenario,
        ),
        containsAll(SchedulerSimulationScenario.values),
      );
      expect(result.accepted, isTrue, reason: jsonEncode(result.toJson()));
      expect(result.violations, isEmpty);
    },
  );

  test('the same fixed seed produces a byte-identical gate report', () {
    const SeededSchedulerSimulationGate gate = SeededSchedulerSimulationGate();
    const CapacityAwareSimulationReferencePolicy policy =
        CapacityAwareSimulationReferencePolicy();
    final SchedulerSimulationConfig config = SchedulerSimulationConfig(
      seed: 'fixed-release-seed',
      scenarios: const <SchedulerSimulationScenario>[
        SchedulerSimulationScenario.steadyDailyUse,
        SchedulerSimulationScenario.threeWeekAbsence,
      ],
      priorityDistributions: const <SimulationPriorityDistribution>[
        SimulationPriorityDistribution.uniform,
        SimulationPriorityDistribution.topHeavy,
      ],
    );

    final String first = jsonEncode(
      gate.run(policy: policy, config: config).toJson(),
    );
    final String second = jsonEncode(
      gate.run(policy: policy, config: config).toJson(),
    );

    expect(second, first);
  });

  test('reports nondeterministic rebuilds as a release rejection', () {
    const SeededSchedulerSimulationGate gate = SeededSchedulerSimulationGate();
    final SchedulerSimulationConfig config = SchedulerSimulationConfig(
      scenarios: const <SchedulerSimulationScenario>[
        SchedulerSimulationScenario.repeatedQueueRebuilds,
      ],
      priorityDistributions: const <SimulationPriorityDistribution>[
        SimulationPriorityDistribution.uniform,
        SimulationPriorityDistribution.bottomHeavy,
      ],
    );

    final SchedulerSimulationGateReport result = gate.run(
      policy: _NondeterministicPolicy(),
      config: config,
    );

    expect(result.accepted, isFalse);
    expect(
      result.rejectedInvariants,
      contains(SimulationViolationCode.nondeterministicRebuild),
    );
  });

  test('reports every authoritative policy-rejection invariant', () {
    const SeededSchedulerSimulationGate gate = SeededSchedulerSimulationGate();
    final SchedulerSimulationConfig config = SchedulerSimulationConfig(
      cardDailyCap: 1,
      newCardDailyCap: 1,
      topicDailyCap: 1,
      scenarios: const <SchedulerSimulationScenario>[
        SchedulerSimulationScenario.steadyDailyUse,
      ],
      priorityDistributions: const <SimulationPriorityDistribution>[
        SimulationPriorityDistribution.uniform,
        SimulationPriorityDistribution.topHeavy,
      ],
    );

    final SchedulerSimulationGateReport result = gate.run(
      policy: const _RejectedInvariantPolicy(),
      config: config,
    );

    expect(result.accepted, isFalse);
    expect(
      result.rejectedInvariants,
      containsAll(<SimulationViolationCode>[
        SimulationViolationCode.protectedAutomaticPostponement,
        SimulationViolationCode.mandatoryStepAutomaticPostponement,
        SimulationViolationCode.futureLoadSpike,
        SimulationViolationCode.newCardAdmissionWithExhaustedDueCapacity,
        SimulationViolationCode.cardOrTopicStarvation,
        SimulationViolationCode.optimizerContamination,
        SimulationViolationCode.higherPriorityRetentionRegression,
      ]),
    );
  });
}

final class _NondeterministicPolicy implements SchedulerSimulationPolicy {
  int _calls = 0;

  @override
  String get policyVersion => 'intentionally_nondeterministic_test_policy';

  @override
  SimulationDayDecision plan(SimulationDayInput input) {
    _calls++;
    final SimulationDayDecision safe =
        const CapacityAwareSimulationReferencePolicy().plan(input);
    return SimulationDayDecision(
      admittedMandatorySteps: safe.admittedMandatorySteps,
      admittedProtectedReviews: safe.admittedProtectedReviews,
      admittedRegularReviewsByDecile: safe.admittedRegularReviewsByDecile,
      admittedNewCardsByDecile: safe.admittedNewCardsByDecile,
      admittedProtectedTopics: safe.admittedProtectedTopics,
      admittedRegularTopicsByDecile: safe.admittedRegularTopicsByDecile,
      automaticOverflow: safe.automaticOverflow,
      presentation: safe.presentation,
      optimizerInputs: <SimulationOptimizerInputKind, int>{
        ...safe.optimizerInputs,
        SimulationOptimizerInputKind.genuineCardReview:
            (safe.optimizerInputs[SimulationOptimizerInputKind
                    .genuineCardReview] ??
                0) +
            _calls % 2,
      },
    );
  }
}

final class _RejectedInvariantPolicy implements SchedulerSimulationPolicy {
  const _RejectedInvariantPolicy();

  @override
  String get policyVersion => 'intentionally_rejected_test_policy';

  @override
  SimulationDayDecision plan(SimulationDayInput input) {
    final SimulationDayDecision safe =
        const CapacityAwareSimulationReferencePolicy().plan(input);
    if (input.dayIndex != 1) return safe;

    final List<int> admittedNew = List<int>.filled(10, 0);
    final int newIndex = input.newCardsByDecile.indexWhere(
      (int count) => count > 0,
    );
    if (newIndex >= 0) admittedNew[newIndex] = 1;
    final int genuineReviews =
        safe.admittedMandatorySteps +
        safe.admittedProtectedReviews +
        safe.admittedRegularReviews +
        1;

    return SimulationDayDecision(
      admittedMandatorySteps: safe.admittedMandatorySteps,
      admittedProtectedReviews: safe.admittedProtectedReviews,
      admittedRegularReviewsByDecile: safe.admittedRegularReviewsByDecile,
      admittedNewCardsByDecile: admittedNew,
      admittedProtectedTopics: safe.admittedProtectedTopics,
      admittedRegularTopicsByDecile: safe.admittedRegularTopicsByDecile,
      automaticOverflow: <SimulationOverflowAssignment>[
        SimulationOverflowAssignment(
          kind: SimulationWorkKind.card,
          priorityDecile: 1,
          count: 1,
          destinationDayIndex: input.dayIndex + 1000,
          protected: true,
        ),
        SimulationOverflowAssignment(
          kind: SimulationWorkKind.card,
          priorityDecile: 10,
          count: 1,
          destinationDayIndex: input.dayIndex + 2,
          mandatoryStep: true,
        ),
      ],
      presentation: const <SimulationOpportunity>[],
      optimizerInputs: <SimulationOptimizerInputKind, int>{
        SimulationOptimizerInputKind.genuineCardReview: genuineReviews,
        SimulationOptimizerInputKind.practice: 1,
      },
    );
  }
}
