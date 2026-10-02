/// The elements a deck matches, with the ones past the session limit set
/// apart below a divider.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/colored_tag_list.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/shared/ui/status_pill.dart';

/// The rows of [matches], for a list that is either its own scroll view or
/// part of a parent's.
List<Widget> customStudyMatchRows({
  required CustomStudyMatches matches,
  required ValueChanged<CustomStudyEntry> onOpen,
  required ValueChanged<CustomStudyEntry> onToggleCramOnly,
}) {
  if (matches.entries.isEmpty) {
    return const <Widget>[
      Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No cards or topics match these filters.')),
      ),
    ];
  }
  final int studied = matches.sessionEntries.length;
  return <Widget>[
    for (var index = 0; index < matches.entries.length; index++) ...<Widget>[
      if (index == studied) const _SessionLimitDivider(),
      CustomStudyMatchRow(
        entry: matches.entries[index],
        isInSession: index < studied,
        onOpen: () => onOpen(matches.entries[index]),
        onToggleCramOnly: () => onToggleCramOnly(matches.entries[index]),
      ),
    ],
  ];
}

class CustomStudyMatchRow extends StatelessWidget {
  const CustomStudyMatchRow({
    required this.entry,
    required this.isInSession,
    required this.onOpen,
    required this.onToggleCramOnly,
    super.key,
  });

  final CustomStudyEntry entry;

  /// False for rows past the session limit, which are dimmed.
  final bool isInSession;
  final VoidCallback onOpen;
  final VoidCallback onToggleCramOnly;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: isInSession ? 1 : 0.5,
    child: Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ElementTypeBadge(type: entry.ref.type),
              const SizedBox(width: 12),
              Expanded(child: _details()),
              _menu(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _details() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(entry.title, style: AppTextStyles.title),
      if (entry.tagNames.isNotEmpty) ...<Widget>[
        const SizedBox(height: 6),
        ColoredTagList(tagNames: entry.tagNames, maximumVisibleTags: 4),
      ],
      const SizedBox(height: 6),
      if (entry.isCramOnly)
        const StatusPill(text: 'Cram only', color: AppColors.accent)
      else
        Text(
          '${entry.priorityPercent.toStringAsFixed(0)}% priority · '
          'due ${entry.dueDay}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
    ],
  );

  Widget _menu() => PopupMenuButton<String>(
    tooltip: 'Element actions',
    icon: const Icon(Icons.more_vert, size: 17),
    onSelected: (_) => onToggleCramOnly(),
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      CheckedPopupMenuItem<String>(
        value: 'cram',
        checked: entry.isCramOnly,
        child: const Text('Cram only'),
      ),
    ],
  );
}

class _SessionLimitDivider extends StatelessWidget {
  const _SessionLimitDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Row(
      children: <Widget>[
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Not in this session',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Expanded(child: Divider()),
      ],
    ),
  );
}
