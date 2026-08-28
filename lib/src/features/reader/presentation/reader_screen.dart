/// The Reader screen: continuous scrolling with compact persistent bars.
///
/// The bars carry the whole scheduling vocabulary of a reading session — Done,
/// Later, Finish — and they are visible only in scheduled mode. In browse mode
/// the same document is readable but inert, because looking something up must
/// never be mistaken for having processed it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:incremental_reader/src/app/theme.dart';
import 'package:incremental_reader/src/app/toast.dart';
import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/extract.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/features/extract/presentation/extract_context_overlay.dart';
import 'package:incremental_reader/src/features/extract/presentation/formulation_dialog.dart';
import 'package:incremental_reader/src/features/library/presentation/library_view_model.dart';
import 'package:incremental_reader/src/features/priority/presentation/priority_dialog.dart';
import 'package:incremental_reader/src/features/queue/presentation/study_route_result.dart';
import 'package:incremental_reader/src/features/reader/presentation/block_span_builder.dart';
import 'package:incremental_reader/src/features/reader/presentation/extract_highlights.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_selection.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_side_panel.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_view.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_view_model.dart';
import 'package:incremental_reader/src/features/reader/presentation/selection_toolbar.dart';
import 'package:incremental_reader/src/features/reader/presentation/typography_controller.dart';

/// Pushes the Reader for [sourceId] and refreshes the Library on return.
Future<void> openReader(
  BuildContext context,
  WidgetRef ref, {
  required String sourceId,
  required ReaderMode mode,
  ReaderAnchor? initialAnchor,
}) async {
  await Navigator.of(context).push<StudyRouteResult>(
    MaterialPageRoute<StudyRouteResult>(
      builder: (BuildContext context) => ReaderScreen(
        request: ReaderRequest(
          sourceId: sourceId,
          mode: mode,
          initialAnchor: initialAnchor,
        ),
      ),
    ),
  );
  await ref.read(libraryViewModelProvider.notifier).refresh();
}

/// Opens a source from the queue and reports whether a terminal action
/// committed. Back remains a cancellation and leaves the source due.
Future<StudyRouteResult> openReaderForStudy(
  BuildContext context,
  WidgetRef ref, {
  required String sourceId,
  required ReaderMode mode,
  ReaderAnchor? initialAnchor,
}) async =>
    await Navigator.of(context).push<StudyRouteResult>(
      MaterialPageRoute<StudyRouteResult>(
        builder: (BuildContext context) => ReaderScreen(
          request: ReaderRequest(
            sourceId: sourceId,
            mode: mode,
            initialAnchor: initialAnchor,
          ),
        ),
      ),
    ) ??
    StudyRouteResult.canceled;

/// Reads one source.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.request, super.key});

  final ReaderRequest request;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final GlobalKey<ReaderViewState> _readerKey = GlobalKey<ReaderViewState>();
  final GlobalKey _surfaceKey = GlobalKey();
  ReaderSelectionController? _selection;
  bool _openedAtMarker = false;

  /// Open by default: the outline is how a 50k-word chapter stays navigable,
  /// and the extract list is the record of what has already been processed.
  /// Both are context for reading, not a tool the user should have to fetch.
  bool _panelOpen = true;
  ReaderPanelTab _panelTab = ReaderPanelTab.outline;

  /// Topmost visible block, so the outline can follow the reader.
  String? _currentBlockId;

  /// The extract chosen in the panel, painted in the stronger wash.
  String? _focusedExtractId;

  List<Extract>? _highlightedExtracts;
  String? _highlightedFocusId;
  Map<String, List<BlockHighlight>> _extractHighlights =
      const <String, List<BlockHighlight>>{};
  Map<String, int> _extractMarks = const <String, int>{};

  @override
  void dispose() {
    _selection?.dispose();
    super.dispose();
  }

  /// Converts a global rectangle into the reading surface's own coordinates.
  ///
  /// The selection controller works in screen space because that is what
  /// render objects report; the toolbar lives inside a stack that starts below
  /// the app bar, so the two have to be reconciled somewhere.
  Rect? _toSurfaceSpace(Rect global) {
    final box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return global.shift(-box.localToGlobal(Offset.zero));
  }

  Size? get _surfaceSize {
    final box = _surfaceKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  /// Recomputes the extract washes only when the extracts or the focus change.
  ///
  /// The Reader rebuilds on every scroll tick to keep the outline in step, and
  /// re-deriving every provenance range at that rate would be work for
  /// nothing.
  void _syncExtractPainting(ReaderUiState state) {
    if (identical(_highlightedExtracts, state.extracts) &&
        _highlightedFocusId == _focusedExtractId) {
      return;
    }
    _highlightedExtracts = state.extracts;
    _highlightedFocusId = _focusedExtractId;
    _extractHighlights = buildExtractHighlights(
      state.document,
      state.extracts,
      focusedExtractId: _focusedExtractId,
    );
    _extractMarks = extractMarksByCoveredBlock(state.document, state.extracts);
  }

  /// Tracks the block under the top of the viewport for the outline.
  void _updateCurrentBlock(String? blockId) {
    if (blockId == null || _currentBlockId == blockId) return;
    if (!mounted) return;
    setState(() => _currentBlockId = blockId);
  }

  /// Scrolls to the start of [blockId], which the outline names by id.
  ///
  /// The outline is built from the document in hand, so a block id is a valid
  /// way to point at a row of it. The anchor it produces is a byte offset, and
  /// only that offset is ever stored.
  Future<void> _animateToBlock(Document document, String blockId) async {
    final Block? block = document.blockById(blockId);
    if (block == null) return;
    await _readerKey.currentState?.animateToAnchor(
      ReaderAnchor(
        utf8Offset: block.sourceStartUtf8,
        contentRevision: document.contentRevision,
      ),
    );
  }

  /// Scrolls to an extract and paints it, so choosing one in the panel lands
  /// on a visible passage instead of an unmarked position. Choosing the same
  /// one again clears the paint.
  void _goToExtract(Extract extract) {
    final bool clearing = _focusedExtractId == extract.id;
    setState(() => _focusedExtractId = clearing ? null : extract.id);
    if (clearing) return;
    unawaited(
      _readerKey.currentState?.animateToAnchor(
            extract.provenance.startAnchor,
            alignment: 0.3,
          ) ??
          Future<void>.value(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = readerViewModelProvider(widget.request);
    final state = ref.watch(provider);
    final model = ref.read(provider.notifier);
    final typography = ref.watch(readerTypographyProvider);

    ref.listen<AsyncValue<ReaderUiState>>(provider, (
      AsyncValue<ReaderUiState>? previous,
      AsyncValue<ReaderUiState> next,
    ) {
      final data = next.valueOrNull;
      if (data == null) return;

      final message = data.message;
      if (message != null) {
        final undoId = data.lastExtractId;
        showToast(
          context,
          message.text,
          isError: message.isError,
          actionLabel: undoId == null || message.isError ? null : 'Undo',
          onAction: undoId == null || message.isError
              ? null
              : () => unawaited(model.undoExtract(undoId)),
        );
        model.clearMessage();
      }
      if (data.isDone && Navigator.of(context).canPop()) {
        // Consume the signal before leaving. It is retained state on a keyed
        // family provider, so an uncleared flag re-fires on the next open of
        // the same source and pops it again instantly.
        final bool repetition = data.wasRepetition;
        model.clearDone();
        Navigator.of(
          context,
        ).pop(repetition ? StudyRouteResult.committed : StudyRouteResult.moved);
      }
    });

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not open this source.\n$error')),
      ),
      data: (ReaderUiState data) =>
          _buildReader(context, data, model, typography),
    );
  }

  Widget _buildReader(
    BuildContext context,
    ReaderUiState state,
    ReaderViewModel model,
    ReaderTypography typography,
  ) {
    final controller = _selection ??= ReaderSelectionController(state.document);
    _syncExtractPainting(state);

    // Opening at the marker happens once per screen, not on every rebuild:
    // otherwise scrolling away would keep snapping the reader back.
    if (!_openedAtMarker && state.openedAt != null) {
      _openedAtMarker = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _readerKey.currentState?.jumpToAnchor(state.openedAt!);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(state.source.title),
        actions: <Widget>[
          if (state.mode == ReaderMode.browse)
            TextButton(
              onPressed: model.continueScheduled,
              child: const Text('Continue reading'),
            ),
          IconButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => const _TypographyDialog(),
            ),
            icon: const Icon(Icons.text_fields),
            tooltip: 'Reading appearance',
          ),
          IconButton(
            onPressed: () => setState(() => _panelOpen = !_panelOpen),
            icon: Icon(
              _panelOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            ),
            color: _panelOpen ? AppColors.accent : null,
            tooltip: _panelOpen
                ? 'Hide outline and extracts'
                : 'Show outline and extracts',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          // Keyboard-first on Windows: the three terminal actions and the
          // marker are reachable without leaving the keyboard.
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              model.done,
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
              model.later(),
          const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
            final anchor = _readerKey.currentState?.topVisibleAnchor;
            if (anchor != null) unawaited(model.placeMarkerAt(anchor));
          },
          const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
              _extractSelection(model),
          // SuperMemo's own key for "make an item out of this".
          const SingleActivator(LogicalKeyboardKey.keyZ, alt: true): () =>
              unawaited(_formulate(model, state)),
          // And its key for "how important is this?".
          kPriorityShortcut: () => unawaited(
            showPriorityDialog(context, ref, elementRef: state.topic.ref),
          ),
        },
        child: Focus(
          // Not while a block is open in the editor: a rebuild that re-attaches
          // this node would otherwise reclaim focus from the field mid-word.
          autofocus: !state.isEditing,
          child: Column(
            children: <Widget>[
              _StatusBar(state: state),
              if (state.showSoftPositionBanner)
                _SoftPositionBanner(
                  onConfirm: model.confirmSoftPosition,
                  onDismiss: model.dismissSoftBanner,
                  onGoTo: () {
                    final anchor = state.source.resume.softPosition;
                    if (anchor != null) {
                      _readerKey.currentState?.animateToAnchor(anchor);
                    }
                  },
                ),
              if (state.showReminder)
                _ReminderLine(
                  words: state.wordsThisSession,
                  onDismiss: model.dismissReminder,
                  onDone: model.done,
                ),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Stack(
                        key: _surfaceKey,
                        children: <Widget>[
                          ReaderView(
                            key: _readerKey,
                            document: state.document,
                            controller: controller,
                            typography: typography,
                            marker: state.marker,
                            softPosition: state.softPosition,
                            onGutterTap: state.canCommitProgress
                                ? model.placeMarkerAt
                                : null,
                            extractMarks: _extractMarks,
                            extractHighlights: _extractHighlights,
                            onExtractMarksTap: (Block block) =>
                                _openContext(context, state, model, block),
                            onVisiblePositionChanged: (ReaderAnchor anchor) {
                              unawaited(model.recordPosition(anchor));
                              _updateCurrentBlock(
                                state.document.blockForAnchor(anchor)?.id,
                              );
                            },
                            editingBlockId: state.editingBlockId,
                            isBusy: state.isBusy,
                            onEditCommit: (Block block, String markdown) =>
                                unawaited(model.commitEdit(block, markdown)),
                            onEditCancel: (Block _) => model.cancelEditing(),
                            onEditDelete: (Block block) =>
                                unawaited(model.deleteBlock(block)),
                          ),
                          _SelectionToolbarLayer(
                            controller: controller,
                            canCommitProgress: state.canCommitProgress,
                            toSurfaceSpace: _toSurfaceSpace,
                            surfaceSize: () => _surfaceSize,
                            onExtract: () => _extractSelection(model),
                            onSetMarker: () {
                              final anchor = controller
                                  .resolveSelection()
                                  ?.range
                                  .startAnchor;
                              if (anchor != null) {
                                unawaited(model.placeMarkerAt(anchor));
                                controller.clear();
                              }
                            },
                            onCopy: () {
                              final resolved = controller.resolveSelection();
                              if (resolved == null) return;
                              unawaited(
                                Clipboard.setData(
                                  ClipboardData(text: resolved.markdown),
                                ),
                              );
                              showToast(context, 'Copied');
                            },
                            onEditBlock: !state.canCommitProgress
                                ? null
                                : () {
                                    final anchor = controller
                                        .resolveSelection()
                                        ?.range
                                        .startAnchor;
                                    if (anchor == null) return;
                                    final block = state.document
                                        .blockForAnchor(anchor);
                                    if (block == null) return;
                                    controller.clear();
                                    model.beginEditing(block);
                                  },
                          ),
                        ],
                      ),
                    ),
                    if (_panelOpen)
                      ReaderSidePanel(
                        document: state.document,
                        extracts: state.extracts,
                        tab: _panelTab,
                        currentBlockId: _currentBlockId,
                        focusedExtractId: _focusedExtractId,
                        onTabChanged: (ReaderPanelTab next) =>
                            setState(() => _panelTab = next),
                        onGoToBlock: (String blockId) => unawaited(
                          _animateToBlock(state.document, blockId),
                        ),
                        onGoToExtract: _goToExtract,
                        onClose: () => setState(() => _panelOpen = false),
                      ),
                  ],
                ),
              ),
              _ActionBar(
                state: state,
                model: model,
                controller: controller,
                onExtract: () => _extractSelection(model),
                onFormulate: () => unawaited(_formulate(model, state)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Extracts whatever is selected, then clears the selection.
  ///
  /// The viewport, the marker, and the schedule are all deliberately
  /// untouched: the point of frictionless extraction is that reading
  /// continues exactly where it was.
  Future<void> _extractSelection(ReaderViewModel model) async {
    if (_selection?.canExtract != true) return;
    final resolved = _selection?.resolveSelection();
    if (resolved == null) return;
    final created = await model.extractSelection(resolved.range);
    if (created != null) _selection?.clear();
  }

  /// Formulates cards straight from this article.
  ///
  /// Seeded with the current selection when there is one, which is the
  /// SuperMemo gesture: select the sentence, make the item, keep reading. The
  /// article's own schedule and marker are untouched either way.
  Future<void> _formulate(ReaderViewModel model, ReaderUiState state) async {
    if (!state.canCommitProgress || state.isBusy) return;
    final resolved = _selection?.resolveSelection();
    final drafts = await showFormulationDialog(
      context,
      seedText: resolved?.markdown ?? '',
      existingCardCount: state.cardsFromSource,
      parentNoun: 'article',
    );
    if (drafts == null) return;
    final created = await model.formulate(drafts);
    if (created) _selection?.clear();
  }

  /// Opens the browse-only context overlay for a block's extracts.
  Future<void> _openContext(
    BuildContext context,
    ReaderUiState state,
    ReaderViewModel model,
    Block block,
  ) async {
    final extracts = extractsCoveringBlock(
      state.document,
      state.extracts,
      block.id,
    );
    if (extracts.isEmpty) return;

    final action = await showExtractContext(
      context,
      document: state.document,
      block: block,
      extracts: extracts,
    );
    if (action == null) return;

    await _readerKey.currentState?.animateToAnchor(action.anchor);
  }
}

/// Shows the selection toolbar while a selection exists on screen.
///
/// Rebuilt from the controller rather than from screen state so that dragging
/// a selection moves the toolbar with it without the whole Reader rebuilding.
class _SelectionToolbarLayer extends StatelessWidget {
  const _SelectionToolbarLayer({
    required this.controller,
    required this.canCommitProgress,
    required this.toSurfaceSpace,
    required this.surfaceSize,
    required this.onExtract,
    required this.onSetMarker,
    required this.onCopy,
    required this.onEditBlock,
  });

  final ReaderSelectionController controller;
  final bool canCommitProgress;
  final Rect? Function(Rect global) toSurfaceSpace;
  final Size? Function() surfaceSize;
  final VoidCallback onExtract;
  final VoidCallback onSetMarker;
  final VoidCallback onCopy;
  final VoidCallback? onEditBlock;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (BuildContext context, Widget? child) {
      final global = controller.selectionBoundsGlobal();
      final size = surfaceSize();
      if (global == null || size == null) return const SizedBox.shrink();
      final local = toSurfaceSpace(global);
      if (local == null) return const SizedBox.shrink();

      return SelectionToolbar(
        anchorRect: local,
        viewportSize: size,
        canExtract: canCommitProgress && controller.canExtract,
        canSetMarker: canCommitProgress,
        extractHint: !canCommitProgress
            ? 'Choose Continue reading to extract from this source'
            : 'Extraction spanning several blocks is not supported yet',
        onExtract: onExtract,
        onSetMarker: onSetMarker,
        onCopy: onCopy,
        onEditBlock: onEditBlock,
      );
    },
  );
}

class _TypographyDialog extends ConsumerWidget {
  const _TypographyDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = ref.watch(readerTypographyProvider);
    final model = ref.read(readerTypographyProvider.notifier);
    return AlertDialog(
      title: const Text('Reading appearance'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TypographySlider(
              label: 'Text size',
              value: typography.fontSize,
              min: kMinFontSize,
              max: kMaxFontSize,
              divisions: (kMaxFontSize - kMinFontSize).round(),
              onChanged: (double value) =>
                  model.nudgeFontSize(value - typography.fontSize),
            ),
            _TypographySlider(
              label: 'Column width',
              value: typography.columnWidth,
              min: 520,
              max: 1100,
              divisions: 29,
              onChanged: model.setColumnWidth,
            ),
            _TypographySlider(
              label: 'Line height',
              value: typography.lineHeight,
              min: 1.3,
              max: 2.2,
              divisions: 18,
              onChanged: model.setLineHeight,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: model.reset, child: const Text('Reset')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _TypographySlider extends StatelessWidget {
  const _TypographySlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 100, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          label: value.toStringAsFixed(1),
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state});

  final ReaderUiState state;

  @override
  Widget build(BuildContext context) {
    final due = state.effectiveDueDay ?? state.topic.schedule.algorithmicDueDay;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
        child: Row(
          children: <Widget>[
            if (state.mode == ReaderMode.browse) ...<Widget>[
              const _Pill(text: 'Browsing', color: AppColors.softMarker),
              const SizedBox(width: 12),
              const Text('Nothing here changes progress or scheduling'),
            ] else ...<Widget>[
              const _Pill(text: 'Reading today', color: AppColors.accent),
              const SizedBox(width: 12),
              Text(
                state.marker == null
                    ? 'No marker placed yet'
                    : '${state.progressPercent.toStringAsFixed(0)}% processed',
              ),
            ],
            const Spacer(),
            Text('Repetitions ${state.topic.repetitionCount} · next $due'),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );
}

/// Offers the forgotten-marker recovery without acting on its own.
class _SoftPositionBanner extends StatelessWidget {
  const _SoftPositionBanner({
    required this.onConfirm,
    required this.onDismiss,
    required this.onGoTo,
  });

  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  final VoidCallback onGoTo;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    color: AppColors.softMarker.withValues(alpha: 0.1),
    child: Row(
      children: <Widget>[
        const Icon(Icons.history, size: 15, color: AppColors.softMarker),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'You were here last time, but no marker was placed.',
            style: TextStyle(fontSize: 12, color: AppColors.text),
          ),
        ),
        TextButton(onPressed: onGoTo, child: const Text('Go there')),
        TextButton(
          onPressed: onConfirm,
          child: const Text('Make it the marker'),
        ),
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Dismiss for this session',
        ),
      ],
    ),
  );
}

/// The nonblocking session reminder.
class _ReminderLine extends StatelessWidget {
  const _ReminderLine({
    required this.words,
    required this.onDismiss,
    required this.onDone,
  });

  final int words;
  final VoidCallback onDismiss;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    color: AppColors.accent.withValues(alpha: 0.08),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'About $words words this session. A good place to stop — '
            'place the marker and press Done.',
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
        ),
        TextButton(onPressed: onDone, child: const Text('Done')),
        IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close, size: 15),
          tooltip: 'Keep reading',
        ),
      ],
    ),
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.state,
    required this.model,
    required this.controller,
    required this.onExtract,
    required this.onFormulate,
  });

  final ReaderUiState state;
  final ReaderViewModel model;
  final ReaderSelectionController controller;
  final VoidCallback onExtract;
  final VoidCallback onFormulate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) => Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _hintFor(controller),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            OutlinedButton(
              onPressed:
                  state.canCommitProgress &&
                      !state.isBusy &&
                      controller.canExtract
                  ? onExtract
                  : null,
              child: const Text('Extract'),
            ),
            const SizedBox(width: 6),
            if (state.canCommitProgress) ...<Widget>[
              // Undoing an edit is a text operation, not a scheduling one, so
              // it sits with the content actions and never touches the due
              // date. It appends the reverse splice rather than rewinding.
              if (state.canUndoEdit) ...<Widget>[
                TextButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () => unawaited(model.undoEdit()),
                  icon: const Icon(Icons.undo, size: 15),
                  label: const Text('Undo edit'),
                ),
                const SizedBox(width: 6),
              ],
              OutlinedButton(
                onPressed: state.isBusy ? null : onFormulate,
                child: const Text('Formulate'),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: state.isBusy ? null : model.dismiss,
                child: const Text('Dismiss source'),
              ),
              const SizedBox(width: 6),
              // Two different commands, deliberately distinct. Later Today
              // moves the element inside today's queue and leaves the due
              // date alone, so it comes back in this same session; Postpone
              // takes it off today entirely.
              OutlinedButton(
                onPressed: state.isBusy ? null : model.later,
                child: const Text('Later today'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: state.isBusy
                    ? null
                    : () async {
                        final int? days = await _promptForDays(context);
                        if (days != null) await model.later(days: days);
                      },
                child: const Text('Postpone…'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: state.isBusy ? null : model.done,
                child: const Text('Done'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _hintFor(ReaderSelectionController selection) {
    if (!state.canCommitProgress) {
      return 'Browsing is read-only. Choose Continue reading to extract.';
    }
    if (selection.hasSelection && !selection.canExtract) {
      return 'Multi-block extraction arrives in M5. Select within one block.';
    }
    if (selection.canExtract) {
      return 'Selection ready — Extract (Ctrl+E) keeps your place.';
    }
    return 'Select text to extract. Click the left margin to place the marker.';
  }
}

/// Asks how many days to push an element out by.
Future<int?> _promptForDays(BuildContext context) async {
  final TextEditingController controller = TextEditingController(text: '1');
  try {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final int? value = int.tryParse(controller.text.trim());
          final bool valid = value != null && value >= 1 && value <= 3650;
          return AlertDialog(
            title: const Text('Postpone by'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Moves the next repetition this many days out. It is a '
                    'reschedule, not a repetition: the A-factor, priority '
                    'and repetition count are left alone.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      helperText: '1-3650 days',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.of(context).pop(value)
                    : null,
                child: const Text('Postpone'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}
