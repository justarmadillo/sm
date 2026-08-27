/// The knowledge tree, and the way into any element in the collection.
///
/// This replaces the flat library list. A flat list could only ever show
/// sources, which hid most of the collection: extracts and cards are elements
/// in their own right, with their own schedules, and the relationship between
/// them is the thing worth seeing. There is one collection, forever, so the
/// tree is the collection rather than a view of part of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../application/content/content_tree_query.dart';
import '../../../domain/scheduling/element.dart';
import '../../../domain/scheduling/topic_scheduler.dart';
import '../../library/presentation/import_sheet.dart';
import '../../library/presentation/library_view_model.dart';
import '../../priority/presentation/priority_dialog.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/presentation/reader_view_model.dart';
import '../../search/presentation/search_screen.dart';
import '../../shared/element_type_badge.dart';

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
final FutureProvider<List<ContentNode>> contentTreeProvider =
    FutureProvider<List<ContentNode>>(
      (Ref ref) => ref.watch(contentTreeQueryProvider).load(),
    );

class ContentsScreen extends ConsumerStatefulWidget {
  const ContentsScreen({super.key});

  @override
  ConsumerState<ContentsScreen> createState() => _ContentsScreenState();
}

class _ContentsScreenState extends ConsumerState<ContentsScreen> {
  /// Refs whose children are showing. Collapsed is the default, because a
  /// collection large enough to need a tree is too large to open at once.
  final Set<ElementRef> _expanded = <ElementRef>{};

  /// Types the tree is restricted to; empty means everything.
  Set<ElementType> _types = const <ElementType>{};

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ContentNode>> tree = ref.watch(contentTreeProvider);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        kSearchShortcut: () => openSearch(context, ref),
      },
      child: Focus(autofocus: true, child: _scaffold(context, tree)),
    );
  }

  Widget _scaffold(BuildContext context, AsyncValue<List<ContentNode>> tree) {
    return Scaffold(
      appBar: AppBar(
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
            onPressed: () => setState(() {
              _expanded
                ..clear()
                ..addAll(_allRefs(tree.valueOrNull ?? const <ContentNode>[]));
            }),
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
      ),
      body: tree.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not load the tree.\n$error')),
        data: (List<ContentNode> roots) => Column(
          children: <Widget>[
            _TypeFilter(
              selected: _types,
              onChanged: (Set<ElementType> types) =>
                  setState(() => _types = types),
            ),
            Expanded(child: _buildBody(roots)),
          ],
        ),
      ),
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

  Future<void> _runAction(String action, ContentNode node) async {
    final LibraryViewModel model = ref.read(libraryViewModelProvider.notifier);
    switch (action) {
      case 'open':
        if (node.ref.type == ElementType.source) {
          await openReader(
            context,
            ref,
            sourceId: node.ref.id,
            mode: ReaderMode.scheduled,
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

  Widget _buildBody(List<ContentNode> roots) {
    final List<_Row> rows = <_Row>[];
    for (final ContentNode root in roots) {
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
  void _flatten(ContentNode node, int depth, List<_Row> rows) {
    final bool matches = _types.isEmpty || _types.contains(node.ref.type);
    if (matches) rows.add(_Row(node: node, depth: depth));
    final bool showChildren =
        _expanded.contains(node.ref) || (!matches && _types.isNotEmpty);
    if (!showChildren) return;
    for (final ContentNode child in node.children) {
      _flatten(child, matches ? depth + 1 : depth, rows);
    }
  }

  Iterable<ElementRef> _allRefs(List<ContentNode> nodes) sync* {
    for (final ContentNode node in nodes) {
      yield node.ref;
      yield* _allRefs(node.children);
    }
  }
}

/// One visible line: a node and how deep it sits.
@immutable
final class _Row {
  const _Row({required this.node, required this.depth});
  final ContentNode node;
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
    required this.onToggle,
    required this.onPriority,
    required this.onAction,
  });

  final _Row row;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onPriority;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final ContentNode node = row.node;
    final bool hasChildren = node.children.isNotEmpty;
    final bool isDismissed =
        node.status == Sm20ElementStatus.dismissed ||
        node.lifecycle == ElementLifecycle.dismissed;
    return Padding(
      padding: EdgeInsets.only(left: row.depth * 20.0, bottom: 2),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: hasChildren ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: hasChildren
                      ? Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                          color: AppColors.muted,
                        )
                      : null,
                ),
                ElementTypeBadge(type: node.ref.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
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
                          decoration: isDismissed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (node.preview.isNotEmpty)
                        Text(
                          node.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasChildren) ...<Widget>[
                  Text(
                    '${node.subtreeSize - 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (node.dueDay != null)
                  Text(
                    node.dueDay.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                IconButton(
                  tooltip: 'Priority',
                  onPressed: onPriority,
                  icon: const Icon(Icons.low_priority, size: 17),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Element actions',
                  icon: const Icon(Icons.more_vert, size: 17),
                  onSelected: onAction,
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        if (node.ref.type == ElementType.source)
                          const PopupMenuItem<String>(
                            value: 'open',
                            child: Text('Open'),
                          ),
                        if (node.ref.type == ElementType.source)
                          const PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
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
                        if (node.ref.type == ElementType.source)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                ),
              ],
            ),
          ),
        ),
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
