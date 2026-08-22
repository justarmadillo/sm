/// Processing surface for an independently scheduled extract.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/toast.dart';
import '../../../domain/content/block.dart';
import '../../../domain/content/document.dart';
import '../../../domain/content/reader_anchor.dart';
import '../../priority/presentation/priority_dialog.dart';
import '../../queue/presentation/study_route_result.dart';
import '../../reader/presentation/extract_highlights.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/presentation/reader_selection.dart';
import '../../reader/presentation/reader_view.dart';
import '../../reader/presentation/reader_view_model.dart';
import '../../reader/presentation/typography_controller.dart';
import 'extract_context_overlay.dart';
import 'extract_view_model.dart';
import 'formulation_dialog.dart';

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
  ReaderSelectionController? _selection;
  String? _documentIdentity;
  bool _openedAtAnchor = false;

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
        model.clearMessage();
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

  Widget _buildExtract(
    BuildContext context,
    ExtractUiState state,
    ExtractViewModel model,
  ) {
    final selection = _selectionFor(state.document);
    final typography = ref.watch(readerTypographyProvider);
    final initialAnchor = widget.request.initialAnchor;
    if (!_openedAtAnchor &&
        initialAnchor != null &&
        state.document.containsAnchor(initialAnchor)) {
      _openedAtAnchor = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _readerKey.currentState?.jumpToAnchor(initialAnchor);
      });
    }
    return Scaffold(
      appBar: AppBar(
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
            onPressed: state.canMutate && !state.isBusy
                ? () => _edit(context, state, model)
                : null,
            icon: const Icon(Icons.edit_outlined),
            tooltip: state.canEdit
                ? 'Edit extract'
                : 'Nested extracts depend on this text',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              model.done,
          const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
              model.later(),
          const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
              _extractSelection(model),
          kPriorityShortcut: () => unawaited(
            showPriorityDialog(context, ref, elementRef: state.topic.ref),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: <Widget>[
              _ExtractStatusBar(state: state),
              Expanded(
                child: ReaderView(
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
              ),
              _ExtractActionBar(
                state: state,
                selection: selection,
                onExtract: () => _extractSelection(model),
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
          width: 620,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 8,
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
    if (provenance.parentIsSource) {
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
    child: Row(
      children: <Widget>[
        _StatusPill(
          text: state.canMutate ? 'Processing' : 'Browsing',
          color: state.canMutate ? AppColors.accent : AppColors.softMarker,
        ),
        const SizedBox(width: 12),
        Text(
          '${state.children.length} nested · ${state.cards.length} cards',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const Spacer(),
        Text(
          'Step ${state.topic.stepIndex} · '
          '${state.effectiveDueDay ?? state.topic.schedule.algorithmicDueDay}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
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
    required this.onExtract,
    required this.onFormulate,
    required this.onDismiss,
    required this.onLater,
    required this.onDone,
  });

  final ExtractUiState state;
  final ReaderSelectionController selection;
  final VoidCallback onExtract;
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
    child: ListenableBuilder(
      listenable: selection,
      builder: (BuildContext context, Widget? child) => Row(
        children: <Widget>[
          Expanded(
            child: Text(
              !state.canMutate
                  ? 'Browsing is read-only.'
                  : selection.hasSelection && !selection.canExtract
                  ? 'Select within one block.'
                  : selection.canExtract
                  ? 'Selection ready — Extract more (Ctrl+E).'
                  : 'Refine, extract further, or formulate cards.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          if (state.canMutate) ...<Widget>[
            OutlinedButton(
              onPressed: !state.isBusy && selection.canExtract
                  ? onExtract
                  : null,
              child: const Text('Extract more'),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: state.isBusy ? null : onFormulate,
              child: const Text('Formulate'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: state.isBusy ? null : onDismiss,
              child: const Text('Dismiss'),
            ),
            OutlinedButton(
              onPressed: state.isBusy ? null : onLater,
              child: const Text('Later'),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: state.isBusy ? null : onDone,
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    ),
  );
}
