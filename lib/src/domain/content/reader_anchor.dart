/// Stable coordinates into a source document.
///
/// An anchor is `(blockId, utf8Offset)`, never a scroll position and never a
/// percentage. Blocks are immutable and their ids are stable, so an anchor
/// resolves identically whether or not the block is currently mounted, at any
/// font size, and after any window resize.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// A single position inside a block.
@immutable
final class ReaderAnchor implements Comparable<ReaderAnchor> {
  const ReaderAnchor({required this.blockId, required this.utf8Offset});

  /// Identifier of the block this position lives in.
  final String blockId;

  /// UTF-8 byte offset within that block's raw markdown.
  final int utf8Offset;

  /// The same position with a different offset.
  ReaderAnchor withOffset(int offset) =>
      ReaderAnchor(blockId: blockId, utf8Offset: offset);

  @override
  int compareTo(ReaderAnchor other) {
    final byBlock = blockId.compareTo(other.blockId);
    if (byBlock != 0) return byBlock;
    return utf8Offset.compareTo(other.utf8Offset);
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderAnchor &&
      other.blockId == blockId &&
      other.utf8Offset == utf8Offset;

  @override
  int get hashCode => Object.hash(blockId, utf8Offset);

  @override
  String toString() => 'ReaderAnchor($blockId@$utf8Offset)';
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

  /// Whether both ends live in the same block.
  bool get isSameBlock => startAnchor.blockId == endAnchor.blockId;

  /// Whether the range selects nothing.
  bool get isCollapsed =>
      isSameBlock && startAnchor.utf8Offset == endAnchor.utf8Offset;

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
  String toString() => 'SelectionRange($startAnchor -> $endAnchor)';
}

/// Lowercase hex SHA-256 of [markdown], encoded as UTF-8.
String hashSelection(String markdown) =>
    sha256.convert(utf8.encode(markdown)).toString();
