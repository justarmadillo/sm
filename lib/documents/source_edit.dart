/// The append-only record of every edit made to a source's text.
///
/// One row per applied splice, keyed by the content revision it produced.
/// Undo appends an inverse splice at a *new* revision rather than deleting a
/// row, so the journal is always a complete forward history and replaying it
/// is total.
///
/// Each row also keeps the positions displaced by its splice, so undo can
/// restore exact coordinates instead of trying to invert a lossy migration.
///
/// See `plans/reader/EDITABLE_READER.md` §6.1 and §9.3.
library;

import 'dart:convert';

import 'package:incremental_reader/documents/extract.dart';
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
        state: _provenanceStateFromIndex(json['state']),
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
          for (final entry
              in (json['provenance'] as List<Object?>? ?? const <Object?>[]))
            ProvenanceSnapshot.fromJson(entry! as Map<String, Object?>),
        ],
      );

  /// Decodes a stored payload, tolerating the empty string.
  ///
  /// An unreadable payload decodes to [none] rather than throwing. The journal
  /// row it came from is still a real edit that still replays; all that is lost
  /// is the marker and provenance this particular undo would have put back, and
  /// refusing to undo at all would not put them back either.
  factory SourceEditRestore.decode(String encoded) {
    if (encoded.isEmpty) return none;
    try {
      final Object? decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) return none;
      return SourceEditRestore.fromJson(decoded);
    } on FormatException {
      return none;
    }
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

/// The provenance state stored as [raw], or [ProvenanceState.stale] when the
/// number is not one this build knows.
///
/// Unlike the extract table's own column this one lives inside a JSON blob
/// with no `CHECK` constraint behind it. `stale` is the pessimistic answer:
/// it says the recorded location is no longer known to show the same passage,
/// which is exactly what an unreadable state means.
ProvenanceState _provenanceStateFromIndex(Object? raw) {
  if (raw is! int || raw < 0 || raw >= ProvenanceState.values.length) {
    return ProvenanceState.stale;
  }
  return ProvenanceState.values[raw];
}
