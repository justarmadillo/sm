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
import 'package:incremental_reader/features/browser/element_content_query.dart';
import 'package:incremental_reader/features/browser/import_sheet.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';
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

/// The body of one element, for the detail pane.
final AutoDisposeFutureProviderFamily<ElementContent?, ElementRef>
elementContentProvider = FutureProvider.autoDispose
    .family<ElementContent?, ElementRef>(
      (Ref ref, ElementRef elementRef) =>
          ref.watch(elementContentQueryProvider).load(elementRef),
    );

/// Width of the detail pane, wide enough for a paragraph of prose.
const double _kDetailPaneWidth = 420;

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

  /// The row the detail pane is showing, or null when the pane is closed.
  ElementRef? _selected;

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
        data: _treeAndDetail,
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

  /// The tree, with the detail pane beside it once something is selected.
  ///
  /// A 420-pixel pane and a tree cannot share a phone's width, so on a narrow
  /// window the pane takes the screen instead and its close button is the way
  /// back to the tree.
  Widget _treeAndDetail(List<BrowserTreeNode> roots) {
    final bool hasRoomForBoth = !isCompactWidth(context);
    final bool isPaneOpen = _selected != null;
    return Column(
      children: <Widget>[
        if (hasRoomForBoth || !isPaneOpen)
          _TypeFilter(
            selected: _types,
            onChanged: (Set<ElementType> types) =>
                setState(() => _types = types),
          ),
        Expanded(
          child: hasRoomForBoth
              ? Row(
                  children: <Widget>[
                    Expanded(child: _buildBody(roots)),
                    if (isPaneOpen) _detailPane(width: _kDetailPaneWidth),
                  ],
                )
              : isPaneOpen
              ? _detailPane(width: null)
              : _buildBody(roots),
        ),
      ],
    );
  }

  /// A card has no screen of its own to open; it is reviewed, not read.
  Widget _detailPane({required double? width}) {
    return _ElementDetailPane(
      elementRef: _selected!,
      width: width,
      onClose: () => setState(() => _selected = null),
      onOpen: _selected!.type == ElementType.card
          ? null
          : () => unawaited(_openElement(_selected!)),
    );
  }

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

  /// Opens the screen that owns an element, for the work the pane cannot do.
  Future<void> _openElement(ElementRef elementRef) async {
    switch (elementRef.type) {
      case ElementType.source:
        await openReader(
          context,
          ref,
          sourceId: elementRef.id,
          mode: ReaderMode.browse,
        );
      case ElementType.extract:
        await openExtract(
          context,
          ref,
          extractId: elementRef.id,
          mode: ExtractMode.browse,
        );
      case ElementType.card:
        return;
    }
    if (!mounted) return;
    ref.invalidate(browserTreeProvider);
    ref.invalidate(elementContentProvider(elementRef));
  }

  Future<void> _runAction(String action, BrowserTreeNode node) async {
    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    switch (action) {
      case 'open':
        // Browse, not a scheduled sitting. Opening something to look at it
        // from a browser is not the same as being handed it by the queue, and
        // offering Done and Postpone here invites recording a repetition that
        // never happened. The Reader's own "Continue reading" promotes the
        // session when that is what the user meant.
        if (node.ref.type == ElementType.source) {
          await openReader(
            context,
            ref,
            sourceId: node.ref.id,
            mode: ReaderMode.browse,
          );
        }
      case 'rename':
        final String? title = await _promptForTitle(context, node.title);
        if (title != null) await model.rename(node.ref.id, title);
      case 'dismiss':
        await model.dismiss(node.ref);
      case 'undismiss':
        await model.undismiss(node.ref);
      case 'delete':
        if (await _confirmDelete(context, node.title)) {
          await model.deleteSource(node.ref.id);
        }
      // The four moves. Each is filing and nothing else, so none of them
      // needs a confirmation: the reverse move is one click away.
      case 'move_up':
        await model.moveUp(node.ref);
      case 'move_down':
        await model.moveDown(node.ref);
      case 'nest':
        await model.nestUnderPreviousSibling(node.ref);
      case 'lift':
        await model.liftOutOfParent(node.ref);
    }
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
    for (var index = 0; index < roots.length; index++) {
      _flatten(
        roots[index],
        0,
        rows,
        isFirstAmongSiblings: index == 0,
        isLastAmongSiblings: index == roots.length - 1,
      );
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
        isSelected: _selected == rows[index].node.ref,
        onSelect: () => setState(() => _selected = rows[index].node.ref),
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
  void _flatten(
    BrowserTreeNode node,
    int depth,
    List<_TreeRow> rows, {
    required bool isFirstAmongSiblings,
    required bool isLastAmongSiblings,
  }) {
    final bool matches = _types.isEmpty || _types.contains(node.ref.type);
    if (matches) {
      rows.add(
        _TreeRow(
          node: node,
          depth: depth,
          isFirstAmongSiblings: isFirstAmongSiblings,
          isLastAmongSiblings: isLastAmongSiblings,
        ),
      );
    }
    final bool shouldShowChildren =
        _expanded.contains(node.ref) || (!matches && _types.isNotEmpty);
    if (!shouldShowChildren) return;
    for (var index = 0; index < node.children.length; index++) {
      _flatten(
        node.children[index],
        matches ? depth + 1 : depth,
        rows,
        isFirstAmongSiblings: index == 0,
        isLastAmongSiblings: index == node.children.length - 1,
      );
    }
  }

  Iterable<ElementRef> _allRefs(List<BrowserTreeNode> nodes) sync* {
    for (final BrowserTreeNode node in nodes) {
      yield node.ref;
      yield* _allRefs(node.children);
    }
  }
}

/// One visible line: a node, how deep it sits, and which moves it has room
/// for.
@immutable
final class _TreeRow {
  const _TreeRow({
    required this.node,
    required this.depth,
    required this.isFirstAmongSiblings,
    required this.isLastAmongSiblings,
  });

  final BrowserTreeNode node;
  final int depth;

  /// Nothing above it in its own level, so it can neither rise nor nest.
  final bool isFirstAmongSiblings;

  /// Nothing below it in its own level, so it cannot sink further.
  final bool isLastAmongSiblings;
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
    required this.isSelected,
    required this.onSelect,
    required this.onToggle,
    required this.onPriority,
    required this.onAction,
    required this.onCreate,
    required this.onDropOnto,
    required this.onDropAbove,
  });

  final _TreeRow row;
  final bool isExpanded;
  final bool isSelected;

  /// Shows this element's content in the detail pane.
  final VoidCallback onSelect;

  /// Opens or closes this element's children. Bound to the chevron alone, so
  /// that clicking a row means "show me this" rather than "fold this away".
  final VoidCallback onToggle;
  final VoidCallback onPriority;
  final ValueChanged<String> onAction;

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
                  child: _draggableCard(node, hasChildren, isDismissed),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The row, both as something that can be picked up and as somewhere to drop.
  ///
  /// A long press starts the drag on every platform, mouse included: a plain
  /// drag would fight the list's own scrolling, and on a phone that is the
  /// gesture that would be lost.
  Widget _draggableCard(
    BrowserTreeNode node,
    bool hasChildren,
    bool isDismissed,
  ) {
    final Widget card = _card(node, hasChildren, isDismissed);
    return LongPressDraggable<ElementRef>(
      data: node.ref,
      feedback: _DragLabel(title: node.title, type: node.ref.type),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: DragTarget<ElementRef>(
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
      ),
    );
  }

  /// One row of the tree: the expand arrow, the type badge, the title and
  /// preview, then the counts and the per-element commands.
  Widget _card(BrowserTreeNode node, bool hasChildren, bool isDismissed) {
    return Material(
      color: isSelected
          ? AppColors.accent.withValues(alpha: 0.10)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: <Widget>[
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
              IconButton(
                tooltip: 'Priority',
                onPressed: onPriority,
                icon: const Icon(Icons.low_priority, size: 17),
              ),
              _NewElementMenu(isRowMenu: true, onSelected: onCreate),
              _actionMenu(node, isDismissed),
            ],
          ),
        ),
      ),
    );
  }

  /// A fixed-width slot, so childless rows still line up with their siblings.
  Widget _expandArrow(bool hasChildren) {
    return SizedBox(
      width: 22,
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

  Widget _mutedLabel(String text) =>
      Text(text, style: const TextStyle(fontSize: 11, color: AppColors.muted));

  /// Only a source can be opened, renamed, or deleted; an extract is reached
  /// through its parent and removed with it.
  ///
  /// The moves sit in the same menu, below a divider: they are about where the
  /// row is kept rather than what it is, and each is disabled when the row is
  /// already at that edge of its level.
  Widget _actionMenu(BrowserTreeNode node, bool isDismissed) {
    final bool isSource = node.ref.type == ElementType.source;
    return PopupMenuButton<String>(
      tooltip: 'Element actions',
      icon: const Icon(Icons.more_vert, size: 17),
      onSelected: onAction,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (isSource)
          const PopupMenuItem<String>(value: 'open', child: Text('Open')),
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
        if (isSource)
          const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'move_up',
          enabled: !row.isFirstAmongSiblings,
          child: const Text('Move up'),
        ),
        PopupMenuItem<String>(
          value: 'move_down',
          enabled: !row.isLastAmongSiblings,
          child: const Text('Move down'),
        ),
        PopupMenuItem<String>(
          value: 'nest',
          enabled: !row.isFirstAmongSiblings,
          child: const Text('Nest under the row above'),
        ),
        PopupMenuItem<String>(
          value: 'lift',
          enabled: node.parentRef != null,
          child: const Text('Move out one level'),
        ),
      ],
    );
  }
}

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

/// The content of the selected element, beside the tree.
///
/// A tree of titles answers "what came out of what" and nothing else. Reading
/// or fixing the text behind a row meant opening the screen that owns that
/// kind of element and coming back — which is a poor way to work through a
/// collection. The pane keeps the list in view while the text is on screen.
class _ElementDetailPane extends ConsumerStatefulWidget {
  const _ElementDetailPane({
    required this.elementRef,
    required this.onClose,
    required this.onOpen,
    required this.width,
  });

  final ElementRef elementRef;
  final VoidCallback onClose;

  /// How wide to draw. Null when the pane has the screen to itself.
  final double? width;

  /// Opens the element's own screen, for what the pane deliberately cannot do.
  final VoidCallback? onOpen;

  @override
  ConsumerState<_ElementDetailPane> createState() => _ElementDetailPaneState();
}

class _ElementDetailPaneState extends ConsumerState<_ElementDetailPane> {
  final TextEditingController _body = TextEditingController();
  final TextEditingController _back = TextEditingController();

  /// What the fields were last filled from, so that a rebuild while the user
  /// is typing does not put the stored text back under their cursor.
  ElementRef? _filledFrom;
  String? _filledBody;
  String? _filledBack;

  @override
  void dispose() {
    _body.dispose();
    _back.dispose();
    super.dispose();
  }

  void _fill(ElementContent content) {
    if (_filledFrom == content.ref &&
        _filledBody == content.body &&
        _filledBack == content.back) {
      return;
    }
    _filledFrom = content.ref;
    _filledBody = content.body;
    _filledBack = content.back;
    _body.text = content.body;
    _back.text = content.back ?? '';
  }

  Future<void> _save(ElementContent content) async {
    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    switch (content.ref.type) {
      case ElementType.extract:
        await model.editExtract(content.ref.id, _body.text);
      case ElementType.card:
        await model.editCard(
          content.ref.id,
          front: _body.text,
          back: content.back == null ? null : _back.text,
        );
      case ElementType.source:
        return;
    }
    if (!mounted) return;
    ref.invalidate(elementContentProvider(content.ref));
    ref.invalidate(browserTreeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ElementContent?> content = ref.watch(
      elementContentProvider(widget.elementRef),
    );
    return Container(
      width: widget.width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: content.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not load this element.\n$error')),
        data: (ElementContent? loaded) => loaded == null
            ? const Center(
                child: Text(
                  'This element is no longer here.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            : _content(loaded),
      ),
    );
  }

  /// The detail pane: a header, the element's text, then the save row.
  Widget _content(ElementContent content) {
    _fill(content);
    // A card carries a question and an answer; everything else is one body.
    final bool isCard = content.ref.type == ElementType.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(content),
        const Divider(height: 1, color: AppColors.border),
        Expanded(child: _editableFields(content, isCard)),
        const Divider(height: 1, color: AppColors.border),
        _saveRow(content),
      ],
    );
  }

  /// Type badge, title, and the ways out of the pane.
  Widget _header(ElementContent content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
      child: Row(
        children: <Widget>[
          ElementTypeBadge(type: content.ref.type),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              content.title.isEmpty ? '(untitled)' : content.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          if (widget.onOpen != null)
            IconButton(
              tooltip: 'Open',
              onPressed: widget.onOpen,
              icon: const Icon(Icons.open_in_new, size: 17),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 17),
          ),
        ],
      ),
    );
  }

  /// The body field, plus an answer field for a card.
  ///
  /// Read-only rather than hidden when the element cannot be edited, so the
  /// text is still there to read and copy.
  Widget _editableFields(ElementContent content, bool isCard) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isCard) _fieldLabel('Question', topPadding: 0),
          TextField(
            controller: _body,
            readOnly: !content.isEditable,
            minLines: 6,
            maxLines: null,
            style: const TextStyle(fontSize: 13, height: 1.45),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (isCard && content.back != null) ...<Widget>[
            _fieldLabel('Answer', topPadding: 12),
            TextField(
              controller: _back,
              readOnly: !content.isEditable,
              minLines: 3,
              maxLines: null,
              style: const TextStyle(fontSize: 13, height: 1.45),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {required double topPadding}) => Padding(
    padding: EdgeInsets.fromLTRB(0, topPadding, 0, 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppColors.muted),
    ),
  );

  /// Says why the element cannot be edited when it cannot, and reassures that
  /// editing is not a repetition when it can.
  Widget _saveRow(ElementContent content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              content.notEditableReason ?? 'Edits never reschedule.',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
          if (content.isEditable)
            FilledButton(
              onPressed: () => unawaited(_save(content)),
              child: const Text('Save'),
            ),
        ],
      ),
    );
  }
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

Future<bool> _confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete this element?'),
        content: Text(
          'The content and every descendant are retained and can be '
          'restored. Only the schedule goes.\n\n$title',
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
