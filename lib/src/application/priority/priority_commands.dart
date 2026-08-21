/// Commands that change relative priority.
///
/// Priority is attention allocation, not urgency: it decides ordering and
/// admission among elements that are *already* eligible. None of these
/// commands may move a due date, change an interval, or pull not-yet-due
/// material forward — if one did, priority would stop being a separate axis
/// and the queue would have no way to tell "important" from "late".
library;

import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../app_command.dart';

/// Place an element at an exact order key.
///
/// The low-level primitive the other commands resolve to. Direct callers are
/// rare — the UI works in percent and in neighbours, because a raw key means
/// nothing to a human — but tests and migrations need a way to say exactly
/// where something goes.
final class SetPriority extends AppCommand {
  SetPriority(
    super.operationId, {
    required this.ref,
    required this.rank,
    super.timestampUtc,
  });

  final ElementRef ref;
  final PriorityRank rank;
}

/// Place an element at a percent of the collection, `0` being the highest.
///
/// The UI works in percent exclusively. An absolute 0–100 score inflates
/// until it carries no information; a percent is a claim about *this* element
/// against everything else, so promoting one necessarily demotes another.
final class SetPriorityPercent extends AppCommand {
  SetPriorityPercent(
    super.operationId, {
    required this.ref,
    required this.percent,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// `0` is the most important, `100` the least.
  final double percent;
}

/// Move an element to sit between two others, as a drag in the browser does.
final class ReorderPriority extends AppCommand {
  ReorderPriority(
    super.operationId, {
    required this.ref,
    this.after,
    this.before,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// The element it should follow, or null to place it at the top.
  final PriorityRank? after;

  /// The element it should precede, or null to place it at the bottom.
  final PriorityRank? before;
}

/// Nudge an element one place up or down the queue.
///
/// SuperMemo's Shift+Ctrl+Up / Down. Cheap to reach for, which is the point:
/// prioritizing well is a habit built by many small honest adjustments.
final class StepPriority extends AppCommand {
  StepPriority(
    super.operationId, {
    required this.ref,
    required this.increase,
    this.places = 1,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// Whether the element becomes more important.
  final bool increase;

  /// How many neighbours to jump over.
  final int places;
}

/// Spread a percent range across a set of elements, in their current order.
///
/// The bulk-reprioritization operation. It exists because inheritance is
/// exact: an article given a high priority hands that priority to every
/// extract and card it produces, which is right at creation time and wrong
/// once reading is finished. Spreading afterwards is how the few genuinely
/// important children keep the rank and the rest fall to where they belong.
final class SpreadPriority extends AppCommand {
  SpreadPriority(
    super.operationId, {
    required this.refs,
    required this.fromPercent,
    required this.toPercent,
    super.timestampUtc,
  });

  /// The elements to spread, in the order they should end up.
  final List<ElementRef> refs;

  /// Most important end of the range.
  final double fromPercent;

  /// Least important end of the range.
  final double toPercent;
}
