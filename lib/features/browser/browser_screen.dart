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
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/features/browser/browser_providers.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/browser/import_sheet.dart';
import 'package:incremental_reader/features/browser/open_element.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';
import 'package:incremental_reader/features/occlusion/occlusion_screen.dart';
import 'package:incremental_reader/features/priority/learning_command_menu.dart';
import 'package:incremental_reader/features/priority/learning_commands.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/reader/reader_image_input.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/search/search_screen.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/features/tags/tags_picker_dialog.dart';
import 'package:incremental_reader/features/tags/tags_providers.dart';
import 'package:incremental_reader/features/tags/tags_screen.dart';
import 'package:incremental_reader/features/video/import_video_sheet.dart';
import 'package:incremental_reader/features/video/video_screen.dart';
import 'package:incremental_reader/features/video/video_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/colored_tag_list.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';
import 'package:incremental_reader/shared/ui/video_thumbnail.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

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

/// Tag definitions used by the Browser's intersecting filter.
final FutureProvider<List<Tag>> browserTagsProvider = FutureProvider<List<Tag>>(
  (Ref ref) => ref.watch(tagRepositoryProvider).listTags(),
);

/// Horizontal step per level of nesting.
///
/// Wide enough that a level's guide can sit directly under its parent's
/// expander and still leave a gap before the child's card starts.
const double _kIndentStep = 26;

/// Where a level's guide sits inside its column: under the centre of the
/// expander of the row that owns that level.
const double _kGuideOffset = 19;

/// How siblings are ordered while preserving the collection's tree shape.
enum _BrowserOrder { filing, addedNewest, addedOldest }

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
  final Set<ElementRef> _selected = <ElementRef>{};
  bool _isSelecting = false;
  bool _hasSeededExpansion = false;

  /// Types the tree is restricted to; empty means everything.
  Set<ElementType> _types = const <ElementType>{};

  /// Every selected tag must be effective on a row for that row to remain.
  Set<String> _tagIds = const <String>{};

  _BrowserOrder _order = _BrowserOrder.filing;

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

    return PopScope<Object?>(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _isSelecting) _clearSelection();
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          kSearchShortcut: () => openSearch(context, ref),
        },
        child: Focus(autofocus: true, child: _scaffold(context, tree)),
      ),
    );
  }

  /// Back leaves selection mode before it is allowed to leave the Browser.
  void _clearSelection() {
    setState(() {
      _selected.clear();
      _isSelecting = false;
    });
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
        data: _browserBody,
      ),
    );
  }

  /// Making things, search, and the two whole-tree expand controls.
  PreferredSizeWidget _appBar(
    BuildContext context,
    AsyncValue<List<BrowserTreeNode>> tree,
  ) {
    if (_isSelecting) return _selectionAppBar(tree);
    final bool isNarrow = isCompactWidth(context);
    return AppBar(
      title: const Text('Browser'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Tags',
          onPressed: _manageTags,
          icon: const Icon(Icons.label_outline),
        ),
        IconButton(
          tooltip: 'Select elements',
          onPressed: () => setState(() => _isSelecting = true),
          icon: const Icon(Icons.checklist),
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

  /// Batch actions replace navigation while a selection is active.
  PreferredSizeWidget _selectionAppBar(
    AsyncValue<List<BrowserTreeNode>> tree,
  ) => AppBar(
    leading: IconButton(
      tooltip: 'Clear selection',
      onPressed: _clearSelection,
      icon: const Icon(Icons.close),
    ),
    title: Text('${_selected.length} selected'),
    actions: <Widget>[
      IconButton(
        tooltip: 'Select all visible elements',
        onPressed: () =>
            _selectAllVisible(tree.valueOrNull ?? const <BrowserTreeNode>[]),
        icon: const Icon(Icons.select_all),
      ),
      LearningCommandMenu(
        onSelected: _runSelectedLearningCommand,
        isEnabled: _selected.isNotEmpty,
        size: 48,
      ),
      IconButton(
        tooltip: 'Add or remove tags',
        onPressed: _selected.isEmpty ? null : _changeSelectedTags,
        icon: const Icon(Icons.label_outline),
      ),
      IconButton(
        tooltip: 'Delete selected elements',
        onPressed: _selected.isEmpty
            ? null
            : () => unawaited(
                _deleteSelection(tree.valueOrNull ?? const <BrowserTreeNode>[]),
              ),
        icon: const Icon(Icons.delete_outline),
      ),
      const SizedBox(width: 8),
    ],
  );

  void _expandAll(AsyncValue<List<BrowserTreeNode>> tree) {
    setState(() {
      _expanded
        ..clear()
        ..addAll(_allRefs(tree.valueOrNull ?? const <BrowserTreeNode>[]));
    });
  }

  void _selectAllVisible(List<BrowserTreeNode> roots) {
    final List<_TreeRow> rows = _visibleRows(roots);
    setState(() => _selected.addAll(rows.map((_TreeRow row) => row.node.ref)));
  }

  void _toggleSelection(ElementRef ref_) {
    setState(() {
      _isSelecting = true;
      if (!_selected.remove(ref_)) _selected.add(ref_);
    });
  }

  Future<void> _runSelectedLearningCommand(LearningCommand command) async {
    final LearningCommandAnswers? answers = await askForLearningCommand(
      context,
      command,
    );
    if (answers == null || !mounted) return;
    await ref
        .read(browserViewModelProvider.notifier)
        .applyLearningCommandToSelection(
          command,
          _selected.toList(growable: false),
          answers: answers,
        );
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _isSelecting = false;
    });
    ref.invalidate(browserTreeProvider);
  }

  Future<void> _deleteSelection(List<BrowserTreeNode> roots) async {
    final List<BrowserTreeNode> nodes = <BrowserTreeNode>[
      for (final BrowserTreeNode node in _allNodes(roots))
        if (_selected.contains(node.ref)) node,
    ];
    if (!await _confirmDeleteSelection(context, nodes) || !mounted) return;
    await ref
        .read(browserViewModelProvider.notifier)
        .deleteElements(_selected.toList(growable: false));
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _isSelecting = false;
    });
    ref.invalidate(browserTreeProvider);
  }

  /// The type filter above the tree.
  Widget _browserBody(List<BrowserTreeNode> roots) => Column(
    children: <Widget>[
      _TypeFilter(
        selected: _types,
        onChanged: (Set<ElementType> types) => setState(() => _types = types),
        order: _order,
        onOrderChanged: (_BrowserOrder order) => setState(() => _order = order),
      ),
      _TagFilter(
        tags: ref.watch(browserTagsProvider).valueOrNull ?? const <Tag>[],
        selected: _tagIds,
        onChanged: (Set<String> tagIds) => setState(() => _tagIds = tagIds),
        onManage: _manageTags,
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
      case _NewElement.topic:
        await _createTopic(context, under);
      case _NewElement.video:
        await _createVideo(context, under);
      case _NewElement.card:
        await _createCards(context, under);
      case _NewElement.imageOcclusion:
        await _createImageOcclusion(context, under);
    }
  }

  /// Adds a video and opens it, the way an imported chapter is opened.
  ///
  /// There is nothing to read in the dialog the user just filled in — the
  /// video is somewhere else — so the useful next step is always the screen
  /// with the Open button on it.
  Future<void> _createVideo(
    BuildContext context,
    BrowserTreeNode? under,
  ) async {
    final VideoImportRequest? request = await openVideoCreationPage(
      context,
      ref,
    );
    if (request == null || !context.mounted) return;

    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    final String? videoElementId = await model.importVideo(
      url: request.url,
      title: request.title,
      startSeconds: 0,
      endSeconds: request.durationSeconds,
      durationSeconds: request.durationSeconds,
      thumbnailUrl: request.thumbnailUrl,
    );
    if (videoElementId != null && under != null) {
      await model.fileUnder(
        ref_: ElementRef(id: videoElementId, type: ElementType.video),
        parentRef: under.ref,
      );
      setState(() => _expanded.add(under.ref));
    }
    ref.invalidate(browserTreeProvider);
    if (videoElementId == null || !context.mounted) return;
    await openVideo(
      context,
      ref,
      videoElementId: videoElementId,
      mode: VideoMode.scheduled,
    );
    ref.invalidate(browserTreeProvider);
  }

  /// Adds a topic from typed, pasted, or opened Markdown, then opens it.
  Future<void> _createTopic(
    BuildContext context,
    BrowserTreeNode? under,
  ) async {
    final ImportRequest? request = await openTopicCreationPage(context);
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
    if (sourceId == null || !context.mounted) return;
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
    final FormulationResult? formulation = await openFormulationPage(
      context,
      ref: ref,
      seedText: '',
      existingCardCount: under?.children.length ?? 0,
      overlapContextBefore: ref
          .read(settingsStoreProvider)
          .currentOrDefaults
          .cards
          .overlapContextBefore,
      overlapContextAfter: ref
          .read(settingsStoreProvider)
          .currentOrDefaults
          .cards
          .overlapContextAfter,
      parentNoun: under == null ? 'collection' : 'element',
    );
    if (formulation == null || !context.mounted) return;

    final BrowserViewModel model = ref.read(browserViewModelProvider.notifier);
    final List<ElementRef>? created = await model.createCards(
      parent: _cardParentFor(under),
      drafts: formulation.drafts,
      tagIds: formulation.tagIds,
    );
    if (created != null && under != null) {
      for (final ElementRef card in created) {
        await model.fileUnder(ref_: card, parentRef: under.ref);
      }
      setState(() => _expanded.add(under.ref));
    }
    ref.invalidate(browserTreeProvider);
  }

  Future<void> _createImageOcclusion(
    BuildContext context,
    BrowserTreeNode? under,
  ) async {
    try {
      final image = await chooseOcclusionImage(context, ref);
      if (image == null || !context.mounted) return;
      final created = await openOcclusionScreen(
        context,
        ref,
        image: image,
        parent: _cardParentFor(under),
      );
      if (created == null || under == null || !mounted) return;
      final model = ref.read(browserViewModelProvider.notifier);
      for (final card in created) {
        await model.fileUnder(ref_: card, parentRef: under.ref);
      }
      setState(() => _expanded.add(under.ref));
      ref.invalidate(browserTreeProvider);
    } on ReaderImageInputException catch (failure) {
      if (context.mounted) showToast(context, failure.message, isError: true);
    }
  }

  /// What a new card is written *from*, which is not the same as where it is
  /// filed.
  ///
  /// A card can only cite a topic or an extract, so a card added under another
  /// card cites that card's own parent when there is one, and nothing when
  /// there is not. It is still filed exactly where the user asked.
  CardParent? _cardParentFor(BrowserTreeNode? under) {
    final ElementRef? cited = switch (under?.ref.type) {
      ElementType.source ||
      ElementType.extract ||
      ElementType.video => under!.ref,
      ElementType.card => under!.parentRef,
      null => null,
    };
    return switch (cited?.type) {
      ElementType.source => CardParent.source(cited!.id),
      ElementType.extract => CardParent.extract(cited!.id),
      ElementType.video => CardParent.video(cited!.id),
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
      case 'tags':
        await _saveTags(node);
    }
    ref.invalidate(browserTreeProvider);
  }

  Future<void> _saveTags(BrowserTreeNode node) async {
    final Set<String>? chosen = await showTagsPicker(
      context,
      ref,
      initialTagIds: node.directTagIds,
      title: 'Tags on ${node.title}',
    );
    if (chosen == null || !mounted) return;
    final result = await ref
        .read(tagsCommandRunnerProvider)
        .save(
          SaveTagsOfElement(
            OperationId(ref.read(idGeneratorProvider).newId()),
            ref: node.ref,
            tagIds: chosen,
          ),
        );
    if (!mounted) return;
    if (result.isErr) {
      showToast(context, result.failureOrNull!.message, isError: true);
    }
    ref.invalidate(browserTreeProvider);
  }

  /// Keeps renamed filters selected by stable id and drops only tags that the
  /// Tags screen deleted while it was open.
  Future<void> _manageTags() async {
    await openTags(context);
    if (!mounted) return;
    final Set<String> existing = <String>{
      for (final Tag tag in await ref.read(tagRepositoryProvider).listTags())
        tag.id,
    };
    if (!mounted) return;
    setState(() => _tagIds = _tagIds.intersection(existing));
    ref.invalidate(browserTagsProvider);
    ref.invalidate(browserTreeProvider);
  }

  Future<void> _changeSelectedTags() async {
    final bool? shouldInsert = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Change tags on selection'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(true),
            child: const ListTile(
              leading: Icon(Icons.add),
              title: Text('Add tags'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(false),
            child: const ListTile(
              leading: Icon(Icons.remove),
              title: Text('Remove tags'),
            ),
          ),
        ],
      ),
    );
    if (shouldInsert == null || !mounted) return;
    final Set<String>? chosen = await showTagsPicker(context, ref);
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final OperationId operation = OperationId(
      ref.read(idGeneratorProvider).newId(),
    );
    final refs = _selected.toList(growable: false);
    final result = shouldInsert
        ? await ref
              .read(tagsCommandRunnerProvider)
              .insert(
                InsertTagsOnElements(operation, refs: refs, tagIds: chosen),
              )
        : await ref
              .read(tagsCommandRunnerProvider)
              .deleteFromElements(
                DeleteTagsFromElements(operation, refs: refs, tagIds: chosen),
              );
    if (!mounted) return;
    if (result.isErr) {
      showToast(context, result.failureOrNull!.message, isError: true);
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
    final List<_TreeRow> rows = _visibleRows(roots);
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
        isSelectionMode: _isSelecting,
        isSelected: _selected.contains(rows[index].node.ref),
        onSelect: () => _toggleSelection(rows[index].node.ref),
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

  List<_TreeRow> _visibleRows(List<BrowserTreeNode> roots) {
    final List<_TreeRow> rows = <_TreeRow>[];
    for (final BrowserTreeNode root in _ordered(roots)) {
      _flatten(root, 0, rows);
    }
    return rows;
  }

  /// Depth-first walk that emits only what is currently visible.
  ///
  /// A filtered-out node still yields its children: hiding a source would
  /// otherwise hide every card underneath it, which is the opposite of what
  /// filtering to cards means.
  void _flatten(BrowserTreeNode node, int depth, List<_TreeRow> rows) {
    final bool matchesType = _types.isEmpty || _types.contains(node.ref.type);
    final bool matchesTags = node.effectiveTagIds.containsAll(_tagIds);
    final bool matches = matchesType && matchesTags;
    if (matches) rows.add(_TreeRow(node: node, depth: depth));
    final bool shouldShowChildren =
        _expanded.contains(node.ref) ||
        (!matches && (_types.isNotEmpty || _tagIds.isNotEmpty));
    if (!shouldShowChildren) return;
    for (final BrowserTreeNode child in _ordered(node.children)) {
      _flatten(child, matches ? depth + 1 : depth, rows);
    }
  }

  List<BrowserTreeNode> _ordered(List<BrowserTreeNode> nodes) {
    if (_order == _BrowserOrder.filing) return nodes;
    final List<BrowserTreeNode> ordered = <BrowserTreeNode>[...nodes];
    ordered.sort((BrowserTreeNode first, BrowserTreeNode second) {
      final int byAdded = first.addedAtUtc.compareTo(second.addedAtUtc);
      if (byAdded != 0) {
        return _order == _BrowserOrder.addedNewest ? -byAdded : byAdded;
      }
      return first.ref.id.compareTo(second.ref.id);
    });
    return ordered;
  }

  Iterable<ElementRef> _allRefs(List<BrowserTreeNode> nodes) sync* {
    for (final BrowserTreeNode node in nodes) {
      yield node.ref;
      yield* _allRefs(node.children);
    }
  }

  Iterable<BrowserTreeNode> _allNodes(List<BrowserTreeNode> nodes) sync* {
    for (final BrowserTreeNode node in nodes) {
      yield node;
      yield* _allNodes(node.children);
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
  const _TypeFilter({
    required this.selected,
    required this.onChanged,
    required this.order,
    required this.onOrderChanged,
  });

  final Set<ElementType> selected;
  final ValueChanged<Set<ElementType>> onChanged;
  final _BrowserOrder order;
  final ValueChanged<_BrowserOrder> onOrderChanged;

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
              ('Videos', <ElementType>{ElementType.video}),
              ('Cards', <ElementType>{ElementType.card}),
            ])
          FilterChip(
            label: Text(label),
            selected:
                selected.length == types.length && selected.containsAll(types),
            onSelected: (_) => onChanged(types),
          ),
        PopupMenuButton<_BrowserOrder>(
          tooltip: 'Sort order',
          initialValue: order,
          onSelected: onOrderChanged,
          itemBuilder: (BuildContext context) =>
              const <PopupMenuEntry<_BrowserOrder>>[
                PopupMenuItem<_BrowserOrder>(
                  value: _BrowserOrder.filing,
                  child: Text('Filed order'),
                ),
                PopupMenuItem<_BrowserOrder>(
                  value: _BrowserOrder.addedNewest,
                  child: Text('Added — newest first'),
                ),
                PopupMenuItem<_BrowserOrder>(
                  value: _BrowserOrder.addedOldest,
                  child: Text('Added — oldest first'),
                ),
              ],
          child: Chip(
            avatar: const Icon(Icons.sort, size: 17),
            label: Text(switch (order) {
              _BrowserOrder.filing => 'Filed',
              _BrowserOrder.addedNewest => 'Added ↓',
              _BrowserOrder.addedOldest => 'Added ↑',
            }),
          ),
        ),
      ],
    ),
  );
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.selected,
    required this.onChanged,
    required this.onManage,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: <Widget>[
        for (final Tag tag in tags) ...<Widget>[
          FilterChip(
            label: Text('#${tag.name}'),
            selected: selected.contains(tag.id),
            onSelected: (bool isSelected) {
              final Set<String> changed = <String>{...selected};
              isSelected ? changed.add(tag.id) : changed.remove(tag.id);
              onChanged(changed);
            },
          ),
          const SizedBox(width: 6),
        ],
        ActionChip(
          avatar: const Icon(Icons.label_outline, size: 16),
          label: const Text('Tags'),
          onPressed: onManage,
        ),
      ],
    ),
  );
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.row,
    required this.isExpanded,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelect,
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
  final bool isSelectionMode;
  final bool isSelected;

  /// Selects this row. A long press starts selection on touch; the app-bar
  /// Select action provides the same discoverable path for mouse users.
  final VoidCallback onSelect;

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
    if (isSelectionMode) return card;
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
                borderRadius: BorderRadius.circular(AppRadius.row),
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
    final Color restingColor = isDismissed
        ? _kDismissedElementWash
        : AppColors.surface;
    return Material(
      color: isSelected
          ? Color.alphaBlend(AppColors.selection, restingColor)
          : restingColor,
      borderRadius: BorderRadius.circular(AppRadius.row),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.row),
        onTap: isSelectionMode ? onSelect : onOpen,
        onLongPress: onSelect,
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
          _leadingControl(node),
          _expandArrow(hasChildren),
          ElementTypeBadge(type: node.ref.type),
          if (node.thumbnailSource
              case final String thumbnailSource) ...<Widget>[
            const SizedBox(width: 8),
            VideoThumbnail(
              source: thumbnailSource,
              width: 64,
              height: 36,
              borderRadius: 4,
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: _titleSection(node)),
          if (hasChildren) ...<Widget>[
            // How many elements this branch holds, itself excluded.
            _mutedLabel('${node.subtreeSize - 1}'),
            const SizedBox(width: 8),
          ],
          if (node.dueDay != null) _mutedLabel(node.dueDay.toString()),
          if (!isSelectionMode) ..._rowButtons(node, isDismissed),
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
            _leadingControl(node),
            _expandArrow(hasChildren),
            ElementTypeBadge(type: node.ref.type, shouldShowLabel: false),
            if (node.thumbnailSource
                case final String thumbnailSource) ...<Widget>[
              const SizedBox(width: 8),
              VideoThumbnail(
                source: thumbnailSource,
                width: 56,
                height: 32,
                borderRadius: 4,
              ),
            ],
            const SizedBox(width: 8),
            Expanded(child: _titleSection(node)),
          ],
        ),
        Row(
          children: <Widget>[
            const SizedBox(width: _kHandleWidth + _kArrowWidth),
            Expanded(child: _mutedLabel(_metaLine(node, hasChildren))),
            if (!isSelectionMode) ..._rowButtons(node, isDismissed),
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

  Widget _leadingControl(BrowserTreeNode node) => isSelectionMode
      ? SizedBox(
          width: _kHandleWidth,
          child: Checkbox(
            value: isSelected,
            onChanged: (_) => onSelect(),
            visualDensity: VisualDensity.compact,
          ),
        )
      : _dragHandle(node);

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

  /// A dismissed element keeps normal readable text. Its yellow row wash is
  /// the familiar "suspended" signal and makes clear the content still exists.
  Widget _titleSection(BrowserTreeNode node) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          node.title.isEmpty ? '(untitled)' : node.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (node.tagNames.isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          ColoredTagList(tagNames: node.tagNames, maximumVisibleTags: 3),
        ],
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
          const PopupMenuItem<String>(value: 'tags', child: Text('Tags…')),
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

/// The warm wash used by Anki-style suspended notes without obscuring text.
const Color _kDismissedElementWash = AppColors.dismissedWash;

/// What the New menu can make.
enum _NewElement {
  /// A topic typed, pasted, or opened from a Markdown file.
  topic,

  /// A video, studied by its timestamps rather than its text.
  video,

  /// One or more cards, through the same formulation dialog the Reader uses.
  card,

  /// Cards made by masking regions of one image.
  imageOcclusion,
}

/// The New menu, in the app bar and on every row.
///
/// Extracts are deliberately not here. An extract is a passage cut out of
/// something, and it carries the exact range it was cut from; there is no such
/// range to record for one typed into a menu, so extracts are still made by
/// selecting text in the Reader.
class _NewElementMenu extends StatelessWidget {
  const _NewElementMenu({required this.onSelected, this.isRowMenu = false});

  final ValueChanged<_NewElement> onSelected;

  /// A row's menu is smaller and unlabelled whatever the width.
  final bool isRowMenu;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_NewElement>(
    tooltip: isRowMenu ? 'New element here' : 'New',
    onSelected: onSelected,
    icon: isRowMenu ? const Icon(Icons.add, size: 17) : null,
    itemBuilder: (BuildContext context) => const <PopupMenuEntry<_NewElement>>[
      PopupMenuItem<_NewElement>(
        value: _NewElement.topic,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.article_outlined),
          title: Text('Topic'),
        ),
      ),
      PopupMenuItem<_NewElement>(
        value: _NewElement.video,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.smart_display_outlined),
          title: Text('Video'),
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
      PopupMenuItem<_NewElement>(
        value: _NewElement.imageOcclusion,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.image_outlined),
          title: Text('Image occlusion'),
        ),
      ),
    ],
    child: isRowMenu
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
    borderRadius: BorderRadius.circular(AppRadius.row),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(AppRadius.row),
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

/// Confirms the exact union of selected branches, since selecting a parent and
/// its child must not make the warning count that child twice.
Future<bool> _confirmDeleteSelection(
  BuildContext context,
  List<BrowserTreeNode> selectedNodes,
) async {
  final Set<ElementRef> doomed = <ElementRef>{};
  void collect(BrowserTreeNode node) {
    doomed.add(node.ref);
    for (final BrowserTreeNode child in node.children) {
      collect(child);
    }
  }

  for (final BrowserTreeNode node in selectedNodes) {
    collect(node);
  }
  final int selectedCount = selectedNodes.length;
  final int descendantCount = doomed.length - selectedCount;
  final bool? didConfirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('Delete $selectedCount selected?'),
      content: Text(
        descendantCount == 0
            ? 'This erases the selected element'
                  '${selectedCount == 1 ? '' : 's'}. There is no undo.'
            : 'This erases the selected elements and $descendantCount '
                  'element${descendantCount == 1 ? '' : 's'} filed under '
                  'them. There is no undo.',
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
  );
  return didConfirm ?? false;
}
