/// A passage promoted into an independent learning object.
///
/// Extraction never cuts or moves source text. It creates a new object that
/// *references* where it came from, and from that moment the extract has its
/// own schedule, priority, and lifecycle: finishing, dismissing, or deleting
/// the parent changes nothing about it. Provenance exists so context is always
/// recoverable, not so the two stay coupled.
///
/// Because an extract owns a copy of its text, editing the parent can never
/// damage the extract itself. Only the link back can degrade, and when it does
/// it is marked, never quietly repaired: re-finding the passage by searching
/// for its text picks the wrong occurrence whenever a phrase repeats, and
/// reports success while doing it.
library;

import 'package:meta/meta.dart';

import 'reader_anchor.dart';

/// How much of the link back to the parent still holds.
enum ProvenanceState {
  /// The parent's text in the recorded range still hashes to what was taken.
  verbatim,

  /// The parent's text changed under the range. The extract is intact; the
  /// recorded location is no longer known to show the same passage.
  stale,

  /// The recorded range was entirely removed from the parent.
  orphaned,
}

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
    this.state = ProvenanceState.verbatim,
  });

  /// Root source, even for an extract of an extract. Kept denormalized so
  /// "open the source" never has to walk the chain.
  final String sourceId;

  /// Immediate parent: a source, or another extract.
  final String parentId;

  /// Whether [parentId] names a source rather than an extract.
  final bool parentIsSource;

  /// Start of the selection in the parent's document coordinates.
  final ReaderAnchor startAnchor;

  /// End of the selection in the parent's document coordinates.
  final ReaderAnchor endAnchor;

  /// SHA-256 of the exact markdown that was selected, so a later mismatch is
  /// detectable instead of silently wrong.
  final String selectedTextHash;

  /// How much of this link still holds.
  final ProvenanceState state;

  /// First byte of the recorded range.
  int get startUtf8 => startAnchor.utf8Offset;

  /// One past the last byte of the recorded range.
  int get endUtf8 => endAnchor.utf8Offset;

  /// Revision of the parent these offsets were written against.
  int get contentRevision => startAnchor.contentRevision;

  /// Whether the recorded location can still be trusted to show the passage.
  bool get isIntact => state == ProvenanceState.verbatim;

  /// The selection expressed as a range.
  SelectionRange get range => SelectionRange(
    startAnchor: startAnchor,
    endAnchor: endAnchor,
    selectedTextHash: selectedTextHash,
  );

  /// The same provenance with migrated offsets and a re-evaluated state.
  Provenance migratedTo({
    required int startUtf8,
    required int endUtf8,
    required int contentRevision,
    required ProvenanceState state,
  }) => Provenance(
    sourceId: sourceId,
    parentId: parentId,
    parentIsSource: parentIsSource,
    startAnchor: ReaderAnchor(
      utf8Offset: startUtf8,
      contentRevision: contentRevision,
    ),
    endAnchor: ReaderAnchor(
      utf8Offset: endUtf8,
      contentRevision: contentRevision,
    ),
    selectedTextHash: selectedTextHash,
    state: state,
  );

  @override
  bool operator ==(Object other) =>
      other is Provenance &&
      other.sourceId == sourceId &&
      other.parentId == parentId &&
      other.parentIsSource == parentIsSource &&
      other.startAnchor == startAnchor &&
      other.endAnchor == endAnchor &&
      other.selectedTextHash == selectedTextHash &&
      other.state == state;

  @override
  int get hashCode => Object.hash(
    sourceId,
    parentId,
    parentIsSource,
    startAnchor,
    endAnchor,
    selectedTextHash,
    state,
  );

  @override
  String toString() =>
      'Provenance($parentId $startUtf8..$endUtf8 ${state.name})';
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
    this.contentRevision = kInitialContentRevision,
  });

  final String id;

  /// The extracted markdown. Editable: an extract is refined across
  /// encounters, and editing never reschedules it.
  final String markdown;

  final Provenance provenance;
  final DateTime createdAtUtc;

  /// When the text was last edited, or null when untouched since creation.
  final DateTime? editedAtUtc;

  /// Revision of [markdown] itself, for extracts that have children.
  ///
  /// An extract is a parent in its own right: extracting from an extract
  /// records offsets into *this* text, so it needs the same version counter a
  /// source has.
  final int contentRevision;

  /// Whether the text still matches what was originally selected.
  bool get isVerbatim => editedAtUtc == null;

  Extract withMarkdown(
    String value,
    DateTime editedAtUtc, {
    int? contentRevision,
  }) => Extract(
    id: id,
    markdown: value,
    provenance: provenance,
    createdAtUtc: createdAtUtc,
    editedAtUtc: editedAtUtc.toUtc(),
    contentRevision: contentRevision ?? this.contentRevision,
  );

  /// The same extract with a re-evaluated link back to its parent.
  Extract withProvenance(Provenance value) => Extract(
    id: id,
    markdown: markdown,
    provenance: value,
    createdAtUtc: createdAtUtc,
    editedAtUtc: editedAtUtc,
    contentRevision: contentRevision,
  );

  @override
  bool operator ==(Object other) => other is Extract && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Extract($id from ${provenance.parentId})';
}
