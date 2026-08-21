/// A passage promoted into an independent learning object.
///
/// Extraction never cuts or moves source text. It creates a new object that
/// *references* where it came from, and from that moment the extract has its
/// own schedule, priority, and lifecycle: finishing, dismissing, or deleting
/// the parent changes nothing about it. Provenance exists so context is always
/// recoverable, not so the two stay coupled.
library;

import 'package:meta/meta.dart';

import 'reader_anchor.dart';

/// Where an extract came from.
@immutable
final class Provenance {
  const Provenance({
    required this.sourceId,
    required this.parentId,
    required this.parentIsSource,
    required this.startAnchor,
    required this.endAnchor,
    required this.selectedTextHash,
  });

  /// Root source, even for an extract of an extract. Kept denormalized so
  /// "open the source" never has to walk the chain.
  final String sourceId;

  /// Immediate parent: a source, or another extract.
  final String parentId;

  /// Whether [parentId] names a source rather than an extract.
  final bool parentIsSource;

  /// Start of the selection in the parent's coordinates.
  final ReaderAnchor startAnchor;

  /// End of the selection in the parent's coordinates.
  final ReaderAnchor endAnchor;

  /// SHA-256 of the exact markdown that was selected, so a later mismatch is
  /// detectable instead of silently wrong.
  final String selectedTextHash;

  /// Whether the selection stayed inside one block.
  bool get isSameBlock => startAnchor.blockId == endAnchor.blockId;

  /// The selection expressed as a range.
  SelectionRange get range => SelectionRange(
    startAnchor: startAnchor,
    endAnchor: endAnchor,
    selectedTextHash: selectedTextHash,
  );

  @override
  bool operator ==(Object other) =>
      other is Provenance &&
      other.sourceId == sourceId &&
      other.parentId == parentId &&
      other.parentIsSource == parentIsSource &&
      other.startAnchor == startAnchor &&
      other.endAnchor == endAnchor &&
      other.selectedTextHash == selectedTextHash;

  @override
  int get hashCode => Object.hash(
    sourceId,
    parentId,
    parentIsSource,
    startAnchor,
    endAnchor,
    selectedTextHash,
  );

  @override
  String toString() => 'Provenance($parentId $startAnchor..$endAnchor)';
}

/// An independently scheduled passage.
@immutable
final class Extract {
  const Extract({
    required this.id,
    required this.markdown,
    required this.provenance,
    required this.createdAtUtc,
    this.editedAtUtc,
  });

  final String id;

  /// The extracted markdown. Editable: an extract is refined across
  /// encounters, and editing never reschedules it.
  final String markdown;

  final Provenance provenance;
  final DateTime createdAtUtc;

  /// When the text was last edited, or null when untouched since creation.
  final DateTime? editedAtUtc;

  /// Whether the text still matches what was originally selected.
  bool get isVerbatim => editedAtUtc == null;

  Extract withMarkdown(String value, DateTime editedAtUtc) => Extract(
    id: id,
    markdown: value,
    provenance: provenance,
    createdAtUtc: createdAtUtc,
    editedAtUtc: editedAtUtc.toUtc(),
  );

  @override
  bool operator ==(Object other) => other is Extract && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Extract($id from ${provenance.parentId})';
}
