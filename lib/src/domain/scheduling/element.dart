/// The common scheduling shape shared by sources, extracts, and cards.
///
/// The queue and the schedulers treat every element uniformly: type, priority,
/// due-ness, and lifecycle. Type-specific state lives elsewhere — reading
/// position on a source, provenance on an extract, memory state on a card —
/// precisely so that adding a new element type does not change the queue.
library;

import 'package:meta/meta.dart';

import 'priority_rank.dart';
import 'study_day.dart';

/// What kind of learning element this is.
///
/// Sources and extracts are *topics*: the user processes them. Cards are
/// *items*: the user is tested on them. That distinction, not the storage
/// table, is what decides which scheduler applies.
enum ElementType {
  /// An imported document the user reads incrementally.
  source,

  /// A passage promoted out of a source or another extract.
  extract,

  /// A question formulated from an extract.
  card;

  /// Whether this element is processed rather than recalled.
  bool get isTopic => this != ElementType.card;
}

/// Why an element was pushed past its due day.
///
/// The distinction matters at recall time: raising a daily limit or choosing
/// Study More takes back the day's *automatic* deferrals, because those were
/// the app's overload decision, not the user's. A manual Later means "wrong
/// task right now" and is never undone behind the user's back.
enum DeferralKind {
  /// Not deferred.
  none,

  /// The user chose Later.
  manual,

  /// Auto-postponed because the day was over its limit.
  automatic,
}

/// Where an element stands in its lifecycle.
enum ElementLifecycle {
  /// Scheduled and eligible to appear in the queue.
  active,

  /// Temporarily removed. Resuming makes it due today without resetting the
  /// interval step.
  suspended,

  /// Content and provenance retained, scheduling removed for good.
  dismissed,

  /// A source the user explicitly declared finished. Descendants are
  /// unaffected.
  finished,

  /// Soft-deleted, retained only for restore.
  deleted;

  /// Whether the queue may consider this element at all.
  bool get isSchedulable => this == ElementLifecycle.active;
}

/// Provenance of a legacy visible due value when the original canonical due
/// could not be reconstructed safely during migration.
enum LegacyDueProvenance { canonical, legacyDueUnknown }

/// Identity of one element, independent of which table stores it.
@immutable
final class ElementRef implements Comparable<ElementRef> {
  const ElementRef({required this.id, required this.type});

  final String id;
  final ElementType type;

  @override
  int compareTo(ElementRef other) {
    final int byId = id.compareTo(other.id);
    return byId != 0 ? byId : type.index.compareTo(other.type.index);
  }

  @override
  bool operator ==(Object other) =>
      other is ElementRef && other.id == id && other.type == type;

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() => '${type.name}:$id';
}

/// The scheduling facts every element carries.
///
/// [dueDay] is what the element's own scheduler decided. [deferredUntil] is
/// separate and holds auto-postponement: overload must never be recorded as if
/// the algorithm had chosen a later date, or overdue ranking and audit both
/// become lies.
@immutable
final class ElementSchedule {
  const ElementSchedule({
    required this.ref,
    required this.priority,
    required this.lifecycle,
    required this.dueDay,
    required this.originalDueDay,
    this.deferredUntil,
    this.deferralKind = DeferralKind.none,
    this.rootId,
    this.parentElementId,
    this.ordinal,
    this.createdAtUtc,
    this.updatedAtUtc,
    this.revision = 1,
    this.legacyDueProvenance = LegacyDueProvenance.canonical,
  });

  final ElementRef ref;
  final PriorityRank priority;
  final ElementLifecycle lifecycle;

  /// Day the element's scheduler made it eligible.
  final StudyDay dueDay;

  /// Day the scheduler originally chose, preserved across postponement so
  /// overdue ranking still reflects real lateness.
  final StudyDay originalDueDay;

  /// Day the element was pushed to by postponement, if any.
  final StudyDay? deferredUntil;

  /// Whether the deferral came from the user or from overload handling.
  final DeferralKind deferralKind;

  /// The source at the root of this element's provenance, denormalized.
  ///
  /// The queue needs it on every element to stop one article's subtree from
  /// taking over a session, and walking the parent chain on every build would
  /// be a needless join. It is also what lets a card keep its citation if its
  /// source is ever removed.
  final String? rootId;

  /// Immediate learning-element parent. This is the sole canonical parent
  /// coordinate; [rootId] is denormalized provenance, not another parent.
  final String? parentElementId;

  /// User-visible pending-order metadata. It is never identity, priority, or
  /// a due-date tie breaker.
  final int? ordinal;

  /// Audit instants. They may be absent only on rows migrated from schemas
  /// that never recorded them.
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  /// Optimistic-concurrency revision of the common element row.
  final int revision;

  final LegacyDueProvenance legacyDueProvenance;

  /// Canonical topic date. For cards, the exact canonical due lives only in
  /// CardMemory; this day is a legacy projection retained for migration/UI
  /// compatibility.
  StudyDay get algorithmicDueDay => dueDay;

  // There is deliberately no `effectiveDueDay` here. Presentation eligibility
  // is the canonical due plus the typed adjustments that currently apply, and
  // those live in their own table: a getter on this row could only ever see
  // the retired v4 deferral columns and would quietly report a Later, a bury,
  // or a Mercy override as if it had never happened. Ask `EffectiveDueQuery`
  // (screens) or `EffectiveDueService` (domain) instead.

  /// How many days late the element is on [today], per its original due day.
  int overdueDaysOn(StudyDay today) {
    final days = originalDueDay.daysUntil(today);
    return days < 0 ? 0 : days;
  }

  ElementSchedule copyWith({
    PriorityRank? priority,
    ElementLifecycle? lifecycle,
    StudyDay? dueDay,
    StudyDay? originalDueDay,
    StudyDay? deferredUntil,
    DeferralKind? deferralKind,
    String? rootId,
    String? parentElementId,
    int? ordinal,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    int? revision,
    LegacyDueProvenance? legacyDueProvenance,
    bool clearDeferral = false,
  }) => ElementSchedule(
    ref: ref,
    priority: priority ?? this.priority,
    lifecycle: lifecycle ?? this.lifecycle,
    dueDay: dueDay ?? this.dueDay,
    originalDueDay: originalDueDay ?? this.originalDueDay,
    deferredUntil: clearDeferral ? null : (deferredUntil ?? this.deferredUntil),
    deferralKind: clearDeferral
        ? DeferralKind.none
        : (deferralKind ?? this.deferralKind),
    rootId: rootId ?? this.rootId,
    parentElementId: parentElementId ?? this.parentElementId,
    ordinal: ordinal ?? this.ordinal,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    revision: revision ?? this.revision,
    legacyDueProvenance: legacyDueProvenance ?? this.legacyDueProvenance,
  );

  /// The same schedule with any automatic deferral taken back.
  ///
  /// Manual postponements survive: the user said "not now", and raising a
  /// limit is not them changing their mind.
  ElementSchedule withAutomaticDeferralRecalled() =>
      deferralKind == DeferralKind.automatic
      ? copyWith(clearDeferral: true)
      : this;

  @override
  String toString() =>
      'ElementSchedule($ref ${lifecycle.name} due=$dueDay '
      'priority=${priority.orderKey})';
}
