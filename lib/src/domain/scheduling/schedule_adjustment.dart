/// Typed presentation-only schedule adjustments.
///
/// Algorithmic card and topic dues do not belong in this model. An adjustment
/// only changes when an element may be presented, and clearing one retains the
/// audit fields on the adjustment row. All transformations are pure so callers
/// can persist the returned before/after snapshots transactionally.
library;

import 'package:meta/meta.dart';

import 'element.dart';
import 'study_day.dart';

/// How an adjustment participates in effective-due calculation.
enum ScheduleAdjustmentMode {
  /// The element cannot be presented before the adjustment's value.
  lowerBound('lower_bound'),

  /// The adjustment replaces the algorithmic due before bounds are applied.
  exactOverride('exact_override');

  const ScheduleAdjustmentMode(this.wireName);

  final String wireName;
}

/// The user or scheduler action that created an adjustment.
enum ScheduleAdjustmentReason {
  manualLater('manual_later'),
  autoOverflow('auto_overflow'),
  siblingBury('sibling_bury'),
  mercy('mercy'),
  manualReschedule('manual_reschedule');

  const ScheduleAdjustmentReason(this.wireName);

  final String wireName;
}

/// Calendar coordinate used by an element's scheduler.
enum ScheduleTimeDomain {
  /// Cards use an exact UTC instant.
  exactUtc,

  /// Sources and extracts use a local [StudyDay].
  studyDay,
}

extension on ElementRef {
  ScheduleTimeDomain get scheduleTimeDomain => type == ElementType.card
      ? ScheduleTimeDomain.exactUtc
      : ScheduleTimeDomain.studyDay;
}

/// One lifecycle-tracked presentation adjustment.
@immutable
final class ScheduleAdjustment {
  factory ScheduleAdjustment({
    required String id,
    required ElementRef element,
    required ScheduleAdjustmentMode mode,
    required ScheduleAdjustmentReason reason,
    required String operationId,
    required String policyVersion,
    required DateTime createdAtUtc,
    required StudyDay createdStudyDay,
    DateTime? notBeforeAtUtc,
    StudyDay? notBeforeStudyDay,
    DateTime? scheduledForAtUtc,
    StudyDay? scheduledForStudyDay,
    String? batchId,
    DateTime? clearedAtUtc,
    String? clearedByOperationId,
  }) {
    _requireText(id, 'id');
    _requireText(element.id, 'element.id');
    _requireText(operationId, 'operationId');
    _requireText(policyVersion, 'policyVersion');
    if (batchId != null) _requireText(batchId, 'batchId');
    _requireUtc(createdAtUtc, 'createdAtUtc');
    _requireText(createdStudyDay.zoneId, 'createdStudyDay.zoneId');

    final bool hasClearTime = clearedAtUtc != null;
    final bool hasClearOperation = clearedByOperationId != null;
    if (hasClearTime != hasClearOperation) {
      throw ArgumentError(
        'clearedAtUtc and clearedByOperationId must be set together',
      );
    }
    if (clearedAtUtc != null) {
      _requireUtc(clearedAtUtc, 'clearedAtUtc');
      _requireText(clearedByOperationId!, 'clearedByOperationId');
      if (clearedAtUtc.isBefore(createdAtUtc)) {
        throw ArgumentError('an adjustment cannot be cleared before creation');
      }
    }

    final bool reasonNeedsLowerBound = switch (reason) {
      ScheduleAdjustmentReason.manualLater ||
      ScheduleAdjustmentReason.autoOverflow ||
      ScheduleAdjustmentReason.siblingBury => true,
      ScheduleAdjustmentReason.mercy ||
      ScheduleAdjustmentReason.manualReschedule => false,
    };
    if (reasonNeedsLowerBound != (mode == ScheduleAdjustmentMode.lowerBound)) {
      throw ArgumentError('${reason.wireName} cannot use ${mode.wireName}');
    }

    final int notBeforeCount =
        (notBeforeAtUtc == null ? 0 : 1) + (notBeforeStudyDay == null ? 0 : 1);
    final int scheduledForCount =
        (scheduledForAtUtc == null ? 0 : 1) +
        (scheduledForStudyDay == null ? 0 : 1);
    if (mode == ScheduleAdjustmentMode.lowerBound) {
      if (notBeforeCount != 1 || scheduledForCount != 0) {
        throw ArgumentError(
          'a lower_bound needs exactly one not-before value and no '
          'scheduled-for value',
        );
      }
    } else if (scheduledForCount != 1 || notBeforeCount != 0) {
      throw ArgumentError(
        'an exact_override needs exactly one scheduled-for value and no '
        'not-before value',
      );
    }

    if (element.scheduleTimeDomain == ScheduleTimeDomain.exactUtc) {
      if (notBeforeStudyDay != null || scheduledForStudyDay != null) {
        throw ArgumentError('card adjustments must use exact UTC values');
      }
      if (notBeforeAtUtc != null) {
        _requireUtc(notBeforeAtUtc, 'notBeforeAtUtc');
      }
      if (scheduledForAtUtc != null) {
        _requireUtc(scheduledForAtUtc, 'scheduledForAtUtc');
      }
    } else {
      if (notBeforeAtUtc != null || scheduledForAtUtc != null) {
        throw ArgumentError('topic adjustments must use StudyDay values');
      }
      final StudyDay destination = notBeforeStudyDay ?? scheduledForStudyDay!;
      if (destination.zoneId != createdStudyDay.zoneId) {
        throw ArgumentError(
          'a topic adjustment and its creation StudyDay must use one zone',
        );
      }
    }

    return ScheduleAdjustment._(
      id: id,
      element: element,
      mode: mode,
      reason: reason,
      notBeforeAtUtc: notBeforeAtUtc,
      notBeforeStudyDay: notBeforeStudyDay,
      scheduledForAtUtc: scheduledForAtUtc,
      scheduledForStudyDay: scheduledForStudyDay,
      operationId: operationId,
      batchId: batchId,
      policyVersion: policyVersion,
      createdAtUtc: createdAtUtc,
      createdStudyDay: createdStudyDay,
      clearedAtUtc: clearedAtUtc,
      clearedByOperationId: clearedByOperationId,
    );
  }

  const ScheduleAdjustment._({
    required this.id,
    required this.element,
    required this.mode,
    required this.reason,
    required this.notBeforeAtUtc,
    required this.notBeforeStudyDay,
    required this.scheduledForAtUtc,
    required this.scheduledForStudyDay,
    required this.operationId,
    required this.batchId,
    required this.policyVersion,
    required this.createdAtUtc,
    required this.createdStudyDay,
    required this.clearedAtUtc,
    required this.clearedByOperationId,
  });

  final String id;
  final ElementRef element;
  final ScheduleAdjustmentMode mode;
  final ScheduleAdjustmentReason reason;
  final DateTime? notBeforeAtUtc;
  final StudyDay? notBeforeStudyDay;
  final DateTime? scheduledForAtUtc;
  final StudyDay? scheduledForStudyDay;
  final String operationId;
  final String? batchId;
  final String policyVersion;
  final DateTime createdAtUtc;
  final StudyDay createdStudyDay;
  final DateTime? clearedAtUtc;
  final String? clearedByOperationId;

  String get elementId => element.id;

  ScheduleTimeDomain get timeDomain => element.scheduleTimeDomain;

  bool get isActive => clearedAtUtc == null;

  /// Marks this row inactive without discarding its creation audit.
  ///
  /// A second clear is an idempotent no-op and preserves the first clear
  /// operation, which is the lifecycle transition that actually took effect.
  ScheduleAdjustment clear({
    required DateTime atUtc,
    required String operationId,
  }) {
    _requireUtc(atUtc, 'atUtc');
    _requireText(operationId, 'operationId');
    if (!isActive) return this;
    if (atUtc.isBefore(createdAtUtc)) {
      throw ArgumentError('an adjustment cannot be cleared before creation');
    }
    return ScheduleAdjustment(
      id: id,
      element: element,
      mode: mode,
      reason: reason,
      notBeforeAtUtc: notBeforeAtUtc,
      notBeforeStudyDay: notBeforeStudyDay,
      scheduledForAtUtc: scheduledForAtUtc,
      scheduledForStudyDay: scheduledForStudyDay,
      operationId: this.operationId,
      batchId: batchId,
      policyVersion: policyVersion,
      createdAtUtc: createdAtUtc,
      createdStudyDay: createdStudyDay,
      clearedAtUtc: atUtc,
      clearedByOperationId: operationId,
    );
  }

  bool hasSameOperationValue(ScheduleAdjustment other) =>
      element == other.element &&
      mode == other.mode &&
      reason == other.reason &&
      notBeforeAtUtc == other.notBeforeAtUtc &&
      notBeforeStudyDay == other.notBeforeStudyDay &&
      scheduledForAtUtc == other.scheduledForAtUtc &&
      scheduledForStudyDay == other.scheduledForStudyDay &&
      operationId == other.operationId &&
      batchId == other.batchId &&
      policyVersion == other.policyVersion &&
      createdAtUtc == other.createdAtUtc &&
      createdStudyDay == other.createdStudyDay;

  @override
  bool operator ==(Object other) =>
      other is ScheduleAdjustment &&
      id == other.id &&
      hasSameOperationValue(other) &&
      clearedAtUtc == other.clearedAtUtc &&
      clearedByOperationId == other.clearedByOperationId;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    element,
    mode,
    reason,
    notBeforeAtUtc,
    notBeforeStudyDay,
    scheduledForAtUtc,
    scheduledForStudyDay,
    operationId,
    batchId,
    policyVersion,
    createdAtUtc,
    createdStudyDay,
    clearedAtUtc,
    clearedByOperationId,
  ]);
}

/// A deterministic, validated collection of active and cleared adjustments.
@immutable
final class ScheduleAdjustmentSet {
  factory ScheduleAdjustmentSet(Iterable<ScheduleAdjustment> adjustments) {
    final List<ScheduleAdjustment> ordered = adjustments.toList()
      ..sort(_compareAdjustments);
    final Set<String> ids = <String>{};
    final Map<String, ElementType> elementTypes = <String, ElementType>{};
    final Set<String> activeExactKeys = <String>{};
    for (final ScheduleAdjustment adjustment in ordered) {
      if (!ids.add(adjustment.id)) {
        throw StateError('duplicate adjustment id ${adjustment.id}');
      }
      final ElementType? knownType = elementTypes[adjustment.elementId];
      if (knownType != null && knownType != adjustment.element.type) {
        throw StateError(
          'element ${adjustment.elementId} has conflicting element types',
        );
      }
      elementTypes[adjustment.elementId] = adjustment.element.type;
      if (adjustment.isActive &&
          adjustment.mode == ScheduleAdjustmentMode.exactOverride) {
        final String key =
            '${adjustment.elementId}:${adjustment.timeDomain.name}';
        if (!activeExactKeys.add(key)) {
          throw StateError(
            'only one active exact override is allowed for $key',
          );
        }
      }
    }
    return ScheduleAdjustmentSet._(
      List<ScheduleAdjustment>.unmodifiable(ordered),
    );
  }

  const ScheduleAdjustmentSet._(this.adjustments);

  static final ScheduleAdjustmentSet empty = ScheduleAdjustmentSet(
    const <ScheduleAdjustment>[],
  );

  final List<ScheduleAdjustment> adjustments;

  List<ScheduleAdjustment> get active => List<ScheduleAdjustment>.unmodifiable(
    adjustments.where((ScheduleAdjustment value) => value.isActive),
  );

  List<ScheduleAdjustment> activeFor(ElementRef element) =>
      List<ScheduleAdjustment>.unmodifiable(
        adjustments.where(
          (ScheduleAdjustment value) =>
              value.isActive && value.element == element,
        ),
      );

  /// Adds another lower bound without replacing bounds already in force.
  ///
  /// This is used for independently meaningful constraints such as manual
  /// Later and sibling burying. A repeated operation is a no-op.
  ScheduleAdjustmentMutation addLowerBound(ScheduleAdjustment adjustment) {
    _requireMode(adjustment, ScheduleAdjustmentMode.lowerBound);
    return _add(adjustment);
  }

  /// Replaces the active lower bound for this element and reason.
  ///
  /// Auto-overflow uses this operation so rebuilding a queue cannot stack a
  /// fresh delay. Other active reasons are deliberately preserved.
  ScheduleAdjustmentMutation upsertLowerBound(ScheduleAdjustment adjustment) {
    _requireMode(adjustment, ScheduleAdjustmentMode.lowerBound);
    final ScheduleAdjustment? prior = _matchingOperation(adjustment);
    if (prior != null) return _idempotentResult(adjustment, prior);
    _checkIdAvailable(adjustment);

    final List<ScheduleAdjustment> next = <ScheduleAdjustment>[
      for (final ScheduleAdjustment current in adjustments)
        if (current.isActive &&
            current.element == adjustment.element &&
            current.mode == ScheduleAdjustmentMode.lowerBound &&
            current.reason == adjustment.reason)
          current.clear(
            atUtc: adjustment.createdAtUtc,
            operationId: adjustment.operationId,
          )
        else
          current,
      adjustment,
    ];
    return _transition(next, <ElementRef>{adjustment.element});
  }

  /// Creates or replaces the sole active exact override for an element.
  ScheduleAdjustmentMutation setExactOverride(ScheduleAdjustment adjustment) {
    _requireMode(adjustment, ScheduleAdjustmentMode.exactOverride);
    final ScheduleAdjustment? prior = _matchingOperation(adjustment);
    if (prior != null) return _idempotentResult(adjustment, prior);
    _checkIdAvailable(adjustment);

    final List<ScheduleAdjustment> next = <ScheduleAdjustment>[
      for (final ScheduleAdjustment current in adjustments)
        if (current.isActive &&
            current.element == adjustment.element &&
            current.mode == ScheduleAdjustmentMode.exactOverride)
          current.clear(
            atUtc: adjustment.createdAtUtc,
            operationId: adjustment.operationId,
          )
        else
          current,
      adjustment,
    ];
    return _transition(next, <ElementRef>{adjustment.element});
  }

  /// Clears the named rows and leaves every other reason untouched.
  ScheduleAdjustmentMutation clearByIds({
    required Iterable<String> adjustmentIds,
    required DateTime atUtc,
    required String operationId,
  }) {
    _requireUtc(atUtc, 'atUtc');
    _requireText(operationId, 'operationId');
    final Set<String> ids = adjustmentIds.toSet();
    final Set<ElementRef> scope = <ElementRef>{};
    final List<ScheduleAdjustment> next = <ScheduleAdjustment>[
      for (final ScheduleAdjustment current in adjustments)
        if (current.isActive && ids.contains(current.id))
          (() {
            scope.add(current.element);
            return current.clear(atUtc: atUtc, operationId: operationId);
          })()
        else
          current,
    ];
    return _transition(next, scope);
  }

  /// Clears one reason for one element, preserving all coexisting reasons.
  ScheduleAdjustmentMutation clearReasonForElement({
    required ElementRef element,
    required ScheduleAdjustmentReason reason,
    required DateTime atUtc,
    required String operationId,
  }) {
    final List<String> ids = <String>[
      for (final ScheduleAdjustment current in adjustments)
        if (current.isActive &&
            current.element == element &&
            current.reason == reason)
          current.id,
    ];
    return clearByIds(
      adjustmentIds: ids,
      atUtc: atUtc,
      operationId: operationId,
    );
  }

  /// Study More helper: clears only applicable automatic overflow bounds.
  ScheduleAdjustmentMutation clearAutoOverflowFor({
    required Iterable<ElementRef> elements,
    required DateTime atUtc,
    required String operationId,
  }) {
    final Set<ElementRef> selected = elements.toSet();
    final List<String> ids = <String>[
      for (final ScheduleAdjustment current in adjustments)
        if (current.isActive &&
            selected.contains(current.element) &&
            current.reason == ScheduleAdjustmentReason.autoOverflow)
          current.id,
    ];
    return clearByIds(
      adjustmentIds: ids,
      atUtc: atUtc,
      operationId: operationId,
    );
  }

  /// Applies one Mercy batch and captures the exact prior active sets.
  ///
  /// Conflicting automatic overflow and an earlier exact override are
  /// cleared. Manual Later survives unless the confirmed operation explicitly
  /// opts out. Sibling burying and every unrelated element always survive.
  ScheduleAdjustmentMutation applyMercy(
    Iterable<ScheduleAdjustment> mercyOverrides, {
    bool overrideManualLater = false,
  }) {
    final List<ScheduleAdjustment> incoming = mercyOverrides.toList()
      ..sort(_compareAdjustments);
    if (incoming.isEmpty) {
      return _transition(adjustments, const <ElementRef>{});
    }

    final Set<String> batches = <String>{};
    final Set<ElementRef> scope = <ElementRef>{};
    for (final ScheduleAdjustment adjustment in incoming) {
      _requireMode(adjustment, ScheduleAdjustmentMode.exactOverride);
      if (adjustment.reason != ScheduleAdjustmentReason.mercy) {
        throw ArgumentError('a Mercy batch may contain only mercy overrides');
      }
      final String? batchId = adjustment.batchId;
      if (batchId == null) {
        throw ArgumentError('a Mercy override requires a batchId');
      }
      batches.add(batchId);
      if (!scope.add(adjustment.element)) {
        throw ArgumentError(
          'a Mercy batch has two overrides for ${adjustment.element}',
        );
      }
    }
    if (batches.length != 1) {
      throw ArgumentError('all Mercy overrides must share one batchId');
    }

    var next = adjustments.toList();
    for (final ScheduleAdjustment adjustment in incoming) {
      final ScheduleAdjustment? prior = _matchingOperationIn(next, adjustment);
      if (prior != null) {
        _ensureIdempotentValue(adjustment, prior);
        continue;
      }
      _checkIdAvailableIn(next, adjustment);
      next = <ScheduleAdjustment>[
        for (final ScheduleAdjustment current in next)
          if (current.isActive &&
              current.element == adjustment.element &&
              (current.mode == ScheduleAdjustmentMode.exactOverride ||
                  current.reason == ScheduleAdjustmentReason.autoOverflow ||
                  (overrideManualLater &&
                      current.reason == ScheduleAdjustmentReason.manualLater)))
            current.clear(
              atUtc: adjustment.createdAtUtc,
              operationId: adjustment.operationId,
            )
          else
            current,
        adjustment,
      ];
    }
    return _transition(next, scope);
  }

  /// Replaces the active set for an explicit scope while retaining every
  /// prior row as cleared history. Undo uses this with semantic clones of the
  /// target snapshot; no original adjustment row is deleted or reactivated.
  ScheduleAdjustmentMutation replaceActiveForScope({
    required Iterable<ElementRef> elements,
    required Iterable<ScheduleAdjustment> replacements,
    required DateTime atUtc,
    required String operationId,
  }) {
    _requireUtc(atUtc, 'atUtc');
    _requireText(operationId, 'operationId');
    final Set<ElementRef> scope = elements.toSet();
    final List<ScheduleAdjustment> incoming = replacements.toList()
      ..sort(_compareAdjustments);
    for (final ScheduleAdjustment adjustment in incoming) {
      if (!adjustment.isActive || !scope.contains(adjustment.element)) {
        throw ArgumentError('replacement adjustment is outside active scope');
      }
      _checkIdAvailable(adjustment);
    }
    return _transition(<ScheduleAdjustment>[
      for (final ScheduleAdjustment current in adjustments)
        if (current.isActive && scope.contains(current.element))
          current.clear(atUtc: atUtc, operationId: operationId)
        else
          current,
      ...incoming,
    ], scope);
  }

  ScheduleAdjustmentMutation _add(ScheduleAdjustment adjustment) {
    if (!adjustment.isActive) {
      throw ArgumentError('a newly applied adjustment must be active');
    }
    final ScheduleAdjustment? prior = _matchingOperation(adjustment);
    if (prior != null) return _idempotentResult(adjustment, prior);
    _checkIdAvailable(adjustment);
    return _transition(
      <ScheduleAdjustment>[...adjustments, adjustment],
      <ElementRef>{adjustment.element},
    );
  }

  ScheduleAdjustment? _matchingOperation(ScheduleAdjustment incoming) =>
      _matchingOperationIn(adjustments, incoming);

  ScheduleAdjustmentMutation _idempotentResult(
    ScheduleAdjustment incoming,
    ScheduleAdjustment prior,
  ) {
    _ensureIdempotentValue(incoming, prior);
    return _transition(adjustments, <ElementRef>{incoming.element});
  }

  void _checkIdAvailable(ScheduleAdjustment incoming) =>
      _checkIdAvailableIn(adjustments, incoming);

  ScheduleAdjustmentMutation _transition(
    Iterable<ScheduleAdjustment> next,
    Iterable<ElementRef> scope,
  ) {
    final ScheduleAdjustmentSet after = ScheduleAdjustmentSet(next);
    return ScheduleAdjustmentMutation._(
      before: this,
      after: after,
      beforeSnapshot: snapshotFor(scope),
      afterSnapshot: after.snapshotFor(scope),
    );
  }

  /// Captures active adjustment values for exactly [elements].
  ///
  /// Persist this snapshot with a Mercy batch event. It includes every reason,
  /// allowing undo to restore the complete prior active set rather than trying
  /// to infer which bounds existed.
  ScheduleAdjustmentSnapshot snapshotFor(Iterable<ElementRef> elements) {
    final Set<ElementRef> scope = elements.toSet();
    return ScheduleAdjustmentSnapshot(
      elements: scope,
      activeAdjustments: adjustments.where(
        (ScheduleAdjustment value) =>
            value.isActive && scope.contains(value.element),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! ScheduleAdjustmentSet ||
        adjustments.length != other.adjustments.length) {
      return false;
    }
    for (var index = 0; index < adjustments.length; index++) {
      if (adjustments[index] != other.adjustments[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(adjustments);
}

/// Active adjustment state for a bounded set of elements.
@immutable
final class ScheduleAdjustmentSnapshot {
  factory ScheduleAdjustmentSnapshot({
    required Iterable<ElementRef> elements,
    required Iterable<ScheduleAdjustment> activeAdjustments,
  }) {
    final List<ElementRef> orderedElements = elements.toList()
      ..sort(_compareElements);
    final Set<ElementRef> scope = orderedElements.toSet();
    final List<ScheduleAdjustment> ordered = activeAdjustments.toList()
      ..sort(_compareAdjustments);
    for (final ScheduleAdjustment adjustment in ordered) {
      if (!adjustment.isActive) {
        throw ArgumentError('a snapshot contains active adjustments only');
      }
      if (!scope.contains(adjustment.element)) {
        throw ArgumentError('a snapshot adjustment is outside its scope');
      }
    }
    return ScheduleAdjustmentSnapshot._(
      List<ElementRef>.unmodifiable(orderedElements),
      List<ScheduleAdjustment>.unmodifiable(ordered),
    );
  }

  const ScheduleAdjustmentSnapshot._(this.elements, this.activeAdjustments);

  final List<ElementRef> elements;
  final List<ScheduleAdjustment> activeAdjustments;

  List<ScheduleAdjustment> forElement(ElementRef element) =>
      List<ScheduleAdjustment>.unmodifiable(
        activeAdjustments.where(
          (ScheduleAdjustment value) => value.element == element,
        ),
      );
}

/// Pure adjustment-set transition with exact event snapshots.
@immutable
final class ScheduleAdjustmentMutation {
  const ScheduleAdjustmentMutation._({
    required this.before,
    required this.after,
    required this.beforeSnapshot,
    required this.afterSnapshot,
  });

  final ScheduleAdjustmentSet before;
  final ScheduleAdjustmentSet after;
  final ScheduleAdjustmentSnapshot beforeSnapshot;
  final ScheduleAdjustmentSnapshot afterSnapshot;

  bool get changed => before != after;
}

/// Computes effective due without mutating canonical scheduler state.
@immutable
final class EffectiveDueService {
  const EffectiveDueService();

  DateTime cardDueAtUtc({
    required ElementRef card,
    required DateTime algorithmicDueAtUtc,
    required ScheduleAdjustmentSet adjustments,
  }) {
    if (card.type != ElementType.card) {
      throw ArgumentError('cardDueAtUtc requires a card element');
    }
    _requireUtc(algorithmicDueAtUtc, 'algorithmicDueAtUtc');
    final List<ScheduleAdjustment> active = adjustments.activeFor(card);
    DateTime candidate = algorithmicDueAtUtc;
    final List<ScheduleAdjustment> exact = active
        .where(
          (ScheduleAdjustment value) =>
              value.mode == ScheduleAdjustmentMode.exactOverride,
        )
        .toList();
    if (exact.length > 1) {
      throw StateError('a card has more than one active exact override');
    }
    if (exact.isNotEmpty) candidate = exact.single.scheduledForAtUtc!;
    for (final ScheduleAdjustment adjustment in active) {
      final DateTime? lower = adjustment.notBeforeAtUtc;
      if (lower != null && lower.isAfter(candidate)) candidate = lower;
    }
    return candidate;
  }

  StudyDay topicDueStudyDay({
    required ElementRef topic,
    required StudyDay algorithmicDueStudyDay,
    required ScheduleAdjustmentSet adjustments,
  }) {
    if (!topic.type.isTopic) {
      throw ArgumentError('topicDueStudyDay requires a topic element');
    }
    final List<ScheduleAdjustment> active = adjustments.activeFor(topic);
    for (final ScheduleAdjustment adjustment in active) {
      final StudyDay destination =
          adjustment.notBeforeStudyDay ?? adjustment.scheduledForStudyDay!;
      if (destination.zoneId != algorithmicDueStudyDay.zoneId) {
        throw StateError('topic due values use different StudyDay zones');
      }
    }

    StudyDay candidate = algorithmicDueStudyDay;
    final List<ScheduleAdjustment> exact = active
        .where(
          (ScheduleAdjustment value) =>
              value.mode == ScheduleAdjustmentMode.exactOverride,
        )
        .toList();
    if (exact.length > 1) {
      throw StateError('a topic has more than one active exact override');
    }
    if (exact.isNotEmpty) candidate = exact.single.scheduledForStudyDay!;
    for (final ScheduleAdjustment adjustment in active) {
      final StudyDay? lower = adjustment.notBeforeStudyDay;
      if (lower != null && lower > candidate) candidate = lower;
    }
    return candidate;
  }

  /// Due comparison for a card after lifecycle, scope, and plan checks.
  bool isCardDue({
    required ElementRef card,
    required DateTime algorithmicDueAtUtc,
    required DateTime nowUtc,
    required ScheduleAdjustmentSet adjustments,
  }) {
    _requireUtc(nowUtc, 'nowUtc');
    return !cardDueAtUtc(
      card: card,
      algorithmicDueAtUtc: algorithmicDueAtUtc,
      adjustments: adjustments,
    ).isAfter(nowUtc);
  }

  /// Due comparison for a topic after lifecycle, scope, and plan checks.
  bool isTopicDue({
    required ElementRef topic,
    required StudyDay algorithmicDueStudyDay,
    required StudyDay today,
    required ScheduleAdjustmentSet adjustments,
  }) {
    if (today.zoneId != algorithmicDueStudyDay.zoneId) {
      throw ArgumentError('today and algorithmic due use different zones');
    }
    return topicDueStudyDay(
          topic: topic,
          algorithmicDueStudyDay: algorithmicDueStudyDay,
          adjustments: adjustments,
        ) <=
        today;
  }
}

void _requireMode(
  ScheduleAdjustment adjustment,
  ScheduleAdjustmentMode expected,
) {
  if (!adjustment.isActive) {
    throw ArgumentError('a newly applied adjustment must be active');
  }
  if (adjustment.mode != expected) {
    throw ArgumentError(
      'expected ${expected.wireName}, got ${adjustment.mode.wireName}',
    );
  }
}

ScheduleAdjustment? _matchingOperationIn(
  Iterable<ScheduleAdjustment> existing,
  ScheduleAdjustment incoming,
) {
  for (final ScheduleAdjustment adjustment in existing) {
    if (adjustment.element == incoming.element &&
        adjustment.mode == incoming.mode &&
        adjustment.reason == incoming.reason &&
        adjustment.operationId == incoming.operationId) {
      return adjustment;
    }
  }
  return null;
}

void _ensureIdempotentValue(
  ScheduleAdjustment incoming,
  ScheduleAdjustment existing,
) {
  if (!existing.hasSameOperationValue(incoming)) {
    throw StateError(
      'operation ${incoming.operationId} was reused with different values',
    );
  }
}

void _checkIdAvailableIn(
  Iterable<ScheduleAdjustment> existing,
  ScheduleAdjustment incoming,
) {
  for (final ScheduleAdjustment adjustment in existing) {
    if (adjustment.id == incoming.id) {
      if (adjustment.hasSameOperationValue(incoming)) return;
      throw StateError('adjustment id ${incoming.id} is already in use');
    }
  }
}

int _compareElements(ElementRef left, ElementRef right) {
  final int id = left.id.compareTo(right.id);
  return id != 0 ? id : left.type.index.compareTo(right.type.index);
}

int _compareAdjustments(ScheduleAdjustment left, ScheduleAdjustment right) {
  var comparison = _compareElements(left.element, right.element);
  if (comparison != 0) return comparison;
  comparison = left.createdAtUtc.compareTo(right.createdAtUtc);
  if (comparison != 0) return comparison;
  return left.id.compareTo(right.id);
}

void _requireUtc(DateTime instant, String name) {
  if (!instant.isUtc) {
    throw ArgumentError.value(instant, name, 'must be UTC');
  }
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
