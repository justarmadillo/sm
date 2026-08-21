/// Import: paste markdown or open a `.md` file.
///
/// Markdown only in v1, and stored verbatim. The title defaults to the first
/// heading, because typing a title again for a chapter that already names
/// itself is friction with no payoff.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/content/source.dart';

/// What the user asked to import.
@immutable
final class ImportRequest {
  const ImportRequest({
    required this.title,
    required this.markdown,
    required this.pace,
  });

  final String title;
  final String markdown;
  final ReadingPace pace;
}

/// Shows the import dialog and returns what the user entered, or null.
Future<ImportRequest?> showImportSheet(BuildContext context) =>
    showDialog<ImportRequest>(
      context: context,
      builder: (BuildContext context) => const _ImportDialog(),
    );

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _markdown = TextEditingController();
  ReadingPace _pace = ReadingPace.normal;
  bool _titleEditedByHand = false;

  @override
  void initState() {
    super.initState();
    _markdown.addListener(_suggestTitle);
  }

  @override
  void dispose() {
    _markdown.removeListener(_suggestTitle);
    _title.dispose();
    _markdown.dispose();
    super.dispose();
  }

  /// Fills the title from the first heading until the user types their own.
  void _suggestTitle() {
    if (_titleEditedByHand) return;
    final suggestion = firstHeadingOf(_markdown.text);
    if (suggestion != null && suggestion != _title.text) {
      _title.text = suggestion;
    }
  }

  Future<void> _openFile() async {
    const group = XTypeGroup(
      label: 'Markdown',
      extensions: <String>['md', 'markdown', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null) return;

    final text = await File(file.path).readAsString();
    setState(() {
      _markdown.text = text;
      if (!_titleEditedByHand) {
        _title.text = firstHeadingOf(text) ?? _fileTitle(file.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canImport =
        _markdown.text.trim().isNotEmpty && _title.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('Import markdown'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (_) {
                      _titleEditedByHand = true;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openFile,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Open file'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: TextField(
                controller: _markdown,
                maxLines: null,
                expands: false,
                autofocus: true,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Markdown',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                const Text(
                  'Pace',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(width: 12),
                for (final pace in ReadingPace.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(pace.name),
                      selected: _pace == pace,
                      onSelected: (_) => setState(() => _pace = pace),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${countWords(_markdown.text)} words',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
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
          onPressed: canImport
              ? () => Navigator.of(context).pop(
                  ImportRequest(
                    title: _title.text.trim(),
                    markdown: _markdown.text,
                    pace: _pace,
                  ),
                )
              : null,
          child: const Text('Import'),
        ),
      ],
    );
  }

  String _fileTitle(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? fileName : fileName.substring(0, dot);
  }
}

/// The text of the first ATX heading in [markdown], or null.
///
/// Strips the opening hashes and an optional closing run of them, so
/// `### Title ###` suggests `Title` rather than `Title ###`.
String? firstHeadingOf(String markdown) {
  for (final line in markdown.split('\n')) {
    final trimmed = line.trimLeft();
    if (!trimmed.startsWith('#')) continue;
    final text = trimmed
        .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
        .replaceFirst(RegExp(r'\s*#+\s*$'), '')
        .trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}
