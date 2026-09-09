/// Conversion between Dart's UTF-16 string indices and UTF-8 byte offsets.
///
/// Anchors and provenance are stored as UTF-8 byte offsets so they stay valid
/// independently of the runtime string encoding, but every parser and renderer
/// works in Dart's native UTF-16 indices. This is the only place that bridges
/// the two, and it must stay exact for astral-plane characters.
library;

import 'dart:typed_data';

/// UTF-8 bytes the code unit at [utf16Index] contributes, and whether it
/// swallowed the low surrogate following it.
///
/// The two answers come from one test and so are returned together: a high
/// surrogate is four bytes only when a low surrogate follows, and in that case
/// the pair is a single code point the caller must not count twice. This is the
/// only statement of the encoding rules in the app — the byte length and the
/// offset table are both counted with it, so they cannot drift apart.
({int byteCount, bool didConsumePair}) _encodedWidthAt(
  String text,
  int utf16Index,
) {
  final unit = text.codeUnitAt(utf16Index);
  if (unit < 0x80) return (byteCount: 1, didConsumePair: false);
  if (unit < 0x800) return (byteCount: 2, didConsumePair: false);
  if (unit >= 0xD800 && unit <= 0xDBFF) {
    final isPaired =
        utf16Index + 1 < text.length &&
        text.codeUnitAt(utf16Index + 1) >= 0xDC00 &&
        text.codeUnitAt(utf16Index + 1) <= 0xDFFF;
    if (isPaired) return (byteCount: 4, didConsumePair: true);
  }
  // Everything else is three bytes: an ordinary BMP character, and also a
  // surrogate with no partner, for which encoders emit the 3-byte U+FFFD.
  return (byteCount: 3, didConsumePair: false);
}

/// Number of UTF-8 bytes [text] occupies, without allocating an encoded copy.
int utf8Length(String text) {
  var bytes = 0;
  for (var cursor = 0; cursor < text.length; cursor++) {
    final width = _encodedWidthAt(text, cursor);
    bytes += width.byteCount;
    if (width.didConsumePair) cursor++;
  }
  return bytes;
}

/// A reusable index over one string, converting indices in both directions.
///
/// Construction is O(n) in the length of the string and allocates one
/// [Uint32List]. Build it once per block, not once per lookup.
final class Utf8OffsetIndex {
  /// Builds the cumulative byte table for [text].
  Utf8OffsetIndex(this.text) : _byteAt = Uint32List(text.length + 1) {
    var bytes = 0;
    for (var cursor = 0; cursor < text.length; cursor++) {
      _byteAt[cursor] = bytes;
      final width = _encodedWidthAt(text, cursor);
      if (width.didConsumePair) {
        // Both halves of the pair map to the start of the 4-byte sequence;
        // the pair as a whole advances by 4.
        _byteAt[cursor + 1] = bytes;
        cursor++;
      }
      bytes += width.byteCount;
    }
    _byteAt[text.length] = bytes;
  }

  /// The indexed string.
  final String text;

  final Uint32List _byteAt;

  /// Total UTF-8 length of [text].
  int get byteLength => _byteAt[text.length];

  /// UTF-8 byte offset of the UTF-16 index [utf16Index].
  ///
  /// [utf16Index] is clamped into `0..text.length`.
  int toUtf8(int utf16Index) {
    final i = utf16Index.clamp(0, text.length);
    return _byteAt[i];
  }

  /// UTF-16 index of the UTF-8 byte offset [utf8Offset].
  ///
  /// An offset landing inside a multi-byte sequence resolves to the start of
  /// the code point containing it, so a surrogate pair is never split.
  /// [utf8Offset] is clamped into `0..byteLength`.
  int toUtf16(int utf8Offset) {
    final target = utf8Offset.clamp(0, byteLength);
    // First index whose byte offset is >= target. Ties resolve to the lowest
    // such index, which is the high surrogate of a pair rather than its low
    // half, because both halves share one byte offset.
    var low = 0;
    var high = text.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_byteAt[mid] < target) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    // A target inside a multi-byte sequence backs up to the unit holding it.
    var index = _byteAt[low] == target ? low : low - 1;
    // Both halves of a surrogate pair share one byte offset; keep backing up
    // so the result is always the start of a whole code point.
    while (index > 0 && _byteAt[index - 1] == _byteAt[index]) {
      index--;
    }
    return index;
  }
}
