/// Video the user learns from incrementally, addressed in seconds.
///
/// Incremental reading with a different coordinate: a source is text and a
/// position is a byte offset into it; a video is a URL and a position is a
/// second. Everything downstream — the queue, SM20, priority, Mercy — already
/// works on whatever `isTopic` reports, so nothing here re-implements
/// scheduling.
///
/// The two objects are kept apart on purpose. A [Video] is the thing on the
/// internet, one per URL. A [VideoElement] is one *range* over it that the
/// user has chosen to process: the whole talk, or a clip cut out of it. They
/// are the same shape because a clip is not a different kind of thing — it is
/// a narrower range with a parent, which is why cutting a clip out of a clip
/// needs no rule of its own.
///
/// Nothing here plays anything. Playback is external by design: an embedded
/// player depends on another company continuing to permit it, and a
/// collection that stops opening when a policy changes is worthless.
library;

import 'package:incremental_reader/documents/video_time.dart';
import 'package:meta/meta.dart';

/// Which site a video lives on, so the right timestamped link can be built.
///
/// [other] is not a failure. It is the honest answer for every site whose
/// deep-link format is unknown, and the screen tells the user to seek by hand
/// rather than opening a URL whose timestamp is silently ignored.
enum VideoPlatform { youtube, vumedi, other }

/// A video that exists somewhere on the internet.
@immutable
final class Video {
  const Video({
    required this.id,
    required this.url,
    required this.platform,
    required this.addedAtUtc,
    this.durationSeconds,
  });

  final String id;

  /// The page the video is watched on, without any timestamp of ours.
  final String url;

  final VideoPlatform platform;

  /// Whole-video length, when the user typed it.
  ///
  /// Never fetched: asking the site for it would put the feature back under
  /// the API terms it exists to avoid.
  final int? durationSeconds;

  final DateTime addedAtUtc;

  Video copyWith({
    String? url,
    VideoPlatform? platform,
    int? durationSeconds,
  }) => Video(
    id: id,
    url: url ?? this.url,
    platform: platform ?? this.platform,
    addedAtUtc: addedAtUtc,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );

  @override
  bool operator ==(Object other) => other is Video && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Video($id ${platform.name} $url)';
}

/// One scheduled range over a video: the whole thing, or a clip cut from it.
@immutable
final class VideoElement {
  const VideoElement({
    required this.id,
    required this.videoId,
    required this.startSeconds,
    required this.endSeconds,
    required this.createdAtUtc,
    this.parentVideoElementId,
    this.title,
    this.note = '',
    this.resumeSeconds,
    this.editedAtUtc,
    this.revision = 1,
  }) : assert(startSeconds >= 0, 'negative start'),
       assert(endSeconds > startSeconds, 'empty range');

  final String id;

  final String videoId;

  /// The element this clip was cut from, or null on the whole video.
  final String? parentVideoElementId;

  /// The user's own name for this range.
  ///
  /// Required on a whole video, which is otherwise unfindable in the tree.
  /// Optional on a clip, which falls back to its own times — see
  /// [displayTitle].
  final String? title;

  /// What the user wrote about this range. Markdown, and what cards are
  /// formulated from.
  final String note;

  final int startSeconds;

  /// One past the last second of the range, so `rangeSeconds` is a length.
  final int endSeconds;

  /// How far into the video the user says they got.
  ///
  /// Typed, never observed. Playback happens outside the app, so there is no
  /// honest way to know where the viewer actually is, and inventing one would
  /// make progress a number nobody entered.
  final int? resumeSeconds;

  final DateTime createdAtUtc;
  final DateTime? editedAtUtc;

  /// Optimistic-concurrency revision of this row.
  final int revision;

  /// Whether this is a clip rather than the whole video.
  bool get isClip => parentVideoElementId != null;

  /// Length of the range in seconds.
  int get rangeSeconds => endSeconds - startSeconds;

  /// How much of the range the user has been through, or null before they
  /// have said.
  double? get watchedFraction {
    final int? resume = resumeSeconds;
    if (resume == null) return null;
    if (rangeSeconds <= 0) return 1;
    return ((resume - startSeconds) / rangeSeconds).clamp(0, 1).toDouble();
  }

  /// Whether the user has said they reached the end of this range.
  bool get hasReachedEnd =>
      resumeSeconds != null && resumeSeconds! >= endSeconds;

  /// The range written the way the user reads it: `4:12 – 7:30`.
  String get rangeLabel =>
      '${formatVideoTime(startSeconds)} – ${formatVideoTime(endSeconds)}';

  /// What to call this element in a list.
  String get displayTitle {
    final String? named = title;
    if (named != null && named.trim().isNotEmpty) return named;
    return rangeLabel;
  }

  VideoElement copyWith({
    String? title,
    String? note,
    int? startSeconds,
    int? endSeconds,
    int? resumeSeconds,
    DateTime? editedAtUtc,
    int? revision,
  }) => VideoElement(
    id: id,
    videoId: videoId,
    parentVideoElementId: parentVideoElementId,
    title: title ?? this.title,
    note: note ?? this.note,
    startSeconds: startSeconds ?? this.startSeconds,
    endSeconds: endSeconds ?? this.endSeconds,
    resumeSeconds: resumeSeconds ?? this.resumeSeconds,
    createdAtUtc: createdAtUtc,
    editedAtUtc: editedAtUtc ?? this.editedAtUtc,
    revision: revision ?? this.revision,
  );

  @override
  bool operator ==(Object other) => other is VideoElement && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoElement($id $rangeLabel)';
}

/// Seconds of `[startSeconds, endSeconds)` that no range in [covered] touches.
///
/// The video answer to "is there anything left to mine here": a whole talk
/// every second of which already sits inside a clip has been processed, the
/// same way a source every word of which sits inside an extract has. Ranges in
/// [covered] may overlap and arrive in any order.
int secondsOutside({
  required int startSeconds,
  required int endSeconds,
  required List<(int, int)> covered,
}) {
  if (endSeconds <= startSeconds) return 0;

  final List<(int, int)> clamped =
      <(int, int)>[
        for (final (int from, int to) in covered)
          if (to > startSeconds && from < endSeconds)
            (
              from < startSeconds ? startSeconds : from,
              to > endSeconds ? endSeconds : to,
            ),
      ]..sort(
        ((int, int) first, (int, int) second) => first.$1.compareTo(second.$1),
      );

  var uncovered = 0;
  var cursor = startSeconds;
  for (final (int from, int to) in clamped) {
    if (from > cursor) uncovered += from - cursor;
    if (to > cursor) cursor = to;
  }
  return uncovered + (endSeconds - cursor);
}
