/// The filter and frozen route loop for ad-hoc study by inherited tag.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/browser/browser_screen.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';
import 'package:incremental_reader/features/custom_study/custom_study_view_model.dart';
import 'package:incremental_reader/features/daily_queue/open_study_element.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/colored_tag_list.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// Opens a fresh custom-study filter and session.
Future<void> openCustomStudy(BuildContext context, WidgetRef ref) async {
  ref.invalidate(customStudyViewModelProvider);
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<CustomStudyUiState> state = ref.watch(
      customStudyViewModelProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Custom study')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not prepare custom study.\n$error')),
        data: _body,
      ),
    );
  }

  Widget _body(CustomStudyUiState state) {
    final CustomStudyViewModel model = ref.read(
      customStudyViewModelProvider.notifier,
    );
    final List<Tag> tags =
        ref.watch(browserTagsProvider).valueOrNull ?? const <Tag>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TypeFilter(
          selected: state.types,
          areTopicsEnabled: state.shouldReschedule,
          isEnabled: !_isRunning && !state.isLoading,
          onToggle: (ElementType type) => unawaited(model.toggleType(type)),
        ),
        _TagFilter(
          tags: tags,
          selected: state.selectedTagIds,
          isEnabled: !_isRunning && !state.isLoading,
          onChanged: (Set<String> tagIds) =>
              unawaited(model.setSelectedTagIds(tagIds)),
        ),
        _MatchControls(
          state: state,
          isEnabled: !_isRunning && !state.isLoading,
          onMatchChanged: (CustomStudyTagMatch match) =>
              unawaited(model.setMatch(match)),
          onRescheduleChanged: (bool shouldReschedule) =>
              unawaited(model.setShouldReschedule(shouldReschedule)),
        ),
        _SessionSummary(
          state: state,
          isRunning: _isRunning,
          onStart: () => unawaited(_runSession()),
        ),
        const Divider(height: 1),
        Expanded(child: _matches(state.entries)),
      ],
    );
  }

  Widget _matches(List<CustomStudyEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('No cards or topics match these filters.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) =>
          _CustomStudyRow(entry: entries[index]),
    );
  }

  /// Walks the snapshot taken at Start instead of querying between routes.
  Future<void> _runSession() async {
    if (_isRunning) return;
    final CustomStudyViewModel model = ref.read(
      customStudyViewModelProvider.notifier,
    );
    final CustomStudyUiState? state = ref
        .read(customStudyViewModelProvider)
        .valueOrNull;
    if (state == null) return;
    final List<CustomStudyEntry> frozen = model.beginSession();
    if (frozen.isEmpty) return;
    setState(() => _isRunning = true);
    try {
      for (var index = 0; index < frozen.length && mounted; index++) {
        final StudyRouteResult result = await openStudyElement(
          context,
          ref,
          elementRef: frozen[index].ref,
          isPractice: !state.shouldReschedule,
        );
        if (!mounted || !result.advancesSession) break;
        if (result.isRepetition) model.recordCompleted();
      }
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({
    required this.selected,
    required this.areTopicsEnabled,
    required this.isEnabled,
    required this.onToggle,
  });

  final Set<ElementType> selected;
  final bool areTopicsEnabled;
  final bool isEnabled;
  final ValueChanged<ElementType> onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final (String label, ElementType type)
            in const <(String, ElementType)>[
              ('Topics', ElementType.source),
              ('Extracts', ElementType.extract),
              ('Videos', ElementType.video),
              ('Cards', ElementType.card),
            ])
          FilterChip(
            label: Text(label),
            selected: selected.contains(type),
            onSelected: isEnabled && (areTopicsEnabled || !type.isTopic)
                ? (_) => onToggle(type)
                : null,
          ),
      ],
    ),
  );
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.selected,
    required this.isEnabled,
    required this.onChanged,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final bool isEnabled;
  final ValueChanged<Set<String>> onChanged;

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
            onSelected: !isEnabled
                ? null
                : (bool isSelected) {
                    final Set<String> changed = <String>{...selected};
                    isSelected ? changed.add(tag.id) : changed.remove(tag.id);
                    onChanged(changed);
                  },
          ),
          const SizedBox(width: 6),
        ],
      ],
    ),
  );
}

class _MatchControls extends StatelessWidget {
  const _MatchControls({
    required this.state,
    required this.isEnabled,
    required this.onMatchChanged,
    required this.onRescheduleChanged,
  });

  final CustomStudyUiState state;
  final bool isEnabled;
  final ValueChanged<CustomStudyTagMatch> onMatchChanged;
  final ValueChanged<bool> onRescheduleChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 6,
          children: <Widget>[
            ChoiceChip(
              label: const Text('Match all tags'),
              selected: state.match == CustomStudyTagMatch.all,
              onSelected: isEnabled
                  ? (_) => onMatchChanged(CustomStudyTagMatch.all)
                  : null,
            ),
            ChoiceChip(
              label: const Text('Match any tag'),
              selected: state.match == CustomStudyTagMatch.any,
              onSelected: isEnabled
                  ? (_) => onMatchChanged(CustomStudyTagMatch.any)
                  : null,
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reschedule after study'),
          subtitle: Text(
            state.shouldReschedule
                ? 'Cards and topics follow their normal schedules.'
                : 'Practice does not reschedule cards. Topics are disabled '
                      'because reading one always advances its schedule.',
          ),
          value: state.shouldReschedule,
          onChanged: isEnabled ? onRescheduleChanged : null,
        ),
      ],
    ),
  );
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({
    required this.state,
    required this.isRunning,
    required this.onStart,
  });

  final CustomStudyUiState state;
  final bool isRunning;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '${state.entries.length} matches · '
            '${state.completedThisSession} completed',
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
        FilledButton.icon(
          onPressed: state.entries.isEmpty || state.isLoading || isRunning
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

class _CustomStudyRow extends StatelessWidget {
  const _CustomStudyRow({required this.entry});

  final CustomStudyEntry entry;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ElementTypeBadge(type: entry.ref.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(entry.title, style: AppTextStyles.title),
                if (entry.tagNames.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  ColoredTagList(
                    tagNames: entry.tagNames,
                    maximumVisibleTags: 4,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${entry.priorityPercent.toStringAsFixed(0)}% priority · '
                  'due ${entry.dueDay}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
