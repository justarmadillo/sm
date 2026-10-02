/// Asks for a deck's name, for Save as deck and Rename.
library;

import 'package:flutter/material.dart';

/// The trimmed name typed, or null when the dialog was cancelled or left
/// empty.
Future<String?> showDeckNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
}) => showDialog<String>(
  context: context,
  builder: (BuildContext context) =>
      _DeckNameDialog(title: title, initialName: initialName),
);

class _DeckNameDialog extends StatefulWidget {
  const _DeckNameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<_DeckNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _name,
      autofocus: true,
      maxLength: 100,
      decoration: const InputDecoration(labelText: 'Deck name'),
      onSubmitted: (_) => _submit(),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );
}
