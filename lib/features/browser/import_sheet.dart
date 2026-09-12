/// Making a topic: paste or write markdown, or open a `.md` file.
///
/// Markdown only in v1, and stored verbatim. The title defaults to the first
/// heading, because typing a title again for a chapter that already names
/// itself is friction with no payoff.
///
/// Typed, pasted, and opened Markdown all create the same kind of topic.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

/// What the user asked to import.
@immutable
final class ImportRequest {
  const ImportRequest({required this.title, required this.markdown});

  final String title;
  final String markdown;
}

/// Opens the topic creation page and returns what the user entered, or null.
Future<ImportRequest?> openTopicCreationPage(BuildContext context) =>
    Navigator.of(context).push<ImportRequest>(
      MaterialPageRoute<ImportRequest>(
        builder: (BuildContext context) => const _TopicCreationPage(),
      ),
    );

class _TopicCreationPage extends StatefulWidget {
  const _TopicCreationPage();

  @override
  State<_TopicCreationPage> createState() => _TopicCreationPageState();
}

class _TopicCreationPageState extends State<_TopicCreationPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _markdown = TextEditingController();
  bool _wasTitleEditedByHand = false;

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
    if (_wasTitleEditedByHand) return;
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
      if (!_wasTitleEditedByHand) {
        _title.text = firstHeadingOf(text) ?? _fileTitle(file.name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Both are required: an untitled article is unfindable in the tree, and
    // an empty one has nothing to read.
    final bool canImport =
        _markdown.text.trim().isNotEmpty && _title.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add topic'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: canImport ? () => _submit(context) : null,
              child: const Text('Add'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: EdgeInsets.all(isCompactWidth(context) ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _titleArea(context),
                  const SizedBox(height: 18),
                  Expanded(child: _markdownField()),
                  const SizedBox(height: 12),
                  _wordCountRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The title field, beside the file picker that can fill both fields at once.
  Widget _titleArea(BuildContext context) {
    final TextField titleField = TextField(
      controller: _title,
      decoration: const InputDecoration(labelText: 'Title'),
      onChanged: (_) {
        // Typing here stops the file picker from overwriting the title.
        _wasTitleEditedByHand = true;
        setState(() {});
      },
    );
    final OutlinedButton openButton = OutlinedButton.icon(
      onPressed: _openFile,
      icon: const Icon(Icons.folder_open, size: 16),
      label: const Text('Open markdown file'),
    );
    if (isCompactWidth(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          titleField,
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerLeft, child: openButton),
        ],
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: titleField),
        const SizedBox(width: 12),
        openButton,
      ],
    );
  }

  /// Monospaced and page-filling: this is the source text, not a preview.
  Widget _markdownField() {
    return TextField(
      controller: _markdown,
      minLines: null,
      maxLines: null,
      expands: true,
      autofocus: true,
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

  /// Says how much reading is being taken on before it is taken on.
  Widget _wordCountRow() {
    return Row(
      children: <Widget>[
        const Spacer(),
        Text(
          '${countWords(_markdown.text)} words',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    Navigator.of(
      context,
    ).pop(ImportRequest(title: _title.text.trim(), markdown: _markdown.text));
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
