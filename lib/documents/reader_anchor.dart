/// Stable coordinates into a source document.
///
/// An anchor is a UTF-8 byte offset into the *whole* source markdown, stamped
/// with the content revision it was written against. It is never a scroll
/// position, never a percentage, and — deliberately — never names a block.
///
/// Block identity was the previous coordinate and could not survive editing:
/// block ids are positional (`sourceId:index`), so inserting one paragraph
/// silently re-pointed every anchor below it at its neighbour's text. A byte
/// offset names a place in the text instead of a container, so it survives
/// re-parsing, and an edit moves it by an amount the edit itself reports.
///
/// See `plans/reader/EDITABLE_READER.md` §4.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Which side of an insertion a position ends up on.
///
/// An insertion at exactly a stored offset is ambiguous, and the right answer
/// depends on what the position means. Gravity is supplied by the caller that
/// knows the role; it is not stored, because it is a property of the migration
/// rather than of the position.
enum PositionGravity {
  /// Stays before text inserted at the position.
  ///
  /// Correct for reading positions: text typed at the marker is unread, so
  /// the marker must not jump over it.
  left,

  /// Moves after text inserted at the position.
  ///
  /// Correct for the start of a provenance range, so a range never grows to
  /// swallow text typed at its leading edge.
  right,
}

/// The revision every anchor is stamped with before any edit has happened.
const int kInitialContentRevision = 1;

/// A single position inside a source document.
@immutable
final class ReaderAnchor implements Comparable<ReaderAnchor> {
  const ReaderAnchor({
    required this.utf8Offset,
    this.contentRevision = kInitialContentRevision,
  }) : assert(utf8Offset >= 0, 'negative offset');

  /// The very start of any document.
  static const ReaderAnchor start = ReaderAnchor(utf8Offset: 0);

  /// UTF-8 byte offset into the source markdown of [contentRevision].
  final int utf8Offset;

  /// Content revision of the source this offset was written against.
  ///
  /// An anchor older than the source's current revision must be migrated
  /// forward before it is resolved. See `SourceEditJournal`.
  final int contentRevision;

  /// The same position expressed against a different revision.
  ReaderAnchor withOffset(int offset, {int? contentRevision}) => ReaderAnchor(
    utf8Offset: offset,
    contentRevision: contentRevision ?? this.contentRevision,
  );

  /// Whether this anchor predates [currentRevision] and needs migrating.
  bool isStaleAgainst(int currentRevision) => contentRevision < currentRevision;

  /// Ordering is by position only; revision is provenance, not order.
  @override
  int compareTo(ReaderAnchor other) => utf8Offset.compareTo(other.utf8Offset);

  @override
  bool operator ==(Object other) =>
      other is ReaderAnchor &&
      other.utf8Offset == utf8Offset &&
      other.contentRevision == contentRevision;

  @override
  int get hashCode => Object.hash(utf8Offset, contentRevision);

  @override
  String toString() => 'ReaderAnchor(@$utf8Offset r$contentRevision)';
}

/// A selected range of source text, from [startAnchor] up to [endAnchor].
///
/// [selectedTextHash] pins the exact markdown that was selected so provenance
/// can be verified later, and so a mismatch is detectable rather than silent.
@immutable
final class SelectionRange {
  const SelectionRange({
    required this.startAnchor,
    required this.endAnchor,
    required this.selectedTextHash,
  });

  /// Builds a range and derives its hash from [markdown].
  factory SelectionRange.of({
    required ReaderAnchor startAnchor,
    required ReaderAnchor endAnchor,
    required String markdown,
  }) => SelectionRange(
    startAnchor: startAnchor,
    endAnchor: endAnchor,
    selectedTextHash: hashSelection(markdown),
  );

  final ReaderAnchor startAnchor;
  final ReaderAnchor endAnchor;

  /// Lowercase hex SHA-256 of the exact selected markdown.
  final String selectedTextHash;

  /// First byte of the range.
  int get startUtf8 => startAnchor.utf8Offset;

  /// One past the last byte of the range.
  int get endUtf8 => endAnchor.utf8Offset;

  /// Byte length of the range.
  int get lengthUtf8 => endUtf8 - startUtf8;

  /// Whether the range selects nothing.
  bool get isCollapsed => endUtf8 <= startUtf8;

  /// Whether [markdown] is the text this range was created from.
  bool matches(String markdown) => hashSelection(markdown) == selectedTextHash;

  @override
  bool operator ==(Object other) =>
      other is SelectionRange &&
      other.startAnchor == startAnchor &&
      other.endAnchor == endAnchor &&
      other.selectedTextHash == selectedTextHash;

  @override
  int get hashCode => Object.hash(startAnchor, endAnchor, selectedTextHash);

  @override
  String toString() => 'SelectionRange($startUtf8..$endUtf8)';
}

/// Lowercase hex SHA-256 of [markdown], encoded as UTF-8.
String hashSelection(String markdown) =>
    sha256.convert(utf8.encode(markdown)).toString();
