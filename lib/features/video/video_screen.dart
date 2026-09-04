/// Processing surface for one range of a video.
///
/// The Reader's shape with the text replaced by a timeline: where you are,
/// what you cut out of it, and what you wrote. The video itself plays
/// somewhere else — pressing Open hands the platform a timestamped link and
/// this screen gets out of the way.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/documents/video_link.dart';
import 'package:incremental_reader/documents/video_time.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/video/video_clip_dialog.dart';
import 'package:incremental_reader/features/video/video_view_model.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the video screen for browsing.
Future<StudyRouteResult> openVideo(
  BuildContext context,
  WidgetRef ref, {
  required String videoElementId,
  required VideoMode mode,
}) async =>
    await Navigator.of(context).push<StudyRouteResult>(
      MaterialPageRoute<StudyRouteResult>(
        builder: (BuildContext context) => VideoScreen(
          request: VideoRequest(videoElementId: videoElementId, mode: mode),
        ),
      ),
    ) ??
    StudyRouteResult.canceled;

/// Opens the video screen as a scheduled sitting from the queue.
Future<StudyRouteResult> openVideoForStudy(
  BuildContext context,
  WidgetRef ref, {
  required String videoElementId,
}) => openVideo(
  context,
  ref,
  videoElementId: videoElementId,
  mode: VideoMode.scheduled,
);

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({required this.request, super.key});

  final VideoRequest request;

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  late final TextEditingController _note = TextEditingController();

  /// The note as it was last loaded, so an edit made in another window is not
  /// overwritten by whatever this screen happened to have on screen.
  String _loadedNote = '';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  VideoViewModel get _model =>
      ref.read(videoViewModelProvider(widget.request).notifier);

  void _syncNote(VideoUiState state) {
    if (state.element.note == _loadedNote) return;
    _loadedNote = state.element.note;
    _note.text = _loadedNote;
  }

  Future<void> _open(VideoUiState state) async {
    final VideoOpenLink link = state.openLink;
    final Uri? target = Uri.tryParse(link.url);
    if (target == null) {
      showToast(context, 'That link cannot be opened.', isError: true);
      return;
    }
    final bool didOpen = await launchUrl(
      target,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || didOpen) return;
    showToast(context, 'Nothing on this device opens that link.', isError: true);
  }

  Future<void> _setResume(VideoUiState state) async {
    final int? seconds = await showTimeDialog(
      context,
      title: 'Where did you get to?',
      initialSeconds: state.openAtSeconds,
      lowestSeconds: state.element.startSeconds,
      highestSeconds: state.element.endSeconds,
    );
    if (seconds == null) return;
    await _model.setResume(seconds);
  }

  Future<void> _cutClip(VideoUiState state) async {
    final ClipRequest? request = await showClipDialog(
      context,
      defaultStartSeconds: state.openAtSeconds,
      rangeStartSeconds: state.element.startSeconds,
      rangeEndSeconds: state.element.endSeconds,
    );
    if (request == null) return;
    await _model.addClip(
      startSeconds: request.startSeconds,
      endSeconds: request.endSeconds,
      note: request.note,
    );
  }

  Future<void> _formulate(VideoUiState state) async {
    final List<CardDraft>? drafts = await showFormulationDialog(
      context,
      seedText: state.element.note,
      existingCardCount: state.cards.length,
      parentNoun: 'video',
    );
    if (drafts == null || drafts.isEmpty) return;
    await _model.formulate(drafts);
  }

  Future<void> _saveNote() async {
    await _model.edit(note: _note.text);
    _loadedNote = _note.text;
  }

  void _finish(StudyRouteResult outcome) {
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VideoUiState> state = ref.watch(
      videoViewModelProvider(widget.request),
    );
    ref.listen<AsyncValue<VideoUiState>>(videoViewModelProvider(widget.request), (
      AsyncValue<VideoUiState>? previous,
      AsyncValue<VideoUiState> next,
    ) {
      final VideoUiState? value = next.valueOrNull;
      if (value == null) return;
      final UiMessage? message = value.message;
      if (message != null) {
        showToast(context, message.text, isError: message.isError);
        _model.shouldClearMessage();
      }
      if (value.isDone) _finish(StudyRouteResult.committed);
    });

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) =>
          Scaffold(body: Center(child: Text('$error'))),
      data: _scaffold,
    );
  }

  Widget _scaffold(VideoUiState state) {
    _syncNote(state);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(state),
      body: Column(
        children: <Widget>[
          _VideoStatusBar(state: state),
          Expanded(child: _body(state)),
        ],
      ),
      bottomNavigationBar: _VideoActionBar(
        state: state,
        onFormulate: () => _formulate(state),
        onDismiss: _model.dismiss,
        onLater: _model.later,
        onDone: _model.done,
      ),
    );
  }

  PreferredSizeWidget _appBar(VideoUiState state) => AppBar(
    backgroundColor: AppColors.surface,
    title: Text(
      state.element.displayTitle,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 16),
    ),
    actions: <Widget>[
      IconButton(
        tooltip: 'Priority',
        icon: const Icon(Icons.low_priority),
        onPressed: () =>
            showPriorityDialog(context, ref, elementRef: state.topic.ref),
      ),
    ],
  );

  Widget _body(VideoUiState state) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    children: <Widget>[
      _openRow(state),
      const SizedBox(height: 16),
      _resumeRow(state),
      const SizedBox(height: 20),
      _noteEditor(state),
      const SizedBox(height: 24),
      _clipList(state),
    ],
  );

  /// The one button that matters, and the truth about where it lands.
  Widget _openRow(VideoUiState state) {
    final VideoOpenLink link = state.openLink;
    return Row(
      children: <Widget>[
        FilledButton.icon(
          onPressed: () => _open(state),
          icon: const Icon(Icons.play_arrow),
          label: Text('Open at ${formatVideoTime(state.openAtSeconds)}'),
        ),
        const SizedBox(width: 12),
        if (!link.hasTimestamp)
          Expanded(
            child: _SeekHint(seconds: state.openAtSeconds),
          )
        else
          Expanded(
            child: Text(
              state.video.url,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
      ],
    );
  }

  Widget _resumeRow(VideoUiState state) => Row(
    children: <Widget>[
      Expanded(child: _ProgressLine(state: state)),
      const SizedBox(width: 12),
      OutlinedButton(
        onPressed: () => _setResume(state),
        child: const Text('I got to…'),
      ),
    ],
  );

  Widget _noteEditor(VideoUiState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Text(
        'Note',
        style: TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: _note,
        minLines: 4,
        maxLines: null,
        style: const TextStyle(fontSize: 14, height: 1.5),
        decoration: const InputDecoration(
          hintText: 'What is worth keeping from this?',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: _saveNote, child: const Text('Save note')),
      ),
    ],
  );

  Widget _clipList(VideoUiState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Text(
            'Clips (${state.clips.length})',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const Spacer(),
          if (state.canMutate)
            TextButton.icon(
              onPressed: () => _cutClip(state),
              icon: const Icon(Icons.content_cut, size: 16),
              label: const Text('Cut a clip'),
            ),
        ],
      ),
      const SizedBox(height: 4),
      if (state.clips.isEmpty)
        const Text(
          'Nothing cut from this yet.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        )
      else
        for (final VideoElement clip in state.clips)
          _ClipTile(
            clip: clip,
            onOpen: () => openVideo(
              context,
              ref,
              videoElementId: clip.id,
              mode: VideoMode.browse,
            ),
          ),
    ],
  );
}

/// Asks for one time inside a known range.
///
/// Shared by the resume row and anything else that needs a single moment; the
/// clip dialog asks for two and has its own.
Future<int?> showTimeDialog(
  BuildContext context, {
  required String title,
  required int initialSeconds,
  required int lowestSeconds,
  required int highestSeconds,
}) => showDialog<int>(
  context: context,
  builder: (BuildContext context) => _TimeDialog(
    title: title,
    initialSeconds: initialSeconds,
    lowestSeconds: lowestSeconds,
    highestSeconds: highestSeconds,
  ),
);

class _TimeDialog extends StatefulWidget {
  const _TimeDialog({
    required this.title,
    required this.initialSeconds,
    required this.lowestSeconds,
    required this.highestSeconds,
  });

  final String title;
  final int initialSeconds;
  final int lowestSeconds;
  final int highestSeconds;

  @override
  State<_TimeDialog> createState() => _TimeDialogState();
}

class _TimeDialogState extends State<_TimeDialog> {
  late final TextEditingController _time = TextEditingController(
    text: formatVideoTime(widget.initialSeconds),
  );

  @override
  void initState() {
    super.initState();
    _time.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  int? get _seconds {
    final int? parsed = parseVideoTime(_time.text);
    if (parsed == null) return null;
    if (parsed < widget.lowestSeconds || parsed > widget.highestSeconds) {
      return null;
    }
    return parsed;
  }

  void _accept() {
    final int? seconds = _seconds;
    if (seconds == null) return;
    Navigator.of(context).pop(seconds);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: dialogContentWidth(context, preferred: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _time,
            autofocus: true,
            onSubmitted: (_) => _accept(),
            decoration: const InputDecoration(
              hintText: '4:12',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Between ${formatVideoTime(widget.lowestSeconds)} and '
            '${formatVideoTime(widget.highestSeconds)}.',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
        onPressed: _seconds == null ? null : _accept,
        child: const Text('Save'),
      ),
    ],
  );
}

/// What to do when the platform will not take a timestamp.
class _SeekHint extends StatelessWidget {
  const _SeekHint({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      const Icon(Icons.info_outline, size: 14, color: AppColors.softMarker),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          'Seek to ${formatVideoTime(seconds)} yourself.',
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ),
      IconButton(
        tooltip: 'Copy the time',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.copy, size: 14),
        onPressed: () => Clipboard.setData(
          ClipboardData(text: formatVideoTime(seconds)),
        ),
      ),
    ],
  );
}

/// How far through this range the user says they are.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.state});

  final VideoUiState state;

  @override
  Widget build(BuildContext context) {
    final double? watched = state.element.watchedFraction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          watched == null
              ? 'Not started · ${state.element.rangeLabel}'
              : '${(watched * 100).round()}% of '
                    '${state.element.rangeLabel}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: watched ?? 0,
            minHeight: 5,
            backgroundColor: AppColors.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({required this.clip, required this.onOpen});

  final VideoElement clip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: AppColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: ListTile(
      dense: true,
      onTap: onOpen,
      leading: const Icon(
        Icons.content_cut,
        size: 16,
        color: AppColors.extractInk,
      ),
      title: Text(
        clip.rangeLabel,
        style: const TextStyle(fontSize: 13, color: AppColors.extractInk),
      ),
      subtitle: clip.note.trim().isEmpty
          ? null
          : Text(
              clip.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
    ),
  );
}

class _VideoStatusBar extends StatelessWidget {
  const _VideoStatusBar({required this.state});

  final VideoUiState state;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: isCompactWidth(context)
        ? Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _statusParts(),
          )
        : Row(
            children: <Widget>[
              ..._statusParts().take(2),
              const Spacer(),
              ..._statusParts().skip(2),
            ],
          ),
  );

  List<Widget> _statusParts() => <Widget>[
    _StatusPill(
      text: state.canMutate ? 'Processing' : 'Browsing',
      color: state.canMutate ? AppColors.accent : AppColors.softMarker,
    ),
    Text(
      '${state.clips.length} clips · ${state.cards.length} cards · '
      '${formatVideoTime(state.unclippedSeconds)} uncut',
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    ),
    Text(
      'Repetitions ${state.topic.repetitionCount} · '
      '${state.effectiveDueDay ?? state.topic.schedule.algorithmicDueDay}',
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    ),
  ];
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );
}

class _VideoActionBar extends StatelessWidget {
  const _VideoActionBar({
    required this.state,
    required this.onFormulate,
    required this.onDismiss,
    required this.onLater,
    required this.onDone,
  });

  final VideoUiState state;
  final VoidCallback onFormulate;
  final VoidCallback onDismiss;
  final VoidCallback onLater;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    // The bar is the last thing above the Android gesture strip, so it has to
    // give that strip its own space or Done sits under the swipe area.
    child: SafeArea(
      top: false,
      child: isCompactWidth(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _hint(),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: _buttons()),
              ],
            )
          : Row(children: <Widget>[Expanded(child: _hint()), _buttons()]),
    ),
  );

  Widget _hint() => Text(
    state.canMutate
        ? 'Watch, mark where you got to, cut what is worth keeping.'
        : 'Browsing: you can still write the note and move the position.',
    style: const TextStyle(fontSize: 12, color: AppColors.muted),
  );

  Widget _buttons() => Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.end,
    children: <Widget>[
      TextButton(
        onPressed: state.canMutate && state.element.note.trim().isNotEmpty
            ? onFormulate
            : null,
        child: const Text('Cards'),
      ),
      TextButton(
        onPressed: state.canMutate ? onDismiss : null,
        child: const Text('Dismiss'),
      ),
      TextButton(
        onPressed: state.canMutate ? onLater : null,
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: state.canMutate ? onDone : null,
        child: const Text('Done'),
      ),
    ],
  );
}
