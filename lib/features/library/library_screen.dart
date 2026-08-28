/// The knowledge tree, and the way into any element in the collection.
///
/// This replaces the flat library list. A flat list could only ever show
/// sources, which hid most of the collection: extracts and cards are elements
/// in their own right, with their own schedules, and the relationship between
/// them is the thing worth seeing. There is one collection, forever, so the
/// tree is the collection rather than a view of part of it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/library/element_content_query.dart';
import 'package:incremental_reader/features/library/import_sheet.dart';
import 'package:incremental_reader/features/library/library_providers.dart';
import 'package:incremental_reader/features/library/library_tree_query.dart';
import 'package:incremental_reader/features/library/library_view_model.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/search/search_screen.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

/// Opens the knowledge tree.
Future<void> openContents(BuildContext context, WidgetRef ref) async {
  ref.invalidate(contentTreeProvider);
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const ContentsScreen(),
    ),
  );
}

/// The whole tree, rebuilt on demand.
final FutureProvider<List<LibraryTreeNode>> contentTreeProvider =
    FutureProvider<List<LibraryTreeNode>>(
      (Ref ref) => ref.watch(libraryTreeQueryProvider).load(),
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

class ContentsScreen extends ConsumerStatefulWidget {
  const ContentsScreen({super.key});

  @override
  ConsumerState<ContentsScreen> createState() => _ContentsScreenState();
}

class _ContentsScreenState extends ConsumerState<ContentsScreen> {
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
  void _seedExpansion(List<LibraryTreeNode>? roots) {
    if (_hasSeededExpansion || roots == null) return;
    _hasSeededExpansion = true;
    _expanded.addAll(_allRefs(roots));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<LibraryTreeNode>> tree = ref.watch(
      contentTreeProvider,
    );
    _seedExpansion(tree.valueOrNull);

    // Element commands report through the shared ViewModel, so this is where
    // a rename, an edit, or a failed dismiss becomes visible.
    ref.listen<AsyncValue<LibraryUiState>>(libraryViewModelProvider, (
      AsyncValue<LibraryUiState>? previous,
      AsyncValue<LibraryUiState> next,
    ) {
      final UiMessage? message = next.valueOrNull?.message;
      if (message == null) return;
      showToast(context, message.text, isError: message.isError);
      ref.read(libraryViewModelProvider.notifier).shouldClearMessage();
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
    AsyncValue<List<LibraryTreeNode>> tree,
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

  /// Import, search, and the two whole-tree expand controls.
  PreferredSizeWidget _appBar(
    BuildContext context,
    AsyncValue<List<LibraryTreeNode>> tree,
  ) {
    return AppBar(
      title: const Text('Contents'),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => _import(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Import markdown'),
        ),
        IconButton(
          tooltip: 'Search (Ctrl+F)',
          onPressed: () => openSearch(context, ref),
          icon: const Icon(Icons.search),
        ),
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
          onPressed: () => ref.invalidate(contentTreeProvider),
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _expandAll(AsyncValue<List<LibraryTreeNode>> tree) {
    setState(() {
      _expanded
        ..clear()
        ..addAll(_allRefs(tree.valueOrNull ?? const <LibraryTreeNode>[]));
    });
  }

  /// The tree, with the detail pane beside it once something is selected.
  Widget _treeAndDetail(List<LibraryTreeNode> roots) {
    return Column(
      children: <Widget>[
        _TypeFilter(
          selected: _types,
          onChanged: (Set<ElementType> types) => setState(() => _types = types),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(child: _buildBody(roots)),
              if (_selected != null) _detailPane(),
            ],
          ),
        ),
      ],
    );
  }

  /// A card has no screen of its own to open; it is reviewed, not read.
  Widget _detailPane() {
    return _ElementDetailPane(
      elementRef: _selected!,
      onClose: () => setState(() => _selected = null),
      onOpen: _selected!.type == ElementType.card
          ? null
          : () => unawaited(_openElement(_selected!)),
    );
  }

  /// Imports markdown and opens it, as the library screen used to.
  Future<void> _import(BuildContext context) async {
    final ImportRequest? request = await showImportSheet(context);
    if (request == null || !context.mounted) return;
    final String? sourceId = await ref
        .read(libraryViewModelProvider.notifier)
        .importMarkdown(title: request.title, markdown: request.markdown);
    ref.invalidate(contentTreeProvider);
    if (sourceId == null || !context.mounted) return;
    await openReader(
      context,
      ref,
      sourceId: sourceId,
      mode: ReaderMode.scheduled,
    );
    ref.invalidate(contentTreeProvider);
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
    ref.invalidate(contentTreeProvider);
    ref.invalidate(elementContentProvider(elementRef));
  }

  Future<void> _runAction(String action, LibraryTreeNode node) async {
    final LibraryViewModel model = ref.read(libraryViewModelProvider.notifier);
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
    }
    ref.invalidate(contentTreeProvider);
  }

  Widget _buildBody(List<LibraryTreeNode> roots) {
    final List<_TreeRow> rows = <_TreeRow>[];
    for (final LibraryTreeNode root in roots) {
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
          ref.invalidate(contentTreeProvider);
        },
        onAction: (String action) => _runAction(action, rows[index].node),
      ),
    );
  }

  /// Depth-first walk that emits only what is currently visible.
  ///
  /// A filtered-out node still yields its children: hiding a source would
  /// otherwise hide every card underneath it, which is the opposite of what
  /// filtering to cards means.
  void _flatten(LibraryTreeNode node, int depth, List<_TreeRow> rows) {
    final bool matches = _types.isEmpty || _types.contains(node.ref.type);
    if (matches) rows.add(_TreeRow(node: node, depth: depth));
    final bool shouldShowChildren =
        _expanded.contains(node.ref) || (!matches && _types.isNotEmpty);
    if (!shouldShowChildren) return;
    for (final LibraryTreeNode child in node.children) {
      _flatten(child, matches ? depth + 1 : depth, rows);
    }
  }

  Iterable<ElementRef> _allRefs(List<LibraryTreeNode> nodes) sync* {
    for (final LibraryTreeNode node in nodes) {
      yield node.ref;
      yield* _allRefs(node.children);
    }
  }
}

/// One visible line: a node and how deep it sits.
@immutable
final class _TreeRow {
  const _TreeRow({required this.node, required this.depth});
  final LibraryTreeNode node;
  final int depth;
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onChanged});

  final Set<ElementType> selected;
  final ValueChanged<Set<ElementType>> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      children: <Widget>[
        for (final (String label, Set<ElementType> types)
            in <(String, Set<ElementType>)>[
              ('All', <ElementType>{}),
              ('Topics', <ElementType>{ElementType.source}),
              ('Extracts', <ElementType>{ElementType.extract}),
              ('Cards', <ElementType>{ElementType.card}),
            ])
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(label),
              selected:
                  selected.length == types.length &&
                  selected.containsAll(types),
              onSelected: (_) => onChanged(types),
            ),
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

  @override
  Widget build(BuildContext context) {
    final LibraryTreeNode node = row.node;
    final bool hasChildren = node.children.isNotEmpty;
    final bool isDismissed =
        node.status == Sm20ElementStatus.dismissed ||
        node.lifecycle == ElementLifecycle.dismissed;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // One rule per level of ancestry, so a deep extract can be traced
          // back to the article it came from without counting pixels. The
          // gap between rows belongs to the card, not to the guides, or the
          // rules would break into dashes down the page.
          for (int level = 0; level < row.depth; level++) const _IndentGuide(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _card(node, hasChildren, isDismissed),
            ),
          ),
        ],
      ),
    );
  }

  /// One row of the tree: the expand arrow, the type badge, the title and
  /// preview, then the counts and the per-element commands.
  Widget _card(LibraryTreeNode node, bool hasChildren, bool isDismissed) {
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
  Widget _titleAndPreview(LibraryTreeNode node, bool isDismissed) {
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
  Widget _actionMenu(LibraryTreeNode node, bool isDismissed) {
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
      ],
    );
  }
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
  });

  final ElementRef elementRef;
  final VoidCallback onClose;

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
    final LibraryViewModel model = ref.read(libraryViewModelProvider.notifier);
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
    ref.invalidate(contentTreeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ElementContent?> content = ref.watch(
      elementContentProvider(widget.elementRef),
    );
    return Container(
      width: _kDetailPaneWidth,
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
