/// Reads a deterministic, inherited-tag study population without queue writes.
library;

import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:meta/meta.dart';

/// Whether every selected tag or any selected tag must be inherited by a row.
enum CustomStudyTagMatch { all, any }

/// One row eligible for a custom study session.
@immutable
final class CustomStudyEntry {
  const CustomStudyEntry({
    required this.ref,
    required this.title,
    required this.tagNames,
    required this.priorityPercent,
    required this.dueDay,
  });

  final ElementRef ref;
  final String title;
  final List<String> tagNames;
  final double priorityPercent;
  final StudyDay dueDay;
}

/// Projects custom study rows without invoking admission or queue policy.
final class CustomStudyQuery {
  const CustomStudyQuery({
    required BrowserTreeQuery tree,
    required LearningRepository learning,
  }) : _tree = tree,
       _learning = learning;

  final BrowserTreeQuery _tree;
  final LearningRepository _learning;

  /// Reads schedules once and orders matches without consuming randomness.
  Future<List<CustomStudyEntry>> load({
    required Set<String> tagIds,
    required CustomStudyTagMatch match,
    required Set<ElementType> types,
  }) async {
    final List<BrowserTreeNode> roots = await _tree.load();
    final List<ElementSchedule> schedules = await _learning.listSchedules(
      types: ElementType.values.toSet(),
      lifecycles: const <ElementLifecycle>{ElementLifecycle.active},
    );
    final Map<ElementRef, ElementSchedule> schedulesByRef =
        <ElementRef, ElementSchedule>{
          for (final ElementSchedule schedule in schedules)
            schedule.ref: schedule,
        };
    final PriorityScale scale = PriorityScale(
      schedules.map((ElementSchedule schedule) => schedule.priority),
    );
    final List<_RankedCustomStudyEntry> matches = <_RankedCustomStudyEntry>[];
    for (final BrowserTreeNode node in _flatten(roots)) {
      final ElementSchedule? schedule = schedulesByRef[node.ref];
      if (node.lifecycle != ElementLifecycle.active ||
          schedule == null ||
          !types.contains(node.ref.type) ||
          !_matchesTags(
            effectiveTagIds: node.effectiveTagIds,
            selectedTagIds: tagIds,
            match: match,
          )) {
        continue;
      }
      matches.add(
        _RankedCustomStudyEntry(
          rank: schedule.priority,
          entry: CustomStudyEntry(
            ref: node.ref,
            title: node.title,
            tagNames: node.tagNames,
            priorityPercent:
                scale.positionOf(schedule.priority)?.percent ?? 100,
            dueDay: schedule.dueDay,
          ),
        ),
      );
    }
    matches.sort(_compareEntries);
    return List<CustomStudyEntry>.unmodifiable(
      matches.map((_RankedCustomStudyEntry ranked) => ranked.entry),
    );
  }
}

Iterable<BrowserTreeNode> _flatten(List<BrowserTreeNode> nodes) sync* {
  for (final BrowserTreeNode node in nodes) {
    yield node;
    yield* _flatten(node.children);
  }
}

bool _matchesTags({
  required Set<String> effectiveTagIds,
  required Set<String> selectedTagIds,
  required CustomStudyTagMatch match,
}) => switch (match) {
  CustomStudyTagMatch.all => effectiveTagIds.containsAll(selectedTagIds),
  CustomStudyTagMatch.any => selectedTagIds.any(effectiveTagIds.contains),
};

final class _RankedCustomStudyEntry {
  const _RankedCustomStudyEntry({required this.rank, required this.entry});

  final PriorityRank rank;
  final CustomStudyEntry entry;
}

int _compareEntries(
  _RankedCustomStudyEntry first,
  _RankedCustomStudyEntry second,
) {
  final int byPriority = first.rank.compareTo(second.rank);
  if (byPriority != 0) return byPriority;
  final int byDueDay = first.entry.dueDay.compareTo(second.entry.dueDay);
  if (byDueDay != 0) return byDueDay;
  final int byTitle = first.entry.title.compareTo(second.entry.title);
  if (byTitle != 0) return byTitle;
  return first.entry.ref.compareTo(second.entry.ref);
}
