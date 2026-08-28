/// The common scheduling shape shared by sources, extracts, and cards.
///
/// The queue and the schedulers treat every element uniformly: type, priority,
/// due-ness, and lifecycle. Type-specific state lives elsewhere — reading
/// position on a source, provenance on an extract, memory state on a card —
/// precisely so that adding a new element type does not change the queue.
library;

import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:meta/meta.dart';

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

/// Where an element stands in its lifecycle.
enum ElementLifecycle {
  /// Scheduled and eligible to appear in the queue.
  active,

  /// Content and provenance retained, scheduling removed for good.
  dismissed,

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
/// [dueDay] is what the element's own scheduler decided, and it is the only
/// due date there is: SM20 has no deferral overlay, so a postponement is a
/// low-level reschedule that rewrites this value rather than shadowing it.
/// [originalDueDay] is kept beside it so lateness stays measurable.
@immutable
final class ElementSchedule {
  const ElementSchedule({
    required this.ref,
    required this.priority,
    required this.lifecycle,
    required this.dueDay,
    required this.originalDueDay,
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
  /// CardMemory; this day is the day-granular projection of it.
  StudyDay get algorithmicDueDay => dueDay;

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
    String? rootId,
    String? parentElementId,
    int? ordinal,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    int? revision,
    LegacyDueProvenance? legacyDueProvenance,
  }) => ElementSchedule(
    ref: ref,
    priority: priority ?? this.priority,
    lifecycle: lifecycle ?? this.lifecycle,
    dueDay: dueDay ?? this.dueDay,
    originalDueDay: originalDueDay ?? this.originalDueDay,
    rootId: rootId ?? this.rootId,
    parentElementId: parentElementId ?? this.parentElementId,
    ordinal: ordinal ?? this.ordinal,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    revision: revision ?? this.revision,
    legacyDueProvenance: legacyDueProvenance ?? this.legacyDueProvenance,
  );

  @override
  String toString() =>
      'ElementSchedule($ref ${lifecycle.name} due=$dueDay '
      'priority=${priority.orderKey})';
}
