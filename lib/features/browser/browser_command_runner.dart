/// Carries out the Browser's commands, one transaction each.
///
/// Two unrelated jobs live here, and the difference matters. The filing
/// commands rewrite two things and nothing else: which element a row is filed
/// under, and the order of the rows it now sits among. Due days, intervals,
/// priorities, A-factors and extract provenance are all read-only from in
/// there — reorganising a collection is not a repetition, and an extract that
/// moves keeps pointing at the passage it was cut from.
///
/// Deletion is the exception, and the only command in the app that
/// destroys anything. It is kept in the same runner because the Browser is
/// the one screen that offers it and because it needs the same loaded tree
/// the moves do: what goes is what the user saw filed underneath the row.
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
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kBrowserMovedUpType = 'browser.moved_up';
const String kBrowserMovedDownType = 'browser.moved_down';
const String kBrowserNestedType = 'browser.nested';
const String kBrowserLiftedType = 'browser.lifted';
const String kBrowserFiledType = 'browser.filed';
const String kBrowserDeletedType = 'browser.deleted';

/// The Browser's move and delete commands.
final class BrowserCommandRunner {
  BrowserCommandRunner({
    required BrowserTreeQuery tree,
    required ContentRepository content,
    required LearningRepository learning,
    required SearchRepository search,
    required SchedulingContext context,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _tree = tree,
       _content = content,
       _learning = learning,
       _search = search,
       _context = context,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _diagnostics = diagnostics;

  final BrowserTreeQuery _tree;
  final ContentRepository _content;
  final LearningRepository _learning;
  final SearchRepository _search;
  final SchedulingContext _context;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final DiagnosticSink _diagnostics;

  /// Swaps an element with the sibling above it.
  Future<Result<BrowserFilingOutcome>> moveUp(MoveElementUp command) =>
      _run(command, kBrowserMovedUpType, (_TreeIndex index) {
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
      _run(command, kBrowserMovedDownType, (_TreeIndex index) {
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
  ) => _run(command, kBrowserNestedType, (_TreeIndex index) {
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
  ) => _run(command, kBrowserLiftedType, (_TreeIndex index) {
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
      _run(command, kBrowserFiledType, (_TreeIndex index) {
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

  /// Erases an element and everything below it.
  ///
  /// The append-only logs are left alone, as undoing an extract leaves them:
  /// they record what the scheduler did on a day, not what the collection
  /// holds today. A card's review history is the one exception, and only
  /// because its foreign key leaves no choice.
  Future<Result<BrowserDeletionOutcome>> deleteElement(DeleteElement command) =>
      _deleteElements(
        operationId: command.operationId,
        timestampUtc: command.timestampUtc,
        refs: <ElementRef>[command.ref],
      );

  /// Erases every selected branch in one transaction and one operation.
  Future<Result<BrowserDeletionOutcome>> deleteElements(
    DeleteElements command,
  ) => _deleteElements(
    operationId: command.operationId,
    timestampUtc: command.timestampUtc,
    refs: command.refs,
  );

  Future<Result<BrowserDeletionOutcome>> _deleteElements({
    required OperationId operationId,
    required DateTime timestampUtc,
    required List<ElementRef> refs,
  }) async {
    if (refs.isEmpty) {
      return const Err<BrowserDeletionOutcome>(
        ValidationFailure('select at least one element'),
      );
    }
    try {
      return await _transactions.run<Result<BrowserDeletionOutcome>>(() async {
        if (await _learning.hasActivity(
          operationId.value,
          kBrowserDeletedType,
        )) {
          // A resent delete has already happened. Replaying it would report a
          // second removal of rows that are long gone.
          return const Ok<BrowserDeletionOutcome>(
            BrowserDeletionOutcome(deletedRefs: <ElementRef>[]),
          );
        }

        final _TreeIndex index = _TreeIndex.of(await _tree.load());
        final ElementRef? missing = refs.cast<ElementRef?>().firstWhere(
          (ElementRef? ref) => !index.contains(ref!),
          orElse: () => null,
        );
        if (missing != null) {
          return Err<BrowserDeletionOutcome>(
            NotFoundFailure(
              'that element is no longer in the collection',
              entity: 'element',
              id: missing.id,
            ),
          );
        }

        final Set<ElementRef> doomed = <ElementRef>{};
        for (final ElementRef ref in refs) {
          doomed.addAll(await _everythingUnder(ref, index));
        }
        await _erase(doomed);
        await _forgetInTodaysQueues(doomed);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: operationId.value,
            type: kBrowserDeletedType,
            atUtc: timestampUtc,
            ref: refs.first,
            metadata: <String, Object?>{
              'removed': doomed.length,
              'selected': refs.length,
            },
          ),
        );
        await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kBrowserDeletedType,
            timestampUtc: _clock.nowUtc(),
            operationId: operationId,
            fields: <String, Object?>{
              'element': refs.first.id,
              'selected': refs.length,
              'removed': doomed.length,
            },
          ),
        );
        return Ok<BrowserDeletionOutcome>(
          BrowserDeletionOutcome(deletedRefs: doomed.toList()),
        );
      });
    } on Object catch (error, stackTrace) {
      final UnexpectedFailure failure = UnexpectedFailure(
        'command $kBrowserDeletedType failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kBrowserDeletedType,
          timestampUtc: _clock.nowUtc(),
          operationId: operationId,
          failure: failure,
        ),
      );
      return Err<BrowserDeletionOutcome>(failure);
    }
  }

  /// Removes every row [doomed] owns, in the order the foreign keys allow.
  ///
  /// Cards, then extracts, then sources: the database refuses to drop a source
  /// while an extract still names it, and refuses to drop a card while its
  /// memory or its review history survives. Working outwards like this means
  /// those refusals never fire on a deletion the user asked for, and still
  /// fire on one nobody did.
  Future<void> _erase(Set<ElementRef> doomed) async {
    for (final ElementRef ref in _deletionOrder(doomed)) {
      await _search.deleteDocument(ref);
      await _learning.deleteSchedule(ref);
      switch (ref.type) {
        case ElementType.card:
          await _learning.deleteCardState(ref.id);
          await _learning.deleteReviewsForCard(ref.id);
          await _content.deleteCard(ref.id);
        case ElementType.extract:
          await _content.deleteExtract(ref.id);
        case ElementType.source:
          await _content.deleteSource(ref.id);
      }
    }
  }

  /// Takes the deleted refs out of the day's queues.
  ///
  /// The runtime state is a list of ids, not of rows, so nothing in the
  /// database removes them when the elements go. The daily sort drops
  /// unknown refs on its own, but the stage a user is halfway through does
  /// not run that sort, and would offer an element that no longer exists.
  Future<void> _forgetInTodaysQueues(Set<ElementRef> doomed) async {
    final Sm20CollectionState runtime = await _context.runtimeState();
    List<ElementRef> survivors(List<ElementRef> queue) => <ElementRef>[
      for (final ElementRef ref in queue)
        if (!doomed.contains(ref)) ref,
    ];
    await _context.saveRuntimeState(
      runtime.copyWith(
        outstanding: survivors(runtime.outstanding),
        outstandingItems: survivors(runtime.outstandingItems),
        outstandingTopics: survivors(runtime.outstandingTopics),
        finalDrill: survivors(runtime.finalDrill),
        pending: survivors(runtime.pending),
      ),
    );
  }

  /// Everything that has to go when [top] goes.
  ///
  /// Two different descendants, and both are needed. The tree gives what the
  /// user can see filed underneath the row. Provenance gives what the
  /// database will not let go of: an extract dragged clear across the
  /// collection still names the source it was cut from, and that source
  /// cannot be dropped while it does.
  Future<Set<ElementRef>> _everythingUnder(
    ElementRef top,
    _TreeIndex index,
  ) async {
    final Set<ElementRef> found = <ElementRef>{};
    final List<ElementRef> unexplored = <ElementRef>[...index.subtreeOf(top)];
    while (unexplored.isNotEmpty) {
      final ElementRef ref = unexplored.removeLast();
      if (!found.add(ref)) continue;
      unexplored.addAll(await _childrenByProvenance(ref));
      unexplored.addAll(index.subtreeOf(ref));
    }
    return found;
  }

  /// What was cut or formulated from [ref], whatever it is.
  Future<List<ElementRef>> _childrenByProvenance(ElementRef ref) async {
    switch (ref.type) {
      case ElementType.card:
        return const <ElementRef>[];
      case ElementType.source:
        return <ElementRef>[
          for (final extract in await _content.listExtractsOfSource(ref.id))
            ElementRef(id: extract.id, type: ElementType.extract),
          for (final card in await _content.listCardsOfSource(ref.id))
            ElementRef(id: card.id, type: ElementType.card),
        ];
      case ElementType.extract:
        return <ElementRef>[
          for (final extract in await _content.listExtractsOfParent(ref.id))
            ElementRef(id: extract.id, type: ElementType.extract),
          for (final card in await _content.listCardsOfExtract(ref.id))
            ElementRef(id: card.id, type: ElementType.card),
        ];
    }
  }

  /// Cards, then extracts, then sources: the order the foreign keys allow.
  static List<ElementRef> _deletionOrder(Set<ElementRef> refs) => <ElementRef>[
    for (final ElementRef ref in refs)
      if (ref.type == ElementType.card) ref,
    for (final ElementRef ref in refs)
      if (ref.type == ElementType.extract) ref,
    for (final ElementRef ref in refs)
      if (ref.type == ElementType.source) ref,
  ];

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
    String type,
    Result<_Placement> Function(_TreeIndex index) plan,
  ) async {
    try {
      return await _transactions.run<Result<BrowserFilingOutcome>>(() async {
        if (await _learning.hasActivity(command.operationId.value, type)) {
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
            type: type,
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
            name: type,
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
        'command $type failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: type,
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

  /// [top] and everything filed anywhere below it, [top] first.
  List<ElementRef> subtreeOf(ElementRef top) {
    final List<ElementRef> collected = <ElementRef>[top];
    for (final ElementRef child in _childrenOf[top] ?? const <ElementRef>[]) {
      collected.addAll(subtreeOf(child));
    }
    return collected;
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
