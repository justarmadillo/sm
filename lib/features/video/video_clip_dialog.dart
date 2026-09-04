/// Cutting a clip: two times and what you want to remember about them.
///
/// Times are typed rather than scrubbed, because the app is not the player.
/// The start defaults to wherever the user said they got to, which is the
/// moment they are almost always cutting from.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/video_time.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

/// What the user asked to cut.
@immutable
final class ClipRequest {
  const ClipRequest({
    required this.startSeconds,
    required this.endSeconds,
    required this.note,
  });

  final int startSeconds;
  final int endSeconds;
  final String note;
}

/// Asks for a clip's range and note, and returns it, or null.
Future<ClipRequest?> showClipDialog(
  BuildContext context, {
  required int defaultStartSeconds,
  required int rangeStartSeconds,
  required int rangeEndSeconds,
}) => showDialog<ClipRequest>(
  context: context,
  builder: (BuildContext context) => _ClipDialog(
    defaultStartSeconds: defaultStartSeconds,
    rangeStartSeconds: rangeStartSeconds,
    rangeEndSeconds: rangeEndSeconds,
  ),
);

class _ClipDialog extends StatefulWidget {
  const _ClipDialog({
    required this.defaultStartSeconds,
    required this.rangeStartSeconds,
    required this.rangeEndSeconds,
  });

  final int defaultStartSeconds;

  /// The bounds of what is being watched. A clip outside them is not a clip
  /// of it, so the dialog refuses rather than letting the database do it.
  final int rangeStartSeconds;
  final int rangeEndSeconds;

  @override
  State<_ClipDialog> createState() => _ClipDialogState();
}

class _ClipDialogState extends State<_ClipDialog> {
  late final TextEditingController _start = TextEditingController(
    text: formatVideoTime(widget.defaultStartSeconds),
  );
  final TextEditingController _end = TextEditingController();
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _start.addListener(_refresh);
    _end.addListener(_refresh);
  }

  @override
  void dispose() {
    _start.removeListener(_refresh);
    _end.removeListener(_refresh);
    _start.dispose();
    _end.dispose();
    _note.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  int? get _startSeconds => parseVideoTime(_start.text);

  int? get _endSeconds => parseVideoTime(_end.text);

  /// Why the times cannot be used yet, or null when they can.
  ///
  /// One message at a time and only once both fields hold something: telling
  /// the user the end is missing while they are still typing the start is
  /// noise, not help.
  String? get _problem {
    final int? start = _startSeconds;
    final int? end = _endSeconds;
    if (_start.text.trim().isNotEmpty && start == null) {
      return 'The start is not a time. Try 4:12.';
    }
    if (_end.text.trim().isNotEmpty && end == null) {
      return 'The end is not a time. Try 7:30.';
    }
    if (start == null || end == null) return null;
    if (end <= start) return 'The end has to come after the start.';
    if (start < widget.rangeStartSeconds || end > widget.rangeEndSeconds) {
      return 'That falls outside '
          '${formatVideoTime(widget.rangeStartSeconds)} – '
          '${formatVideoTime(widget.rangeEndSeconds)}.';
    }
    return null;
  }

  bool get _canCut =>
      _startSeconds != null && _endSeconds != null && _problem == null;

  void _cut() {
    if (!_canCut) return;
    Navigator.of(context).pop(
      ClipRequest(
        startSeconds: _startSeconds!,
        endSeconds: _endSeconds!,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cut a clip'),
    content: SizedBox(
      width: dialogContentWidth(context, preferred: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _timeRow(),
          const SizedBox(height: 6),
          _problemLine(),
          const SizedBox(height: 12),
          _noteField(),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _canCut ? _cut : null,
        child: const Text('Cut'),
      ),
    ],
  );

  Widget _timeRow() => Row(
    children: <Widget>[
      Expanded(child: _timeField(_start, 'From', '4:12')),
      const SizedBox(width: 12),
      Expanded(child: _timeField(_end, 'To', '7:30')),
    ],
  );

  Widget _timeField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextField(
    controller: controller,
    autofocus: label == 'To',
    onSubmitted: (_) => _cut(),
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

  Widget _noteField() => TextField(
    controller: _note,
    minLines: 3,
    maxLines: null,
    style: const TextStyle(fontSize: 13, height: 1.45),
    decoration: const InputDecoration(
      labelText: 'Note',
      hintText: 'What is worth remembering from these minutes?',
      alignLabelWithHint: true,
      isDense: true,
      border: OutlineInputBorder(),
    ),
  );
}
