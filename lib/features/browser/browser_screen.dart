/// The Browser: the whole collection as one tree, and the way into any
/// element in it.
///
/// A flat list could only ever show sources, which hid most of the collection:
/// extracts and cards are elements in their own right, with their own
/// schedules, and the relationship between them is the thing worth seeing.
/// There is one collection, forever, so the tree is the collection rather than
/// a view of part of it.
///
/// The tree starts out in the shape extraction gives it — an extract under the
/// text it was cut from — and the user can then file anything anywhere: move a
/// row up or down, nest it under the row above, lift it back out, or drag it
/// onto another element entirely. Filing never touches provenance, so an
/// extract dragged across the collection still opens in the passage it came
/// from.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/features/browser/browser_providers.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/browser/import_sheet.dart';
import 'package:incremental_reader/features/browser/open_element.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';
import 'package:incremental_reader/features/priority/learning_command_menu.dart';
import 'package:incremental_reader/features/priority/learning_commands.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/search/search_screen.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

/// Opens the knowledge tree.
Future<void> openBrowser(BuildContext context, WidgetRef ref) async {
  ref.invalidate(browserTreeProvider);
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const BrowserScreen(),
    ),
  );
}

/// The whole tree, rebuilt on demand.
final FutureProvider<List<BrowserTreeNode>> browserTreeProvider =
    FutureProvider<List<BrowserTreeNode>>(
      (Ref ref) => ref.watch(browserTreeQueryProvider).load(),
    );

/// Horizontal step per level of nesting.
///
/// Wide enough that a level's guide can sit directly under its parent's
/// expander and still leave a gap before the child's card starts.
const double _kIndentStep = 26;

/// Where a level's guide sits inside its column: under the centre of the
/// expander of the row that owns that level.
const double _kGuideOffset = 19;

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  /// Refs whose children are showing.
  ///
  /// Opened all the way down the first time a tree arrives. What came out of
  /// what is the one thing this screen shows that a flat list could not, and a
  /// wall of closed rows hides exactly that.
  final Set<ElementRef> _expanded = <ElementRef>{};
  bool _hasSeededExpansion = false;

  /// Types the tree is restricted to; empty means everything.
  Set<ElementType> _types = const <ElementType>{};

  /// Opens every node, once, the first time the tree loads.
  ///
  /// Mutating the set during build is safe because the build that follows is
  /// the one that reads it; there is no state to notify anybody about.
  void _seedExpansion(List<BrowserTreeNode>? roots) {
    if (_hasSeededExpansion || roots == null) return;
    _hasSeededExpansion = true;
    _expanded.addAll(_allRefs(roots));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<BrowserTreeNode>> tree = ref.watch(
      browserTreeProvider,
    );
    _seedExpansion(tree.valueOrNull);

    // Element commands report through the shared ViewModel, so this is where
    // a rename, an edit, or a failed dismiss becomes visible.
    ref.listen<AsyncValue<BrowserUiState>>(browserViewModelProvider, (
      AsyncValue<BrowserUiState>? previous,
      AsyncValue<BrowserUiState> next,
    ) {
      final UiMessage? message = next.valueOrNull?.message;
      if (message == null) return;
      showToast(context, message.text, isError: message.isError);
      ref.read(browserViewModelProvider.notifier).shouldClearMessage();
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        kSearchShortcut: () => openSearch(context, ref),
      },
      child: Focus(autofocus: true, child: _scaffold(context, tree)),
    );
  }

  Widget _scaffold(
    BuildContext context,
    AsyncValue<List<BrowserTreeNode>> tree,
  ) {
    return Scaffold(
      appBar: _appBar(context, tree),
      body: tree.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not load the tree.\n$error')),
        data: _filterAndTree,
      ),
    );
  }

  /// Making things, search, and the two whole-tree expand controls.
  PreferredSizeWidget _appBar(
    BuildContext context,
    AsyncValue<List<BrowserTreeNode>> tree,
  ) {
    final bool isNarrow = isCompactWidth(context);
    return AppBar(
      title: const Text('Browser'),
      actions: <Widget>[
        _NewElementMenu(
          isNarrow: isNarrow,
          // At the top of the bar the new element has no element to belong to,
          // so it lands at the top of the tree. The same menu on a row files
          // it under that row instead.
          onSelected: (_NewElement choice) => _create(context, choice, null),
        ),
        IconButton(
          tooltip: 'Search (Ctrl+F)',
          onPressed: () => openSearch(context, ref),
          icon: const Icon(Icons.search),
        ),
        // The two whole-tree controls and Refresh are housekeeping, not the
        // reason the screen is open, so they are the ones that move into a
        // menu when the bar runs out of room.
        if (isNarrow)
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (String action) {
              switch (action) {
                case 'expand':
                  _expandAll(tree);
                case 'collapse':
                  setState(_expanded.clear);
                case 'refresh':
                  ref.invalidate(browserTreeProvider);
              }
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'expand',
                    child: ListTile(
                      leading: Icon(Icons.unfold_more),
                      title: Text('Expand everything'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'collapse',
                    child: ListTile(
                      leading: Icon(Icons.unfold_less),
                      title: Text('Collapse everything'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: ListTile(
                      leading: Icon(Icons.refresh),
                      title: Text('Refresh'),
                    ),
                  ),
                ],
          )
        else ...<Widget>[
          IconButton(
            tooltip: 'Expand everything',
            onPressed: () => _expandAll(tree),
            icon: const Icon(Icons.unfold_more),
          ),
          IconButton(
            tooltip: 'Collapse everything',
            onPressed: () => setState(_expanded.clear),
            icon: const Icon(Icons.unfold_less),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(browserTreeProvider),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  void _expandAll(AsyncValue<List<BrowserTreeNode>> tree) {
    setState(() {
      _expanded
        ..clear()
        ..addAll(_allRefs(tree.valueOrNull ?? const <BrowserTreeNode>[]));
    });
  }

  /// The type filter above the tree.
  Widget _filterAndTree(List<BrowserTreeNode> roots) => Column(
    children: <Widget>[
      _TypeFilter(
        selected: _types,
        onChanged: (Set<ElementType> types) => setState(() => _types = types),
      ),
      Expanded(child: _buildBody(roots)),
    ],
  );

  /// Makes a new element and files it where the user asked for it.
  ///
  /// [under] is the row the menu was opened on, or null when it was the one in
  /// the app bar. Everything created here is filed under that row afterwards:
  /// what a new element *belongs to* and where the user *keeps* it are two
  /// different questions, and only the second one a menu can answer.
  Future<void> _create(
    BuildContext context,
    _NewElement choice,
    BrowserTreeNode? under,
  ) async {
    switch (choice) {
      case _NewElement.writtenTopic:
        await _createTopic(context, under, isWritten: true);
      case _NewElement.importedTopic:
        await _createTopic(context, under, isWritten: false);
      case _NewElement.card:
        await _createCards(context, under);
    }
  }

  /// Writes or imports a topic, then opens it when it was imported.
  ///
  /// An imported chapter is something to start reading; a topic just written
  /// by hand is already on screen in the dialog the user typed it into, so
  /// opening the Reader on top of it would only be in the way.
  Future<void> _createTopic(
    BuildContext context,
    BrowserTreeNode? under, {
    required bool isWritten,
  }) async {
    final ImportRequest? request = isWritten
        ? await showNewTopicSheet(context)
        : await showImportSheet(context);
    if (request == null || !context.mounted) return;

    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    final String? sourceId = await model.importMarkdown(
      title: request.title,
      markdown: request.markdown,
    );
    if (sourceId != null && under != null) {
      await model.fileUnder(
        ref_: ElementRef(id: sourceId, type: ElementType.source),
        parentRef: under.ref,
      );
      setState(() => _expanded.add(under.ref));
    }
    ref.invalidate(browserTreeProvider);
    if (sourceId == null || isWritten || !context.mounted) return;
    await openReader(
      context,
      ref,
      sourceId: sourceId,
      mode: ReaderMode.scheduled,
    );
    ref.invalidate(browserTreeProvider);
  }

  /// Formulates cards straight into the tree.
  Future<void> _createCards(
    BuildContext context,
    BrowserTreeNode? under,
  ) async {
    final List<CardDraft>? drafts = await showFormulationDialog(
      context,
      seedText: '',
      existingCardCount: under?.children.length ?? 0,
      parentNoun: under == null ? 'collection' : 'element',
    );
    if (drafts == null || !context.mounted) return;

    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    final List<ElementRef>? created = await model.createCards(
      parent: _cardParentFor(under),
      drafts: drafts,
    );
    if (created != null && under != null) {
      for (final ElementRef card in created) {
        await model.fileUnder(ref_: card, parentRef: under.ref);
      }
      setState(() => _expanded.add(under.ref));
    }
    ref.invalidate(browserTreeProvider);
  }

  /// What a new card is written *from*, which is not the same as where it is
  /// filed.
  ///
  /// A card can only cite a topic or an extract, so a card added under another
  /// card cites that card's own parent when there is one, and nothing when
  /// there is not. It is still filed exactly where the user asked.
  CardParent? _cardParentFor(BrowserTreeNode? under) {
    final ElementRef? cited = switch (under?.ref.type) {
      ElementType.source || ElementType.extract => under!.ref,
      ElementType.card => under!.parentRef,
      null => null,
    };
    return switch (cited?.type) {
      ElementType.source => CardParent.source(cited!.id),
      ElementType.extract => CardParent.extract(cited!.id),
      ElementType.card || null => null,
    };
  }

  /// Opens the screen that owns an element. Clicking a row means "show me
  /// this", and the screen that owns the element is the only place that can.
  Future<void> _openElement(ElementRef elementRef) async {
    await openElement(context, ref, elementRef: elementRef);
    if (!mounted) return;
    ref.invalidate(browserTreeProvider);
  }

  Future<void> _runAction(String action, BrowserTreeNode node) async {
    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    switch (action) {
      case 'rename':
        final String? title = await _promptForTitle(context, node.title);
        if (title != null) await model.rename(node.ref.id, title);
      case 'dismiss':
        await model.dismiss(node.ref);
      case 'undismiss':
        await model.undismiss(node.ref);
      case 'delete':
        if (await _confirmDelete(context, node)) {
          await model.deleteElement(node.ref);
        }
    }
    ref.invalidate(browserTreeProvider);
  }

  /// Runs one Learning command against a single row.
  ///
  /// The same confirmation and the same follow-up questions the Priority
  /// queue asks: a command that discards work must say the same thing
  /// wherever the user reached it from.
  Future<void> _runLearningCommand(
    BuildContext context,
    LearningCommand command,
    BrowserTreeNode node,
  ) async {
    final LearningCommandAnswers? answers = await askForLearningCommand(
      context,
      command,
    );
    if (answers == null) return;
    await ref
        .read(browserViewModelProvider.notifier)
        .applyLearningCommand(command, node.ref, answers: answers);
    ref.invalidate(browserTreeProvider);
  }

  /// Files [moved] under [target], which is what a drop on a row means.
  Future<void> _dropOnto(ElementRef moved, BrowserTreeNode target) async {
    await ref
        .read(browserViewModelProvider.notifier)
        .fileUnder(ref_: moved, parentRef: target.ref);
    if (!mounted) return;
    setState(() => _expanded.add(target.ref));
    ref.invalidate(browserTreeProvider);
  }

  /// Files [moved] directly above [target], among that row's own siblings.
  Future<void> _dropAbove(ElementRef moved, BrowserTreeNode target) async {
    await ref
        .read(browserViewModelProvider.notifier)
        .fileUnder(
          ref_: moved,
          parentRef: target.parentRef,
          beforeRef: target.ref,
        );
    if (!mounted) return;
    ref.invalidate(browserTreeProvider);
  }

  Widget _buildBody(List<BrowserTreeNode> roots) {
    final List<_TreeRow> rows = <_TreeRow>[];
    for (final BrowserTreeNode root in roots) {
      _flatten(root, 0, rows);
    }
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Nothing here yet.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
      itemCount: rows.length,
      itemBuilder: (BuildContext context, int index) => _NodeRow(
        row: rows[index],
        isExpanded: _expanded.contains(rows[index].node.ref),
        onOpen: () => unawaited(_openElement(rows[index].node.ref)),
        onToggle: () => setState(() {
          final ElementRef ref_ = rows[index].node.ref;
          if (!_expanded.remove(ref_)) _expanded.add(ref_);
        }),
        onPriority: () async {
          await showPriorityDialog(
            context,
            ref,
            elementRef: rows[index].node.ref,
          );
          ref.invalidate(browserTreeProvider);
        },
        onAction: (String action) => _runAction(action, rows[index].node),
        onLearningCommand: (LearningCommand command) =>
            _runLearningCommand(context, command, rows[index].node),
        onCreate: (_NewElement choice) =>
            _create(context, choice, rows[index].node),
        onDropOnto: (ElementRef moved) =>
            unawaited(_dropOnto(moved, rows[index].node)),
        onDropAbove: (ElementRef moved) =>
            unawaited(_dropAbove(moved, rows[index].node)),
      ),
    );
  }

  /// Depth-first walk that emits only what is currently visible.
  ///
  /// A filtered-out node still yields its children: hiding a source would
  /// otherwise hide every card underneath it, which is the opposite of what
  /// filtering to cards means.
  void _flatten(BrowserTreeNode node, int depth, List<_TreeRow> rows) {
    final bool matches = _types.isEmpty || _types.contains(node.ref.type);
    if (matches) rows.add(_TreeRow(node: node, depth: depth));
    final bool shouldShowChildren =
        _expanded.contains(node.ref) || (!matches && _types.isNotEmpty);
    if (!shouldShowChildren) return;
    for (final BrowserTreeNode child in node.children) {
      _flatten(child, matches ? depth + 1 : depth, rows);
    }
  }

  Iterable<ElementRef> _allRefs(List<BrowserTreeNode> nodes) sync* {
    for (final BrowserTreeNode node in nodes) {
      yield node.ref;
      yield* _allRefs(node.children);
    }
  }
}

/// One visible line: a node and how deep it sits.
@immutable
final class _TreeRow {
  const _TreeRow({required this.node, required this.depth});

  final BrowserTreeNode node;
  final int depth;
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onChanged});

  final Set<ElementType> selected;
  final ValueChanged<Set<ElementType>> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final (String label, Set<ElementType> types)
            in <(String, Set<ElementType>)>[
              ('All', <ElementType>{}),
              ('Topics', <ElementType>{ElementType.source}),
              ('Extracts', <ElementType>{ElementType.extract}),
              ('Cards', <ElementType>{ElementType.card}),
            ])
          FilterChip(
            label: Text(label),
            selected:
                selected.length == types.length && selected.containsAll(types),
            onSelected: (_) => onChanged(types),
          ),
      ],
    ),
  );
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.row,
    required this.isExpanded,
    required this.onOpen,
    required this.onToggle,
    required this.onPriority,
    required this.onAction,
    required this.onLearningCommand,
    required this.onCreate,
    required this.onDropOnto,
    required this.onDropAbove,
  });

  final _TreeRow row;
  final bool isExpanded;

  /// Opens the screen that owns this element, which is also where it is
  /// edited: there is one reader for both browsing and reading.
  final VoidCallback onOpen;

  /// Opens or closes this element's children. Bound to the chevron alone, so
  /// that clicking a row means "show me this" rather than "fold this away".
  final VoidCallback onToggle;
  final VoidCallback onPriority;
  final ValueChanged<String> onAction;

  /// One of SM20's Learning commands, run against this row alone.
  final ValueChanged<LearningCommand> onLearningCommand;

  /// Makes a new element and files it under this row.
  final ValueChanged<_NewElement> onCreate;

  /// Something was dropped on this row: file it underneath.
  final ValueChanged<ElementRef> onDropOnto;

  /// Something was dropped in the gap above this row: file it here, beside
  /// this row rather than inside it.
  final ValueChanged<ElementRef> onDropAbove;

  @override
  Widget build(BuildContext context) {
    final BrowserTreeNode node = row.node;
    final bool hasChildren = node.children.isNotEmpty;
    final bool isDismissed =
        node.status == Sm20ElementStatus.dismissed ||
        node.lifecycle == ElementLifecycle.dismissed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DropAboveStrip(node: node, onDrop: onDropAbove),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // One rule per level of ancestry, so a deep extract can be
              // traced back to the article it came from without counting
              // pixels. The gap between rows belongs to the card, not to the
              // guides, or the rules would break into dashes down the page.
              for (int level = 0; level < row.depth; level++)
                const _IndentGuide(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _droppableCard(
                    context,
                    node,
                    hasChildren,
                    isDismissed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The row as somewhere to drop. What can be picked *up* is the handle
  /// inside it, not the whole card.
  Widget _droppableCard(
    BuildContext context,
    BrowserTreeNode node,
    bool hasChildren,
    bool isDismissed,
  ) {
    final Widget card = _card(context, node, hasChildren, isDismissed);
    return DragTarget<ElementRef>(
      onWillAcceptWithDetails: (DragTargetDetails<ElementRef> details) =>
          details.data != node.ref,
      onAcceptWithDetails: (DragTargetDetails<ElementRef> details) =>
          onDropOnto(details.data),
      builder:
          (
            BuildContext context,
            List<ElementRef?> candidates,
            List<dynamic> rejected,
          ) => candidates.isEmpty
          ? card
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: card,
            ),
    );
  }

  /// One row of the tree. Tapping it opens the element; the handle files it.
  Widget _card(
    BuildContext context,
    BrowserTreeNode node,
    bool hasChildren,
    bool isDismissed,
  ) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 7, 8, 7),
          child: isCompactWidth(context)
              ? _stackedRow(node, hasChildren, isDismissed)
              : _oneRow(node, hasChildren, isDismissed),
        ),
      ),
    );
  }

  /// The desktop shape: everything the row knows, on one line.
  Widget _oneRow(BrowserTreeNode node, bool hasChildren, bool isDismissed) =>
      Row(
        children: <Widget>[
          _dragHandle(node),
          _expandArrow(hasChildren),
          ElementTypeBadge(type: node.ref.type),
          const SizedBox(width: 8),
          Expanded(child: _titleAndPreview(node, isDismissed)),
          if (hasChildren) ...<Widget>[
            // How many elements this branch holds, itself excluded.
            _mutedLabel('${node.subtreeSize - 1}'),
            const SizedBox(width: 8),
          ],
          if (node.dueDay != null) _mutedLabel(node.dueDay.toString()),
          ..._rowButtons(node, isDismissed),
        ],
      );

  /// The phone shape. The badge's word, the branch count, the due day and
  /// three buttons together leave the title about eight characters, and the
  /// title is the one thing on the row that says which element this is. The
  /// title takes the width; everything else moves to a line underneath.
  Widget _stackedRow(BrowserTreeNode node, bool hasChildren, bool isDismissed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _dragHandle(node),
            _expandArrow(hasChildren),
            ElementTypeBadge(type: node.ref.type, shouldShowLabel: false),
            const SizedBox(width: 8),
            Expanded(child: _titleAndPreview(node, isDismissed)),
          ],
        ),
        Row(
          children: <Widget>[
            const SizedBox(width: _kHandleWidth + _kArrowWidth),
            Expanded(child: _mutedLabel(_metaLine(node, hasChildren))),
            ..._rowButtons(node, isDismissed),
          ],
        ),
      ],
    );
  }

  /// The two numbers the wide row shows as bare labels, named rather than
  /// positioned: on a line of their own there is no heading above them to say
  /// which is which.
  String _metaLine(BrowserTreeNode node, bool hasChildren) => <String>[
    if (hasChildren) '${node.subtreeSize - 1} inside',
    if (node.dueDay != null) 'due ${node.dueDay}',
  ].join('  ·  ');

  /// The four per-row commands, the same in both shapes.
  List<Widget> _rowButtons(BrowserTreeNode node, bool isDismissed) => <Widget>[
    IconButton(
      tooltip: 'Priority',
      onPressed: onPriority,
      icon: const Icon(Icons.low_priority, size: 17),
      constraints: _kRowButtonConstraints,
      padding: EdgeInsets.zero,
    ),
    _NewElementMenu(isRowMenu: true, onSelected: onCreate),
    LearningCommandMenu(
      onSelected: onLearningCommand,
      size: _kRowButtonConstraints.maxWidth,
    ),
    _actionMenu(node, isDismissed),
  ];

  /// The row is picked up by its handle, the way the priority queue's rows
  /// are. A long press on the card was the only gesture that filed anything
  /// and nothing on screen said so, which is why the moves ended up duplicated
  /// as a menu.
  Widget _dragHandle(BrowserTreeNode node) => Draggable<ElementRef>(
    data: node.ref,
    feedback: _DragLabel(title: node.title, type: node.ref.type),
    childWhenDragging: const SizedBox(width: _kHandleWidth),
    child: const SizedBox(
      width: _kHandleWidth,
      child: Icon(Icons.drag_indicator, size: 17, color: AppColors.muted),
    ),
  );

  /// A fixed-width slot, so childless rows still line up with their siblings.
  Widget _expandArrow(bool hasChildren) {
    return SizedBox(
      width: _kArrowWidth,
      child: hasChildren
          ? InkResponse(
              onTap: onToggle,
              radius: 14,
              child: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: AppColors.muted,
              ),
            )
          : null,
    );
  }

  /// A dismissed element keeps its place in the tree but is struck through:
  /// its content is still there, it is only out of the queue.
  Widget _titleAndPreview(BrowserTreeNode node, bool isDismissed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          node.title.isEmpty ? '(untitled)' : node.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDismissed ? AppColors.muted : null,
            decoration: isDismissed ? TextDecoration.lineThrough : null,
          ),
        ),
        if (node.preview.isNotEmpty)
          Text(
            node.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
      ],
    );
  }

  Widget _mutedLabel(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 11, color: AppColors.muted),
  );

  /// Only a source can be renamed. Delete is offered on every row: an extract
  /// or a card the user no longer wants is reachable no other way, and it
  /// takes the whole branch filed under it with it.
  ///
  /// Filing is not in here. Where a row is kept is answered by dragging it,
  /// and a menu of move up / move down / nest / lift was a second, clumsier
  /// vocabulary for the same thing.
  Widget _actionMenu(BrowserTreeNode node, bool isDismissed) {
    final bool isSource = node.ref.type == ElementType.source;
    return SizedBox(
      width: _kRowButtonConstraints.maxWidth,
      height: _kRowButtonConstraints.maxHeight,
      child: PopupMenuButton<String>(
        tooltip: 'Element actions',
        icon: const Icon(Icons.more_vert, size: 17),
        padding: EdgeInsets.zero,
        onSelected: onAction,
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          if (isSource)
            const PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
          if (isDismissed)
            const PopupMenuItem<String>(
              value: 'undismiss',
              child: Text('Undismiss'),
            )
          else
            const PopupMenuItem<String>(
              value: 'dismiss',
              child: Text('Dismiss (keep content)'),
            ),
          const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

/// Width of the drag handle's slot.
const double _kHandleWidth = 26;

/// Width of the expand chevron's slot.
const double _kArrowWidth = 22;

/// A row's buttons are tighter than Material's default 48-pixel target: three
/// of them at that size take half a phone's width away from the title.
const BoxConstraints _kRowButtonConstraints = BoxConstraints.tightFor(
  width: 34,
  height: 34,
);

/// What the New menu can make.
enum _NewElement {
  /// A topic typed straight into the dialog.
  writtenTopic,

  /// A topic imported from a file or pasted in.
  importedTopic,

  /// One or more cards, through the same formulation dialog the Reader uses.
  card,
}

/// The New menu, in the app bar and on every row.
///
/// Extracts are deliberately not here. An extract is a passage cut out of
/// something, and it carries the exact range it was cut from; there is no such
/// range to record for one typed into a menu, so extracts are still made by
/// selecting text in the Reader.
class _NewElementMenu extends StatelessWidget {
  const _NewElementMenu({
    required this.onSelected,
    this.isNarrow = false,
    this.isRowMenu = false,
  });

  final ValueChanged<_NewElement> onSelected;

  /// A narrow window drops the button's label and keeps the icon.
  final bool isNarrow;

  /// A row's menu is smaller and unlabelled whatever the width.
  final bool isRowMenu;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_NewElement>(
    tooltip: isRowMenu ? 'New element here' : 'New',
    onSelected: onSelected,
    icon: isRowMenu || isNarrow
        ? Icon(Icons.add, size: isRowMenu ? 17 : 24)
        : null,
    itemBuilder: (BuildContext context) => const <PopupMenuEntry<_NewElement>>[
      PopupMenuItem<_NewElement>(
        value: _NewElement.writtenTopic,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.article_outlined),
          title: Text('Topic'),
        ),
      ),
      PopupMenuItem<_NewElement>(
        value: _NewElement.importedTopic,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.file_open_outlined),
          title: Text('Topic from markdown'),
        ),
      ),
      PopupMenuItem<_NewElement>(
        value: _NewElement.card,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.style_outlined),
          title: Text('Cards'),
        ),
      ),
    ],
    child: isRowMenu || isNarrow
        ? null
        : const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(Icons.add, size: 18),
                SizedBox(width: 6),
                Text('New'),
              ],
            ),
          ),
  );
}

/// What a dragged row looks like while it is in the air.
class _DragLabel extends StatelessWidget {
  const _DragLabel({required this.title, required this.type});

  final String title;
  final ElementType type;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 4,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ElementTypeBadge(type: type),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title.isEmpty ? '(untitled)' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The gap above a row, as somewhere to drop.
///
/// Dropping on a row files the dragged element *inside* it; dropping in the
/// gap files it *beside* it, in front of that row. Without the gap there is no
/// gesture for "put it back at this level", only ever deeper.
class _DropAboveStrip extends StatelessWidget {
  const _DropAboveStrip({required this.node, required this.onDrop});

  final BrowserTreeNode node;
  final ValueChanged<ElementRef> onDrop;

  @override
  Widget build(BuildContext context) => DragTarget<ElementRef>(
    onWillAcceptWithDetails: (DragTargetDetails<ElementRef> details) =>
        details.data != node.ref,
    onAcceptWithDetails: (DragTargetDetails<ElementRef> details) =>
        onDrop(details.data),
    builder:
        (
          BuildContext context,
          List<ElementRef?> candidates,
          List<dynamic> rejected,
        ) => SizedBox(
          height: 8,
          child: candidates.isEmpty
              ? null
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: ColoredBox(color: AppColors.accent),
                ),
        ),
  );
}

/// One vertical rule marking a level of nesting.
class _IndentGuide extends StatelessWidget {
  const _IndentGuide();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: _kIndentStep,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(width: _kGuideOffset),
        SizedBox(width: 1, child: ColoredBox(color: AppColors.border)),
      ],
    ),
  );
}

Future<String?> _promptForTitle(BuildContext context, String current) {
  final TextEditingController controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        onSubmitted: (String value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Rename'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// The one confirmation in the app that has to be read rather than dismissed.
///
/// It names the size of the branch, because the row on screen shows a title
/// and gives no hint that forty extracts and their cards are filed under it,
/// and nothing here can be taken back afterwards.
Future<bool> _confirmDelete(BuildContext context, BrowserTreeNode node) async {
  final int below = node.subtreeSize - 1;
  final String title = node.title.isEmpty ? '(untitled)' : node.title;
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Delete?'),
          content: Text(
            below == 0
                ? 'This erases it. There is no undo.\n\n$title'
                : 'This erases it and the $below element'
                      '${below == 1 ? '' : 's'} filed under it — their text, '
                      'their extracts and their cards. There is no undo.'
                      '\n\n$title',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}
