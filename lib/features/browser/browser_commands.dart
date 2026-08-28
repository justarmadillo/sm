/// What the Browser can change about where an element is kept.
///
/// Filing only. None of these commands touches a due date, an interval, a
/// priority, or an extract's provenance: moving a row in the Browser is
/// housekeeping, and housekeeping must never look like a repetition.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/command_base.dart';

/// Base for every command that files one element somewhere else.
abstract base class BrowserFilingCommand extends AppCommand {
  BrowserFilingCommand(
    super.operationId, {
    required this.ref,
    super.timestampUtc,
  });

  /// The element being moved.
  final ElementRef ref;
}

/// Swaps an element with the sibling above it.
final class MoveElementUp extends BrowserFilingCommand {
  MoveElementUp(super.operationId, {required super.ref, super.timestampUtc});
}

/// Swaps an element with the sibling below it.
final class MoveElementDown extends BrowserFilingCommand {
  MoveElementDown(super.operationId, {required super.ref, super.timestampUtc});
}

/// Files an element under the sibling directly above it, at the end of that
/// sibling's own children.
///
/// The sibling above is the only target that needs no drag: it is the row the
/// user is already looking at, one line up.
final class NestElementUnderPreviousSibling extends BrowserFilingCommand {
  NestElementUnderPreviousSibling(
    super.operationId, {
    required super.ref,
    super.timestampUtc,
  });
}

/// Files an element beside its current parent, directly after it.
///
/// The reverse of [NestElementUnderPreviousSibling], and the only way back out
/// of a branch for an element that has no siblings to move against.
final class LiftElementOutOfParent extends BrowserFilingCommand {
  LiftElementOutOfParent(
    super.operationId, {
    required super.ref,
    super.timestampUtc,
  });
}

/// Files an element under [parentRef], or at the top of the tree when that is
/// null, in front of [beforeRef] when one is named.
///
/// This is what a drag reports: a new parent and the row it was dropped above.
final class FileElementUnder extends BrowserFilingCommand {
  FileElementUnder(
    super.operationId, {
    required super.ref,
    required this.parentRef,
    this.beforeRef,
    super.timestampUtc,
  });

  /// Where the element is going. Null files it at the top of the tree.
  final ElementRef? parentRef;

  /// The sibling the element is dropped in front of. Null appends it last.
  final ElementRef? beforeRef;
}

/// What one filing command did.
final class BrowserFilingOutcome {
  const BrowserFilingOutcome({required this.movedRef, required this.rewritten});

  /// The element that moved.
  final ElementRef movedRef;

  /// How many schedule rows had their filing rewritten, the moved element
  /// included. Siblings are renumbered as a block, so this is normally more
  /// than one.
  final int rewritten;
}
