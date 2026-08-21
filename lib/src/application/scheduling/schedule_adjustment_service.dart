/// Transaction-scoped application service for presentation adjustments.
library;

import 'dart:convert';

import '../../core/ids.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/schedule_adjustment.dart';
import '../../domain/scheduling/scheduler_event.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../ports/repositories.dart';
import 'scheduling_journal.dart';

const String kAdjustmentPolicyVersion = 'schedule_adjustments_v1';

final class AdjustmentApplication {
  const AdjustmentApplication({
    required this.mutation,
    required this.alreadyApplied,
  });

  final ScheduleAdjustmentMutation mutation;
  final bool alreadyApplied;
}

/// Applies adjustment transitions without touching canonical scheduler state.
/// Callers keep this inside the same database transaction as their activity
/// and transfer-generation writes.
final class ScheduleAdjustmentService {
  ScheduleAdjustmentService({
    required LearningRepository learning,
    required IdGenerator ids,
  }) : _learning = learning,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids);

  final LearningRepository _learning;
  final IdGenerator _ids;
  final SchedulingJournal _journal;

  Future<AdjustmentApplication> setLowerBound({
    required ElementRef element,
    required ScheduleAdjustmentReason reason,
    required String operationId,
    required DateTime atUtc,
    required StudyDay studyDay,
    DateTime? notBeforeAtUtc,
    StudyDay? notBeforeStudyDay,
    bool replaceSameReason = false,
    String policyVersion = kAdjustmentPolicyVersion,
    String? batchId,
  }) async {
    final SchedulerEventType eventType = switch (reason) {
      ScheduleAdjustmentReason.manualLater => SchedulerEventType.manualLaterSet,
      ScheduleAdjustmentReason.autoOverflow =>
        SchedulerEventType.autoOverflowSet,
      ScheduleAdjustmentReason.siblingBury => SchedulerEventType.siblingBuried,
      ScheduleAdjustmentReason.mercy ||
      ScheduleAdjustmentReason.manualReschedule => throw ArgumentError(
        '${reason.wireName} is not a lower-bound reason',
      ),
    };
    final ScheduleAdjustmentSet before = await _loadSet(element);
    final ScheduleAdjustment incoming = ScheduleAdjustment(
      id: _ids.newId(),
      element: element,
      mode: ScheduleAdjustmentMode.lowerBound,
      reason: reason,
      notBeforeAtUtc: notBeforeAtUtc,
      notBeforeStudyDay: notBeforeStudyDay,
      operationId: operationId,
      batchId: batchId,
      policyVersion: policyVersion,
      createdAtUtc: atUtc,
      createdStudyDay: studyDay,
    );
    final ScheduleAdjustmentMutation mutation = replaceSameReason
        ? before.upsertLowerBound(incoming)
        : before.addLowerBound(incoming);
    if (!mutation.changed) {
      return AdjustmentApplication(mutation: mutation, alreadyApplied: true);
    }
    await _persist(mutation);
    final _CanonicalEnvelope canonical = await _canonical(element);
    await _journal.appendScheduler(
      operationId: operationId,
      ref: element,
      eventType: eventType,
      atUtc: atUtc,
      studyDay: studyDay,
      policyVersion: policyVersion,
      schedulerName: canonical.schedulerName,
      schedulerVersion: canonical.schedulerVersion,
      stateBefore: canonical.state,
      stateAfter: canonical.state,
      algorithmicDueBefore: canonical.algorithmicDue,
      algorithmicDueAfter: canonical.algorithmicDue,
      adjustmentsBefore: mutation.beforeSnapshot,
      adjustmentsAfter: mutation.afterSnapshot,
      batchId: batchId,
      metadata: <String, Object?>{'reason': reason.wireName},
    );
    return AdjustmentApplication(mutation: mutation, alreadyApplied: false);
  }

  Future<AdjustmentApplication> setExactOverride({
    required ElementRef element,
    required ScheduleAdjustmentReason reason,
    required String operationId,
    required DateTime atUtc,
    required StudyDay studyDay,
    DateTime? scheduledForAtUtc,
    StudyDay? scheduledForStudyDay,
    String policyVersion = kAdjustmentPolicyVersion,
    String? batchId,
  }) async {
    if (reason != ScheduleAdjustmentReason.manualReschedule &&
        reason != ScheduleAdjustmentReason.mercy) {
      throw ArgumentError('${reason.wireName} is not an exact-override reason');
    }
    final SchedulerEventType eventType =
        reason == ScheduleAdjustmentReason.mercy
        ? SchedulerEventType.mercyApplied
        : SchedulerEventType.manualRescheduleSet;
    final ScheduleAdjustmentSet before = await _loadSet(element);
    final ScheduleAdjustment incoming = ScheduleAdjustment(
      id: _ids.newId(),
      element: element,
      mode: ScheduleAdjustmentMode.exactOverride,
      reason: reason,
      scheduledForAtUtc: scheduledForAtUtc,
      scheduledForStudyDay: scheduledForStudyDay,
      operationId: operationId,
      batchId: batchId,
      policyVersion: policyVersion,
      createdAtUtc: atUtc,
      createdStudyDay: studyDay,
    );
    final ScheduleAdjustmentMutation mutation = before.setExactOverride(
      incoming,
    );
    if (!mutation.changed) {
      return AdjustmentApplication(mutation: mutation, alreadyApplied: true);
    }
    await _persist(mutation);
    final _CanonicalEnvelope canonical = await _canonical(element);
    await _journal.appendScheduler(
      operationId: operationId,
      ref: element,
      eventType: eventType,
      atUtc: atUtc,
      studyDay: studyDay,
      policyVersion: policyVersion,
      schedulerName: canonical.schedulerName,
      schedulerVersion: canonical.schedulerVersion,
      stateBefore: canonical.state,
      stateAfter: canonical.state,
      algorithmicDueBefore: canonical.algorithmicDue,
      algorithmicDueAfter: canonical.algorithmicDue,
      adjustmentsBefore: mutation.beforeSnapshot,
      adjustmentsAfter: mutation.afterSnapshot,
      batchId: batchId,
      metadata: <String, Object?>{'reason': reason.wireName},
    );
    return AdjustmentApplication(mutation: mutation, alreadyApplied: false);
  }

  /// Clears adjustments consumed by a genuine review/encounter. The complete
  /// before/after snapshot is returned for the canonical transition event.
  Future<ScheduleAdjustmentMutation> clearAfterCanonicalTransition({
    required ElementRef element,
    required DateTime atUtc,
    required String operationId,
  }) async {
    final ScheduleAdjustmentSet before = await _loadSet(element);
    final ScheduleAdjustmentMutation mutation = before.clearByIds(
      adjustmentIds: <String>[
        for (final adjustment in before.activeFor(element)) adjustment.id,
      ],
      atUtc: atUtc,
      operationId: operationId,
    );
    await _persist(mutation);
    return mutation;
  }

  Future<ScheduleAdjustmentMutation> clearAutoOverflow({
    required Iterable<ElementRef> elements,
    required DateTime atUtc,
    required StudyDay studyDay,
    required String operationId,
  }) async {
    final Set<ElementRef> scope = elements.toSet();
    final ScheduleAdjustmentSet before = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(elements: scope),
    );
    final ScheduleAdjustmentMutation mutation = before.clearAutoOverflowFor(
      elements: scope,
      atUtc: atUtc,
      operationId: operationId,
    );
    await _persist(mutation);
    for (final ElementRef element in scope) {
      final List<ScheduleAdjustment> beforeFor = mutation.beforeSnapshot
          .forElement(element);
      final List<ScheduleAdjustment> afterFor = mutation.afterSnapshot
          .forElement(element);
      if (beforeFor.length == afterFor.length) continue;
      final _CanonicalEnvelope canonical = await _canonical(element);
      await _journal.appendScheduler(
        operationId: operationId,
        ref: element,
        eventType: SchedulerEventType.autoOverflowCleared,
        atUtc: atUtc,
        studyDay: studyDay,
        policyVersion: kAdjustmentPolicyVersion,
        schedulerName: canonical.schedulerName,
        schedulerVersion: canonical.schedulerVersion,
        stateBefore: canonical.state,
        stateAfter: canonical.state,
        algorithmicDueBefore: canonical.algorithmicDue,
        algorithmicDueAfter: canonical.algorithmicDue,
        adjustmentsBefore: mutation.beforeSnapshot,
        adjustmentsAfter: mutation.afterSnapshot,
      );
    }
    return mutation;
  }

  /// Restores the semantic active set captured before an undone operation.
  /// Restored rows are new audited lifecycle rows; original rows and their
  /// clear provenance remain untouched.
  Future<ScheduleAdjustmentMutation> restoreSnapshot({
    required ScheduleAdjustmentSnapshot snapshot,
    required DateTime atUtc,
    required StudyDay studyDay,
    required String operationId,
  }) async {
    final ScheduleAdjustmentSet before = ScheduleAdjustmentSet(
      await _learning.listActiveAdjustments(
        elements: snapshot.elements.toSet(),
      ),
    );
    final List<ScheduleAdjustment> restored = <ScheduleAdjustment>[
      for (final prior in snapshot.activeAdjustments)
        ScheduleAdjustment(
          id: _ids.newId(),
          element: prior.element,
          mode: prior.mode,
          reason: prior.reason,
          notBeforeAtUtc: prior.notBeforeAtUtc,
          notBeforeStudyDay: prior.notBeforeStudyDay,
          scheduledForAtUtc: prior.scheduledForAtUtc,
          scheduledForStudyDay: prior.scheduledForStudyDay,
          operationId: operationId,
          batchId: prior.batchId,
          policyVersion: prior.policyVersion,
          createdAtUtc: atUtc,
          createdStudyDay: prior.element.type == ElementType.card
              ? studyDay
              : StudyDay(
                  year: studyDay.year,
                  month: studyDay.month,
                  day: studyDay.day,
                  zoneId:
                      prior.notBeforeStudyDay?.zoneId ??
                      prior.scheduledForStudyDay!.zoneId,
                ),
        ),
    ];
    final ScheduleAdjustmentMutation mutation = before.replaceActiveForScope(
      elements: snapshot.elements,
      replacements: restored,
      atUtc: atUtc,
      operationId: operationId,
    );
    await _persist(mutation);
    return mutation;
  }

  Future<ScheduleAdjustmentSet> _loadSet(ElementRef element) async =>
      ScheduleAdjustmentSet(
        await _learning.listAdjustmentsFor(element, includeCleared: true),
      );

  Future<void> _persist(ScheduleAdjustmentMutation mutation) async {
    if (!mutation.changed) return;
    final Map<String, ScheduleAdjustment> before = <String, ScheduleAdjustment>{
      for (final adjustment in mutation.before.adjustments)
        adjustment.id: adjustment,
    };
    await _learning.saveAdjustments(<ScheduleAdjustment>[
      for (final adjustment in mutation.after.adjustments)
        if (before[adjustment.id] != adjustment) adjustment,
    ]);
  }

  Future<_CanonicalEnvelope> _canonical(ElementRef element) async {
    if (element.type == ElementType.card) {
      final CardState? state = await _learning.findCardState(element.id);
      if (state == null) throw StateError('missing card state for $element');
      return _CanonicalEnvelope(
        state: state.memory.canonicalFsrsJson(),
        algorithmicDue: SchedulerEvent.encodeUtcDue(state.memory.dueAtUtc),
        schedulerName: state.memory.schedulerName,
        schedulerVersion: state.memory.schedulerVersion,
      );
    }
    final TopicState? topic = await _learning.findTopic(element);
    if (topic == null) throw StateError('missing topic state for $element');
    return _CanonicalEnvelope(
      state: jsonEncode(<String, Object?>{
        'scheduler_kind': topic.schedulerKind.storageName,
        'scheduler_version': topic.schedulerVersion,
        'interval_days': topic.intervalDays,
        'a_factor': topic.aFactor,
        'encounters': topic.encounters,
        'last_encounter_day': topic.lastEncounterDay?.epochDay,
        'policy_input_snapshot': topic.policyInputSnapshot,
        'revision': topic.revision,
      }),
      algorithmicDue: SchedulerEvent.encodeStudyDayDue(
        topic.schedule.algorithmicDueDay,
      ),
      schedulerName: topic.schedulerKind.storageName,
      schedulerVersion: topic.schedulerVersion,
    );
  }
}

final class _CanonicalEnvelope {
  const _CanonicalEnvelope({
    required this.state,
    required this.algorithmicDue,
    required this.schedulerName,
    required this.schedulerVersion,
  });

  final String state;
  final String algorithmicDue;
  final String schedulerName;
  final String schedulerVersion;
}
