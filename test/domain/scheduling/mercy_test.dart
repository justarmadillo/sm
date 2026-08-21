library;

import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/mercy.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/scheduler_event.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const StudyDayCalendar calendar = StudyDayCalendar(zone: FixedOffsetZone.utc);
  const MercyPlanner planner = MercyPlanner(calendar: calendar);

  group('Mercy candidate boundaries', () {
    test(
      'scope, period, future, steps, lifecycle, and protection are explicit',
      () {
        final List<MercyCandidate> candidates = <MercyCandidate>[
          _candidate('selected', due: 10, branches: const <String>{'branch-a'}),
          _candidate('outside', due: 10, branches: const <String>{'branch-b'}),
          _candidate('future', due: 11, branches: const <String>{'branch-a'}),
          _candidate('old', due: 8, branches: const <String>{'branch-a'}),
          _candidate(
            'step',
            due: 10,
            branches: const <String>{'branch-a'},
            isStep: true,
          ),
          _candidate(
            'protected',
            due: 10,
            branches: const <String>{'branch-a'},
            isProtected: true,
          ),
          _candidate(
            'inactive',
            due: 10,
            branches: const <String>{'branch-a'},
            isEligible: false,
          ),
        ];
        final MercyPreview preview = planner.preview(
          _request(
            candidates: candidates,
            scope: MercyBranchScope('branch-a'),
            today: 10,
            collectingStart: 9,
            collectingEnd: 11,
            includeFuture: false,
            beforeCards: const <int>[5, 1],
            beforeTopics: const <int>[0, 0],
            capacity: MercyDailyCapacity(cardsPerDay: 10, topicsPerDay: 10),
          ),
        );

        expect(
          preview.assignments.map((MercyAssignment value) => value.element.id),
          <String>['selected'],
        );
        expect(preview.exclusionCounts, <MercyExclusionReason, int>{
          MercyExclusionReason.outsideScope: 1,
          MercyExclusionReason.futureRepetitionNotSelected: 1,
          MercyExclusionReason.outsideCollectingPeriod: 1,
          MercyExclusionReason.dueIntradayStep: 1,
          MercyExclusionReason.protected: 1,
          MercyExclusionReason.lifecycleIneligible: 1,
        });
      },
    );

    test(
      'subset scope touches no candidate outside the immutable coordinates',
      () {
        final MercyCandidate selected = _candidate('selected', due: 10);
        final MercyCandidate untouched = _candidate('untouched', due: 10);
        final MercyPreview preview = planner.preview(
          _request(
            candidates: <MercyCandidate>[selected, untouched],
            scope: MercySubsetScope(<ElementRef>{selected.ref}),
            beforeCards: const <int>[2, 0],
            beforeTopics: const <int>[0, 0],
          ),
        );

        expect(preview.assignments.single.element, selected.ref);
        expect(
          preview.exclusions.single,
          isA<MercyExclusion>()
              .having(
                (MercyExclusion value) => value.element,
                'element',
                untouched.ref,
              )
              .having(
                (MercyExclusion value) => value.reason,
                'reason',
                MercyExclusionReason.outsideScope,
              ),
        );
      },
    );
  });

  group('Mercy assignment', () {
    test('uses separate capacity ledgers and puts higher priority earlier', () {
      final List<MercyCandidate> candidates = <MercyCandidate>[
        _candidate('card-low', due: 10, priority: 0.80),
        _candidate('card-high', due: 10, priority: 0.05),
        _candidate(
          'topic-low',
          due: 10,
          priority: 0.70,
          type: ElementType.source,
        ),
        _candidate(
          'topic-high',
          due: 10,
          priority: 0.02,
          type: ElementType.extract,
        ),
      ];
      final MercyPreview preview = planner.preview(
        _request(
          candidates: candidates,
          beforeCards: const <int>[2, 0],
          beforeTopics: const <int>[2, 0],
          capacity: MercyDailyCapacity(cardsPerDay: 1, topicsPerDay: 1),
        ),
      );
      final Map<String, MercyAssignment> byId = <String, MercyAssignment>{
        for (final MercyAssignment value in preview.assignments)
          value.element.id: value,
      };

      expect(byId['card-high']!.toDay, _day(10));
      expect(byId['card-low']!.toDay, _day(11));
      expect(byId['topic-high']!.toDay, _day(10));
      expect(byId['topic-low']!.toDay, _day(11));
      expect(preview.afterLoad[0].cards, 1);
      expect(preview.afterLoad[0].topics, 1);
      expect(preview.afterLoad[1].cards, 1);
      expect(preview.afterLoad[1].topics, 1);
    });

    test(
      'horizon selection balances both days without a shared domain cap',
      () {
        final List<MercyCandidate> candidates = <MercyCandidate>[
          for (var index = 0; index < 4; index++)
            _candidate('card-$index', due: 10, priority: index / 10),
        ];
        final MercyPreview preview = planner.preview(
          _request(
            candidates: candidates,
            beforeCards: const <int>[4, 0],
            beforeTopics: const <int>[0, 0],
            capacity: const MercyDestinationHorizon(),
          ),
        );

        expect(
          preview.assignments
              .where((MercyAssignment value) => value.toDay == _day(10))
              .map((MercyAssignment value) => value.element.id),
          <String>['card-0', 'card-1'],
        );
        expect(
          preview.afterLoad.map((MercyDailyLoad value) => value.cards),
          <int>[2, 2],
        );
      },
    );

    test('reports capacity exclusions without changing the before load', () {
      final MercyPreview preview = planner.preview(
        _request(
          candidates: <MercyCandidate>[_candidate('card', due: 10)],
          beforeCards: const <int>[1],
          beforeTopics: const <int>[0],
          capacity: MercyDailyCapacity(cardsPerDay: 0, topicsPerDay: 0),
        ),
      );

      expect(preview.assignments, isEmpty);
      expect(preview.exclusionCounts, <MercyExclusionReason, int>{
        MercyExclusionReason.noDestinationCapacity: 1,
      });
      expect(preview.beforeLoad.single.cards, 1);
      expect(preview.afterLoad.single.cards, 1);
    });

    test('exact assignments can move work earlier and later', () {
      final List<MercyCandidate> candidates = <MercyCandidate>[
        _candidate('future-high', due: 12, priority: 0.01),
        _candidate('today-low', due: 10, priority: 0.90),
      ];
      final MercyPreview preview = planner.preview(
        _request(
          candidates: candidates,
          today: 10,
          collectingEnd: 12,
          includeFuture: true,
          beforeCards: const <int>[1, 0, 1],
          beforeTopics: const <int>[0, 0, 0],
          capacity: MercyDailyCapacity(cardsPerDay: 1, topicsPerDay: 1),
        ),
      );
      final Map<String, MercyAssignment> byId = <String, MercyAssignment>{
        for (final MercyAssignment value in preview.assignments)
          value.element.id: value,
      };

      expect(byId['future-high']!.movesEarlier, isTrue);
      expect(byId['future-high']!.toDay, _day(10));
      expect(byId['today-low']!.movesLater, isTrue);
      expect(byId['today-low']!.toDay, _day(11));
    });

    test('manual Later survives as a floor while auto-overflow does not', () {
      final MercyCandidate card = _candidate('card', due: 13);
      final ScheduleAdjustment manual = _cardBound(
        id: 'manual',
        element: card.ref,
        reason: ScheduleAdjustmentReason.manualLater,
        day: 12,
      );
      final ScheduleAdjustment automatic = _cardBound(
        id: 'auto',
        element: card.ref,
        reason: ScheduleAdjustmentReason.autoOverflow,
        day: 13,
      );
      final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet(
        <ScheduleAdjustment>[manual, automatic],
      );
      final MercyPreview preserved = planner.preview(
        _request(
          candidates: <MercyCandidate>[card],
          today: 10,
          collectingEnd: 13,
          includeFuture: true,
          beforeCards: const <int>[0, 0, 0],
          beforeTopics: const <int>[0, 0, 0],
          adjustments: adjustments,
        ),
      );
      final MercyPreview overridden = planner.preview(
        _request(
          candidates: <MercyCandidate>[card],
          today: 10,
          collectingEnd: 13,
          includeFuture: true,
          beforeCards: const <int>[0, 0, 0],
          beforeTopics: const <int>[0, 0, 0],
          adjustments: adjustments,
          protection: const MercyProtectionRules(overrideManualLater: true),
        ),
      );

      expect(preserved.assignments.single.toDay, _day(12));
      expect(overridden.assignments.single.toDay, _day(10));
    });

    test('selected criteria operate only inside a bounded priority band', () {
      final List<MercyCandidate> candidates = <MercyCandidate>[
        _candidate(
          'slightly-higher',
          due: 10,
          priority: 0.11,
          criteria: const MercyCriterionValues(repetitionLateness: 0),
        ),
        _candidate(
          'urgent-same-band',
          due: 10,
          priority: 0.19,
          criteria: const MercyCriterionValues(repetitionLateness: 1),
        ),
        _candidate(
          'urgent-lower-band',
          due: 10,
          priority: 0.21,
          criteria: const MercyCriterionValues(repetitionLateness: 1),
        ),
      ];
      final MercyPreview preview = planner.preview(
        _request(
          candidates: candidates,
          beforeCards: const <int>[3, 0],
          beforeTopics: const <int>[0, 0],
          criteria: MercyCriteriaPolicy(
            priorityBandWidth: 0.1,
            deterministicSeed: 'fixture',
            repetitionLatenessWeight: 1,
          ),
        ),
      );

      expect(
        preview.assignments.map((MercyAssignment value) => value.element.id),
        <String>['urgent-same-band', 'slightly-higher', 'urgent-lower-band'],
      );
      expect(preview.policyVersion, kMercyPolicyVersion);
    });
  });

  test(
    'identical inputs produce byte-identical previews and revision tokens',
    () {
      final MercyPreviewRequest request = _request(
        candidates: <MercyCandidate>[
          _candidate('a', due: 10, priority: 0.4),
          _candidate('b', due: 10, priority: 0.4),
        ],
        beforeCards: const <int>[2, 0],
        beforeTopics: const <int>[0, 0],
        priorMercyCount: 1,
        criteria: MercyCriteriaPolicy(
          priorityBandWidth: 0.1,
          deterministicSeed: 'stable-seed',
          stableRandomWeight: 1,
        ),
      );

      final MercyPreview first = planner.preview(request);
      final MercyPreview second = planner.preview(request);
      final MercyPreview restored = MercyPreview.fromJson(first.toJson());
      expect(second.toJson(), first.toJson());
      expect(restored.toJson(), first.toJson());
      expect(second.confirmationToken.digest, first.confirmationToken.digest);
      expect(first.warnings, <MercyWarning>[
        MercyWarning.repeatedMercyMayHideChronicOverload,
      ]);
      expect(first.confirmationToken.candidateRevisions, hasLength(2));
    },
  );
}

MercyPreviewRequest _request({
  required List<MercyCandidate> candidates,
  List<int> beforeCards = const <int>[1, 0],
  List<int> beforeTopics = const <int>[0, 0],
  MercyScope scope = const MercyCollectionScope(),
  int today = 10,
  int collectingStart = 9,
  int collectingEnd = 10,
  bool includeFuture = false,
  MercyDestinationPolicy? capacity,
  ScheduleAdjustmentSet? adjustments,
  MercyProtectionRules protection = const MercyProtectionRules(),
  MercyCriteriaPolicy? criteria,
  int priorMercyCount = 0,
}) {
  if (beforeCards.length != beforeTopics.length) {
    throw ArgumentError('fixture ledgers must have the same length');
  }
  return MercyPreviewRequest(
    today: _day(today),
    scope: scope,
    collectingPeriod: MercyCollectingPeriod(
      start: _day(collectingStart),
      end: _day(collectingEnd),
    ),
    includeFutureRepetitions: includeFuture,
    destinationPolicy:
        capacity ?? MercyDailyCapacity(cardsPerDay: 10, topicsPerDay: 10),
    destinationWindow: MercyDestinationWindow(
      days: <MercyDestinationDay>[
        for (var index = 0; index < beforeCards.length; index++)
          MercyDestinationDay(
            day: _day(10 + index),
            cardScheduledForAtUtc: DateTime.utc(2026, 3, 10 + index, 5),
            beforeCardLoad: beforeCards[index],
            beforeTopicLoad: beforeTopics[index],
          ),
      ],
    ),
    criteriaPolicy:
        criteria ??
        MercyCriteriaPolicy(
          priorityBandWidth: 0.01,
          deterministicSeed: 'fixture',
        ),
    protectionRules: protection,
    candidates: candidates,
    adjustments: adjustments ?? ScheduleAdjustmentSet.empty,
    priorMercyBatchCountInPeriod: priorMercyCount,
  );
}

MercyCandidate _candidate(
  String id, {
  required int due,
  ElementType type = ElementType.card,
  int revision = 1,
  double priority = 0.5,
  Set<String> branches = const <String>{},
  MercyCriterionValues criteria = const MercyCriterionValues(),
  bool isProtected = false,
  bool isStep = false,
  bool isEligible = true,
}) {
  final ElementRef ref = ElementRef(id: id, type: type);
  return MercyCandidate(
    ref: ref,
    revision: revision,
    currentEffectiveDueDay: _day(due),
    priorityFraction: priority,
    canonical: MercyCanonicalSnapshot(
      serializedState: '{"id":"$id"}',
      algorithmicDue: type == ElementType.card
          ? SchedulerEvent.encodeUtcDue(DateTime.utc(2026, 3, due, 5))
          : SchedulerEvent.encodeStudyDayDue(_day(due)),
      schedulerName: type == ElementType.card
          ? 'dart-fsrs'
          : 'topic_afactor_v1',
      schedulerVersion: 'fixture-v1',
    ),
    branchIds: branches,
    criteria: criteria,
    isProtected: isProtected,
    isDueIntradayStep: isStep,
    isLifecycleEligible: isEligible,
  );
}

ScheduleAdjustment _cardBound({
  required String id,
  required ElementRef element,
  required ScheduleAdjustmentReason reason,
  required int day,
}) => ScheduleAdjustment(
  id: id,
  element: element,
  mode: ScheduleAdjustmentMode.lowerBound,
  reason: reason,
  notBeforeAtUtc: DateTime.utc(2026, 3, day, 12),
  operationId: 'set-$id',
  policyVersion: 'adjustments-v1',
  createdAtUtc: DateTime.utc(2026, 3, 9, 12),
  createdStudyDay: _day(9),
);

StudyDay _day(int day) =>
    StudyDay(year: 2026, month: 3, day: day, zoneId: 'UTC');
