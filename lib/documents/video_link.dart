/// Turning a video URL and a second into the link that opens it there.
///
/// Kept apart from any screen so the rules are testable with plain
/// `dart test`, and kept apart from [Video] so adding a site later is one
/// entry here and one test, not a change to stored data.
///
/// The design rule: **never pretend a timestamp worked.** Appending a
/// parameter a site ignores produces a link that opens at zero while the app
/// claims it opened at 4:12, which reads as a broken app rather than as an
/// unsupported site. So an unknown site returns its URL untouched and says so,
/// and the screen asks the user to seek by hand.
library;

import 'package:incremental_reader/documents/video.dart';
import 'package:meta/meta.dart';

/// A link to open, and whether the time is actually carried in it.
@immutable
final class VideoOpenLink {
  const VideoOpenLink({required this.url, required this.hasTimestamp});

  /// The URL to hand the platform.
  final String url;

  /// Whether [url] lands at the requested second.
  ///
  /// False means the screen must show the time separately, because the site
  /// will open at the beginning.
  final bool hasTimestamp;

  @override
  bool operator ==(Object other) =>
      other is VideoOpenLink &&
      other.url == url &&
      other.hasTimestamp == hasTimestamp;

  @override
  int get hashCode => Object.hash(url, hasTimestamp);

  @override
  String toString() => 'VideoOpenLink($url timestamped=$hasTimestamp)';
}

/// Which site [url] points at.
///
/// Matching is on the host and nothing else: a title or a path that mentions
/// YouTube is not a YouTube link, and treating it as one would build a
/// timestamp parameter for the wrong player.
VideoPlatform detectVideoPlatform(String url) {
  final Uri? parsed = Uri.tryParse(url.trim());
  if (parsed == null) return VideoPlatform.other;

  final String host = parsed.host.toLowerCase();
  final String bare = host.startsWith('www.') ? host.substring(4) : host;
  return switch (bare) {
    'youtube.com' || 'm.youtube.com' || 'youtu.be' => VideoPlatform.youtube,
    'vumedi.com' => VideoPlatform.vumedi,
    _ => VideoPlatform.other,
  };
}

/// The link that opens [url] at [atSeconds], as far as [platform] allows.
///
/// VuMedi is deliberately in the untimestamped group. Its player's deep-link
/// format is not known here, and a guess that fails is worse than a seek hint
/// that works.
VideoOpenLink videoOpenLink({
  required String url,
  required VideoPlatform platform,
  required int atSeconds,
}) {
  if (platform != VideoPlatform.youtube) {
    return VideoOpenLink(url: url, hasTimestamp: false);
  }

  final Uri? parsed = Uri.tryParse(url.trim());
  if (parsed == null) return VideoOpenLink(url: url, hasTimestamp: false);

  final int seconds = atSeconds < 0 ? 0 : atSeconds;
  // Replaced rather than added: a link copied out of YouTube at some other
  // moment already carries a `t`, and two of them is undefined.
  final Map<String, String> query = <String, String>{
    ...parsed.queryParameters,
    't': '${seconds}s',
  };
  return VideoOpenLink(
    url: parsed.replace(queryParameters: query).toString(),
    hasTimestamp: true,
  );
}
