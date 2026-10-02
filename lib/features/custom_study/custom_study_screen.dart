/// Custom study: browse the collection by tag, save the filter as a deck,
/// and study or cram what it matches.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/browser/browser_screen.dart';
import 'package:incremental_reader/features/browser/open_element.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';
import 'package:incremental_reader/features/custom_study/custom_study_view_model.dart';
import 'package:incremental_reader/features/custom_study/widgets/deck_list.dart';
import 'package:incremental_reader/features/custom_study/widgets/deck_name_dialog.dart';
import 'package:incremental_reader/features/custom_study/widgets/deck_options.dart';
import 'package:incremental_reader/features/custom_study/widgets/match_list.dart';
import 'package:incremental_reader/features/custom_study/widgets/tag_filter_list.dart';
import 'package:incremental_reader/features/daily_queue/open_study_element.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// Opens a fresh custom-study filter and session.
Future<void> openCustomStudy(BuildContext context, WidgetRef ref) async {
  ref.invalidate(customStudyViewModelProvider);
  ref.invalidate(browserTagsProvider);
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const CustomStudyScreen(),
    ),
  );
}

class CustomStudyScreen extends ConsumerStatefulWidget {
  const CustomStudyScreen({super.key});

  @override
  ConsumerState<CustomStudyScreen> createState() => _CustomStudyScreenState();
}

class _CustomStudyScreenState extends ConsumerState<CustomStudyScreen> {
  bool _isRunning = false;

  CustomStudyViewModel get _model =>
      ref.read(customStudyViewModelProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CustomStudyUiState> state = ref.watch(
      customStudyViewModelProvider,
    );
    ref.listen<AsyncValue<CustomStudyUiState>>(customStudyViewModelProvider, (
      AsyncValue<CustomStudyUiState>? previous,
      AsyncValue<CustomStudyUiState> next,
    ) {
      if (next.valueOrNull?.message case final message?) {
        showToast(context, message.text, isError: message.isError);
        _model.clearMessage();
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Custom study')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not prepare custom study.\n$error')),
        data: (CustomStudyUiState data) =>
            isCompactWidth(context) ? _narrowBody(data) : _wideBody(data),
      ),
    );
  }

  /// Decks and tags on the left, what they match on the right.
  Widget _wideBody(CustomStudyUiState state) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      SizedBox(
        width: 300,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _deckList(state),
              const Divider(height: 1),
              Expanded(child: _tagList(state, isScrollable: true)),
            ],
          ),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ..._filterHeader(state),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 24),
                children: _matchRows(state),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  /// One scrolling column, with the deck list and tags folded away until
  /// asked for, so the matches stay in reach on a phone.
  Widget _narrowBody(CustomStudyUiState state) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: <Widget>[
      ExpansionTile(
        title: Text(state.selectedDeck?.name ?? 'Unsaved filter'),
        subtitle: const Text('Decks'),
        children: <Widget>[_deckList(state)],
      ),
      ExpansionTile(
        title: Text(_tagSummary(state.filter)),
        subtitle: const Text('Tags'),
        children: <Widget>[_tagList(state, isScrollable: false)],
      ),
      ..._filterHeader(state),
      const Divider(height: 1),
      const SizedBox(height: 10),
      ..._matchRows(state),
    ],
  );

  bool _isEnabled(CustomStudyUiState state) => !_isRunning && !state.isLoading;

  Widget _deckList(CustomStudyUiState state) => CustomDeckList(
    decks: state.decks,
    selectedDeckId: state.selectedDeckId,
    isEnabled: _isEnabled(state),
    onSelect: (String? deckId) => unawaited(_model.selectDeck(deckId)),
    onRename: (CustomDeck deck) => unawaited(_renameDeck(deck)),
    onDelete: (CustomDeck deck) => unawaited(_deleteDeck(deck)),
  );

  Widget _tagList(CustomStudyUiState state, {required bool isScrollable}) =>
      TagFilterList(
        tags: ref.watch(browserTagsProvider).valueOrNull ?? const <Tag>[],
        filter: state.filter,
        tagCounts: state.matches.tagCounts,
        isEnabled: _isEnabled(state),
        isScrollable: isScrollable,
        onCycle: (String tagId) => unawaited(_model.cycleTag(tagId)),
      );

  List<Widget> _filterHeader(CustomStudyUiState state) => <Widget>[
    _DeckHeader(
      state: state,
      isEnabled: _isEnabled(state),
      onSave: () => unawaited(_model.saveDeck()),
      onSaveAs: () => unawaited(_saveAsNewDeck()),
      onRevert: () => unawaited(_model.revert()),
    ),
    if (state.selectedDeck != null && state.filter.includeTagIds.isEmpty)
      const _NoIncludeTagsBanner(),
    DeckOptions(
      filter: state.filter,
      isEnabled: _isEnabled(state),
      onToggleType: (ElementType type) => unawaited(_model.toggleType(type)),
      onMatchChanged: (CustomDeckTagMatch match) =>
          unawaited(_model.setMatch(match)),
      onDueOnlyChanged: (bool isDueOnly) =>
          unawaited(_model.setDueOnly(isDueOnly)),
      onOrderChanged: (CustomDeckOrder order) =>
          unawaited(_model.setOrder(order)),
      onSessionLimitChanged: (int? limit) =>
          unawaited(_model.setSessionLimit(limit)),
      onRescheduleChanged: (bool shouldReschedule) =>
          unawaited(_model.setShouldReschedule(shouldReschedule)),
    ),
    _SessionSummary(
      state: state,
      isRunning: _isRunning,
      onReshuffle: () => unawaited(_model.reshuffle()),
      onStart: () => unawaited(_runSession()),
    ),
  ];

  List<Widget> _matchRows(CustomStudyUiState state) => customStudyMatchRows(
    matches: state.matches,
    onOpen: (CustomStudyEntry entry) =>
        unawaited(openElement(context, ref, elementRef: entry.ref)),
    onToggleCramOnly: (CustomStudyEntry entry) =>
        unawaited(_toggleCramOnly(entry)),
  );

  Future<void> _toggleCramOnly(CustomStudyEntry entry) async {
    await _model.markCramOnly(<ElementRef>[
      entry.ref,
    ], isCramOnly: !entry.isCramOnly);
    ref.invalidate(browserTagsProvider);
  }

  Future<void> _saveAsNewDeck() async {
    final String? name = await showDeckNameDialog(
      context,
      title: 'Save as deck',
    );
    if (name != null) await _model.saveAsNewDeck(name);
  }

  Future<void> _renameDeck(CustomDeck deck) async {
    final String? name = await showDeckNameDialog(
      context,
      title: 'Rename deck',
      initialName: deck.name,
    );
    if (name != null) await _model.renameDeck(deck.id, name);
  }

  Future<void> _deleteDeck(CustomDeck deck) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete ${deck.name}?'),
        content: const Text(
          'The deck is deleted for good. The cards and topics it studies '
          'stay exactly as they are.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete ?? false) await _model.deleteDeck(deck.id);
  }

  /// Walks the snapshot taken at Start instead of querying between routes.
  Future<void> _runSession() async {
    if (_isRunning) return;
    final CustomStudyUiState? state = ref
        .read(customStudyViewModelProvider)
        .valueOrNull;
    if (state == null) return;
    final List<CustomStudyStep> frozen = _model.beginSession();
    if (frozen.isEmpty) return;
    setState(() => _isRunning = true);
    try {
      for (var index = 0; index < frozen.length && mounted; index++) {
        final StudyRouteResult result = await openStudyElement(
          context,
          ref,
          elementRef: frozen[index].ref,
          scheduling: frozen[index].scheduling,
          customDeckId: state.selectedDeckId,
        );
        if (!mounted || !result.advancesSession) break;
        if (result.isRepetition) _model.recordCompleted();
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  static String _tagSummary(CustomDeckFilter filter) {
    final int included = filter.includeTagIds.length;
    final int excluded = filter.excludeTagIds.length;
    if (included == 0 && excluded == 0) return 'All tags';
    return '$included included · $excluded excluded';
  }
}

/// The deck's name, whether it has unsaved changes, and the save actions.
class _DeckHeader extends StatelessWidget {
  const _DeckHeader({
    required this.state,
    required this.isEnabled,
    required this.onSave,
    required this.onSaveAs,
    required this.onRevert,
  });

  final CustomStudyUiState state;
  final bool isEnabled;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          state.selectedDeck?.name ?? 'Unsaved filter',
          style: AppTextStyles.subheading,
        ),
        if (state.isDirty) ...<Widget>[
          const Tooltip(
            message: 'Unsaved changes',
            child: Icon(Icons.circle, size: 8, color: AppColors.accent),
          ),
          TextButton(
            onPressed: isEnabled ? onSave : null,
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: isEnabled ? onRevert : null,
            child: const Text('Revert'),
          ),
        ],
        OutlinedButton.icon(
          onPressed: isEnabled ? onSaveAs : null,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text('Save as deck…'),
        ),
      ],
    ),
  );
}

/// A saved deck whose included tags were all deleted studies everything, and
/// that should never happen silently.
class _NoIncludeTagsBanner extends StatelessWidget {
  const _NoIncludeTagsBanner();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Text(
      'This deck includes no tags, so it draws from the whole collection.',
      style: TextStyle(color: AppColors.danger),
    ),
  );
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.state,
    required this.isRunning,
    required this.onReshuffle,
    required this.onStart,
  });

  final CustomStudyUiState state;
  final bool isRunning;
  final VoidCallback onReshuffle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final int matched = state.matches.entries.length;
    final int studying = state.matches.sessionEntries.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              '$matched matches · studying $studying · '
              '${state.completedThisSession} completed',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          if (state.filter.order == CustomDeckOrder.random)
            IconButton(
              tooltip: 'Reshuffle',
              onPressed: state.isLoading || isRunning ? null : onReshuffle,
              icon: const Icon(Icons.shuffle),
            ),
          FilledButton.icon(
            onPressed: studying == 0 || state.isLoading || isRunning
                ? null
                : onStart,
            icon: isRunning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(isRunning ? 'Studying' : 'Start'),
          ),
        ],
      ),
    );
  }
}
