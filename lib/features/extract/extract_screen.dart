/// Processing surface for an independently scheduled extract.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/extract_context_overlay.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/reader/typography_controller.dart';
import 'package:incremental_reader/features/reader/widgets/extract_highlights.dart';
import 'package:incremental_reader/features/reader/widgets/reader_selection.dart';
import 'package:incremental_reader/features/reader/widgets/reader_view.dart';
import 'package:incremental_reader/features/reader/widgets/selection_knobs.dart';
import 'package:incremental_reader/features/reader/widgets/selection_toolbar.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

Future<StudyRouteResult> openExtract(
  BuildContext context,
  WidgetRef ref, {
  required String extractId,
  required ExtractMode mode,
  ReaderAnchor? initialAnchor,
}) async =>
    await Navigator.of(context).push<StudyRouteResult>(
      MaterialPageRoute<StudyRouteResult>(
        builder: (BuildContext context) => ExtractScreen(
          request: ExtractRequest(
            extractId: extractId,
            mode: mode,
            initialAnchor: initialAnchor,
          ),
        ),
      ),
    ) ??
    StudyRouteResult.canceled;

class ExtractScreen extends ConsumerStatefulWidget {
  const ExtractScreen({required this.request, super.key});

  final ExtractRequest request;

  @override
  ConsumerState<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends ConsumerState<ExtractScreen> {
  final GlobalKey<ReaderViewState> _readerKey = GlobalKey<ReaderViewState>();
  final GlobalKey _surfaceKey = GlobalKey();
  ReaderSelectionController? _selection;
  String? _documentIdentity;
  bool _hasOpenedAtAnchor = false;

  /// Converts a global rectangle into the reading surface's own coordinates.
  ///
  /// The selection controller works in screen space because that is what
  /// render objects report; the toolbar lives inside a stack that starts below
  /// the status bar, so the two have to be reconciled somewhere.
  Rect? _toSurfaceSpace(Rect global) {
    final RenderObject? box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return global.shift(-box.localToGlobal(Offset.zero));
  }

  /// The same conversion for a single point, which the selection knobs need.
  Offset? _toSurfacePoint(Offset global) {
    final RenderObject? box = _surfaceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return global - box.localToGlobal(Offset.zero);
  }

  Size? get _surfaceSize {
    final RenderObject? box = _surfaceKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  @override
  void dispose() {
    _selection?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = extractViewModelProvider(widget.request);
    final asyncState = ref.watch(provider);
    final model = ref.read(provider.notifier);

    ref.listen<AsyncValue<ExtractUiState>>(provider, (
      AsyncValue<ExtractUiState>? previous,
      AsyncValue<ExtractUiState> next,
    ) {
      final state = next.valueOrNull;
      if (state == null) return;
      final message = state.message;
      if (message != null) {
        final undoId = message.text == 'Extracted' ? state.lastExtractId : null;
        showToast(
          context,
          message.text,
          isError: message.isError,
          actionLabel: undoId == null ? null : 'Undo',
          onAction: undoId == null
              ? null
              : () => unawaited(model.undoExtract(undoId)),
        );
        model.shouldClearMessage();
      }
      if (state.isDone && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(StudyRouteResult.committed);
      }
    });

    return asyncState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not open this extract.\n$error')),
      ),
      data: (ExtractUiState state) => _buildExtract(context, state, model),
    );
  }

  /// The Extract screen, top to bottom: status bar, the extract's text with
  /// the selection toolbar over it, then the action bar.
  Widget _buildExtract(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
  ) {
    final selection = _selectionFor(state.document);
    final typography = ref.watch(readerTypographyProvider);

    // Opening at the anchor happens once per screen, not on every rebuild:
    // otherwise scrolling away would keep snapping back.
    final initialAnchor = widget.request.initialAnchor;
    if (!_hasOpenedAtAnchor &&
        initialAnchor != null &&
        state.document.containsAnchor(initialAnchor)) {
      _hasOpenedAtAnchor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _readerKey.currentState?.jumpToAnchor(initialAnchor);
      });
    }

    return Scaffold(
      appBar: _appBar(context, state, model),
      body: CallbackShortcuts(
        bindings: _keyboardShortcuts(context, state, model),
        child: Focus(
          autofocus: true,
          child: Column(
            children: <Widget>[
              _ExtractStatusBar(state: state),
              Expanded(
                child: _extractSurface(
                  context,
                  state,
                  model,
                  typography,
                  selection,
                ),
              ),
              _ExtractActionBar(
                state: state,
                selection: selection,
                onFormulate: () => _formulate(context, state, model),
                onDismiss: () => _dismiss(context, model),
                onLater: model.later,
                onDone: model.done,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The title bar: reaching the parent, and editing the extract's own words.
  PreferredSizeWidget _appBar(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
  ) {
    return AppBar(
      title: const Text('Process extract'),
      actions: <Widget>[
        if (!state.canMutate)
          TextButton(
            onPressed: model.continueScheduled,
            child: const Text('Process now'),
          ),
        IconButton(
          onPressed: () => _openParent(context, state),
          icon: const Icon(Icons.account_tree_outlined),
          tooltip: 'Open parent',
        ),
        IconButton(
          // Editing the words is allowed while browsing; processing the
          // element is not.
          onPressed: state.isBusy ? null : () => _edit(context, state, model),
          icon: const Icon(Icons.edit_outlined),
          tooltip: state.canEdit
              ? 'Edit extract'
              : 'Nested extracts depend on this text',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Map<ShortcutActivator, VoidCallback> _keyboardShortcuts(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
  ) {
    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          model.done,
      const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
          model.later(),
      const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
          _extractSelection(model),
      kPriorityShortcut: () => unawaited(
        showPriorityDialog(context, ref, elementRef: state.topic.ref),
      ),
    };
  }

  /// The extract's text, with the selection toolbar floating over it.
  ///
  /// Selecting inside an extract is how a further extract is cut, so the same
  /// toolbar belongs here. There is no marker: an extract is processed whole
  /// rather than resumed part-way through.
  Widget _extractSurface(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
    ReaderTypography typography,
    ReaderSelectionController selection,
  ) {
    return Stack(
      key: _surfaceKey,
      children: <Widget>[
        ReaderView(
          key: _readerKey,
          document: state.document,
          controller: selection,
          typography: typography,
          extractMarks: extractMarksByCoveredBlock(
            state.document,
            state.children,
          ),
          extractHighlights: buildExtractHighlights(
            state.document,
            state.children,
          ),
          onExtractMarksTap: (Block block) =>
              _openChildContext(context, state, block),
        ),
        // Filled rather than left to size itself: its knobs are positioned,
        // and a stack of nothing but positioned children collapses to a point
        // that no finger can reach.
        Positioned.fill(
          child: SelectionKnobLayer(
            controller: selection,
            toSurfaceSpace: _toSurfacePoint,
          ),
        ),
        SelectionToolbarLayer(
          controller: selection,
          canExtract: state.canMutate,
          extractHint: !state.canMutate
              ? 'Choose Process now to extract from this extract'
              : 'Extraction spanning several blocks is not supported yet',
          toSurfaceSpace: _toSurfaceSpace,
          surfaceSize: () => _surfaceSize,
          onExtract: () => _extractSelection(model),
          onCopy: () {
            final resolved = selection.resolveSelection();
            if (resolved == null) return;
            unawaited(
              Clipboard.setData(ClipboardData(text: resolved.markdown)),
            );
            showToast(context, 'Copied');
          },
          onEditBlock: state.isBusy
              ? null
              : () => unawaited(_edit(context, state, model)),
        ),
      ],
    );
  }

  ReaderSelectionController _selectionFor(Document document) {
    final identity = '${document.sourceId}:${document.markdown.hashCode}';
    if (_selection != null && _documentIdentity == identity) return _selection!;
    final old = _selection;
    _selection = ReaderSelectionController(document);
    _documentIdentity = identity;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    return _selection!;
  }

  Future<void> _extractSelection(ExtractViewModel model) async {
    if (_selection?.canExtract != true) return;
    final resolved = _selection?.resolveSelection();
    if (resolved == null) return;
    final created = await model.extractSelection(resolved.range);
    if (created != null) _selection?.clear();
  }

  Future<void> _edit(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
  ) async {
    if (!state.canEdit) {
      showToast(
        context,
        'This extract has nested extracts, so its coordinates must stay fixed.',
        isError: true,
      );
      return;
    }
    final controller = TextEditingController(text: state.extract.markdown);
    final markdown = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Edit extract'),
        content: SizedBox(
          width: dialogContentWidth(context, preferred: 620),
          child: TextField(
            controller: controller,
            autofocus: true,
            // Eight lines plus a title, two buttons and an open keyboard is
            // more height than a phone has, and the field scrolls anyway.
            minLines: isCompactWidth(context) ? 4 : 8,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: 'Markdown',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (markdown != null) await model.edit(markdown);
  }

  Future<void> _openParent(BuildContext context, ExtractUiState state) async {
    final provenance = state.extract.provenance;
    if (provenance.hasSourceAsParent) {
      await openReader(
        context,
        ref,
        sourceId: provenance.parentId,
        mode: ReaderMode.browse,
        initialAnchor: provenance.startAnchor,
      );
    } else {
      await openExtract(
        context,
        ref,
        extractId: provenance.parentId,
        mode: ExtractMode.browse,
        initialAnchor: provenance.startAnchor,
      );
    }
  }

  Future<void> _openChildContext(
    BuildContext context,
    ExtractUiState state,
    Block block,
  ) async {
    final extracts = extractsCoveringBlock(
      state.document,
      state.children,
      block.id,
    );
    if (extracts.isEmpty) return;
    final action = await showExtractContext(
      context,
      document: state.document,
      block: block,
      extracts: extracts,
    );
    if (action == null || !context.mounted) return;
    final matching = extracts.where(
      (extract) => extract.id == action.extractId,
    );
    if (matching.isNotEmpty) {
      await openExtract(
        context,
        ref,
        extractId: matching.first.id,
        mode: ExtractMode.browse,
      );
    }
  }

  Future<void> _formulate(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
  ) async {
    final drafts = await showFormulationDialog(
      context,
      seedText: state.extract.markdown,
      existingCardCount: state.cards.length,
    );
    if (drafts != null) await model.formulate(drafts);
  }

  Future<void> _dismiss(BuildContext context, ExtractViewModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Dismiss extract?'),
        content: const Text(
          'The extract, its nested extracts, and its cards stay available. '
          'Only this extract leaves the learning queue.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await model.dismiss();
  }
}

class _ExtractStatusBar extends StatelessWidget {
  const _ExtractStatusBar({required this.state});

  final ExtractUiState state;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    // The same trade the Reader's bar makes: nothing here is droppable, so on
    // a narrow window the three parts wrap rather than overflow.
    child: isCompactWidth(context)
        ? Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _statusParts(),
          )
        : Row(
            children: <Widget>[
              ..._statusParts().take(2),
              const Spacer(),
              ..._statusParts().skip(2),
            ],
          ),
  );

  /// Whether this visit can change anything, what the extract holds, and when
  /// it comes back.
  List<Widget> _statusParts() => <Widget>[
    _StatusPill(
      text: state.canMutate ? 'Processing' : 'Browsing',
      color: state.canMutate ? AppColors.accent : AppColors.softMarker,
    ),
    Text(
      '${state.children.length} nested · ${state.cards.length} cards',
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    ),
    Text(
      'Repetitions ${state.topic.repetitionCount} · '
      '${state.effectiveDueDay ?? state.topic.schedule.algorithmicDueDay}',
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    ),
  ];
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

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

class _ExtractActionBar extends StatelessWidget {
  const _ExtractActionBar({
    required this.state,
    required this.selection,
    required this.onFormulate,
    required this.onDismiss,
    required this.onLater,
    required this.onDone,
  });

  final ExtractUiState state;
  final ReaderSelectionController selection;
  final VoidCallback onFormulate;
  final VoidCallback onDismiss;
  final VoidCallback onLater;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    // The bar is the last thing above the Android gesture strip, so it has to
    // give that strip its own space or Done sits under the swipe area.
    child: SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: selection,
        builder: (BuildContext context, Widget? child) =>
            isCompactWidth(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _hint(),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: _buttons()),
                ],
              )
            : Row(
                children: <Widget>[
                  Expanded(child: _hint()),
                  _buttons(),
                ],
              ),
      ),
    ),
  );

  /// What the selection currently allows, in one sentence.
  Widget _hint() => Text(
    !state.canMutate
        ? 'Browsing: you can still correct the text.'
        : selection.hasSelection && !selection.canExtract
        ? 'Select within one block.'
        : selection.canExtract
        ? 'Selection ready — Extract above it, or Ctrl+E.'
        : 'Refine, extract further, or formulate cards.',
    style: const TextStyle(fontSize: 12, color: AppColors.muted),
  );

  /// Wraps onto a second row rather than overflowing when the window is too
  /// narrow to hold four buttons on one line.
  ///
  /// Cutting a further extract is not here: it belongs to the selection, and
  /// the toolbar that floats over the selection already offers it.
  Widget _buttons() => Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      if (state.canMutate) ...<Widget>[
        FilledButton.tonal(
          onPressed: state.isBusy ? null : onFormulate,
          child: const Text('Formulate'),
        ),
        TextButton(
          onPressed: state.isBusy ? null : onDismiss,
          child: const Text('Dismiss'),
        ),
        OutlinedButton(
          onPressed: state.isBusy ? null : onLater,
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: state.isBusy ? null : onDone,
          child: const Text('Done'),
        ),
      ],
    ],
  );
}
