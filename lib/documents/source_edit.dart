/// The append-only record of every edit made to a source's text.
///
/// One row per applied splice, keyed by the content revision it produced.
/// Undo appends an inverse splice at a *new* revision rather than deleting a
/// row, so the journal is always a complete forward history and replaying it
/// is total.
///
/// The journal is what makes a position written against an older revision
/// recoverable instead of merely suspect: it can be migrated forward through
/// the intervening splices and land exactly where eager migration would have
/// put it.
///
/// See `plans/reader/EDITABLE_READER.md` §6.1 and §9.3.
library;

import 'dart:convert';

import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/position_migration.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:meta/meta.dart';

/// One child's link back, exactly as it stood before an edit.
@immutable
final class ProvenanceSnapshot {
  const ProvenanceSnapshot({
    required this.extractId,
    required this.startUtf8,
    required this.endUtf8,
    required this.state,
  });

  factory ProvenanceSnapshot.fromJson(Map<String, Object?> json) =>
      ProvenanceSnapshot(
        extractId: json['id']! as String,
        startUtf8: json['start']! as int,
        endUtf8: json['end']! as int,
        state: ProvenanceState.values[json['state']! as int],
      );

  final String extractId;
  final int startUtf8;
  final int endUtf8;
  final ProvenanceState state;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': extractId,
    'start': startUtf8,
    'end': endUtf8,
    'state': state.index,
  };
}

/// Everything an edit displaced, recorded so undoing it is exact.
///
/// Migration is not invertible: a position that pointed inside removed text
/// was collapsed, and the collapse threw the original away. Undo is supposed
/// to leave no trace of the edit, so the pre-edit values travel with the
/// journal row rather than being recomputed from a rule that cannot recover
/// them.
@immutable
final class SourceEditRestore {
  const SourceEditRestore({
    this.markerUtf8,
    this.softUtf8,
    this.provenance = const <ProvenanceSnapshot>[],
  });

  factory SourceEditRestore.fromJson(Map<String, Object?> json) =>
      SourceEditRestore(
        markerUtf8: json['marker'] as int?,
        softUtf8: json['soft'] as int?,
        provenance: <ProvenanceSnapshot>[
          for (final entry in (json['provenance'] as List<Object?>? ??
              const <Object?>[]))
            ProvenanceSnapshot.fromJson(entry! as Map<String, Object?>),
        ],
      );

  /// Decodes a stored payload, tolerating the empty string.
  factory SourceEditRestore.decode(String encoded) {
    if (encoded.isEmpty) return none;
    return SourceEditRestore.fromJson(
      jsonDecode(encoded) as Map<String, Object?>,
    );
  }

  /// Nothing to restore.
  static const SourceEditRestore none = SourceEditRestore();

  final int? markerUtf8;
  final int? softUtf8;
  final List<ProvenanceSnapshot> provenance;

  Map<String, Object?> toJson() => <String, Object?>{
    'marker': markerUtf8,
    'soft': softUtf8,
    'provenance': <Map<String, Object?>>[
      for (final entry in provenance) entry.toJson(),
    ],
  };

  String encode() => jsonEncode(toJson());
}

/// One applied splice.
@immutable
final class SourceEdit {
  const SourceEdit({
    required this.id,
    required this.sourceId,
    required this.contentRevision,
    required this.splice,
    required this.removedText,
    required this.appliedAtUtc,
    required this.operationId,
    this.isUndo = false,
    this.restore = SourceEditRestore.none,
  });

  final String id;

  /// The source, or extract, whose text this edit changed.
  final String sourceId;

  /// The revision this splice *produced*. The revision before it is one less
  /// only when no edit was ever rejected; always compare, never assume.
  final int contentRevision;

  /// What was replaced, and with what.
  final TextSplice splice;

  /// The exact text the splice removed, kept so undo is exact.
  final String removedText;

  final DateTime appliedAtUtc;

  /// Idempotency key of the command that applied this edit.
  final String operationId;

  /// Whether this edit was itself the undo of an earlier one.
  final bool isUndo;

  /// What this edit displaced, so undoing it restores rather than approximates.
  final SourceEditRestore restore;

  /// The splice that reverses this edit.
  TextSplice get inverseSplice => splice.inverse(removedText);

  @override
  bool operator ==(Object other) => other is SourceEdit && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SourceEdit($sourceId r$contentRevision $splice${isUndo ? ' undo' : ''})';
}

/// Replays journal entries over positions written against older revisions.
///
/// Entries may be supplied in any order; they are sorted by revision, because
/// migration is only associative when applied in the order the edits happened.
final class SourceEditJournal {
  SourceEditJournal(Iterable<SourceEdit> edits)
    : _edits = List<SourceEdit>.unmodifiable(
        edits.toList()
          ..sort(
            (SourceEdit a, SourceEdit b) =>
                a.contentRevision.compareTo(b.contentRevision),
          ),
      );

  /// An empty journal, for a source that has never been edited.
  static final SourceEditJournal empty = SourceEditJournal(
    const <SourceEdit>[],
  );

  final List<SourceEdit> _edits;

  List<SourceEdit> get edits => _edits;

  /// Highest revision recorded, or null when nothing has been edited.
  int? get latestRevision =>
      _edits.isEmpty ? null : _edits.last.contentRevision;

  /// Edits that produced a revision after [contentRevision].
  Iterable<SourceEdit> after(int contentRevision) =>
      _edits.where((SourceEdit e) => e.contentRevision > contentRevision);

  /// Brings [anchor] forward to [currentRevision].
  ///
  /// Returns the anchor unchanged when it is already current. A gap in the
  /// journal cannot be bridged, so a missing entry yields null rather than a
  /// position that only looks plausible.
  ReaderAnchor? migrateAnchorForward(
    ReaderAnchor anchor, {
    required int currentRevision,
    PositionGravity gravity = PositionGravity.left,
  }) {
    if (anchor.contentRevision >= currentRevision) return anchor;
    final pending = after(anchor.contentRevision).toList();
    if (!_isContiguous(pending, anchor.contentRevision, currentRevision)) {
      return null;
    }
    var offset = anchor.utf8Offset;
    for (final edit in pending) {
      offset = migrateOffset(offset, edit.splice, gravity: gravity).utf8Offset;
    }
    return ReaderAnchor(utf8Offset: offset, contentRevision: currentRevision);
  }

  /// Brings the byte range `[startUtf8, endUtf8)` forward to [currentRevision].
  ///
  /// [MigratedRange.touchedByEdit] is true when *any* replayed splice touched
  /// the range, so a caller re-verifies provenance exactly when it must.
  MigratedRange? migrateRangeForward(
    int startUtf8,
    int endUtf8, {
    required int fromRevision,
    required int currentRevision,
  }) {
    if (fromRevision >= currentRevision) {
      return MigratedRange(
        startUtf8: startUtf8,
        endUtf8: endUtf8,
        touchedByEdit: false,
      );
    }
    final pending = after(fromRevision).toList();
    if (!_isContiguous(pending, fromRevision, currentRevision)) return null;
    var start = startUtf8;
    var end = endUtf8;
    var touched = false;
    for (final edit in pending) {
      final migrated = migrateRange(start, end, edit.splice);
      start = migrated.startUtf8;
      end = migrated.endUtf8;
      touched = touched || migrated.touchedByEdit;
    }
    return MigratedRange(
      startUtf8: start,
      endUtf8: end,
      touchedByEdit: touched,
    );
  }

  /// Whether [pending] covers every revision from [from] up to [to].
  static bool _isContiguous(List<SourceEdit> pending, int from, int to) {
    if (pending.length != to - from) return false;
    var expected = from + 1;
    for (final edit in pending) {
      if (edit.contentRevision != expected) return false;
      expected++;
    }
    return true;
  }
}
