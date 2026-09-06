/// Adding a video: its link, title, duration, and optional thumbnail.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/documents/video_link.dart';
import 'package:incremental_reader/documents/video_time.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

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
Future<VideoImportRequest?> showImportVideoSheet(BuildContext context) =>
    showDialog<VideoImportRequest>(
      context: context,
      builder: (BuildContext context) => const _ImportVideoDialog(),
    );

class _ImportVideoDialog extends StatefulWidget {
  const _ImportVideoDialog();

  @override
  State<_ImportVideoDialog> createState() => _ImportVideoDialogState();
}

class _ImportVideoDialogState extends State<_ImportVideoDialog> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _length = TextEditingController();
  final TextEditingController _thumbnail = TextEditingController();

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
    final String thumbnail = _thumbnail.text.trim();
    final Uri? thumbnailUri = Uri.tryParse(thumbnail);
    if (thumbnail.isNotEmpty &&
        (thumbnailUri?.hasScheme != true ||
            thumbnailUri?.host.isEmpty != false)) {
      return 'The thumbnail needs a complete link.';
    }
    return null;
  }

  bool get _canImport =>
      _url.text.trim().isNotEmpty &&
      _title.text.trim().isNotEmpty &&
      _durationSeconds != null &&
      _problem == null;

  void _import() {
    if (!_canImport) return;
    Navigator.of(context).pop(
      VideoImportRequest(
        url: _url.text.trim(),
        title: _title.text.trim(),
        durationSeconds: _durationSeconds!,
        thumbnailUrl: _thumbnail.text.trim().isEmpty
            ? null
            : _thumbnail.text.trim(),
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
}
