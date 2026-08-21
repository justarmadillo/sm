/// Side-effect-free apply and undo plans for a confirmed Mercy preview.
///
/// A persistence adapter must execute each returned plan in one transaction:
/// save changed adjustment rows, append every audit event, and save the batch
/// snapshot. No repository is used here, which keeps stale validation ahead of
/// all writes and makes the transaction boundary explicit to the caller.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/mercy.dart';
import '../../domain/scheduling/schedule_adjustment.dart';
import '../../domain/scheduling/schedule_adjustment_codec.dart';
import '../../domain/scheduling/scheduler_event.dart';
import '../../domain/scheduling/study_day.dart';

/// One selected item retained with the durable batch for exact audit and undo.
@immutable
final class MercyAppliedItemSnapshot {
  const MercyAppliedItemSnapshot({
    required this.element,
    required this.canonical,
    required this.fromDay,
    required this.toDay,
    required this.appliedEventId,
  });

  final ElementRef element;
  final MercyCanonicalSnapshot canonical;
  final StudyDay fromDay;
  final StudyDay toDay;
  final String appliedEventId;
}

/// Durable state needed to validate and exactly undo one applied batch.
@immutable
final class MercyAppliedBatchSnapshot {
  const MercyAppliedBatchSnapshot({
    required this.batchId,
    required this.appliedEventId,
    required this.policyVersion,
    required this.priorAdjustments,
    required this.appliedAdjustments,
    required this.items,
  });

  final String batchId;
  final String appliedEventId;
  final String policyVersion;

  /// Exact active set before apply, including every adjustment reason.
  final ScheduleAdjustmentSnapshot priorAdjustments;

  /// Exact active set immediately after apply, used as the undo CAS token.
  final ScheduleAdjustmentSnapshot appliedAdjustments;
  final List<MercyAppliedItemSnapshot> items;

  String get priorAdjustmentsJson => encodeAdjustmentSnapshot(priorAdjustments);
}

/// A confirmed transition ready for one transactional persistence call.
@immutable
final class MercyApplyPlan {
  const MercyApplyPlan({
    required this.preview,
    required this.batchId,
    required this.operationId,
    required this.adjustmentMutation,
    required this.auditEvents,
    required this.undoSnapshot,
  });

  final MercyPreview preview;
  final String batchId;
  final String operationId;
  final ScheduleAdjustmentMutation adjustmentMutation;
  final List<SchedulerEvent> auditEvents;
  final MercyAppliedBatchSnapshot undoSnapshot;

  ScheduleAdjustmentSnapshot get priorAdjustments =>
      adjustmentMutation.beforeSnapshot;
  ScheduleAdjustmentSnapshot get appliedAdjustments =>
      adjustmentMutation.afterSnapshot;

  /// This plan contains presentation state only.
  bool get changesCanonicalSchedulerState => false;
}

/// Exact semantic restoration ready for one transactional persistence call.
@immutable
final class MercyUndoPlan {
  const MercyUndoPlan({
    required this.batchId,
    required this.operationId,
    required this.adjustmentMutation,
    required this.auditEvents,
    required this.restoredPriorSnapshot,
  });

  final String batchId;
  final String operationId;
  final ScheduleAdjustmentMutation adjustmentMutation;
  final List<SchedulerEvent> auditEvents;

  /// Original values being restored. The mutation uses new audited rows so
  /// neither original nor applied history is reactivated or deleted.
  final ScheduleAdjustmentSnapshot restoredPriorSnapshot;

  bool get changesCanonicalSchedulerState => false;
}

/// Converts a pure preview into append-only adjustment/event transition plans.
final class MercyWorkflow {
  const MercyWorkflow();

  /// Validates all scoped revisions and the active adjustment snapshot before
  /// producing any rows. A thrown [StaleMercyPreview] means the caller must
  /// discard this result and regenerate the preview without writing anything.
  MercyApplyPlan planApply({
    required MercyPreview preview,
    required Iterable<MercyCandidate> currentCandidates,
    required ScheduleAdjustmentSet currentAdjustments,
    required String batchId,
    required String operationId,
    required DateTime occurredAtUtc,
    required StudyDay studyDay,
  }) {
    _requireText(batchId, 'batchId');
    _requireText(operationId, 'operationId');
    _requireUtc(occurredAtUtc, 'occurredAtUtc');
    if (preview.assignments.isEmpty) {
      throw StateError('an empty Mercy preview cannot be applied');
    }
    if (preview.policyVersion != preview.confirmationToken.policyVersion) {
      throw StaleMercyPreview('preview policy version no longer matches');
    }

    final Map<ElementRef, MercyCandidate> current = _validateCandidateRevisions(
      preview,
      currentCandidates,
    );
    final Set<ElementRef> scope = <ElementRef>{
      for (final MercyRevisionStamp stamp
          in preview.confirmationToken.candidateRevisions)
        stamp.element,
    };
    final String currentAdjustmentDigest = adjustmentSnapshotDigest(
      currentAdjustments.snapshotFor(scope),
    );
    if (currentAdjustmentDigest !=
        preview.confirmationToken.adjustmentSnapshotDigest) {
      throw StaleMercyPreview(
        'active adjustments changed after the Mercy preview',
        changed: scope,
      );
    }

    final List<ScheduleAdjustment> overrides = <ScheduleAdjustment>[
      for (final MercyAssignment assignment in preview.assignments)
        ScheduleAdjustment(
          id: _stableId('mercy-adjustment', '$batchId|${assignment.element}'),
          element: assignment.element,
          mode: ScheduleAdjustmentMode.exactOverride,
          reason: ScheduleAdjustmentReason.mercy,
          scheduledForAtUtc: assignment.scheduledForAtUtc,
          scheduledForStudyDay: assignment.scheduledForStudyDay,
          operationId: _itemOperationId(operationId, assignment.element),
          batchId: batchId,
          policyVersion: preview.policyVersion,
          createdAtUtc: occurredAtUtc,
          createdStudyDay: studyDay,
        ),
    ];
    final ScheduleAdjustmentMutation mutation = currentAdjustments.applyMercy(
      overrides,
      overrideManualLater: preview.protectionRules.overrideManualLater,
    );
    final String batchAppliedEventId = _stableId(
      'mercy-applied-event',
      '$batchId|$operationId',
    );
    final List<SchedulerEvent> events = <SchedulerEvent>[
      SchedulerEvent(
        id: _stableId('mercy-preview-event', '$batchId|$operationId'),
        operationId: '$operationId:previewed',
        eventType: SchedulerEventType.mercyPreviewed,
        occurredAtUtc: occurredAtUtc,
        studyDay: studyDay,
        policyVersion: preview.policyVersion,
        adjustmentsBefore: encodeAdjustmentSnapshot(mutation.beforeSnapshot),
        adjustmentsAfter: encodeAdjustmentSnapshot(mutation.beforeSnapshot),
        batchId: batchId,
        metadata: <String, Object?>{
          'confirmation_token': preview.confirmationToken.digest,
          'selected_cards': preview.selectedCardCount,
          'selected_topics': preview.selectedTopicCount,
          'exclusion_counts': <String, int>{
            for (final MapEntry<MercyExclusionReason, int> entry
                in preview.exclusionCounts.entries)
              entry.key.name: entry.value,
          },
          'warnings': preview.warnings
              .map((MercyWarning value) => value.name)
              .toList(),
        },
      ),
      SchedulerEvent(
        id: batchAppliedEventId,
        operationId: '$operationId:applied',
        eventType: SchedulerEventType.mercyApplied,
        occurredAtUtc: occurredAtUtc,
        studyDay: studyDay,
        policyVersion: preview.policyVersion,
        adjustmentsBefore: encodeAdjustmentSnapshot(mutation.beforeSnapshot),
        adjustmentsAfter: encodeAdjustmentSnapshot(mutation.afterSnapshot),
        batchId: batchId,
        metadata: <String, Object?>{
          'confirmation_token': preview.confirmationToken.digest,
          'item_count': preview.selectedCount,
          'override_manual_later': preview.protectionRules.overrideManualLater,
        },
      ),
    ];
    final List<MercyAppliedItemSnapshot> items = <MercyAppliedItemSnapshot>[];
    for (final MercyAssignment assignment in preview.assignments) {
      final MercyCandidate candidate = current[assignment.element]!;
      final String eventId = _stableId(
        'mercy-item-applied-event',
        '$batchId|${assignment.element}',
      );
      final ScheduleAdjustmentSnapshot beforeFor = mutation.before.snapshotFor(
        <ElementRef>{assignment.element},
      );
      final ScheduleAdjustmentSnapshot afterFor = mutation.after.snapshotFor(
        <ElementRef>{assignment.element},
      );
      events.add(
        SchedulerEvent(
          id: eventId,
          operationId: _itemOperationId(operationId, assignment.element),
          element: assignment.element,
          eventType: SchedulerEventType.mercyApplied,
          occurredAtUtc: occurredAtUtc,
          studyDay: studyDay,
          schedulerName: candidate.canonical.schedulerName,
          schedulerVersion: candidate.canonical.schedulerVersion,
          policyVersion: preview.policyVersion,
          stateBefore: candidate.canonical.serializedState,
          stateAfter: candidate.canonical.serializedState,
          algorithmicDueBefore: candidate.canonical.algorithmicDue,
          algorithmicDueAfter: candidate.canonical.algorithmicDue,
          adjustmentsBefore: encodeAdjustmentSnapshot(beforeFor),
          adjustmentsAfter: encodeAdjustmentSnapshot(afterFor),
          batchId: batchId,
          metadata: <String, Object?>{
            'from_study_day': assignment.fromDay.epochDay,
            'to_study_day': assignment.toDay.epochDay,
            'zone_id': assignment.toDay.zoneId,
            'scheduled_for_at_utc':
                assignment.scheduledForAtUtc?.millisecondsSinceEpoch,
            'priority_fraction': assignment.priorityFraction,
            'criteria_score': assignment.criteriaScore,
          },
        ),
      );
      items.add(
        MercyAppliedItemSnapshot(
          element: assignment.element,
          canonical: candidate.canonical,
          fromDay: assignment.fromDay,
          toDay: assignment.toDay,
          appliedEventId: eventId,
        ),
      );
    }

    final MercyAppliedBatchSnapshot undoSnapshot = MercyAppliedBatchSnapshot(
      batchId: batchId,
      appliedEventId: batchAppliedEventId,
      policyVersion: preview.policyVersion,
      priorAdjustments: mutation.beforeSnapshot,
      appliedAdjustments: mutation.afterSnapshot,
      items: List<MercyAppliedItemSnapshot>.unmodifiable(items),
    );
    return MercyApplyPlan(
      preview: preview,
      batchId: batchId,
      operationId: operationId,
      adjustmentMutation: mutation,
      auditEvents: List<SchedulerEvent>.unmodifiable(events),
      undoSnapshot: undoSnapshot,
    );
  }

  /// Restores the exact semantic active set that existed before [applied].
  ///
  /// The current active set must still equal the applied batch snapshot. This
  /// prevents undo from silently erasing a Later/reschedule made afterward.
  /// Restored values use new lifecycle rows; all original and applied rows stay
  /// in append-only history.
  MercyUndoPlan planUndo({
    required MercyAppliedBatchSnapshot applied,
    required ScheduleAdjustmentSet currentAdjustments,
    required String operationId,
    required DateTime occurredAtUtc,
    required StudyDay studyDay,
  }) {
    _requireText(operationId, 'operationId');
    _requireUtc(occurredAtUtc, 'occurredAtUtc');
    final Set<ElementRef> scope = applied.appliedAdjustments.elements.toSet();
    final ScheduleAdjustmentSnapshot currentSnapshot = currentAdjustments
        .snapshotFor(scope);
    if (adjustmentSnapshotDigest(currentSnapshot) !=
        adjustmentSnapshotDigest(applied.appliedAdjustments)) {
      throw StaleMercyPreview(
        'active adjustments changed after the Mercy batch was applied',
        changed: scope,
      );
    }

    final List<ScheduleAdjustment> restored = <ScheduleAdjustment>[
      for (final ScheduleAdjustment prior
          in applied.priorAdjustments.activeAdjustments)
        _restoredAdjustment(
          prior: prior,
          operationId: operationId,
          occurredAtUtc: occurredAtUtc,
          studyDay: studyDay,
        ),
    ];
    final ScheduleAdjustmentMutation mutation = currentAdjustments
        .replaceActiveForScope(
          elements: scope,
          replacements: restored,
          atUtc: occurredAtUtc,
          operationId: operationId,
        );
    final List<SchedulerEvent> events = <SchedulerEvent>[
      SchedulerEvent(
        id: _stableId('mercy-undone-event', '${applied.batchId}|$operationId'),
        operationId: '$operationId:undone',
        eventType: SchedulerEventType.mercyUndone,
        occurredAtUtc: occurredAtUtc,
        studyDay: studyDay,
        policyVersion: applied.policyVersion,
        adjustmentsBefore: encodeAdjustmentSnapshot(mutation.beforeSnapshot),
        adjustmentsAfter: encodeAdjustmentSnapshot(mutation.afterSnapshot),
        undoesEventId: applied.appliedEventId,
        batchId: applied.batchId,
        metadata: <String, Object?>{'item_count': applied.items.length},
      ),
    ];
    final Map<ElementRef, MercyAppliedItemSnapshot> items =
        <ElementRef, MercyAppliedItemSnapshot>{
          for (final MercyAppliedItemSnapshot item in applied.items)
            item.element: item,
        };
    for (final ElementRef element in scope.toList()..sort()) {
      final MercyAppliedItemSnapshot item = items[element]!;
      events.add(
        SchedulerEvent(
          id: _stableId(
            'mercy-item-undone-event',
            '${applied.batchId}|$operationId|$element',
          ),
          operationId: _itemOperationId(operationId, element),
          element: element,
          eventType: SchedulerEventType.mercyUndone,
          occurredAtUtc: occurredAtUtc,
          studyDay: studyDay,
          schedulerName: item.canonical.schedulerName,
          schedulerVersion: item.canonical.schedulerVersion,
          policyVersion: applied.policyVersion,
          stateBefore: item.canonical.serializedState,
          stateAfter: item.canonical.serializedState,
          algorithmicDueBefore: item.canonical.algorithmicDue,
          algorithmicDueAfter: item.canonical.algorithmicDue,
          adjustmentsBefore: encodeAdjustmentSnapshot(
            mutation.before.snapshotFor(<ElementRef>{element}),
          ),
          adjustmentsAfter: encodeAdjustmentSnapshot(
            mutation.after.snapshotFor(<ElementRef>{element}),
          ),
          undoesEventId: item.appliedEventId,
          batchId: applied.batchId,
        ),
      );
    }
    return MercyUndoPlan(
      batchId: applied.batchId,
      operationId: operationId,
      adjustmentMutation: mutation,
      auditEvents: List<SchedulerEvent>.unmodifiable(events),
      restoredPriorSnapshot: applied.priorAdjustments,
    );
  }
}

Map<ElementRef, MercyCandidate> _validateCandidateRevisions(
  MercyPreview preview,
  Iterable<MercyCandidate> candidates,
) {
  final Map<ElementRef, MercyCandidate> scoped = <ElementRef, MercyCandidate>{};
  for (final MercyCandidate candidate in candidates) {
    if (!preview.scope.contains(candidate)) continue;
    if (scoped.containsKey(candidate.ref)) {
      throw ArgumentError('duplicate current candidate ${candidate.ref}');
    }
    scoped[candidate.ref] = candidate;
  }
  final Map<ElementRef, int> expected = <ElementRef, int>{
    for (final MercyRevisionStamp stamp
        in preview.confirmationToken.candidateRevisions)
      stamp.element: stamp.revision,
  };
  final Set<ElementRef> all = <ElementRef>{...expected.keys, ...scoped.keys};
  final List<ElementRef> changed = <ElementRef>[
    for (final ElementRef element in all)
      if (expected[element] == null ||
          scoped[element] == null ||
          expected[element] != scoped[element]!.revision)
        element,
  ]..sort();
  if (changed.isNotEmpty) {
    throw StaleMercyPreview(
      'candidate revisions changed after the Mercy preview',
      changed: changed,
    );
  }
  return scoped;
}

ScheduleAdjustment _restoredAdjustment({
  required ScheduleAdjustment prior,
  required String operationId,
  required DateTime occurredAtUtc,
  required StudyDay studyDay,
}) {
  final StudyDay createdDay = prior.element.type == ElementType.card
      ? studyDay
      : StudyDay(
          year: studyDay.year,
          month: studyDay.month,
          day: studyDay.day,
          zoneId:
              prior.notBeforeStudyDay?.zoneId ??
              prior.scheduledForStudyDay!.zoneId,
        );
  return ScheduleAdjustment(
    id: _stableId(
      'mercy-undo-adjustment',
      '$operationId|${prior.id}|${prior.element}',
    ),
    element: prior.element,
    mode: prior.mode,
    reason: prior.reason,
    notBeforeAtUtc: prior.notBeforeAtUtc,
    notBeforeStudyDay: prior.notBeforeStudyDay,
    scheduledForAtUtc: prior.scheduledForAtUtc,
    scheduledForStudyDay: prior.scheduledForStudyDay,
    operationId: '$operationId:restore:${prior.id}',
    batchId: prior.batchId,
    policyVersion: prior.policyVersion,
    createdAtUtc: occurredAtUtc,
    createdStudyDay: createdDay,
  );
}

String _itemOperationId(String operationId, ElementRef element) =>
    '$operationId:item:${element.type.name}:${element.id}';

String _stableId(String prefix, String payload) {
  final String digest = sha256.convert(utf8.encode(payload)).toString();
  return '$prefix-${digest.substring(0, 24)}';
}

void _requireUtc(DateTime value, String name) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, name, 'must be UTC');
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
