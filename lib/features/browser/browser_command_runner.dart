/// Carries out the Browser's filing commands, one transaction each.
///
/// Every command here rewrites two things and nothing else: which element a
/// row is filed under, and the order of the rows it now sits among. Due days,
/// intervals, priorities, A-factors and extract provenance are all read-only
/// from in here — reorganising a collection is not a repetition, and an
/// extract that moves keeps pointing at the passage it was cut from.
///
/// Siblings are renumbered as a block rather than nudged one at a time. A
/// collection built before filing existed has no ordinals at all, so there is
/// nothing to nudge, and handing the whole level fresh consecutive numbers is
/// both simpler to read and impossible to leave with two rows claiming the
/// same place.
library;

import 'package:incremental_reader/features/browser/browser_commands.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kBrowserMovedUpKind = 'browser.moved_up';
const String kBrowserMovedDownKind = 'browser.moved_down';
const String kBrowserNestedKind = 'browser.nested';
const String kBrowserLiftedKind = 'browser.lifted';
const String kBrowserFiledKind = 'browser.filed';

/// The Browser's move commands.
final class BrowserCommandRunner {
  BrowserCommandRunner({
    required BrowserTreeQuery tree,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _tree = tree,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _diagnostics = diagnostics;

  final BrowserTreeQuery _tree;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final DiagnosticSink _diagnostics;

  /// Swaps an element with the sibling above it.
  Future<Result<BrowserFilingOutcome>> moveUp(MoveElementUp command) =>
      _run(command, kBrowserMovedUpKind, (_TreeIndex index) {
        final _Level level = index.levelOf(command.ref);
        final int position = level.positionOf(command.ref);
        if (position <= 0) {
          return const Err<_Placement>(
            ValidationFailure('already first in its list'),
          );
        }
        return Ok<_Placement>(
          _Placement(
            parentRef: level.parentRef,
            siblingsInOrder: _swapped(level.refs, position, position - 1),
          ),
        );
      });

  /// Swaps an element with the sibling below it.
  Future<Result<BrowserFilingOutcome>> moveDown(MoveElementDown command) =>
      _run(command, kBrowserMovedDownKind, (_TreeIndex index) {
        final _Level level = index.levelOf(command.ref);
        final int position = level.positionOf(command.ref);
        if (position >= level.refs.length - 1) {
          return const Err<_Placement>(
            ValidationFailure('already last in its list'),
          );
        }
        return Ok<_Placement>(
          _Placement(
            parentRef: level.parentRef,
            siblingsInOrder: _swapped(level.refs, position, position + 1),
          ),
        );
      });

  /// Files an element under the sibling above it, last among its children.
  Future<Result<BrowserFilingOutcome>> nestUnderPreviousSibling(
    NestElementUnderPreviousSibling command,
  ) => _run(command, kBrowserNestedKind, (_TreeIndex index) {
    final _Level level = index.levelOf(command.ref);
    final int position = level.positionOf(command.ref);
    if (position <= 0) {
      return const Err<_Placement>(
        ValidationFailure('nothing above it to nest under'),
      );
    }
    final ElementRef newParent = level.refs[position - 1];
    return Ok<_Placement>(
      _Placement(
        parentRef: newParent,
        siblingsInOrder: <ElementRef>[
          ...index.childrenOf(newParent),
          command.ref,
        ],
        vacatedParentRef: level.parentRef,
        vacatedSiblingsInOrder: <ElementRef>[
          for (final ElementRef sibling in level.refs)
            if (sibling != command.ref) sibling,
        ],
      ),
    );
  });

  /// Files an element beside its parent, directly after it.
  Future<Result<BrowserFilingOutcome>> liftOutOfParent(
    LiftElementOutOfParent command,
  ) => _run(command, kBrowserLiftedKind, (_TreeIndex index) {
    final _Level level = index.levelOf(command.ref);
    final ElementRef? oldParent = level.parentRef;
    if (oldParent == null) {
      return const Err<_Placement>(
        ValidationFailure('already at the top of the tree'),
      );
    }
    final _Level parentLevel = index.levelOf(oldParent);
    final List<ElementRef> siblings = <ElementRef>[...parentLevel.refs]
      ..insert(parentLevel.positionOf(oldParent) + 1, command.ref);
    return Ok<_Placement>(
      _Placement(
        parentRef: parentLevel.parentRef,
        siblingsInOrder: siblings,
        vacatedParentRef: oldParent,
        vacatedSiblingsInOrder: <ElementRef>[
          for (final ElementRef sibling in level.refs)
            if (sibling != command.ref) sibling,
        ],
      ),
    );
  });

  /// Files an element under a named parent, in front of a named sibling.
  Future<Result<BrowserFilingOutcome>> fileUnder(FileElementUnder command) =>
      _run(command, kBrowserFiledKind, (_TreeIndex index) {
        final ElementRef? newParent = command.parentRef;
        if (newParent == command.ref) {
          return const Err<_Placement>(
            ValidationFailure('an element cannot be filed under itself'),
          );
        }
        // Filing a branch into its own descendant would cut that branch out of
        // the tree entirely: every row in it would name a parent inside the
        // part that is no longer reachable.
        if (newParent != null && index.isDescendant(newParent, command.ref)) {
          return const Err<_Placement>(
            ValidationFailure('an element cannot be filed under its own child'),
          );
        }

        final _Level level = index.levelOf(command.ref);
        final List<ElementRef> target = <ElementRef>[
          for (final ElementRef sibling in index.childrenOf(newParent))
            if (sibling != command.ref) sibling,
        ];
        final int insertAt = command.beforeRef == null
            ? target.length
            : target.indexOf(command.beforeRef!);
        target.insert(insertAt < 0 ? target.length : insertAt, command.ref);

        return Ok<_Placement>(
          _Placement(
            parentRef: newParent,
            siblingsInOrder: target,
            vacatedParentRef: level.parentRef,
            vacatedSiblingsInOrder: <ElementRef>[
              for (final ElementRef sibling in level.refs)
                if (sibling != command.ref) sibling,
            ],
          ),
        );
      });

  static List<ElementRef> _swapped(
    List<ElementRef> refs,
    int first,
    int second,
  ) {
    final List<ElementRef> moved = <ElementRef>[...refs];
    final ElementRef held = moved[first];
    moved[first] = moved[second];
    moved[second] = held;
    return moved;
  }

  /// Reads the tree, works out the new arrangement, and writes it.
  ///
  /// The tree is loaded inside the transaction, from the same query the screen
  /// draws from, so "the sibling above" means exactly the row the user saw
  /// above rather than whatever a second ordering rule would have produced.
  Future<Result<BrowserFilingOutcome>> _run(
    BrowserFilingCommand command,
    String kind,
    Result<_Placement> Function(_TreeIndex index) plan,
  ) async {
    try {
      return await _transactions.run<Result<BrowserFilingOutcome>>(() async {
        if (await _learning.hasActivity(command.operationId.value, kind)) {
          // A resent move is the same move. Replaying it would walk the
          // element one further step in the same direction.
          return Ok<BrowserFilingOutcome>(
            BrowserFilingOutcome(movedRef: command.ref, rewritten: 0),
          );
        }

        final _TreeIndex index = _TreeIndex.of(await _tree.load());
        if (!index.contains(command.ref)) {
          return Err<BrowserFilingOutcome>(
            NotFoundFailure(
              'that element is no longer in the collection',
              entity: 'element',
              id: command.ref.id,
            ),
          );
        }

        final Result<_Placement> planned = plan(index);
        if (planned.isErr) {
          return Err<BrowserFilingOutcome>(planned.failureOrNull!);
        }
        final _Placement placement = planned.valueOrNull!;

        final List<ElementSchedule> rewritten = <ElementSchedule>[
          ...await _renumber(
            placement.siblingsInOrder,
            under: placement.parentRef,
          ),
          if (placement.vacatedSiblingsInOrder != null)
            ...await _renumber(
              placement.vacatedSiblingsInOrder!,
              under: placement.vacatedParentRef,
            ),
        ];
        await _learning.saveSchedules(rewritten);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kind,
            atUtc: command.timestampUtc,
            ref: command.ref,
            metadata: <String, Object?>{
              'parent': placement.parentRef?.id,
              'rewritten': rewritten.length,
            },
          ),
        );
        if (rewritten.isNotEmpty) await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kind,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: <String, Object?>{
              'element': command.ref.id,
              'rewritten': rewritten.length,
            },
          ),
        );
        return Ok<BrowserFilingOutcome>(
          BrowserFilingOutcome(
            movedRef: command.ref,
            rewritten: rewritten.length,
          ),
        );
      });
    } on Object catch (error, stackTrace) {
      final UnexpectedFailure failure = UnexpectedFailure(
        'command $kind failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kind,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<BrowserFilingOutcome>(failure);
    }
  }

  /// Gives one level consecutive ordinals, and files every row in it under
  /// [under].
  ///
  /// Rows whose filing is already what it should be are left out of the write
  /// entirely, so moving the last of a hundred siblings writes two rows rather
  /// than a hundred.
  Future<List<ElementSchedule>> _renumber(
    List<ElementRef> level, {
    required ElementRef? under,
  }) async {
    final DateTime now = _clock.nowUtc();
    final List<ElementSchedule> changed = <ElementSchedule>[];
    for (var position = 0; position < level.length; position++) {
      final ElementSchedule? stored = await _learning.findSchedule(
        level[position],
      );
      if (stored == null) continue;
      if (stored.ordinal == position && stored.parentElementId == under?.id) {
        continue;
      }
      changed.add(
        _refiled(stored, parentId: under?.id, ordinal: position, nowUtc: now),
      );
    }
    return changed;
  }

  /// A schedule with new filing and nothing else changed.
  ///
  /// Written out in full rather than through `copyWith`, because filing an
  /// element at the top of the tree means writing a null parent, and a
  /// `copyWith` that reads `parent ?? this.parent` can never express that.
  static ElementSchedule _refiled(
    ElementSchedule stored, {
    required String? parentId,
    required int ordinal,
    required DateTime nowUtc,
  }) => ElementSchedule(
    ref: stored.ref,
    priority: stored.priority,
    lifecycle: stored.lifecycle,
    dueDay: stored.dueDay,
    originalDueDay: stored.originalDueDay,
    rootId: stored.rootId,
    parentElementId: parentId,
    ordinal: ordinal,
    createdAtUtc: stored.createdAtUtc,
    updatedAtUtc: nowUtc,
    // The row did change, so its revision advances: a grade holding an older
    // snapshot must be told to re-read rather than quietly writing the old
    // filing back.
    revision: stored.revision + 1,
    legacyDueProvenance: stored.legacyDueProvenance,
  );
}

/// One level of the tree: the rows filed under a parent, in their order.
final class _Level {
  const _Level({required this.parentRef, required this.refs});

  final ElementRef? parentRef;
  final List<ElementRef> refs;

  int positionOf(ElementRef ref) => refs.indexOf(ref);
}

/// Where an element goes, and what the level it left now looks like.
final class _Placement {
  const _Placement({
    required this.parentRef,
    required this.siblingsInOrder,
    this.vacatedParentRef,
    this.vacatedSiblingsInOrder,
  });

  /// The parent the element is filed under after the move.
  final ElementRef? parentRef;

  /// That parent's children afterwards, in order, the moved element included.
  final List<ElementRef> siblingsInOrder;

  /// The parent the element left, when the move crosses levels.
  final ElementRef? vacatedParentRef;

  /// What is left of that level, in order. Null when the element stayed put.
  final List<ElementRef>? vacatedSiblingsInOrder;
}

/// The loaded tree, in the shapes a move needs to ask about.
final class _TreeIndex {
  _TreeIndex._(this._parentOf, this._childrenOf, this._roots);

  factory _TreeIndex.of(List<BrowserTreeNode> roots) {
    final Map<ElementRef, ElementRef?> parentOf = <ElementRef, ElementRef?>{};
    final Map<ElementRef, List<ElementRef>> childrenOf =
        <ElementRef, List<ElementRef>>{};
    void walk(List<BrowserTreeNode> nodes, ElementRef? parent) {
      for (final BrowserTreeNode node in nodes) {
        parentOf[node.ref] = parent;
        childrenOf[node.ref] = <ElementRef>[
          for (final BrowserTreeNode child in node.children) child.ref,
        ];
        walk(node.children, node.ref);
      }
    }

    walk(roots, null);
    return _TreeIndex._(parentOf, childrenOf, <ElementRef>[
      for (final BrowserTreeNode root in roots) root.ref,
    ]);
  }

  final Map<ElementRef, ElementRef?> _parentOf;
  final Map<ElementRef, List<ElementRef>> _childrenOf;
  final List<ElementRef> _roots;

  bool contains(ElementRef ref) => _parentOf.containsKey(ref);

  /// The rows filed under [parent], in their displayed order. A null parent
  /// asks for the top of the tree.
  List<ElementRef> childrenOf(ElementRef? parent) =>
      parent == null ? _roots : (_childrenOf[parent] ?? const <ElementRef>[]);

  /// The level [ref] currently sits in, and what it sits under.
  _Level levelOf(ElementRef ref) {
    final ElementRef? parent = _parentOf[ref];
    return _Level(parentRef: parent, refs: childrenOf(parent));
  }

  /// Whether [candidate] is [ancestor] itself or sits anywhere below it.
  bool isDescendant(ElementRef candidate, ElementRef ancestor) {
    ElementRef? walker = candidate;
    while (walker != null) {
      if (walker == ancestor) return true;
      walker = _parentOf[walker];
    }
    return false;
  }
}
