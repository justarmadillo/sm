/// Making a topic: paste or write markdown, or open a `.md` file or a zip.
///
/// Typed and pasted markdown is stored verbatim. An opened file also brings
/// the images its markdown links, the figures a PDF converter such as Marker
/// saves beside it; `markdown_file_input.dart` reads them. The title defaults
/// to the first heading, because typing a title again for a chapter that
/// already names itself is friction with no payoff.
///
/// Typed, pasted, and opened Markdown all create the same kind of topic.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/browser/markdown_file_input.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

/// What the user asked to import.
@immutable
final class ImportRequest {
  const ImportRequest({
    required this.title,
    required this.markdown,
    this.images = const <SourceImageImport>[],
  });

  final String title;
  final String markdown;

  /// Images the markdown still links, from the file it was opened from.
  final List<SourceImageImport> images;
}

/// Opens the topic creation page and returns what the user entered, or null.
Future<ImportRequest?> openTopicCreationPage(
  BuildContext context, {
  required MarkdownFileInput markdownFileInput,
}) => Navigator.of(context).push<ImportRequest>(
  MaterialPageRoute<ImportRequest>(
    builder: (BuildContext context) =>
        _TopicCreationPage(markdownFileInput: markdownFileInput),
  ),
);

class _TopicCreationPage extends StatefulWidget {
  const _TopicCreationPage({required this.markdownFileInput});

  final MarkdownFileInput markdownFileInput;

  @override
  State<_TopicCreationPage> createState() => _TopicCreationPageState();
}

class _TopicCreationPageState extends State<_TopicCreationPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _markdown = TextEditingController();
  bool _wasTitleEditedByHand = false;
  bool _isOpeningFile = false;

  /// Images of the last opened file, whether or not the text still links them.
  List<SourceImageImport> _openedImages = const <SourceImageImport>[];
  int _missingImageCount = 0;

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
    setState(() => _isOpeningFile = true);
    final MarkdownWithImages? opened = await _chooseFile();
    if (!mounted) return;
    setState(() {
      _isOpeningFile = false;
      if (opened == null) return;
      _markdown.text = opened.markdown;
      _openedImages = opened.images;
      _missingImageCount = opened.missingImageCount;
      if (!_wasTitleEditedByHand) {
        _title.text =
            firstHeadingOf(opened.markdown) ?? _fileTitle(opened.fileName);
      }
    });
    if (opened != null && opened.shouldZipFolderForImages) {
      showToast(context, 'Zip the Marker folder to bring its images');
    }
  }

  /// The chosen file, or null when nothing was chosen or it could not be read.
  Future<MarkdownWithImages?> _chooseFile() async {
    try {
      return await widget.markdownFileInput.chooseMarkdownFile();
    } on MarkdownFileInputException catch (failure) {
      if (mounted) showToast(context, failure.message, isError: true);
    } on Object {
      if (mounted) {
        showToast(
          context,
          'The selected file could not be read',
          isError: true,
        );
      }
    }
    return null;
  }

  /// The opened images the markdown still links, each once: an image whose
  /// link the user deleted is not worth storing.
  List<SourceImageImport> _linkedImages() {
    final Map<String, SourceImageImport> imagesByReference =
        <String, SourceImageImport>{
          for (final SourceImageImport image in _openedImages)
            if (_markdown.text.contains(image.srcRef)) image.srcRef: image,
        };
    return imagesByReference.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    // Both are required: an untitled article is unfindable in the tree, and
    // an empty one has nothing to read.
    final bool canImport =
        _markdown.text.trim().isNotEmpty &&
        _title.text.trim().isNotEmpty &&
        !_isOpeningFile;

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
                  _countsRow(),
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
      onPressed: _isOpeningFile ? null : _openFile,
      icon: const Icon(Icons.folder_open, size: 16),
      label: const Text('Open markdown or zip'),
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

  /// Says how much reading, and how many figures, are being taken on before
  /// they are taken on.
  Widget _countsRow() {
    const TextStyle mutedStyle = TextStyle(
      fontSize: 12,
      color: AppColors.muted,
    );
    final bool hasOpenedImages =
        _openedImages.isNotEmpty || _missingImageCount > 0;
    final int linkedImageCount = _linkedImages().length;
    return Row(
      children: <Widget>[
        if (hasOpenedImages)
          Text(
            linkedImageCount == 1
                ? '1 image attached'
                : '$linkedImageCount images attached',
            style: mutedStyle,
          ),
        if (_missingImageCount > 0) ...<Widget>[
          const SizedBox(width: 4),
          Text(
            '· $_missingImageCount not found',
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ],
        const Spacer(),
        Text('${countWords(_markdown.text)} words', style: mutedStyle),
      ],
    );
  }

  void _submit(BuildContext context) {
    Navigator.of(context).pop(
      ImportRequest(
        title: _title.text.trim(),
        markdown: _markdown.text,
        images: _linkedImages(),
      ),
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
