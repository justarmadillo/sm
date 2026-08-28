/// How stored positions move when source text is spliced.
///
/// Total and deterministic: every input offset has exactly one defined output.
/// There is no text search, no fuzzy matching, and no heuristic anywhere in
/// this file, because a heuristic that guesses wrong relocates a position
/// silently — the one failure mode the reader must never have.
///
/// See `plans/reader/EDITABLE_READER.md` §6.
library;

import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:meta/meta.dart';

/// The result of moving one position across one splice.
@immutable
final class MigratedPosition {
  const MigratedPosition(this.utf8Offset, {this.wasInsideEdit = false});

  /// Where the position now lives.
  final int utf8Offset;

  /// Whether the text this position pointed at was removed by the splice.
  ///
  /// The position was collapsed to the start of the edit. It is not wrong —
  /// it is the closest surviving place — but what it referred to is gone.
  final bool wasInsideEdit;

  @override
  bool operator ==(Object other) =>
      other is MigratedPosition &&
      other.utf8Offset == utf8Offset &&
      other.wasInsideEdit == wasInsideEdit;

  @override
  int get hashCode => Object.hash(utf8Offset, wasInsideEdit);

  @override
  String toString() =>
      'MigratedPosition($utf8Offset${wasInsideEdit ? ' inside' : ''})';
}

/// Moves [offset] across [splice].
///
/// The three rules, for a splice replacing `[a, b)` with `n` bytes:
///
/// * `offset < a` — unchanged; the edit happened after it.
/// * `offset > b` — shifted by `n - (b - a)`; the edit happened before it.
/// * `a <= offset <= b` — a boundary, resolved below.
///
/// The boundaries:
///
/// * `a < offset < b` — the text it pointed at was removed. Collapses to `a`
///   and reports [MigratedPosition.wasInsideEdit].
/// * `offset == a == b` (a pure insertion at the position) — ambiguous by
///   definition, so [gravity] decides: [PositionGravity.left] stays at `a`,
///   [PositionGravity.right] moves to `a + n`.
/// * `offset == a < b` — stays at `a`, the surviving text before the edit.
/// * `offset == b > a` — moves to `a + n`, immediately after the new text.
int migrateOffsetSimple(
  int offset,
  TextSplice splice, {
  PositionGravity gravity = PositionGravity.left,
}) => migrateOffset(offset, splice, gravity: gravity).utf8Offset;

/// Moves [offset] across [splice], reporting whether it was inside the edit.
MigratedPosition migrateOffset(
  int offset,
  TextSplice splice, {
  PositionGravity gravity = PositionGravity.left,
}) {
  final a = splice.startUtf8;
  final b = splice.endUtf8;

  if (offset < a) return MigratedPosition(offset);
  if (offset > b) return MigratedPosition(offset + splice.shift);

  // Every remaining case is a boundary: a <= offset <= b.
  if (a == b) {
    // Pure insertion exactly at the position. Nothing was removed, so this is
    // never "inside" an edit; only gravity separates the two answers.
    return MigratedPosition(
      gravity == PositionGravity.left ? a : a + splice.insertedLength,
    );
  }
  if (offset == a) return MigratedPosition(a);
  if (offset == b) return MigratedPosition(a + splice.insertedLength);
  return MigratedPosition(a, wasInsideEdit: true);
}

/// Moves [anchor] across [splice] and stamps it with [contentRevision].
ReaderAnchor migrateAnchor(
  ReaderAnchor anchor,
  TextSplice splice, {
  required int contentRevision,
  PositionGravity gravity = PositionGravity.left,
}) => ReaderAnchor(
  utf8Offset: migrateOffset(
    anchor.utf8Offset,
    splice,
    gravity: gravity,
  ).utf8Offset,
  contentRevision: contentRevision,
);

/// The result of moving a byte range across a splice.
@immutable
final class MigratedRange {
  const MigratedRange({
    required this.startUtf8,
    required this.endUtf8,
    required this.wasTouchedByEdit,
  });

  final int startUtf8;
  final int endUtf8;

  /// Whether the range overlapped the replaced region.
  ///
  /// A range that did not overlap covers byte-identical text, whether or not
  /// it shifted, so its provenance needs no re-verification. Only a range that
  /// did overlap has to be re-hashed.
  final bool wasTouchedByEdit;

  /// Whether the range no longer covers anything.
  bool get isEmpty => endUtf8 <= startUtf8;

  @override
  bool operator ==(Object other) =>
      other is MigratedRange &&
      other.startUtf8 == startUtf8 &&
      other.endUtf8 == endUtf8 &&
      other.wasTouchedByEdit == wasTouchedByEdit;

  @override
  int get hashCode => Object.hash(startUtf8, endUtf8, wasTouchedByEdit);

  @override
  String toString() =>
      'MigratedRange($startUtf8..$endUtf8${wasTouchedByEdit ? ' touched' : ''})';
}

/// Moves the range `[startUtf8, endUtf8)` across [splice].
///
/// The two ends carry opposite gravity on purpose, so a range never grows to
/// swallow text typed at either of its edges: the start moves after an
/// insertion at the start, the end stays before an insertion at the end.
MigratedRange migrateRange(
  int startUtf8,
  int endUtf8,
  TextSplice splice,
) {
  final start = migrateOffset(
    startUtf8,
    splice,
    gravity: PositionGravity.right,
  );
  final end = migrateOffset(endUtf8, splice, gravity: PositionGravity.left);
  final migratedStart = start.utf8Offset;
  final migratedEnd = end.utf8Offset < migratedStart
      ? migratedStart
      : end.utf8Offset;
  return MigratedRange(
    startUtf8: migratedStart,
    endUtf8: migratedEnd,
    wasTouchedByEdit: _overlapsEdit(startUtf8, endUtf8, splice),
  );
}

/// Whether `[start, end)` shares any byte with the region [splice] replaces.
///
/// A pure insertion strictly inside the range counts: it changed the bytes the
/// range covers even though it removed none.
bool _overlapsEdit(int start, int end, TextSplice splice) {
  final a = splice.startUtf8;
  final b = splice.endUtf8;
  if (splice.isPureInsertion) return a > start && a < end;
  return a < end && b > start;
}
