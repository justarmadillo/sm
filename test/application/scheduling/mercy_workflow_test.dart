library;

import 'package:incremental_reader/src/application/scheduling/mercy_workflow.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/mercy.dart';
import 'package:incremental_reader/src/domain/scheduling/schedule_adjustment.dart';
import 'package:incremental_reader/src/domain/scheduling/scheduler_event.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  const StudyDayCalendar calendar = StudyDayCalendar(zone: FixedOffsetZone.utc);
  const MercyPlanner planner = MercyPlanner(calendar: calendar);
  const MercyWorkflow workflow = MercyWorkflow();

  test('apply matches preview and changes presentation state only', () {
    final MercyCandidate candidate = _candidate(revision: 7, effectiveDay: 13);
    final ScheduleAdjustment manual = _bound(
      id: 'manual',
      reason: ScheduleAdjustmentReason.manualLater,
      day: 12,
    );
    final ScheduleAdjustment automatic = _bound(
      id: 'automatic',
      reason: ScheduleAdjustmentReason.autoOverflow,
      day: 13,
    );
    final ScheduleAdjustment oldExact = _exact(
      id: 'old-exact',
      reason: ScheduleAdjustmentReason.manualReschedule,
      day: 11,
    );
    final ScheduleAdjustmentSet before = ScheduleAdjustmentSet(
      <ScheduleAdjustment>[manual, automatic, oldExact],
    );
    final MercyPreview preview = planner.preview(
      _request(candidate: candidate, adjustments: before),
    );

    final MercyApplyPlan plan = workflow.planApply(
      preview: preview,
      currentCandidates: <MercyCandidate>[candidate],
      currentAdjustments: before,
      batchId: 'batch-1',
      operationId: 'apply-1',
      occurredAtUtc: DateTime.utc(2026, 3, 10, 8),
      studyDay: _day(10),
    );

    expect(plan.changesCanonicalSchedulerState, isFalse);
    expect(plan.preview.assignments.single.toDay, _day(12));
    expect(plan.priorAdjustments.activeAdjustments, hasLength(3));
    expect(
      plan.adjustmentMutation.after
          .activeFor(candidate.ref)
          .map((ScheduleAdjustment value) => value.reason),
      <ScheduleAdjustmentReason>[
        ScheduleAdjustmentReason.manualLater,
        ScheduleAdjustmentReason.mercy,
      ],
      reason: 'manual Later survives; auto-overflow and old exact do not',
    );
    expect(plan.auditEvents, hasLength(3));
    expect(plan.auditEvents[0].eventType, SchedulerEventType.mercyPreviewed);
    expect(plan.auditEvents[1].eventType, SchedulerEventType.mercyApplied);
    final SchedulerEvent itemEvent = plan.auditEvents[2];
    expect(itemEvent.element, candidate.ref);
    expect(itemEvent.stateAfter, itemEvent.stateBefore);
    expect(itemEvent.algorithmicDueAfter, itemEvent.algorithmicDueBefore);
    expect(itemEvent.stateAfter, candidate.canonical.serializedState);
    expect(itemEvent.batchId, 'batch-1');
  });

  test(
    'stale candidate revision rejects apply before producing a mutation',
    () {
      final MercyCandidate previewed = _candidate(revision: 1);
      final ScheduleAdjustmentSet adjustments = ScheduleAdjustmentSet.empty;
      final MercyPreview preview = planner.preview(
        _request(candidate: previewed, adjustments: adjustments),
      );

      expect(
        () => workflow.planApply(
          preview: preview,
          currentCandidates: <MercyCandidate>[_candidate(revision: 2)],
          currentAdjustments: adjustments,
          batchId: 'batch-stale',
          operationId: 'apply-stale',
          occurredAtUtc: DateTime.utc(2026, 3, 10, 8),
          studyDay: _day(10),
        ),
        throwsA(
          isA<StaleMercyPreview>().having(
            (StaleMercyPreview value) => value.changed,
            'changed',
            <ElementRef>[previewed.ref],
          ),
        ),
      );
      expect(adjustments, ScheduleAdjustmentSet.empty);
    },
  );

  test(
    'stale adjustment state rejects apply even when revision is unchanged',
    () {
      final MercyCandidate candidate = _candidate(revision: 1);
      final MercyPreview preview = planner.preview(
        _request(
          candidate: candidate,
          adjustments: ScheduleAdjustmentSet.empty,
        ),
      );
      final ScheduleAdjustmentSet changed = ScheduleAdjustmentSet.empty
          .addLowerBound(
            _bound(
              id: 'later-after-preview',
              reason: ScheduleAdjustmentReason.manualLater,
              day: 12,
            ),
          )
          .after;

      expect(
        () => workflow.planApply(
          preview: preview,
          currentCandidates: <MercyCandidate>[candidate],
          currentAdjustments: changed,
          batchId: 'batch-stale-adjustment',
          operationId: 'apply-stale-adjustment',
          occurredAtUtc: DateTime.utc(2026, 3, 10, 8),
          studyDay: _day(10),
        ),
        throwsA(isA<StaleMercyPreview>()),
      );
    },
  );

  test('batch undo restores the exact prior semantic set append-only', () {
    final MercyCandidate candidate = _candidate(revision: 3, effectiveDay: 13);
    final List<ScheduleAdjustment> originals = <ScheduleAdjustment>[
      _bound(
        id: 'manual',
        reason: ScheduleAdjustmentReason.manualLater,
        day: 12,
      ),
      _bound(
        id: 'automatic',
        reason: ScheduleAdjustmentReason.autoOverflow,
        day: 13,
      ),
      _exact(
        id: 'reschedule',
        reason: ScheduleAdjustmentReason.manualReschedule,
        day: 11,
      ),
    ];
    final ScheduleAdjustmentSet before = ScheduleAdjustmentSet(originals);
    final MercyPreview preview = planner.preview(
      _request(candidate: candidate, adjustments: before),
    );
    final MercyApplyPlan applied = workflow.planApply(
      preview: preview,
      currentCandidates: <MercyCandidate>[candidate],
      currentAdjustments: before,
      batchId: 'batch-undo',
      operationId: 'apply-undo-fixture',
      occurredAtUtc: DateTime.utc(2026, 3, 10, 8),
      studyDay: _day(10),
    );

    final MercyUndoPlan undo = workflow.planUndo(
      applied: applied.undoSnapshot,
      currentAdjustments: applied.adjustmentMutation.after,
      operationId: 'undo-1',
      occurredAtUtc: DateTime.utc(2026, 3, 10, 9),
      studyDay: _day(10),
    );

    expect(undo.changesCanonicalSchedulerState, isFalse);
    final List<ScheduleAdjustment> restored = undo.adjustmentMutation.after
        .activeFor(candidate.ref);
    expect(restored, hasLength(3));
    for (final ScheduleAdjustment original in originals) {
      expect(
        restored,
        contains(
          predicate<ScheduleAdjustment>(
            (ScheduleAdjustment value) => _sameSemanticValue(value, original),
          ),
        ),
      );
    }
    expect(
      restored.any(
        (ScheduleAdjustment value) =>
            value.reason == ScheduleAdjustmentReason.mercy,
      ),
      isFalse,
    );
    for (final ScheduleAdjustment original in originals) {
      expect(
        undo.adjustmentMutation.after.adjustments.any(
          (ScheduleAdjustment value) => value.id == original.id,
        ),
        isTrue,
        reason: 'original adjustment history must not be deleted',
      );
    }
    expect(undo.auditEvents, hasLength(2));
    expect(undo.auditEvents.first.eventType, SchedulerEventType.mercyUndone);
    expect(
      undo.auditEvents.first.undoesEventId,
      applied.undoSnapshot.appliedEventId,
    );
    expect(
      undo.auditEvents.last.undoesEventId,
      applied.undoSnapshot.items.single.appliedEventId,
    );
  });

  test('undo fails stale instead of erasing a later user adjustment', () {
    final MercyCandidate candidate = _candidate(revision: 1);
    final MercyPreview preview = planner.preview(
      _request(candidate: candidate, adjustments: ScheduleAdjustmentSet.empty),
    );
    final MercyApplyPlan applied = workflow.planApply(
      preview: preview,
      currentCandidates: <MercyCandidate>[candidate],
      currentAdjustments: ScheduleAdjustmentSet.empty,
      batchId: 'batch-stale-undo',
      operationId: 'apply-stale-undo',
      occurredAtUtc: DateTime.utc(2026, 3, 10, 8),
      studyDay: _day(10),
    );
    final ScheduleAdjustmentSet changed = applied.adjustmentMutation.after
        .addLowerBound(
          _bound(
            id: 'later-after-apply',
            reason: ScheduleAdjustmentReason.manualLater,
            day: 12,
            createdAt: DateTime.utc(2026, 3, 10, 9),
          ),
        )
        .after;

    expect(
      () => workflow.planUndo(
        applied: applied.undoSnapshot,
        currentAdjustments: changed,
        operationId: 'undo-stale',
        occurredAtUtc: DateTime.utc(2026, 3, 10, 10),
        studyDay: _day(10),
      ),
      throwsA(isA<StaleMercyPreview>()),
    );
  });
}

MercyPreviewRequest _request({
  required MercyCandidate candidate,
  required ScheduleAdjustmentSet adjustments,
}) => MercyPreviewRequest(
  today: _day(10),
  scope: const MercyCollectionScope(),
  collectingPeriod: MercyCollectingPeriod(start: _day(9), end: _day(13)),
  includeFutureRepetitions: true,
  destinationPolicy: MercyDailyCapacity(cardsPerDay: 1, topicsPerDay: 1),
  destinationWindow: MercyDestinationWindow(
    days: <MercyDestinationDay>[
      for (var day = 10; day <= 12; day++)
        MercyDestinationDay(
          day: _day(day),
          cardScheduledForAtUtc: DateTime.utc(2026, 3, day, 5),
          beforeCardLoad:
              candidate.ref.type == ElementType.card &&
                  candidate.currentEffectiveDueDay == _day(day)
              ? 1
              : 0,
          beforeTopicLoad: 0,
        ),
    ],
  ),
  criteriaPolicy: MercyCriteriaPolicy(
    priorityBandWidth: 0.05,
    deterministicSeed: 'workflow-fixture',
  ),
  protectionRules: const MercyProtectionRules(),
  candidates: <MercyCandidate>[candidate],
  adjustments: adjustments,
);

MercyCandidate _candidate({int revision = 1, int effectiveDay = 10}) {
  const ElementRef ref = ElementRef(id: 'card-1', type: ElementType.card);
  return MercyCandidate(
    ref: ref,
    revision: revision,
    currentEffectiveDueDay: _day(effectiveDay),
    priorityFraction: 0.2,
    canonical: MercyCanonicalSnapshot(
      serializedState: '{"state":"review","revision":$revision}',
      algorithmicDue: SchedulerEvent.encodeUtcDue(DateTime.utc(2026, 3, 10, 5)),
      schedulerName: 'dart-fsrs',
      schedulerVersion: 'dart-fsrs/2.0.1+FSRS-6',
    ),
  );
}

ScheduleAdjustment _bound({
  required String id,
  required ScheduleAdjustmentReason reason,
  required int day,
  DateTime? createdAt,
}) => ScheduleAdjustment(
  id: id,
  element: const ElementRef(id: 'card-1', type: ElementType.card),
  mode: ScheduleAdjustmentMode.lowerBound,
  reason: reason,
  notBeforeAtUtc: DateTime.utc(2026, 3, day, 12),
  operationId: 'set-$id',
  policyVersion: 'adjustments-v1',
  createdAtUtc: createdAt ?? DateTime.utc(2026, 3, 9, 12),
  createdStudyDay: _day(createdAt?.day ?? 9),
);

ScheduleAdjustment _exact({
  required String id,
  required ScheduleAdjustmentReason reason,
  required int day,
}) => ScheduleAdjustment(
  id: id,
  element: const ElementRef(id: 'card-1', type: ElementType.card),
  mode: ScheduleAdjustmentMode.exactOverride,
  reason: reason,
  scheduledForAtUtc: DateTime.utc(2026, 3, day, 5),
  operationId: 'set-$id',
  policyVersion: 'adjustments-v1',
  createdAtUtc: DateTime.utc(2026, 3, 9, 12),
  createdStudyDay: _day(9),
);

bool _sameSemanticValue(ScheduleAdjustment left, ScheduleAdjustment right) =>
    left.element == right.element &&
    left.mode == right.mode &&
    left.reason == right.reason &&
    left.notBeforeAtUtc == right.notBeforeAtUtc &&
    left.notBeforeStudyDay == right.notBeforeStudyDay &&
    left.scheduledForAtUtc == right.scheduledForAtUtc &&
    left.scheduledForStudyDay == right.scheduledForStudyDay &&
    left.batchId == right.batchId &&
    left.policyVersion == right.policyVersion;

StudyDay _day(int day) =>
    StudyDay(year: 2026, month: 3, day: day, zoneId: 'UTC');
