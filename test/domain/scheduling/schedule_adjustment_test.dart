library;

import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const ElementRef card = ElementRef(id: 'card-1', type: ElementType.card);
  const ElementRef topic = ElementRef(id: 'topic-1', type: ElementType.source);
  const ElementRef otherCard = ElementRef(id: 'card-2', type: ElementType.card);

  group('validation', () {
    test('accepts only the value for the adjustment mode', () {
      expect(
        () => ScheduleAdjustment(
          id: 'invalid',
          element: card,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.manualLater,
          notBeforeAtUtc: _instant(5),
          scheduledForAtUtc: _instant(6),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScheduleAdjustment(
          id: 'invalid',
          element: card,
          mode: ScheduleAdjustmentMode.exactOverride,
          reason: ScheduleAdjustmentReason.manualReschedule,
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
    });

    test('reason fixes lower-bound versus exact-override semantics', () {
      expect(
        () => ScheduleAdjustment(
          id: 'invalid',
          element: card,
          mode: ScheduleAdjustmentMode.exactOverride,
          reason: ScheduleAdjustmentReason.autoOverflow,
          scheduledForAtUtc: _instant(5),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScheduleAdjustment(
          id: 'invalid',
          element: topic,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.mercy,
          notBeforeStudyDay: _day(5),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
    });

    test('cards strictly use UTC instants', () {
      expect(
        () => ScheduleAdjustment(
          id: 'card-day',
          element: card,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.manualLater,
          notBeforeStudyDay: _day(5),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScheduleAdjustment(
          id: 'card-local',
          element: card,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.manualLater,
          notBeforeAtUtc: DateTime(2026, 3, 5),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
    });

    test('topics strictly use StudyDays from one historical zone', () {
      expect(
        () => ScheduleAdjustment(
          id: 'topic-instant',
          element: topic,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.manualLater,
          notBeforeAtUtc: _instant(5),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ScheduleAdjustment(
          id: 'topic-zone',
          element: topic,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.manualLater,
          notBeforeStudyDay: _day(5, zoneId: 'Europe/Berlin'),
          operationId: 'op',
          policyVersion: 'v1',
          createdAtUtc: _instant(1),
          createdStudyDay: _day(1),
        ),
        throwsArgumentError,
      );
    });

    test('clear lifecycle audit fields are paired and chronological', () {
      final ScheduleAdjustment active = _cardBound(
        id: 'later',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 5,
      );
      expect(
        () => ScheduleAdjustment(
          id: 'unpaired',
          element: card,
          mode: ScheduleAdjustmentMode.lowerBound,
          reason: ScheduleAdjustmentReason.manualLater,
          notBeforeAtUtc: _instant(5),
          operationId: 'set',
          policyVersion: 'v1',
          createdAtUtc: _instant(2),
          createdStudyDay: _day(2),
          clearedAtUtc: _instant(3),
        ),
        throwsArgumentError,
      );
      expect(
        () => active.clear(atUtc: _instant(0), operationId: 'clear'),
        throwsArgumentError,
      );

      final ScheduleAdjustment cleared = active.clear(
        atUtc: _instant(4),
        operationId: 'clear-1',
      );
      expect(cleared.isActive, isFalse);
      expect(cleared.clearedAtUtc, _instant(4));
      expect(cleared.clearedByOperationId, 'clear-1');
      expect(
        cleared.clear(atUtc: _instant(6), operationId: 'clear-2'),
        same(cleared),
        reason: 'the first successful lifecycle transition remains audited',
      );
    });
  });

  group('effective due', () {
    const EffectiveDueService service = EffectiveDueService();

    test('exact card override is chosen before every active lower bound', () {
      final ScheduleAdjustment exact = _cardExact(
        id: 'exact',
        reason: ScheduleAdjustmentReason.manualReschedule,
        destinationDay: 5,
      );
      final ScheduleAdjustment earlierBound = _cardBound(
        id: 'bound-8',
        reason: ScheduleAdjustmentReason.siblingBury,
        destinationDay: 8,
      );
      final ScheduleAdjustment laterBound = _cardBound(
        id: 'bound-12',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 12,
      );
      final ScheduleAdjustment clearedBound = _cardBound(
        id: 'cleared-20',
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 20,
      ).clear(atUtc: _instant(3), operationId: 'clear');
      final ScheduleAdjustmentSet set = ScheduleAdjustmentSet(
        <ScheduleAdjustment>[laterBound, exact, clearedBound, earlierBound],
      );

      expect(
        service.cardDueAtUtc(
          card: card,
          algorithmicDueAtUtc: _instant(10),
          adjustments: set,
        ),
        _instant(12),
      );
      expect(
        service.isCardDue(
          card: card,
          algorithmicDueAtUtc: _instant(10),
          nowUtc: _instant(11),
          adjustments: set,
        ),
        isFalse,
      );
    });

    test('exact overrides can move topics earlier or later', () {
      final ScheduleAdjustmentSet earlier =
          ScheduleAdjustmentSet(<ScheduleAdjustment>[
            _topicExact(
              id: 'mercy-early',
              reason: ScheduleAdjustmentReason.mercy,
              destinationDay: 5,
              batchId: 'batch-1',
            ),
          ]);
      final ScheduleAdjustmentSet constrained =
          ScheduleAdjustmentSet(<ScheduleAdjustment>[
            ...earlier.adjustments,
            _topicBound(
              id: 'manual-9',
              reason: ScheduleAdjustmentReason.manualLater,
              destinationDay: 9,
            ),
          ]);

      expect(
        service.topicDueStudyDay(
          topic: topic,
          algorithmicDueStudyDay: _day(8),
          adjustments: earlier,
        ),
        _day(5),
      );
      expect(
        service.topicDueStudyDay(
          topic: topic,
          algorithmicDueStudyDay: _day(8),
          adjustments: constrained,
        ),
        _day(9),
        reason: 'manual Later still constrains an earlier Mercy assignment',
      );
      expect(
        service.isTopicDue(
          topic: topic,
          algorithmicDueStudyDay: _day(8),
          today: _day(8),
          adjustments: constrained,
        ),
        isFalse,
      );
    });

    test('topic comparison rejects a changed StudyDay zone', () {
      final ScheduleAdjustmentSet set =
          ScheduleAdjustmentSet(<ScheduleAdjustment>[
            _topicBound(
              id: 'bound',
              reason: ScheduleAdjustmentReason.manualLater,
              destinationDay: 9,
            ),
          ]);
      expect(
        () => service.topicDueStudyDay(
          topic: topic,
          algorithmicDueStudyDay: _day(8, zoneId: 'Europe/Berlin'),
          adjustments: set,
        ),
        throwsStateError,
      );
    });
  });

  group('set transitions', () {
    test('multiple lower bounds coexist but active exact overrides do not', () {
      final List<ScheduleAdjustment> bounds = <ScheduleAdjustment>[
        _cardBound(
          id: 'later',
          reason: ScheduleAdjustmentReason.manualLater,
          destinationDay: 5,
        ),
        _cardBound(
          id: 'auto',
          reason: ScheduleAdjustmentReason.autoOverflow,
          destinationDay: 7,
        ),
        _cardBound(
          id: 'sibling',
          reason: ScheduleAdjustmentReason.siblingBury,
          destinationDay: 6,
        ),
      ];
      expect(ScheduleAdjustmentSet(bounds).active, hasLength(3));
      expect(
        () => ScheduleAdjustmentSet(<ScheduleAdjustment>[
          _cardExact(
            id: 'manual',
            reason: ScheduleAdjustmentReason.manualReschedule,
            destinationDay: 4,
          ),
          _cardExact(
            id: 'mercy',
            reason: ScheduleAdjustmentReason.mercy,
            destinationDay: 8,
            batchId: 'batch',
          ),
        ]),
        throwsStateError,
      );
    });

    test('add helper keeps independent lower bounds of the same reason', () {
      final ScheduleAdjustment first = _cardBound(
        id: 'later-1',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 5,
      );
      final ScheduleAdjustment second = _cardBound(
        id: 'later-2',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 8,
        operationId: 'later-again',
        createdDay: 3,
      );

      final ScheduleAdjustmentSet result = ScheduleAdjustmentSet.empty
          .addLowerBound(first)
          .after
          .addLowerBound(second)
          .after;
      expect(result.activeFor(card), hasLength(2));
    });

    test('auto-overflow upsert clears only its prior value', () {
      final ScheduleAdjustment manual = _cardBound(
        id: 'manual',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 9,
      );
      final ScheduleAdjustment sibling = _cardBound(
        id: 'sibling',
        reason: ScheduleAdjustmentReason.siblingBury,
        destinationDay: 6,
      );
      final ScheduleAdjustment oldAuto = _cardBound(
        id: 'auto-old',
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 7,
      );
      final ScheduleAdjustment newAuto = _cardBound(
        id: 'auto-new',
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 11,
        operationId: 'auto-upsert',
        createdDay: 3,
      );
      final ScheduleAdjustmentSet initial = ScheduleAdjustmentSet(
        <ScheduleAdjustment>[oldAuto, sibling, manual],
      );

      final ScheduleAdjustmentMutation mutation = initial.upsertLowerBound(
        newAuto,
      );
      expect(
        mutation.after.active.map((ScheduleAdjustment value) => value.id),
        containsAll(<String>['manual', 'sibling', 'auto-new']),
      );
      final ScheduleAdjustment auditedOld = mutation.after.adjustments
          .singleWhere((ScheduleAdjustment value) => value.id == 'auto-old');
      expect(auditedOld.isActive, isFalse);
      expect(auditedOld.clearedByOperationId, 'auto-upsert');
      expect(mutation.beforeSnapshot.activeAdjustments, hasLength(3));
    });

    test(
      'setting an exact override replaces only the prior exact override',
      () {
        final ScheduleAdjustment bound = _cardBound(
          id: 'manual-later',
          reason: ScheduleAdjustmentReason.manualLater,
          destinationDay: 9,
        );
        final ScheduleAdjustment prior = _cardExact(
          id: 'old-reschedule',
          reason: ScheduleAdjustmentReason.manualReschedule,
          destinationDay: 7,
        );
        final ScheduleAdjustment replacement = _cardExact(
          id: 'new-reschedule',
          reason: ScheduleAdjustmentReason.manualReschedule,
          destinationDay: 4,
          operationId: 'replace-exact',
          createdDay: 3,
        );

        final ScheduleAdjustmentSet result = ScheduleAdjustmentSet(
          <ScheduleAdjustment>[bound, prior],
        ).setExactOverride(replacement).after;
        expect(result.activeFor(card), <ScheduleAdjustment>[
          bound,
          replacement,
        ]);
        final ScheduleAdjustment auditedPrior = result.adjustments.singleWhere(
          (ScheduleAdjustment value) => value.id == prior.id,
        );
        expect(auditedPrior.isActive, isFalse);
        expect(auditedPrior.clearedByOperationId, replacement.operationId);
      },
    );

    test('repeated operation is deterministic and cannot change its value', () {
      final ScheduleAdjustment first = _cardBound(
        id: 'auto',
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 7,
        operationId: 'same-op',
      );
      final ScheduleAdjustmentSet applied = ScheduleAdjustmentSet.empty
          .upsertLowerBound(first)
          .after;

      final ScheduleAdjustment retry = _cardBound(
        id: 'another-generated-id',
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 7,
        operationId: 'same-op',
      );
      expect(applied.upsertLowerBound(retry).changed, isFalse);
      expect(
        () => applied.upsertLowerBound(
          _cardBound(
            id: 'bad-retry',
            reason: ScheduleAdjustmentReason.autoOverflow,
            destinationDay: 10,
            operationId: 'same-op',
          ),
        ),
        throwsStateError,
      );
    });

    test('Study More clears auto-overflow only for selected elements', () {
      final ScheduleAdjustmentSet initial =
          ScheduleAdjustmentSet(<ScheduleAdjustment>[
            _cardBound(
              id: 'auto-selected',
              reason: ScheduleAdjustmentReason.autoOverflow,
              destinationDay: 7,
            ),
            _cardBound(
              id: 'manual',
              reason: ScheduleAdjustmentReason.manualLater,
              destinationDay: 9,
            ),
            _cardBound(
              id: 'sibling',
              reason: ScheduleAdjustmentReason.siblingBury,
              destinationDay: 8,
            ),
            _cardExact(
              id: 'reschedule',
              reason: ScheduleAdjustmentReason.manualReschedule,
              destinationDay: 6,
            ),
            _cardBound(
              id: 'auto-other',
              element: otherCard,
              reason: ScheduleAdjustmentReason.autoOverflow,
              destinationDay: 7,
            ),
          ]);

      final ScheduleAdjustmentSet result = initial
          .clearAutoOverflowFor(
            elements: const <ElementRef>[card],
            atUtc: _instant(4),
            operationId: 'study-more',
          )
          .after;
      expect(
        result.activeFor(card).map((ScheduleAdjustment value) => value.reason),
        containsAll(<ScheduleAdjustmentReason>[
          ScheduleAdjustmentReason.manualLater,
          ScheduleAdjustmentReason.siblingBury,
          ScheduleAdjustmentReason.manualReschedule,
        ]),
      );
      expect(
        result.activeFor(card),
        isNot(
          contains(
            predicate<ScheduleAdjustment>(
              (ScheduleAdjustment value) =>
                  value.reason == ScheduleAdjustmentReason.autoOverflow,
            ),
          ),
        ),
      );
      expect(result.activeFor(otherCard), hasLength(1));
    });

    test('construction and transitions have stable ordering', () {
      final ScheduleAdjustment a = _cardBound(
        id: 'a',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 5,
      );
      final ScheduleAdjustment b = _cardBound(
        id: 'b',
        element: otherCard,
        reason: ScheduleAdjustmentReason.siblingBury,
        destinationDay: 6,
      );
      expect(
        ScheduleAdjustmentSet(<ScheduleAdjustment>[b, a]),
        ScheduleAdjustmentSet(<ScheduleAdjustment>[a, b]),
      );
    });
  });

  group('Mercy', () {
    test('clears conflicts, preserves bounds, and captures prior set', () {
      final ScheduleAdjustment manual = _cardBound(
        id: 'manual',
        reason: ScheduleAdjustmentReason.manualLater,
        destinationDay: 12,
      );
      final ScheduleAdjustment auto = _cardBound(
        id: 'auto',
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 14,
      );
      final ScheduleAdjustment sibling = _cardBound(
        id: 'sibling',
        reason: ScheduleAdjustmentReason.siblingBury,
        destinationDay: 9,
      );
      final ScheduleAdjustment priorExact = _cardExact(
        id: 'prior-exact',
        reason: ScheduleAdjustmentReason.manualReschedule,
        destinationDay: 10,
      );
      final ScheduleAdjustment unrelatedAuto = _cardBound(
        id: 'unrelated',
        element: otherCard,
        reason: ScheduleAdjustmentReason.autoOverflow,
        destinationDay: 20,
      );
      final ScheduleAdjustmentSet initial = ScheduleAdjustmentSet(
        <ScheduleAdjustment>[manual, auto, sibling, priorExact, unrelatedAuto],
      );
      final ScheduleAdjustment mercy = _cardExact(
        id: 'mercy',
        reason: ScheduleAdjustmentReason.mercy,
        destinationDay: 5,
        operationId: 'mercy-apply',
        createdDay: 4,
        batchId: 'mercy-batch',
      );

      final ScheduleAdjustmentMutation mutation = initial.applyMercy(
        <ScheduleAdjustment>[mercy],
      );
      final List<ScheduleAdjustment> selected = mutation.after.activeFor(card);
      expect(
        selected.map((ScheduleAdjustment value) => value.reason),
        containsAll(<ScheduleAdjustmentReason>[
          ScheduleAdjustmentReason.manualLater,
          ScheduleAdjustmentReason.siblingBury,
          ScheduleAdjustmentReason.mercy,
        ]),
      );
      expect(selected, hasLength(3));
      expect(mutation.after.activeFor(otherCard), <ScheduleAdjustment>[
        unrelatedAuto,
      ]);
      expect(
        mutation.beforeSnapshot
            .forElement(card)
            .map((ScheduleAdjustment value) => value.id),
        containsAll(<String>['manual', 'auto', 'sibling', 'prior-exact']),
      );
      expect(
        ScheduleAdjustmentSet(mutation.beforeSnapshot.activeAdjustments),
        ScheduleAdjustmentSet(<ScheduleAdjustment>[
          manual,
          auto,
          sibling,
          priorExact,
        ]),
        reason: 'the event snapshot can restore the exact prior active set',
      );
      expect(
        const EffectiveDueService().cardDueAtUtc(
          card: card,
          algorithmicDueAtUtc: _instant(8),
          adjustments: mutation.after,
        ),
        _instant(12),
        reason: 'Mercy does not bypass the preserved manual Later bound',
      );
      expect(
        mutation.after.applyMercy(<ScheduleAdjustment>[mercy]).changed,
        isFalse,
      );
    });

    test('confirmation may explicitly override manual Later', () {
      final ScheduleAdjustmentSet initial =
          ScheduleAdjustmentSet(<ScheduleAdjustment>[
            _cardBound(
              id: 'manual',
              reason: ScheduleAdjustmentReason.manualLater,
              destinationDay: 12,
            ),
            _cardBound(
              id: 'sibling',
              reason: ScheduleAdjustmentReason.siblingBury,
              destinationDay: 9,
            ),
          ]);
      final ScheduleAdjustmentSet result =
          initial.applyMercy(<ScheduleAdjustment>[
            _cardExact(
              id: 'mercy',
              reason: ScheduleAdjustmentReason.mercy,
              destinationDay: 5,
              operationId: 'mercy-override-manual',
              createdDay: 4,
              batchId: 'batch',
            ),
          ], overrideManualLater: true).after;

      expect(
        result.activeFor(card).map((ScheduleAdjustment value) => value.reason),
        <ScheduleAdjustmentReason>[
          ScheduleAdjustmentReason.siblingBury,
          ScheduleAdjustmentReason.mercy,
        ],
      );
    });

    test('requires one exact batch and one assignment per element', () {
      final ScheduleAdjustment mercy = _cardExact(
        id: 'mercy',
        reason: ScheduleAdjustmentReason.mercy,
        destinationDay: 5,
        batchId: 'batch-1',
      );
      expect(
        () => ScheduleAdjustmentSet.empty.applyMercy(<ScheduleAdjustment>[
          mercy,
          _cardExact(
            id: 'mercy-2',
            reason: ScheduleAdjustmentReason.mercy,
            destinationDay: 6,
            operationId: 'mercy-2',
            batchId: 'batch-1',
          ),
        ]),
        throwsArgumentError,
      );
      expect(
        () => ScheduleAdjustmentSet.empty.applyMercy(<ScheduleAdjustment>[
          mercy,
          _cardExact(
            id: 'other',
            element: otherCard,
            reason: ScheduleAdjustmentReason.mercy,
            destinationDay: 6,
            operationId: 'other',
            batchId: 'batch-2',
          ),
        ]),
        throwsArgumentError,
      );
    });
  });
}

ScheduleAdjustment _cardBound({
  required String id,
  required ScheduleAdjustmentReason reason,
  required int destinationDay,
  ElementRef element = const ElementRef(id: 'card-1', type: ElementType.card),
  String? operationId,
  int createdDay = 2,
}) => ScheduleAdjustment(
  id: id,
  element: element,
  mode: ScheduleAdjustmentMode.lowerBound,
  reason: reason,
  notBeforeAtUtc: _instant(destinationDay),
  operationId: operationId ?? 'set-$id',
  policyVersion: 'adjustments-v1',
  createdAtUtc: _instant(createdDay),
  createdStudyDay: _day(createdDay),
);

ScheduleAdjustment _cardExact({
  required String id,
  required ScheduleAdjustmentReason reason,
  required int destinationDay,
  ElementRef element = const ElementRef(id: 'card-1', type: ElementType.card),
  String? operationId,
  int createdDay = 2,
  String? batchId,
}) => ScheduleAdjustment(
  id: id,
  element: element,
  mode: ScheduleAdjustmentMode.exactOverride,
  reason: reason,
  scheduledForAtUtc: _instant(destinationDay),
  operationId: operationId ?? 'set-$id',
  batchId: batchId,
  policyVersion: 'adjustments-v1',
  createdAtUtc: _instant(createdDay),
  createdStudyDay: _day(createdDay),
);

ScheduleAdjustment _topicBound({
  required String id,
  required ScheduleAdjustmentReason reason,
  required int destinationDay,
}) => ScheduleAdjustment(
  id: id,
  element: const ElementRef(id: 'topic-1', type: ElementType.source),
  mode: ScheduleAdjustmentMode.lowerBound,
  reason: reason,
  notBeforeStudyDay: _day(destinationDay),
  operationId: 'set-$id',
  policyVersion: 'adjustments-v1',
  createdAtUtc: _instant(2),
  createdStudyDay: _day(2),
);

ScheduleAdjustment _topicExact({
  required String id,
  required ScheduleAdjustmentReason reason,
  required int destinationDay,
  String? batchId,
}) => ScheduleAdjustment(
  id: id,
  element: const ElementRef(id: 'topic-1', type: ElementType.source),
  mode: ScheduleAdjustmentMode.exactOverride,
  reason: reason,
  scheduledForStudyDay: _day(destinationDay),
  operationId: 'set-$id',
  batchId: batchId,
  policyVersion: 'adjustments-v1',
  createdAtUtc: _instant(2),
  createdStudyDay: _day(2),
);

DateTime _instant(int day) => DateTime.utc(2026, 3, day, 12);

StudyDay _day(int day, {String zoneId = 'UTC'}) =>
    StudyDay(year: 2026, month: 3, day: day, zoneId: zoneId);
