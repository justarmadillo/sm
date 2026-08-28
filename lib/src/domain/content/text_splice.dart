/// The only way source text is ever allowed to change.
///
/// A splice says *replace bytes `[startUtf8, endUtf8)` with this text*. Delete,
/// insert, and replace are all the same shape: a delete inserts nothing, an
/// insert removes nothing.
///
/// Nothing in this application computes an edit by comparing an old document
/// against a new one. Diffing is a heuristic — given text that repeats, several
/// answers are equally consistent with the result, and the wrong one relocates
/// stored positions into the wrong paragraph while reporting success. Because
/// every edit arrives as an explicit splice, position migration is arithmetic
/// with exactly one defined answer per input.
///
/// See `plans/reader/EDITABLE_READER.md` §5.
library;

import 'package:incremental_reader/src/core/utf8_offsets.dart';
import 'package:incremental_reader/src/domain/content/markdown_block_parser.dart';
import 'package:meta/meta.dart';

/// Largest insertion a single splice may carry.
///
/// A bound exists so a runaway paste cannot commit a multi-gigabyte row inside
/// the edit transaction; it is far above any realistic edit.
const int kMaxSpliceBytes = 8 * 1024 * 1024;

/// Why a splice was refused.
enum SpliceRejection {
  /// Bounds are inverted, negative, or past the end of the text.
  outOfRange,

  /// A bound falls inside a multi-byte character.
  notOnCharacterBoundary,

  /// The insertion exceeds [kMaxSpliceBytes].
  tooLarge,

  /// The splice removes nothing and inserts nothing.
  empty,
}

/// A replacement of one byte range of a document with new text.
@immutable
final class TextSplice {
  /// Builds a splice, normalizing [inserted] before it is measured.
  ///
  /// Normalizing after measuring is the classic desync: text pasted with CRLF
  /// line endings measures longer than the `\n` form that is actually stored,
  /// and every position after the splice then drifts by the number of lines.
  factory TextSplice({
    required int startUtf8,
    required int endUtf8,
    String inserted = '',
  }) => TextSplice._(startUtf8, endUtf8, normalizeMarkdown(inserted));

  /// Builds a splice from text that is already normalized.
  ///
  /// Only for values read back out of the edit journal, which stored the
  /// normalized form.
  const TextSplice.normalized({
    required int startUtf8,
    required int endUtf8,
    String inserted = '',
  }) : this._(startUtf8, endUtf8, inserted);

  const TextSplice._(this.startUtf8, this.endUtf8, this.inserted);

  /// Removes `[start, end)` and inserts nothing.
  factory TextSplice.delete(int startUtf8, int endUtf8) =>
      TextSplice(startUtf8: startUtf8, endUtf8: endUtf8);

  /// Inserts [text] at [offset] without removing anything.
  factory TextSplice.insert(int offset, String text) =>
      TextSplice(startUtf8: offset, endUtf8: offset, inserted: text);

  /// First byte replaced.
  final int startUtf8;

  /// One past the last byte replaced. Equal to [startUtf8] for an insertion.
  final int endUtf8;

  /// Normalized text put in place of the removed range. May be empty.
  final String inserted;

  /// Bytes removed.
  int get removedLength => endUtf8 - startUtf8;

  /// Bytes inserted.
  int get insertedLength => utf8Length(inserted);

  /// How far every offset at or after [endUtf8] moves.
  int get shift => insertedLength - removedLength;

  /// Whether this splice changes nothing.
  bool get isNoop => removedLength == 0 && insertedLength == 0;

  /// Whether this splice only adds text.
  bool get isPureInsertion => removedLength == 0;

  /// Whether applying this to [text] would leave it exactly as it is.
  ///
  /// Re-saving a block the user opened and did not change produces a splice
  /// with real bounds and identical content. It must not advance the revision:
  /// the counter has to mean "number of edits that changed something", or
  /// replaying the journal stops landing where eager migration did.
  bool changesNothingIn(String text) => removedFrom(text) == inserted;

  /// Validates against [text], returning null when the splice may be applied.
  SpliceRejection? validateAgainst(String text) {
    if (isNoop) return SpliceRejection.empty;
    if (startUtf8 < 0 || endUtf8 < startUtf8) return SpliceRejection.outOfRange;
    final index = Utf8OffsetIndex(text);
    if (endUtf8 > index.byteLength) return SpliceRejection.outOfRange;
    if (insertedLength > kMaxSpliceBytes) return SpliceRejection.tooLarge;
    if (!_onBoundary(index, startUtf8) || !_onBoundary(index, endUtf8)) {
      return SpliceRejection.notOnCharacterBoundary;
    }
    if (changesNothingIn(text)) return SpliceRejection.empty;
    return null;
  }

  /// [text] with this splice applied. Callers validate first.
  String applyTo(String text) {
    final index = Utf8OffsetIndex(text);
    final start = index.toUtf16(startUtf8);
    final end = index.toUtf16(endUtf8);
    return text.replaceRange(start, end, inserted);
  }

  /// The exact text this splice removes from [text].
  String removedFrom(String text) {
    if (removedLength == 0) return '';
    final index = Utf8OffsetIndex(text);
    return text.substring(index.toUtf16(startUtf8), index.toUtf16(endUtf8));
  }

  /// The splice that undoes this one, given the text it removed.
  ///
  /// Undo is an ordinary forward edit at a new revision, never a rewind: the
  /// journal stays append-only, so replaying it is always total.
  TextSplice inverse(String removedText) => TextSplice.normalized(
    startUtf8: startUtf8,
    endUtf8: startUtf8 + insertedLength,
    inserted: removedText,
  );

  static bool _onBoundary(Utf8OffsetIndex index, int offset) =>
      index.toUtf8(index.toUtf16(offset)) == offset;

  @override
  bool operator ==(Object other) =>
      other is TextSplice &&
      other.startUtf8 == startUtf8 &&
      other.endUtf8 == endUtf8 &&
      other.inserted == inserted;

  @override
  int get hashCode => Object.hash(startUtf8, endUtf8, inserted);

  @override
  String toString() =>
      'TextSplice($startUtf8..$endUtf8 -> ${insertedLength}b)';
}
