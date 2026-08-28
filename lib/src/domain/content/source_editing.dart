/// Applying one edit to a source, in one pure step.
///
/// Everything an edit changes is computed here and returned as a value: the
/// new markdown, the new revision, where the reading positions moved, and what
/// happened to every child's link back. The repository layer's only job is to
/// write that value down inside a transaction.
///
/// Keeping it pure is what makes the hard cases testable without a database —
/// multi-byte boundaries, ranges that straddle the edit, an extract whose text
/// was deleted out from under it.
///
/// See `plans/reader/EDITABLE_READER.md` §6, §7, §10.2.
library;

import 'package:incremental_reader/src/domain/content/extract.dart';
import 'package:incremental_reader/src/domain/content/position_migration.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/content/source_edit.dart';
import 'package:incremental_reader/src/domain/content/text_splice.dart';
import 'package:meta/meta.dart';

/// A child whose provenance points into the text being edited.
@immutable
final class ChildProvenance {
  const ChildProvenance({required this.extractId, required this.provenance});

  final String extractId;
  final Provenance provenance;
}

/// What one child's link back becomes after the edit.
@immutable
final class ProvenanceUpdate {
  const ProvenanceUpdate({
    required this.extractId,
    required this.provenance,
    required this.changed,
  });

  final String extractId;

  /// The migrated provenance, already carrying its new state.
  final Provenance provenance;

  /// Whether anything about it actually moved, so untouched rows are not
  /// rewritten and their `updated` bookkeeping stays honest.
  final bool changed;
}

/// Everything one edit produces.
@immutable
final class SourceEditOutcome {
  const SourceEditOutcome({
    required this.markdown,
    required this.contentRevision,
    required this.splice,
    required this.removedText,
    required this.marker,
    required this.softPosition,
    required this.markerWasInsideEdit,
    required this.softWasInsideEdit,
    required this.provenanceUpdates,
  });

  /// The source text after the splice.
  final String markdown;

  /// The revision this edit produced.
  final int contentRevision;

  final TextSplice splice;

  /// Exactly what the splice removed, so the inverse is exact.
  final String removedText;

  final ReaderAnchor? marker;
  final ReaderAnchor? softPosition;

  /// Whether the marker pointed inside the removed text.
  ///
  /// It has been collapsed to the start of the edit — the nearest surviving
  /// place — but the passage it referred to is gone.
  final bool markerWasInsideEdit;

  final bool softWasInsideEdit;

  /// One entry per child whose provenance was examined.
  final List<ProvenanceUpdate> provenanceUpdates;

  /// Children whose provenance actually moved or changed state.
  Iterable<ProvenanceUpdate> get changedProvenance =>
      provenanceUpdates.where((ProvenanceUpdate u) => u.changed);
}

/// Applies [splice] to [markdown] and migrates everything that points into it.
///
/// Callers validate the splice first; this assumes it is applicable.
SourceEditOutcome applySourceEditToText({
  required String markdown,
  required int contentRevision,
  required TextSplice splice,
  ReaderAnchor? marker,
  ReaderAnchor? softPosition,
  List<ChildProvenance> children = const <ChildProvenance>[],
}) {
  final removedText = splice.removedFrom(markdown);
  final next = splice.applyTo(markdown);
  final nextRevision = contentRevision + 1;

  final migratedMarker = marker == null
      ? null
      : migrateOffset(marker.utf8Offset, splice);
  final migratedSoft = softPosition == null
      ? null
      : migrateOffset(softPosition.utf8Offset, splice);

  final updates = <ProvenanceUpdate>[];
  for (final child in children) {
    updates.add(_migrateChild(child, splice, next, nextRevision));
  }

  return SourceEditOutcome(
    markdown: next,
    contentRevision: nextRevision,
    splice: splice,
    removedText: removedText,
    marker: migratedMarker == null
        ? null
        : ReaderAnchor(
            utf8Offset: migratedMarker.utf8Offset,
            contentRevision: nextRevision,
          ),
    softPosition: migratedSoft == null
        ? null
        : ReaderAnchor(
            utf8Offset: migratedSoft.utf8Offset,
            contentRevision: nextRevision,
          ),
    markerWasInsideEdit: migratedMarker?.wasInsideEdit ?? false,
    softWasInsideEdit: migratedSoft?.wasInsideEdit ?? false,
    provenanceUpdates: List<ProvenanceUpdate>.unmodifiable(updates),
  );
}

ProvenanceUpdate _migrateChild(
  ChildProvenance child,
  TextSplice splice,
  String nextMarkdown,
  int nextRevision,
) {
  final before = child.provenance;
  final wasEmpty = before.endUtf8 <= before.startUtf8;
  var migrated = migrateRange(before.startUtf8, before.endUtf8, splice);

  // A range that sat entirely inside replaced text has nowhere of its own to
  // go, but the text that replaced it is where the passage used to be. Pointing
  // there — clearly flagged — is more useful than pointing nowhere, and it is
  // still exact: it is the span the splice wrote, not a guess at where the
  // words went. A pure deletion has no replacement, so that case stays empty
  // and becomes an orphan.
  final replacedInPlace =
      !wasEmpty &&
      migrated.isEmpty &&
      splice.insertedLength > 0 &&
      before.startUtf8 >= splice.startUtf8 &&
      before.endUtf8 <= splice.endUtf8;
  if (replacedInPlace) {
    migrated = MigratedRange(
      startUtf8: splice.startUtf8,
      endUtf8: splice.startUtf8 + splice.insertedLength,
      touchedByEdit: true,
    );
  }

  final state = _stateAfter(
    previous: before.state,
    migrated: migrated,
    wasEmpty: wasEmpty,
    expectedHash: before.selectedTextHash,
    nextMarkdown: nextMarkdown,
  );

  final moved =
      migrated.startUtf8 != before.startUtf8 ||
      migrated.endUtf8 != before.endUtf8 ||
      state != before.state ||
      before.contentRevision != nextRevision;

  return ProvenanceUpdate(
    extractId: child.extractId,
    provenance: before.migratedTo(
      startUtf8: migrated.startUtf8,
      endUtf8: migrated.endUtf8,
      contentRevision: nextRevision,
      state: state,
    ),
    changed: moved,
  );
}

/// A degraded link never repairs itself.
///
/// Re-verification can only tell that the bytes now under a range match the
/// hash, which for a range that was already reported as broken is a
/// coincidence rather than evidence. Clearing the flag is a decision for the
/// user, not for a migration.
ProvenanceState _stateAfter({
  required ProvenanceState previous,
  required MigratedRange migrated,
  required bool wasEmpty,
  required String expectedHash,
  required String nextMarkdown,
}) {
  if (migrated.isEmpty && !wasEmpty) return ProvenanceState.orphaned;
  if (previous != ProvenanceState.verbatim) return previous;
  if (!migrated.touchedByEdit) return previous;
  final slice = _sliceUtf8(
    nextMarkdown,
    migrated.startUtf8,
    migrated.endUtf8,
  );
  return hashSelection(slice) == expectedHash
      ? ProvenanceState.verbatim
      : ProvenanceState.stale;
}

String _sliceUtf8(String text, int startUtf8, int endUtf8) {
  if (endUtf8 <= startUtf8) return '';
  final splice = TextSplice.normalized(
    startUtf8: startUtf8,
    endUtf8: endUtf8,
  );
  return splice.removedFrom(text);
}

/// Outcome of asking a repository to apply an edit.
///
/// A sealed result rather than an exception: a rejected edit and a conflicting
/// one are ordinary states of a shared document, and the caller has something
/// specific to say to the user about each.
sealed class SourceEditResult {
  const SourceEditResult();
}

/// The edit was applied and everything pointing into the text was migrated.
final class SourceEditApplied extends SourceEditResult {
  const SourceEditApplied({
    required this.source,
    required this.edit,
    required this.outcome,
  });

  /// The source as it now stands.
  final Source source;

  /// The journal row that was written.
  final SourceEdit edit;

  /// What moved, and what degraded.
  final SourceEditOutcome outcome;
}

/// The command had already been applied; nothing was written a second time.
final class SourceEditReplayed extends SourceEditResult {
  const SourceEditReplayed({required this.source, required this.edit});

  final Source source;
  final SourceEdit edit;
}

/// Someone else advanced the text first. Nothing was written.
final class SourceEditConflict extends SourceEditResult {
  const SourceEditConflict({
    required this.expectedRevision,
    required this.actualRevision,
  });

  final int expectedRevision;
  final int actualRevision;
}

/// The splice itself was not applicable. Nothing was written.
final class SourceEditRejected extends SourceEditResult {
  const SourceEditRejected(this.reason);

  final SpliceRejection reason;
}

/// There is no such source. Nothing was written.
final class SourceEditTargetMissing extends SourceEditResult {
  const SourceEditTargetMissing(this.sourceId);

  final String sourceId;
}
