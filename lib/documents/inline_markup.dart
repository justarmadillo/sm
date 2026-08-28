/// Rendered inline text and its exact mapping back to markdown source.
///
/// Rendering markdown drops characters: the `**` of a strong span, the
/// `](url)` of a link, the backslash of an escape. Extraction has to record
/// where the user's selection came from in the *source*, so every rendered run
/// keeps the content range it was produced from.
library;

import 'package:meta/meta.dart';

/// Inline formatting applied to a run of rendered text.
enum InlineStyle { emphasis, strong, code, strikethrough, link, image, math }

/// Which side of a run a rendered position belongs to.
///
/// A position sitting exactly between two runs is ambiguous, and the ambiguity
/// is not cosmetic: resolving the *end* of a selection to the following run
/// would drag the closing `**` or `](url)` into the extracted markdown. Range
/// starts use [leading]; range ends use [trailing].
enum RenderedEdge {
  /// The position opens the run that begins at it.
  leading,

  /// The position closes the run that ends at it.
  trailing,
}

/// One contiguous run of rendered text produced from one contiguous range of
/// block content.
@immutable
final class InlineSegment {
  const InlineSegment({
    required this.text,
    required this.renderedStart,
    required this.contentStart,
    required this.contentEnd,
    this.styles = const <InlineStyle>{},
    this.linkHref,
    this.imageUrl,
    this.math,
  });

  /// Rendered characters of this run.
  final String text;

  /// Index of [text] within the block's rendered plain text.
  final int renderedStart;

  /// Start of the originating range in the block content text.
  final int contentStart;

  /// End of the originating range in the block content text.
  final int contentEnd;

  /// Formatting that applies to the whole run.
  final Set<InlineStyle> styles;

  /// Destination of an [InlineStyle.link] run.
  final String? linkHref;

  /// Source URL of an [InlineStyle.image] run.
  final String? imageUrl;

  /// TeX body of an [InlineStyle.math] run.
  final String? math;

  /// End of [text] within the block's rendered plain text.
  int get renderedEnd => renderedStart + text.length;

  /// Whether rendered characters map one-to-one onto content characters.
  ///
  /// False for escapes and images, where rendered length differs from source
  /// length and interior positions cannot be resolved precisely.
  bool get isIdentity => text.length == contentEnd - contentStart;

  /// Content index corresponding to [renderedIndex] within this run.
  int contentIndexFor(int renderedIndex) {
    final local = (renderedIndex - renderedStart).clamp(0, text.length);
    if (isIdentity) return contentStart + local;
    // Non-identity runs collapse to their boundaries so a selection never
    // lands inside markup it cannot address.
    return local == 0 ? contentStart : contentEnd;
  }

  /// Rendered index corresponding to [contentIndex] within this run.
  int renderedIndexFor(int contentIndex) {
    final local = (contentIndex - contentStart).clamp(
      0,
      contentEnd - contentStart,
    );
    if (isIdentity) return renderedStart + local;
    return local == 0 ? renderedStart : renderedEnd;
  }

  @override
  String toString() =>
      'InlineSegment("$text" rendered=$renderedStart..$renderedEnd '
      'content=$contentStart..$contentEnd styles=${styles.map((InlineStyle style) => style.name).toList()})';
}

/// The full rendered text of one block plus every run that produced it.
@immutable
final class InlineLayout {
  const InlineLayout({required this.plainText, required this.segments});

  /// Empty layout, for blocks with no inline content.
  static const InlineLayout empty = InlineLayout(
    plainText: '',
    segments: <InlineSegment>[],
  );

  /// Concatenation of every segment's text, in order.
  final String plainText;

  /// Runs in rendered order. Contiguous and gapless over [plainText].
  final List<InlineSegment> segments;

  /// Content index that rendered index [renderedIndex] came from.
  ///
  /// [edge] decides which run owns a position that falls exactly between two.
  int contentIndexForRendered(
    int renderedIndex, {
    RenderedEdge edge = RenderedEdge.leading,
  }) {
    if (segments.isEmpty) return 0;
    final target = renderedIndex.clamp(0, plainText.length);
    final segment = edge == RenderedEdge.leading
        ? _segmentAtLeading(target)
        : _segmentAtTrailing(target);
    return segment.contentIndexFor(target);
  }

  /// Rendered index corresponding to content index [contentIndex].
  int renderedIndexForContent(int contentIndex) {
    if (segments.isEmpty) return 0;
    if (contentIndex <= segments.first.contentStart) return 0;
    for (final segment in segments) {
      if (contentIndex < segment.contentEnd) {
        return segment.renderedIndexFor(contentIndex);
      }
      if (contentIndex == segment.contentEnd) return segment.renderedEnd;
    }
    return plainText.length;
  }

  /// Last run that starts at or before [renderedIndex].
  InlineSegment _segmentAtLeading(int renderedIndex) {
    var low = 0;
    var high = segments.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (segments[mid].renderedStart <= renderedIndex) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return segments[low];
  }

  /// First run that ends at or after [renderedIndex].
  InlineSegment _segmentAtTrailing(int renderedIndex) {
    var low = 0;
    var high = segments.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (segments[mid].renderedEnd >= renderedIndex) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return segments[low];
  }
}
