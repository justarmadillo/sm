/// Adding a video: a link, a name, and the part of it worth studying.
///
/// The range defaults to the whole thing from zero, because most videos are
/// worth starting at the beginning and the two fields are there for the talk
/// whose first twenty minutes are introductions.
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
    required this.startSeconds,
    required this.endSeconds,
    this.durationSeconds,
  });

  final String url;
  final String title;
  final int startSeconds;
  final int endSeconds;
  final int? durationSeconds;
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
  final TextEditingController _start = TextEditingController(text: '0:00');
  final TextEditingController _end = TextEditingController();

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
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  List<TextEditingController> get _watched => <TextEditingController>[
    _url,
    _title,
    _length,
    _start,
    _end,
  ];

  void _refresh() => setState(() {});

  VideoPlatform get _platform => detectVideoPlatform(_url.text);

  int? get _durationSeconds =>
      _length.text.trim().isEmpty ? null : parseVideoTime(_length.text);

  int? get _startSeconds => parseVideoTime(_start.text);

  /// The end of the studied range: what was typed, or the whole length.
  ///
  /// Leaving it blank has to mean something, and "all of it" is the only
  /// reading that does not require the user to know the length twice.
  int? get _endSeconds =>
      _end.text.trim().isEmpty ? _durationSeconds : parseVideoTime(_end.text);

  String? get _problem {
    if (_url.text.trim().isNotEmpty && Uri.tryParse(_url.text.trim()) == null) {
      return 'That link cannot be read.';
    }
    if (_length.text.trim().isNotEmpty && _durationSeconds == null) {
      return 'The length is not a time. Try 1:04:12.';
    }
    if (_start.text.trim().isNotEmpty && _startSeconds == null) {
      return 'The start is not a time. Try 4:12.';
    }
    if (_end.text.trim().isNotEmpty && parseVideoTime(_end.text) == null) {
      return 'The end is not a time. Try 20:00.';
    }
    if (_end.text.trim().isEmpty && _durationSeconds == null) {
      return 'Give an end time, or the video’s full length.';
    }
    final int? start = _startSeconds;
    final int? end = _endSeconds;
    if (start != null && end != null && end <= start) {
      return 'The end has to come after the start.';
    }
    return null;
  }

  bool get _canImport =>
      _url.text.trim().isNotEmpty &&
      _title.text.trim().isNotEmpty &&
      _startSeconds != null &&
      _endSeconds != null &&
      _problem == null;

  void _import() {
    if (!_canImport) return;
    Navigator.of(context).pop(
      VideoImportRequest(
        url: _url.text.trim(),
        title: _title.text.trim(),
        startSeconds: _startSeconds!,
        endSeconds: _endSeconds!,
        durationSeconds: _durationSeconds,
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
            _rangeRow(),
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

  Widget _rangeRow() => Row(
    children: <Widget>[
      Expanded(child: _field(_length, 'Full length', '1:04:12')),
      const SizedBox(width: 12),
      Expanded(child: _field(_start, 'Study from', '0:00')),
      const SizedBox(width: 12),
      Expanded(child: _field(_end, 'to', 'the end')),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextField(
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
