/// Everything about a deck except its tags: which element types, how tags
/// combine, which elements, in what order, how many, and whether studying
/// them reschedules.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';

/// The session sizes offered; null is no limit.
const List<int?> _kSessionLimits = <int?>[10, 20, 50, 100, 200, null];

class DeckOptions extends StatelessWidget {
  const DeckOptions({
    required this.filter,
    required this.isEnabled,
    required this.onToggleType,
    required this.onMatchChanged,
    required this.onDueOnlyChanged,
    required this.onOrderChanged,
    required this.onSessionLimitChanged,
    required this.onRescheduleChanged,
    super.key,
  });

  final CustomDeckFilter filter;
  final bool isEnabled;
  final ValueChanged<ElementType> onToggleType;
  final ValueChanged<CustomDeckTagMatch> onMatchChanged;
  final ValueChanged<bool> onDueOnlyChanged;
  final ValueChanged<CustomDeckOrder> onOrderChanged;
  final ValueChanged<int?> onSessionLimitChanged;
  final ValueChanged<bool> onRescheduleChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _typeChips(),
        const SizedBox(height: 6),
        _filterChips(),
        const SizedBox(height: 6),
        _sessionDropdowns(),
        _rescheduleSwitch(),
      ],
    ),
  );

  Widget _typeChips() => Wrap(
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
          selected: filter.types.contains(type),
          onSelected: isEnabled ? (_) => onToggleType(type) : null,
        ),
    ],
  );

  /// Match all / any only matters once two tags are included, so it waits
  /// until then rather than offering a choice that changes nothing.
  Widget _filterChips() {
    final bool canMatch = isEnabled && filter.includeTagIds.length > 1;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        ChoiceChip(
          label: const Text('Match all tags'),
          selected: filter.match == CustomDeckTagMatch.all,
          onSelected: canMatch
              ? (_) => onMatchChanged(CustomDeckTagMatch.all)
              : null,
        ),
        ChoiceChip(
          label: const Text('Match any tag'),
          selected: filter.match == CustomDeckTagMatch.any,
          onSelected: canMatch
              ? (_) => onMatchChanged(CustomDeckTagMatch.any)
              : null,
        ),
        FilterChip(
          label: const Text('Due only'),
          tooltip:
              'Only what is due today or overdue. Cram-only elements '
              'have no due date, so they are left out.',
          selected: filter.isDueOnly,
          onSelected: isEnabled ? onDueOnlyChanged : null,
        ),
      ],
    );
  }

  Widget _sessionDropdowns() => Wrap(
    spacing: 16,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      DropdownButton<CustomDeckOrder>(
        value: filter.order,
        onChanged: isEnabled
            ? (CustomDeckOrder? order) {
                if (order != null) onOrderChanged(order);
              }
            : null,
        items: const <DropdownMenuItem<CustomDeckOrder>>[
          DropdownMenuItem<CustomDeckOrder>(
            value: CustomDeckOrder.priority,
            child: Text('Priority order'),
          ),
          DropdownMenuItem<CustomDeckOrder>(
            value: CustomDeckOrder.random,
            child: Text('Random order'),
          ),
          DropdownMenuItem<CustomDeckOrder>(
            value: CustomDeckOrder.dueDate,
            child: Text('Due date order'),
          ),
          DropdownMenuItem<CustomDeckOrder>(
            value: CustomDeckOrder.newestAdded,
            child: Text('Newest added first'),
          ),
        ],
      ),
      DropdownButton<int?>(
        value: _kSessionLimits.contains(filter.sessionLimit)
            ? filter.sessionLimit
            : null,
        onChanged: isEnabled ? onSessionLimitChanged : null,
        items: <DropdownMenuItem<int?>>[
          for (final int? limit in _kSessionLimits)
            DropdownMenuItem<int?>(
              value: limit,
              child: Text(limit == null ? 'No limit' : '$limit per session'),
            ),
        ],
      ),
    ],
  );

  Widget _rescheduleSwitch() => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Reschedule after study'),
    subtitle: Text(
      filter.shouldReschedule
          ? 'Cards not due yet are rescheduled early by FSRS. Cram-only '
                'elements are always practiced.'
          : 'Practice: nothing studied here changes its schedule.',
    ),
    value: filter.shouldReschedule,
    onChanged: isEnabled ? onRescheduleChanged : null,
  );
}
