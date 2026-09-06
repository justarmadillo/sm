/// Adding a video: its link, title, duration, and optional thumbnail.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/documents/video_link.dart';
import 'package:incremental_reader/documents/video_time.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/reader/reader_image_input.dart';
import 'package:incremental_reader/features/reader/reader_providers.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';
import 'package:incremental_reader/shared/ui/video_thumbnail.dart';

/// What the user asked to import.
@immutable
final class VideoImportRequest {
  const VideoImportRequest({
    required this.url,
    required this.title,
    required this.durationSeconds,
    this.thumbnailUrl,
  });

  final String url;
  final String title;
  final int durationSeconds;
  final String? thumbnailUrl;
}

/// Shows the import dialog and returns what the user entered, or null.
Future<VideoImportRequest?> showImportVideoSheet(
  BuildContext context,
  WidgetRef ref,
) => showDialog<VideoImportRequest>(
  context: context,
  builder: (BuildContext context) =>
      _ImportVideoDialog(imageInput: ref.read(readerImageInputProvider)),
);

class _ImportVideoDialog extends StatefulWidget {
  const _ImportVideoDialog({required this.imageInput});

  final ReaderImageInput imageInput;

  @override
  State<_ImportVideoDialog> createState() => _ImportVideoDialogState();
}

class _ImportVideoDialogState extends State<_ImportVideoDialog> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _length = TextEditingController();
  final TextEditingController _thumbnail = TextEditingController();
  SourceImageImport? _thumbnailImage;
  bool _isChoosingThumbnail = false;

  @override
  void initState() {
    super.initState();
    for (final TextEditingController controller in _watched) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _watched) {
      controller.removeListener(_refresh);
    }
    _url.dispose();
    _title.dispose();
    _length.dispose();
    _thumbnail.dispose();
    super.dispose();
  }

  List<TextEditingController> get _watched => <TextEditingController>[
    _url,
    _title,
    _length,
    _thumbnail,
  ];

  void _refresh() => setState(() {});

  VideoPlatform get _platform => detectVideoPlatform(_url.text);

  int? get _durationSeconds =>
      _length.text.trim().isEmpty ? null : parseVideoTime(_length.text);

  String? get _problem {
    if (_url.text.trim().isNotEmpty && Uri.tryParse(_url.text.trim()) == null) {
      return 'That link cannot be read.';
    }
    if (_length.text.trim().isNotEmpty && _durationSeconds == null) {
      return 'The length is not a time. Try 1:04:12.';
    }
    if (_durationSeconds == null || _durationSeconds! <= 0) {
      return 'Give the video’s full duration, for example 1:04:12.';
    }
    final String thumbnail = _thumbnailSource ?? '';
    final Uri? thumbnailUri = Uri.tryParse(thumbnail);
    if (thumbnail.isNotEmpty &&
        !thumbnail.startsWith('data:image/') &&
        ((thumbnailUri?.scheme == 'http' || thumbnailUri?.scheme == 'https') !=
                true ||
            thumbnailUri?.host.isEmpty != false)) {
      return 'The thumbnail needs a complete http:// or https:// link.';
    }
    return null;
  }

  bool get _canImport =>
      _url.text.trim().isNotEmpty &&
      _title.text.trim().isNotEmpty &&
      _durationSeconds != null &&
      _problem == null;

  String? get _thumbnailSource {
    final SourceImageImport? image = _thumbnailImage;
    if (image != null) return videoThumbnailDataUrl(image);
    final String link = _thumbnail.text.trim();
    return link.isEmpty ? null : link;
  }

  void _import() {
    if (!_canImport) return;
    Navigator.of(context).pop(
      VideoImportRequest(
        url: _url.text.trim(),
        title: _title.text.trim(),
        durationSeconds: _durationSeconds!,
        thumbnailUrl: _thumbnailSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a video'),
    content: SizedBox(
      width: dialogContentWidth(context, preferred: 560),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _urlField(),
            const SizedBox(height: 6),
            _platformLine(),
            const SizedBox(height: 12),
            _field(_title, 'Title', 'What this talk is'),
            const SizedBox(height: 12),
            _field(_length, 'Duration', '1:04:12'),
            const SizedBox(height: 12),
            _field(
              _thumbnail,
              'Thumbnail link (optional)',
              'https://…/preview.jpg',
            ),
            const SizedBox(height: 8),
            _thumbnailButtons(),
            if (_thumbnailSource case final String thumbnailSource) ...<Widget>[
              const SizedBox(height: 10),
              VideoThumbnail(source: thumbnailSource, width: 180, height: 101),
            ],
            const SizedBox(height: 6),
            _problemLine(),
          ],
        ),
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _canImport ? _import : null,
        child: const Text('Add'),
      ),
    ],
  );

  Widget _urlField() => TextField(
    controller: _url,
    autofocus: true,
    decoration: const InputDecoration(
      labelText: 'Link',
      hintText: 'https://…',
      isDense: true,
      border: OutlineInputBorder(),
    ),
  );

  /// Says up front whether Open will land on the timestamp.
  ///
  /// Told here rather than discovered later, because the answer changes how
  /// the user works: on a site that cannot be deep-linked they will be
  /// scrubbing by hand every session.
  Widget _platformLine() {
    if (_url.text.trim().isEmpty) {
      return const Text(
        'YouTube, VuMedi, or anywhere else with a link.',
        style: TextStyle(fontSize: 11, color: AppColors.muted),
      );
    }
    final bool hasTimestamp = _platform == VideoPlatform.youtube;
    return Text(
      hasTimestamp
          ? 'YouTube — Open will land on the exact second.'
          : 'Open will show the page; you will seek to the time yourself.',
      style: const TextStyle(fontSize: 11, color: AppColors.muted),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint) =>
      TextField(
        controller: controller,
        onSubmitted: (_) => _import(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _problemLine() {
    final String? problem = _problem;
    return Text(
      problem ?? 'Times as m:ss or h:mm:ss.',
      style: TextStyle(
        fontSize: 11,
        color: problem == null ? AppColors.muted : Colors.red.shade700,
      ),
    );
  }

  Widget _thumbnailButtons() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: <Widget>[
      OutlinedButton.icon(
        onPressed: _isChoosingThumbnail ? null : _chooseThumbnail,
        icon: const Icon(Icons.folder_open_outlined, size: 18),
        label: const Text('Choose image'),
      ),
      OutlinedButton.icon(
        onPressed: _isChoosingThumbnail ? null : _pasteThumbnail,
        icon: const Icon(Icons.content_paste_outlined, size: 18),
        label: const Text('Paste image'),
      ),
      if (_thumbnailImage != null)
        TextButton(
          onPressed: _clearChosenThumbnail,
          child: const Text('Clear'),
        ),
    ],
  );

  Future<void> _chooseThumbnail() async {
    await _readThumbnail(() => widget.imageInput.chooseImages());
  }

  Future<void> _pasteThumbnail() async {
    await _readThumbnail(widget.imageInput.readClipboardImage);
  }

  /// Keeps a valid first image even when a multi-file selection also failed.
  Future<void> _readThumbnail(
    Future<List<SourceImageImport>> Function() readImages,
  ) async {
    setState(() => _isChoosingThumbnail = true);
    SourceImageImport? image;
    try {
      image = (await readImages()).firstOrNull;
    } on ReaderImageInputException catch (failure) {
      image = failure.validImages.firstOrNull;
      if (mounted) showToast(context, failure.message, isError: true);
    } on Object {
      if (mounted) {
        showToast(context, 'The image could not be read.', isError: true);
      }
    }
    if (!mounted) return;
    setState(() {
      _isChoosingThumbnail = false;
      if (image != null) {
        _thumbnailImage = image;
        _thumbnail.clear();
      }
    });
  }

  void _clearChosenThumbnail() => setState(() => _thumbnailImage = null);
}

/// Embeds a chosen image so it remains portable across devices and backups.
String videoThumbnailDataUrl(SourceImageImport image) =>
    'data:${image.mime};base64,${base64Encode(image.bytes)}';
