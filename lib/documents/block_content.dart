/// The renderable slice of a block's raw markdown, with an exact index map.
///
/// A block's raw markdown may contain per-line syntax that is not content:
/// the `> ` of a blockquote, the `- ` of a list item, the `## ` of a heading.
/// [BlockContent] concatenates only the content spans, and remembers where
/// every resulting character came from in the raw block. Every content
/// character corresponds to exactly one raw character, so mapping never has to
/// invent a position.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A half-open `[start, end)` range of UTF-16 indices in a block's raw text.
@immutable
final class Utf16Span {
  const Utf16Span(this.start, this.end) : assert(start <= end, 'inverted span');

  final int start;
  final int end;

  int get length => end - start;

  bool get isEmpty => start == end;

  @override
  bool operator ==(Object other) =>
      other is Utf16Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Utf16Span($start, $end)';
}

/// Content characters of one block plus their raw-text provenance.
final class BlockContent {
  /// Builds content by concatenating [spans] of [raw], in order.
  factory BlockContent.fromSpans(String raw, List<Utf16Span> spans) {
    final buffer = StringBuffer();
    var length = 0;
    for (final span in spans) {
      length += span.length;
    }
    final map = Uint32List(length + 1);
    var out = 0;
    for (final span in spans) {
      for (var i = span.start; i < span.end; i++) {
        map[out++] = i;
      }
      buffer.write(raw.substring(span.start, span.end));
    }
    // One past the end maps to the end of the final span, or to 0 when empty.
    map[length] = spans.isEmpty ? 0 : spans.last.end;
    return BlockContent._(buffer.toString(), map);
  }

  /// Content that is exactly the whole raw block.
  factory BlockContent.whole(String raw) =>
      BlockContent.fromSpans(raw, <Utf16Span>[Utf16Span(0, raw.length)]);

  const BlockContent._(this.text, this._rawIndex);

  /// Concatenated content characters.
  final String text;

  final Uint32List _rawIndex;

  /// Raw-text UTF-16 index that content index [contentIndex] came from.
  ///
  /// Accepts `text.length` and returns the end of the last content span.
  int rawIndexAt(int contentIndex) =>
      _rawIndex[contentIndex.clamp(0, text.length)];

  /// Content index whose raw index is [rawIndex], or the nearest one after it.
  ///
  /// Returns `text.length` when [rawIndex] is past every content span. Used to
  /// map a stored raw offset back into rendered coordinates.
  int contentIndexForRaw(int rawIndex) {
    var low = 0;
    var high = text.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_rawIndex[mid] < rawIndex) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}
