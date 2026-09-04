/// Saves and loads sources, blocks, extracts, and cards, using Drift.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs. A repository that starts making
/// policy is how scheduling rules end up spread across three folders.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/apply_source_edit.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/source_edit.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

/// Content aggregate: sources, blocks, extracts, cards.
final class DriftContentRepository implements ContentRepository {
  const DriftContentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> insertSource(Source source, Document document) async {
    await _database.into(_database.sources).insert(sourceToCompanion(source));
    await _database.batch((Batch batch) {
      batch.insertAll(_database.blocks, <BlocksCompanion>[
        for (final block in document.blocks) blockToCompanion(block, source.id),
      ]);
    });
  }

  @override
  Future<Source?> findSource(String id) async {
    final row = await (_database.select(
      _database.sources,
    )..where(($SourcesTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : sourceFromRow(row);
  }

  @override
  Future<Document?> findDocument(String sourceId) async {
    final source = await (_database.select(
      _database.sources,
    )..where(($SourcesTable t) => t.id.equals(sourceId))).getSingleOrNull();
    if (source == null) return null;
    final blocks =
        await (_database.select(_database.blocks)
              ..where(($BlocksTable t) => t.sourceId.equals(sourceId))
              ..orderBy(<OrderClauseGenerator<$BlocksTable>>[
                ($BlocksTable t) => OrderingTerm.asc(t.idx),
              ]))
            .get();
    return documentFromRows(source, blocks);
  }

  @override
  Future<List<Source>> listSources() async {
    final rows =
        await (_database.select(_database.sources)
              ..orderBy(<OrderClauseGenerator<$SourcesTable>>[
                ($SourcesTable t) => OrderingTerm.desc(t.importedAtUtc),
              ]))
            .get();
    return <Source>[for (final row in rows) sourceFromRow(row)];
  }

  @override
  Future<void> updateSource(Source source) async {
    // Bump the revision in the same statement so concurrent readers can tell
    // a stale projection from a fresh one. The text itself is deliberately not
    // writable here: it changes only through applySourceEdit, which records
    // the splice and migrates everything pointing into it.
    await _database.customStatement(
      'UPDATE sources SET title = ?, marker_utf8 = ?, '
      'marker_revision = ?, soft_utf8 = ?, soft_revision = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[
        source.title,
        source.resume.marker?.utf8Offset,
        source.resume.marker?.contentRevision,
        source.resume.softPosition?.utf8Offset,
        source.resume.softPosition?.contentRevision,
        source.id,
      ],
    );
  }

  @override
  Future<Source?> saveResumeMarker(String sourceId, ReaderAnchor anchor) async {
    await _database.customStatement(
      'UPDATE sources SET marker_utf8 = ?, marker_revision = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[anchor.utf8Offset, anchor.contentRevision, sourceId],
    );
    return findSource(sourceId);
  }

  @override
  Future<Source?> saveSoftPosition(String sourceId, ReaderAnchor anchor) async {
    await _database.customStatement(
      'UPDATE sources SET soft_utf8 = ?, soft_revision = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[anchor.utf8Offset, anchor.contentRevision, sourceId],
    );
    return findSource(sourceId);
  }

  @override
  Future<Source?> confirmSoftPosition(String sourceId) async {
    await _database.customStatement(
      'UPDATE sources SET marker_utf8 = soft_utf8, '
      'marker_revision = soft_revision, revision = revision + 1 '
      'WHERE id = ? AND soft_utf8 IS NOT NULL',
      <Object?>[sourceId],
    );
    return findSource(sourceId);
  }

  @override
  Future<SourceEditResult> applySourceEdit({
    required String sourceId,
    required TextSplice splice,
    required int baseContentRevision,
    required String operationId,
    required DateTime nowUtc,
    bool isUndo = false,
    SourceEditRestore? restore,
  }) => _database.transaction(() async {
    // A resent command replays its recorded outcome rather than applying the
    // splice twice. The journal row is the record, so this needs no separate
    // bookkeeping table.
    final SourceEditRow? already = await _sourceEditByOperation(operationId);
    if (already != null) {
      final Source? current = await findSource(already.sourceId);
      if (current != null) {
        return SourceEditReplayed(
          source: current,
          edit: sourceEditFromRow(already),
        );
      }
    }

    final SourceRow? row = await (_database.select(
      _database.sources,
    )..where(($SourcesTable t) => t.id.equals(sourceId))).getSingleOrNull();
    if (row == null) return SourceEditTargetMissing(sourceId);

    if (row.contentRevision != baseContentRevision) {
      return SourceEditConflict(
        expectedRevision: baseContentRevision,
        actualRevision: row.contentRevision,
      );
    }

    final SpliceRejection? rejection = splice.validateAgainst(row.markdown);
    if (rejection != null) return SourceEditRejected(rejection);

    final Source before = sourceFromRow(row);
    final List<Extract> children = await listExtractsOfParent(sourceId);

    final SourceEditOutcome outcome = applySourceEditToText(
      markdown: before.markdown,
      contentRevision: before.contentRevision,
      splice: splice,
      marker: before.resume.marker,
      softPosition: before.resume.softPosition,
      children: <ChildProvenance>[
        for (final Extract extract in children)
          ChildProvenance(
            extractId: extract.id,
            provenance: extract.provenance,
          ),
      ],
    );

    // What this edit displaces, captured before it happens. Migration cannot
    // be inverted — a position collapsed onto the start of an edit no longer
    // remembers where it was — so undo restores from this rather than trying
    // to compute its way back.
    final SourceEditRestore displaced = SourceEditRestore(
      markerUtf8: before.resume.marker?.utf8Offset,
      softUtf8: before.resume.softPosition?.utf8Offset,
      provenance: <ProvenanceSnapshot>[
        for (final Extract extract in children)
          ProvenanceSnapshot(
            extractId: extract.id,
            startUtf8: extract.provenance.startUtf8,
            endUtf8: extract.provenance.endUtf8,
            state: extract.provenance.state,
          ),
      ],
    );

    final SourceEdit edit = SourceEdit(
      // Unique by construction: the schema already requires one edit per
      // source per revision, so no identifier generator is needed here.
      id: '$sourceId#${outcome.contentRevision}',
      sourceId: sourceId,
      contentRevision: outcome.contentRevision,
      splice: splice,
      removedText: outcome.removedText,
      appliedAtUtc: nowUtc.toUtc(),
      operationId: operationId,
      isUndo: isUndo,
      restore: displaced,
    );
    await _database
        .into(_database.sourceEdits)
        .insert(sourceEditToCompanion(edit));

    // Undo is the one caller allowed to overwrite migration's answer, because
    // it is restoring a recorded state rather than deriving a new one.
    final ReaderAnchor? marker = _restoredAnchor(
      restore?.markerUtf8,
      outcome.marker,
      outcome.contentRevision,
    );
    final ReaderAnchor? soft = _restoredAnchor(
      restore?.softUtf8,
      outcome.softPosition,
      outcome.contentRevision,
    );

    final Source after = before
        .withMarkdown(
          outcome.markdown,
          contentRevision: outcome.contentRevision,
        )
        .copyWith(
          resume: ResumePosition(marker: marker, softPosition: soft),
        );

    await _database.customStatement(
      'UPDATE sources SET markdown = ?, content_hash = ?, word_count = ?, '
      'content_revision = ?, marker_utf8 = ?, marker_revision = ?, '
      'soft_utf8 = ?, soft_revision = ?, revision = revision + 1 '
      'WHERE id = ?',
      <Object?>[
        after.markdown,
        after.contentHash,
        after.wordCount,
        after.contentRevision,
        after.resume.marker?.utf8Offset,
        after.resume.marker?.contentRevision,
        after.resume.softPosition?.utf8Offset,
        after.resume.softPosition?.contentRevision,
        sourceId,
      ],
    );

    final Map<String, ProvenanceSnapshot> restored =
        <String, ProvenanceSnapshot>{
          if (restore != null)
            for (final ProvenanceSnapshot snapshot in restore.provenance)
              snapshot.extractId: snapshot,
        };

    for (final ProvenanceUpdate update in outcome.provenanceUpdates) {
      final ProvenanceSnapshot? recorded = restored[update.extractId];
      if (recorded == null && !update.hasChanged) continue;
      await _database.customStatement(
        'UPDATE extracts SET start_utf8 = ?, end_utf8 = ?, '
        'anchor_revision = ?, provenance_state = ? WHERE id = ?',
        <Object?>[
          recorded?.startUtf8 ?? update.provenance.startUtf8,
          recorded?.endUtf8 ?? update.provenance.endUtf8,
          update.provenance.contentRevision,
          (recorded?.state ?? update.provenance.state).index,
          update.extractId,
        ],
      );
    }

    // Blocks are a derived cache and nothing persisted refers to their ids, so
    // the whole set is rebuilt rather than patched. A windowed re-parse would
    // have to reason about blank lines merging and splitting neighbours, and
    // about setext headings reaching further than any fixed window — for a
    // per-save cost measured in milliseconds.
    await (_database.delete(
      _database.blocks,
    )..where(($BlocksTable t) => t.sourceId.equals(sourceId))).go();
    final Document document = Document.parse(
      sourceId: sourceId,
      markdown: after.markdown,
      contentRevision: after.contentRevision,
    );
    await _database.batch((Batch batch) {
      batch.insertAll(_database.blocks, <BlocksCompanion>[
        for (final block in document.blocks) blockToCompanion(block, sourceId),
      ]);
    });

    return SourceEditApplied(source: after, edit: edit, outcome: outcome);
  });

  @override
  Future<List<SourceEdit>> listSourceEdits(String sourceId) async {
    final List<SourceEditRow> rows =
        await (_database.select(_database.sourceEdits)
              ..where(($SourceEditsTable t) => t.sourceId.equals(sourceId))
              ..orderBy(<OrderClauseGenerator<$SourceEditsTable>>[
                ($SourceEditsTable t) => OrderingTerm.asc(t.contentRevision),
              ]))
            .get();
    return <SourceEdit>[for (final row in rows) sourceEditFromRow(row)];
  }

  @override
  Future<SourceEdit?> findLatestSourceEdit(String sourceId) async {
    final SourceEditRow? row =
        await (_database.select(_database.sourceEdits)
              ..where(($SourceEditsTable t) => t.sourceId.equals(sourceId))
              ..orderBy(<OrderClauseGenerator<$SourceEditsTable>>[
                ($SourceEditsTable t) => OrderingTerm.desc(t.contentRevision),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : sourceEditFromRow(row);
  }

  /// The recorded offset when undoing, otherwise what migration produced.
  static ReaderAnchor? _restoredAnchor(
    int? recorded,
    ReaderAnchor? migrated,
    int contentRevision,
  ) {
    if (recorded != null) {
      return ReaderAnchor(
        utf8Offset: recorded,
        contentRevision: contentRevision,
      );
    }
    return migrated;
  }

  Future<SourceEditRow?> _sourceEditByOperation(String operationId) =>
      (_database.select(_database.sourceEdits)
            ..where(($SourceEditsTable t) => t.operationId.equals(operationId)))
          .getSingleOrNull();

  @override
  Future<void> insertExtract(Extract extract) =>
      _database.into(_database.extracts).insert(extractToCompanion(extract));

  @override
  Future<Extract?> findExtract(String id) async {
    final row = await (_database.select(
      _database.extracts,
    )..where(($ExtractsTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : extractFromRow(row);
  }

  @override
  Future<List<Extract>> listExtractsOfParent(String parentId) async {
    final rows =
        await (_database.select(_database.extracts)
              ..where(($ExtractsTable t) => t.parentId.equals(parentId))
              ..orderBy(<OrderClauseGenerator<$ExtractsTable>>[
                ($ExtractsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Extract>[for (final row in rows) extractFromRow(row)];
  }

  @override
  Future<List<Extract>> listExtractsOfSource(String sourceId) async {
    final rows =
        await (_database.select(_database.extracts)
              ..where(($ExtractsTable t) => t.sourceId.equals(sourceId))
              ..orderBy(<OrderClauseGenerator<$ExtractsTable>>[
                ($ExtractsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Extract>[for (final row in rows) extractFromRow(row)];
  }

  @override
  Future<List<Extract>> listExtracts() async {
    final rows =
        await (_database.select(_database.extracts)
              ..orderBy(<OrderClauseGenerator<$ExtractsTable>>[
                ($ExtractsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Extract>[for (final row in rows) extractFromRow(row)];
  }

  @override
  Future<Map<String, int>> countExtractsBySource(List<String> sourceIds) async {
    if (sourceIds.isEmpty) return <String, int>{};
    final placeholders = List<String>.filled(sourceIds.length, '?').join(', ');
    final rows = await _database
        .customSelect(
          'SELECT source_id, COUNT(*) AS n FROM extracts '
          'WHERE source_id IN ($placeholders) GROUP BY source_id',
          variables: <Variable<Object>>[
            for (final id in sourceIds) Variable<String>(id),
          ],
        )
        .get();
    return <String, int>{
      for (final row in rows) row.read<String>('source_id'): row.read<int>('n'),
    };
  }

  @override
  Future<void> updateExtract(Extract extract) async {
    await (_database.update(
      _database.extracts,
    )..where(($ExtractsTable t) => t.id.equals(extract.id))).write(
      ExtractsCompanion(
        markdown: Value<String>(extract.markdown),
        editedAtUtc: Value<int?>(
          extract.editedAtUtc == null ? null : toEpochMs(extract.editedAtUtc!),
        ),
      ),
    );
  }

  @override
  Future<void> deleteSource(String id) async {
    // Blocks and the edit journal cascade from this row; extracts do not,
    // and a source that still has one is refused by the foreign key.
    await (_database.delete(
      _database.sources,
    )..where(($SourcesTable t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteExtract(String id) async {
    await (_database.delete(
      _database.extracts,
    )..where(($ExtractsTable t) => t.id.equals(id))).go();
  }

  @override
  Future<void> insertCards(List<Card> cards) async {
    if (cards.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAll(_database.cards, <CardsCompanion>[
        for (final card in cards) cardToCompanion(card),
      ]);
    });
  }

  @override
  Future<Card?> findCard(String id) async {
    final row = await (_database.select(
      _database.cards,
    )..where(($CardsTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : cardFromRow(row);
  }

  @override
  Future<List<Card>> listCardsOfExtract(String extractId) async {
    final rows =
        await (_database.select(_database.cards)
              ..where(
                ($CardsTable t) =>
                    t.parentElementId.equals(extractId) &
                    t.parentElementType.equals(ElementType.extract.index),
              )
              ..orderBy(<OrderClauseGenerator<$CardsTable>>[
                ($CardsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Card>[for (final row in rows) cardFromRow(row)];
  }

  @override
  Future<List<Card>> listCardsOfSource(String sourceId) async {
    final rows =
        await (_database.select(_database.cards)
              ..where(
                ($CardsTable t) =>
                    t.parentElementId.equals(sourceId) &
                    t.parentElementType.equals(ElementType.source.index),
              )
              ..orderBy(<OrderClauseGenerator<$CardsTable>>[
                ($CardsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Card>[for (final row in rows) cardFromRow(row)];
  }

  @override
  Future<List<Card>> listCardsOfVideo(String videoElementId) async {
    final rows =
        await (_database.select(_database.cards)
              ..where(
                ($CardsTable t) =>
                    t.parentElementId.equals(videoElementId) &
                    t.parentElementType.equals(ElementType.video.index),
              )
              ..orderBy(<OrderClauseGenerator<$CardsTable>>[
                ($CardsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Card>[for (final row in rows) cardFromRow(row)];
  }

  @override
  Future<void> updateCard(Card card) async {
    await (_database.update(
      _database.cards,
    )..where(($CardsTable t) => t.id.equals(card.id))).write(
      CardsCompanion(
        front: Value<String>(card.front),
        back: Value<String>(card.back),
        editedAtUtc: Value<int?>(
          card.editedAtUtc == null ? null : toEpochMs(card.editedAtUtc!),
        ),
      ),
    );
  }

  @override
  Future<List<Card>> listCards() async {
    final rows =
        await (_database.select(_database.cards)
              ..orderBy(<OrderClauseGenerator<$CardsTable>>[
                ($CardsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <Card>[for (final row in rows) cardFromRow(row)];
  }

  @override
  Future<void> deleteCard(String id) async {
    await (_database.delete(
      _database.cards,
    )..where(($CardsTable t) => t.id.equals(id))).go();
  }

  @override
  Future<List<Card>> listSiblingCards(String cardId) async {
    // Siblings share the same typed provenance group. A standalone card has
    // no siblings.
    // A card with no parent has no siblings, which is why the query is keyed
    // on the parent rather than on a shared source.
    final rows = await _database
        .customSelect(
          'SELECT c.* FROM cards c '
          'JOIN cards origin ON origin.id = ? '
          'WHERE c.id != origin.id '
          'AND origin.parent_element_id IS NOT NULL '
          'AND c.parent_element_id = origin.parent_element_id '
          'AND c.parent_element_type = origin.parent_element_type '
          'ORDER BY c.created_at_utc, c.id',
          variables: <Variable<Object>>[Variable<String>(cardId)],
          readsFrom: <ResultSetImplementation<Object, Object>>{_database.cards},
        )
        .get();
    return <Card>[
      for (final row in rows) cardFromRow(_database.cards.map(row.data)),
    ];
  }
}
