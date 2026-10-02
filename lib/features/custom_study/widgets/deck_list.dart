/// The saved decks, plus the unsaved filter, as a pickable list.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';

/// Picks the deck whose filter is on screen; null means the unsaved filter.
class CustomDeckList extends StatelessWidget {
  const CustomDeckList({
    required this.decks,
    required this.selectedDeckId,
    required this.isEnabled,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final List<CustomDeck> decks;
  final String? selectedDeckId;
  final bool isEnabled;
  final ValueChanged<String?> onSelect;
  final ValueChanged<CustomDeck> onRename;
  final ValueChanged<CustomDeck> onDelete;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text('Decks', style: AppTextStyles.eyebrow),
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.tune, size: 18),
        title: const Text('Unsaved filter'),
        selected: selectedDeckId == null,
        onTap: isEnabled ? () => onSelect(null) : null,
      ),
      for (final CustomDeck deck in decks) _deckTile(deck),
    ],
  );

  Widget _deckTile(CustomDeck deck) => ListTile(
    dense: true,
    leading: const Icon(Icons.style_outlined, size: 18),
    title: Text(deck.name, overflow: TextOverflow.ellipsis),
    selected: deck.id == selectedDeckId,
    onTap: isEnabled ? () => onSelect(deck.id) : null,
    trailing: PopupMenuButton<String>(
      tooltip: 'Deck actions',
      icon: const Icon(Icons.more_vert, size: 17),
      enabled: isEnabled,
      onSelected: (String action) =>
          action == 'rename' ? onRename(deck) : onDelete(deck),
      itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
        PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
        PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
      ],
    ),
  );
}
