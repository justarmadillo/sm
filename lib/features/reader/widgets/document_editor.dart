/// Edits one source's complete normalized Markdown on a fullscreen route.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Returns rewritten Markdown, or null when the editor is cancelled.
Future<String?> openDocumentEditor(
  BuildContext context, {
  required Document document,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute<String>(
    fullscreenDialog: true,
    builder: (BuildContext context) => DocumentEditor(document: document),
  ),
);

class DocumentEditor extends StatefulWidget {
  const DocumentEditor({required this.document, super.key});

  final Document document;

  @override
  State<DocumentEditor> createState() => _DocumentEditorState();
}

class _DocumentEditorState extends State<DocumentEditor> {
  late final TextEditingController _markdown = TextEditingController(
    text: widget.document.markdown,
  );

  @override
  void dispose() {
    _markdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Edit full markdown'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: _markdown.text == widget.document.markdown
              ? null
              : () => Navigator.of(context).pop(_markdown.text),
          child: const Text('Save'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Untouched paragraphs keep their extract links. Rewritten '
              'passages may make those links stale.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Expanded(child: _markdownField()),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${countWords(_markdown.text)} words',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _markdownField() => TextField(
    controller: _markdown,
    minLines: null,
    maxLines: null,
    expands: true,
    autofocus: true,
    autocorrect: false,
    enableSuggestions: false,
    textAlignVertical: TextAlignVertical.top,
    style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
    decoration: const InputDecoration(
      labelText: 'Markdown',
      alignLabelWithHint: true,
      border: OutlineInputBorder(),
    ),
    onChanged: (_) => setState(() {}),
  );
}
