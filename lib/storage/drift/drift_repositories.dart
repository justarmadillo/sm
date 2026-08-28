/// Drift-backed implementations of the application's repository ports.
///
/// These hold SQL and mapping, nothing else. No repository decides an
/// interval, a lifecycle transition, or whether an operation is allowed —
/// those are the commandRunner' and the domain's jobs. A repository that starts
/// making policy is how scheduling logic ends up spread across three layers.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/apply_source_edit.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/source_edit.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/contracts/repositories.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';
import 'package:incremental_reader/storage/dataset_lineage.dart';

/// Runs handler bodies inside one Drift transaction.
final class DriftTransactionRunner implements TransactionRunner {
  const DriftTransactionRunner(this._database);

  final AppDatabase _database;

  @override
  Future<T> run<T>(Future<T> Function() body) => _database.transaction(body);
}

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
  Future<Source?> setResumeMarker(String sourceId, ReaderAnchor anchor) async {
    await _database.customStatement(
      'UPDATE sources SET marker_utf8 = ?, marker_revision = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[anchor.utf8Offset, anchor.contentRevision, sourceId],
    );
    return findSource(sourceId);
  }

  @override
  Future<Source?> setSoftPosition(String sourceId, ReaderAnchor anchor) async {
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
        .copyWith(resume: ResumePosition(marker: marker, softPosition: soft));

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

    final Map<String, ProvenanceSnapshot> restored = <String, ProvenanceSnapshot>{
      if (restore != null)
        for (final ProvenanceSnapshot snapshot in restore.provenance)
          snapshot.extractId: snapshot,
    };

    for (final ProvenanceUpdate update in outcome.provenanceUpdates) {
      final ProvenanceSnapshot? recorded = restored[update.extractId];
      if (recorded == null && !update.changed) continue;
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
  Future<SourceEdit?> latestSourceEdit(String sourceId) async {
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

/// Learning aggregate: schedules, pacing, priority, activity.
final class DriftLearningRepository implements LearningRepository {
  const DriftLearningRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> insertTopic(TopicState topic) => saveTopic(topic);

  @override
  Future<void> saveTopic(TopicState topic) async {
    await _database
        .into(_database.elementSchedules)
        .insertOnConflictUpdate(scheduleToCompanion(topic.schedule));
    await _database
        .into(_database.topicStates)
        .insertOnConflictUpdate(topicStateToCompanion(topic));
  }

  @override
  Future<bool> compareAndSwapTopic({
    required TopicState expected,
    required TopicState replacement,
  }) {
    if (replacement.revision != expected.revision + 1 ||
        replacement.schedule.revision != expected.schedule.revision + 1) {
      throw ArgumentError('topic replacement must advance both revisions');
    }
    return _database.transaction(() async {
      final int scheduleWrites =
          await (_database.update(_database.elementSchedules)..where(
                ($ElementSchedulesTable table) =>
                    table.elementId.equals(expected.ref.id) &
                    table.elementType.equals(expected.ref.type.index) &
                    table.revision.equals(expected.schedule.revision),
              ))
              .write(scheduleToCompanion(replacement.schedule));
      if (scheduleWrites == 0) return false;
      final int topicWrites =
          await (_database.update(_database.topicStates)..where(
                ($TopicStatesTable table) =>
                    table.elementId.equals(expected.ref.id) &
                    table.elementType.equals(expected.ref.type.index) &
                    table.revision.equals(expected.revision),
              ))
              .write(topicStateToCompanion(replacement));
      if (topicWrites != 1) {
        throw StateError('stale topic revision after schedule CAS');
      }
      return true;
    });
  }

  @override
  Future<void> insertCardState(CardState card) => saveCardState(card);

  @override
  Future<void> saveCardState(CardState card) async {
    await _database
        .into(_database.elementSchedules)
        .insertOnConflictUpdate(scheduleToCompanion(card.schedule));
    await _database
        .into(_database.cardMemories)
        .insertOnConflictUpdate(cardMemoryToCompanion(card.memory));
  }

  @override
  Future<bool> compareAndSwapCardState({
    required CardState expected,
    required CardState replacement,
  }) {
    if (replacement.memory.revision != expected.memory.revision + 1 ||
        replacement.schedule.revision != expected.schedule.revision + 1) {
      throw ArgumentError('card replacement must advance both revisions');
    }
    return _database.transaction(() async {
      final int scheduleWrites =
          await (_database.update(_database.elementSchedules)..where(
                ($ElementSchedulesTable table) =>
                    table.elementId.equals(expected.ref.id) &
                    table.elementType.equals(ElementType.card.index) &
                    table.revision.equals(expected.schedule.revision),
              ))
              .write(scheduleToCompanion(replacement.schedule));
      if (scheduleWrites == 0) return false;
      final int memoryWrites =
          await (_database.update(_database.cardMemories)..where(
                ($CardMemoriesTable table) =>
                    table.cardId.equals(expected.ref.id) &
                    table.revision.equals(expected.memory.revision),
              ))
              .write(cardMemoryToCompanion(replacement.memory));
      if (memoryWrites != 1) {
        throw StateError('stale card revision after schedule CAS');
      }
      return true;
    });
  }

  @override
  Future<CardState?> findCardState(String cardId) async {
    final row =
        await (_database.select(
              _database.cardMemories,
            )..where(($CardMemoriesTable table) => table.cardId.equals(cardId)))
            .getSingleOrNull();
    if (row == null) return null;
    final schedule = await findSchedule(
      ElementRef(id: cardId, type: ElementType.card),
    );
    if (schedule == null) return null;
    return CardState(schedule: schedule, memory: cardMemoryFromRow(row));
  }

  @override
  Future<List<CardState>> listDueCards(DateTime nowUtc) async {
    if (!nowUtc.isUtc) {
      throw ArgumentError.value(nowUtc, 'nowUtc', 'must be UTC');
    }
    final nowMs = toEpochMs(nowUtc);
    final rows =
        await (_database.select(_database.cardMemories)
              ..where(
                ($CardMemoriesTable table) =>
                    table.dueAtUtc.isSmallerOrEqualValue(nowMs),
              )
              ..orderBy(<OrderClauseGenerator<$CardMemoriesTable>>[
                ($CardMemoriesTable table) => OrderingTerm.asc(table.dueAtUtc),
                ($CardMemoriesTable table) => OrderingTerm.asc(table.cardId),
              ]))
            .get();
    final result = <CardState>[];
    for (final row in rows) {
      final schedule = await findSchedule(
        ElementRef(id: row.cardId, type: ElementType.card),
      );
      if (schedule == null || !schedule.lifecycle.isSchedulable) continue;
      result.add(CardState(schedule: schedule, memory: cardMemoryFromRow(row)));
    }
    return result;
  }

  @override
  Future<List<CardState>> listCardStates({
    Set<ElementLifecycle>? lifecycles,
  }) async {
    final scheduleQuery = _database.select(_database.elementSchedules)
      ..where(
        ($ElementSchedulesTable table) =>
            table.elementType.equals(ElementType.card.index) &
            (lifecycles == null
                ? const CustomExpression<bool>('1')
                : table.lifecycle.isIn(
                    lifecycles
                        .map((ElementLifecycle lifecycle) => lifecycle.index)
                        .toList(),
                  )),
      );
    final scheduleRows = await scheduleQuery.get();
    if (scheduleRows.isEmpty) return <CardState>[];
    final Map<String, ElementSchedule> schedules = <String, ElementSchedule>{
      for (final row in scheduleRows) row.elementId: scheduleFromRow(row),
    };
    final memoryRows =
        await (_database.select(_database.cardMemories)..where(
              ($CardMemoriesTable table) =>
                  table.cardId.isIn(schedules.keys.toList()),
            ))
            .get();
    return <CardState>[
      for (final row in memoryRows)
        if (schedules[row.cardId] case final ElementSchedule schedule)
          CardState(schedule: schedule, memory: cardMemoryFromRow(row)),
    ];
  }

  @override
  Future<void> appendReview(ReviewRecord record) => _database
      .into(_database.reviewEvents)
      .insert(reviewRecordToCompanion(record));

  @override
  Future<ReviewRecord?> findReviewByOperationId(String operationId) async {
    final row =
        await (_database.select(_database.reviewEvents)..where(
              ($ReviewEventsTable table) =>
                  table.operationId.equals(operationId),
            ))
            .getSingleOrNull();
    return row == null ? null : reviewRecordFromRow(row);
  }

  @override
  Future<List<ReviewRecord>> listReviewsForCard(String cardId) async {
    final rows =
        await (_database.select(_database.reviewEvents)
              ..where(($ReviewEventsTable table) => table.cardId.equals(cardId))
              ..orderBy(<OrderClauseGenerator<$ReviewEventsTable>>[
                ($ReviewEventsTable table) =>
                    OrderingTerm.asc(table.reviewedAtUtc),
                ($ReviewEventsTable table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    return <ReviewRecord>[for (final row in rows) reviewRecordFromRow(row)];
  }

  @override
  Future<List<ReviewRecord>> listOptimizerReviews() async {
    final rows = await _database
        .customSelect(
          'SELECT r.* FROM review_events r '
          'WHERE r.is_practice = 0 AND NOT EXISTS ('
          'SELECT 1 FROM scheduler_events original '
          'JOIN scheduler_events inverse '
          'ON inverse.undoes_event_id = original.id '
          'WHERE original.operation_id = r.operation_id '
          "AND original.event_type = 'card_reviewed' "
          "AND inverse.event_type = 'card_review_undone') "
          'ORDER BY r.reviewed_at_utc, r.id',
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.reviewEvents,
            _database.schedulerEvents,
          },
        )
        .get();
    return <ReviewRecord>[
      for (final row in rows)
        reviewRecordFromRow(_database.reviewEvents.map(row.data)),
    ];
  }

  @override
  Future<TopicState?> findTopic(ElementRef ref) async {
    final schedule = await findSchedule(ref);
    if (schedule == null) return null;
    final pacing =
        await (_database.select(_database.topicStates)..where(
              ($TopicStatesTable t) =>
                  t.elementId.equals(ref.id) &
                  t.elementType.equals(ref.type.index),
            ))
            .getSingleOrNull();
    if (pacing == null) return null;
    return topicStateFromRows(pacing, schedule);
  }

  @override
  Future<Map<ElementRef, TopicState>> findTopics(List<ElementRef> refs) async {
    if (refs.isEmpty) return <ElementRef, TopicState>{};
    final ids = refs.map((ElementRef r) => r.id).toList();
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    final rows = await _database
        .customSelect(
          'SELECT s.element_id, s.element_type, s.priority_key, s.lifecycle, '
          's.due_day, s.original_due_day, '
          's.root_id, s.parent_element_id, s.ordinal, s.created_at_utc, '
          's.updated_at_utc, s.revision AS schedule_revision, '
          's.legacy_due_provenance, s.zone_id, t.status, '
          't.repetition_count, t.lapse_count, t.stored_interval, '
          't.last_review_day, t.a_factor_raw, t.last_interval_ratio_raw, '
          't.history_block_id, t.recent_postponement_count, '
          't.total_postponement_count, t.learning_control, '
          't.encounters_since_last_card, '
          't.revision AS topic_revision '
          'FROM element_schedules s '
          'JOIN topic_states t ON t.element_id = s.element_id '
          'AND t.element_type = s.element_type '
          'WHERE s.element_id IN ($placeholders)',
          variables: <Variable<Object>>[
            for (final id in ids) Variable<String>(id),
          ],
        )
        .get();

    final result = <ElementRef, TopicState>{};
    for (final row in rows) {
      final ref = ElementRef(
        id: row.read<String>('element_id'),
        type: ElementType.values[row.read<int>('element_type')],
      );
      final zoneId = row.read<String>('zone_id');
      final lastReview = row.read<int?>('last_review_day');
      final createdAt = row.read<int?>('created_at_utc');
      final updatedAt = row.read<int?>('updated_at_utc');
      result[ref] = TopicState(
        schedule: ElementSchedule(
          ref: ref,
          priority: PriorityRank(row.read<String>('priority_key')),
          lifecycle: ElementLifecycle.values[row.read<int>('lifecycle')],
          dueDay: studyDayFromEpochDay(row.read<int>('due_day'), zoneId),
          originalDueDay: studyDayFromEpochDay(
            row.read<int>('original_due_day'),
            zoneId,
          ),
          rootId: row.read<String?>('root_id'),
          parentElementId: row.read<String?>('parent_element_id'),
          ordinal: row.read<int?>('ordinal'),
          createdAtUtc: createdAt == null ? null : fromEpochMs(createdAt),
          updatedAtUtc: updatedAt == null ? null : fromEpochMs(updatedAt),
          revision: row.read<int>('schedule_revision'),
          legacyDueProvenance: LegacyDueProvenance
              .values[row.read<int>('legacy_due_provenance')],
        ),
        status: Sm20ElementStatus.values[row.read<int>('status')],
        repetitionCount: row.read<int>('repetition_count'),
        lapseCount: row.read<int>('lapse_count'),
        storedInterval: row.read<int>('stored_interval'),
        lastReviewDay: lastReview == null
            ? null
            : studyDayFromEpochDay(lastReview, zoneId),
        aFactorRaw: real48FromHex(row.read<String>('a_factor_raw')),
        lastIntervalRatioRaw: real48FromHex(
          row.read<String>('last_interval_ratio_raw'),
        ),
        historyBlockId: row.read<int>('history_block_id'),
        recentPostponementCount: row.read<int>('recent_postponement_count'),
        totalPostponementCount: row.read<int>('total_postponement_count'),
        learningControl: row.read<int>('learning_control'),
        encountersSinceLastCard: row.read<int>('encounters_since_last_card'),
        revision: row.read<int>('topic_revision'),
      );
    }
    return result;
  }

  @override
  Future<void> deleteSchedule(ElementRef ref) async {
    await (_database.delete(_database.topicStates)..where(
          ($TopicStatesTable t) =>
              t.elementId.equals(ref.id) & t.elementType.equals(ref.type.index),
        ))
        .go();
    await (_database.delete(_database.elementSchedules)..where(
          ($ElementSchedulesTable t) =>
              t.elementId.equals(ref.id) & t.elementType.equals(ref.type.index),
        ))
        .go();
  }

  @override
  Future<ElementSchedule?> findSchedule(ElementRef ref) async {
    final row =
        await (_database.select(_database.elementSchedules)..where(
              ($ElementSchedulesTable t) =>
                  t.elementId.equals(ref.id) &
                  t.elementType.equals(ref.type.index),
            ))
            .getSingleOrNull();
    return row == null ? null : scheduleFromRow(row);
  }

  @override
  Future<void> saveSchedule(ElementSchedule schedule) => _database
      .into(_database.elementSchedules)
      .insertOnConflictUpdate(scheduleToCompanion(schedule));

  @override
  Future<List<ElementSchedule>> listByPriority({
    int? limit,
    int? offset,
  }) async {
    final query = _database.select(_database.elementSchedules)
      ..orderBy(<OrderClauseGenerator<$ElementSchedulesTable>>[
        ($ElementSchedulesTable t) => OrderingTerm.asc(t.priorityKey),
        ($ElementSchedulesTable t) => OrderingTerm.asc(t.elementId),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    final rows = await query.get();
    return <ElementSchedule>[for (final row in rows) scheduleFromRow(row)];
  }

  @override
  Future<void> appendActivity(ActivityRecord record) => _database
      .into(_database.activityEvents)
      .insert(
        ActivityEventsCompanion.insert(
          id: record.id,
          operationId: record.operationId,
          elementId: Value<String?>(record.ref?.id),
          elementType: Value<int?>(record.ref?.type.index),
          kind: record.kind,
          atUtc: toEpochMs(record.atUtc),
          durationMs: Value<int?>(record.durationMs),
          metadataJson: Value<String?>(
            record.metadata == null ? null : jsonEncode(record.metadata),
          ),
        ),
      );

  @override
  Future<bool> hasActivity(String operationId, String kind) async {
    final row = await _database
        .customSelect(
          'SELECT 1 AS present FROM activity_events '
          'WHERE operation_id = ? AND kind = ? LIMIT 1',
          variables: <Variable<Object>>[
            Variable<String>(operationId),
            Variable<String>(kind),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> appendRevlog(RevlogEntry entry) =>
      _database.into(_database.revlogEntries).insert(revlogToCompanion(entry));

  @override
  Future<void> appendRevlogBatch(List<RevlogEntry> entries) async {
    if (entries.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAll(_database.revlogEntries, <RevlogEntriesCompanion>[
        for (final entry in entries) revlogToCompanion(entry),
      ]);
    });
  }

  @override
  Future<List<RevlogEntry>> listRevlogFor(ElementRef ref, {int? limit}) async {
    final query = _database.select(_database.revlogEntries)
      ..where(
        ($RevlogEntriesTable t) =>
            t.elementId.equals(ref.id) & t.elementType.equals(ref.type.index),
      )
      ..orderBy(<OrderClauseGenerator<$RevlogEntriesTable>>[
        ($RevlogEntriesTable t) => OrderingTerm.asc(t.atUtc),
        ($RevlogEntriesTable t) => OrderingTerm.asc(t.id),
      ]);
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return <RevlogEntry>[for (final row in rows) revlogFromRow(row)];
  }

  @override
  Future<List<RevlogEntry>> recentRevlog({int limit = 100}) async {
    final rows =
        await (_database.select(_database.revlogEntries)
              ..orderBy(<OrderClauseGenerator<$RevlogEntriesTable>>[
                ($RevlogEntriesTable t) => OrderingTerm.desc(t.atUtc),
              ])
              ..limit(limit))
            .get();
    return <RevlogEntry>[for (final row in rows) revlogFromRow(row)];
  }

  @override
  Future<void> appendSchedulerEvent(SchedulerEvent event) => _database
      .into(_database.schedulerEvents)
      .insert(schedulerEventToCompanion(event));

  @override
  Future<void> appendSchedulerEvents(List<SchedulerEvent> events) async {
    if (events.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAll(_database.schedulerEvents, <SchedulerEventsCompanion>[
        for (final event in events) schedulerEventToCompanion(event),
      ]);
    });
  }

  @override
  Future<SchedulerEvent?> findSchedulerEventByOperationId(
    String operationId, {
    SchedulerEventType? eventType,
  }) async {
    final query = _database.select(_database.schedulerEvents)
      ..where(
        ($SchedulerEventsTable table) =>
            table.operationId.equals(operationId) &
            (eventType == null
                ? const CustomExpression<bool>('1')
                : table.eventType.equals(eventType.wireName)),
      )
      ..orderBy(<OrderClauseGenerator<$SchedulerEventsTable>>[
        ($SchedulerEventsTable table) => OrderingTerm.asc(table.occurredAtUtc),
        ($SchedulerEventsTable table) => OrderingTerm.asc(table.id),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : schedulerEventFromRow(row);
  }

  @override
  Future<List<SchedulerEvent>> listSchedulerEventsFor(
    ElementRef ref, {
    int? limit,
  }) async {
    final query = _database.select(_database.schedulerEvents)
      ..where(
        ($SchedulerEventsTable table) =>
            table.elementId.equals(ref.id) &
            table.elementType.equals(ref.type.index),
      )
      ..orderBy(<OrderClauseGenerator<$SchedulerEventsTable>>[
        ($SchedulerEventsTable table) => OrderingTerm.asc(table.occurredAtUtc),
        ($SchedulerEventsTable table) => OrderingTerm.asc(table.id),
      ]);
    if (limit != null) query.limit(limit);
    final rows = await query.get();
    return <SchedulerEvent>[for (final row in rows) schedulerEventFromRow(row)];
  }

  @override
  Future<Map<RevlogEventType, int>> countRevlogOn(StudyDay day) async {
    // Day boundaries come from the caller's calendar, so the log is bucketed
    // by the same study day the scheduler used rather than by UTC midnight.
    final int from = day.epochDay * Duration.millisecondsPerDay;
    final int to = from + Duration.millisecondsPerDay;
    final rows = await _database
        .customSelect(
          'SELECT event_type, COUNT(*) AS n FROM revlog_entries '
          'WHERE at_utc >= ? AND at_utc < ? GROUP BY event_type',
          variables: <Variable<Object>>[Variable<int>(from), Variable<int>(to)],
        )
        .get();
    return <RevlogEventType, int>{
      for (final row in rows)
        RevlogEventType.fromValue(row.read<int>('event_type')): row.read<int>(
          'n',
        ),
    };
  }

  @override
  Future<ReviewRecord?> findLastReview(String cardId) =>
      _findLastUnundoneReview(cardId);

  @override
  Future<ReviewRecord?> findLastReviewOverall() =>
      _findLastUnundoneReview(null);

  Future<ReviewRecord?> _findLastUnundoneReview(String? cardId) async {
    final String cardPredicate = cardId == null ? '' : 'AND r.card_id = ? ';
    final rows = await _database
        .customSelect(
          'SELECT r.* FROM review_events r '
          'WHERE r.is_practice = 0 $cardPredicate'
          'AND NOT EXISTS (SELECT 1 FROM scheduler_events original '
          'JOIN scheduler_events inverse '
          'ON inverse.undoes_event_id = original.id '
          'WHERE original.operation_id = r.operation_id '
          "AND original.event_type = 'card_reviewed' "
          "AND inverse.event_type = 'card_review_undone') "
          'ORDER BY r.reviewed_at_utc DESC, r.id DESC LIMIT 1',
          variables: <Variable<Object>>[
            if (cardId != null) Variable<String>(cardId),
          ],
          readsFrom: <ResultSetImplementation<Table, Object?>>{
            _database.reviewEvents,
            _database.schedulerEvents,
          },
        )
        .get();
    if (rows.isEmpty) return null;
    return reviewRecordFromRow(_database.reviewEvents.map(rows.single.data));
  }

  @override
  Future<void> saveMercyBatch(StoredMercyBatch batch) => _database
      .into(_database.mercyBatches)
      .insertOnConflictUpdate(
        MercyBatchesCompanion.insert(
          batchId: batch.batchId,
          previewOperationId: batch.previewOperationId,
          policyVersion: batch.policyVersion,
          previewJson: batch.previewJson,
          createdAtUtc: toEpochMs(batch.createdAtUtc),
          applyOperationId: Value<String?>(batch.applyOperationId),
          undoOperationId: Value<String?>(batch.undoOperationId),
          appliedSnapshotJson: Value<String?>(batch.appliedSnapshotJson),
          appliedAtUtc: Value<int?>(
            batch.appliedAtUtc == null ? null : toEpochMs(batch.appliedAtUtc!),
          ),
          undoneAtUtc: Value<int?>(
            batch.undoneAtUtc == null ? null : toEpochMs(batch.undoneAtUtc!),
          ),
        ),
      );

  @override
  Future<StoredMercyBatch?> findMercyBatch(String batchId) async {
    final MercyBatchRow? row =
        await (_database.select(_database.mercyBatches)..where(
              ($MercyBatchesTable table) => table.batchId.equals(batchId),
            ))
            .getSingleOrNull();
    return row == null ? null : _toMercyBatch(row);
  }

  @override
  Future<StoredMercyBatch?> findMercyBatchByPreviewOperation(
    String operationId,
  ) async {
    final MercyBatchRow? row =
        await (_database.select(_database.mercyBatches)..where(
              ($MercyBatchesTable table) =>
                  table.previewOperationId.equals(operationId),
            ))
            .getSingleOrNull();
    return row == null ? null : _toMercyBatch(row);
  }

  @override
  Future<List<StoredMercyBatch>> listAppliedMercyBatchesSince(
    StudyDay day,
  ) async {
    final List<MercyBatchRow> rows =
        await (_database.select(_database.mercyBatches)
              ..where(
                ($MercyBatchesTable table) =>
                    table.appliedAtUtc.isBiggerOrEqualValue(
                      day.epochDay * Duration.millisecondsPerDay,
                    ) &
                    table.undoneAtUtc.isNull(),
              )
              ..orderBy(<OrderClauseGenerator<$MercyBatchesTable>>[
                ($MercyBatchesTable table) =>
                    OrderingTerm.desc(table.appliedAtUtc),
              ]))
            .get();
    return <StoredMercyBatch>[for (final row in rows) _toMercyBatch(row)];
  }

  @override
  Future<StoredMercyBatch?> findLastAppliedMercyBatch() async {
    final MercyBatchRow? row =
        await (_database.select(_database.mercyBatches)
              ..where(
                ($MercyBatchesTable table) =>
                    table.appliedAtUtc.isNotNull() & table.undoneAtUtc.isNull(),
              )
              ..orderBy(<OrderClauseGenerator<$MercyBatchesTable>>[
                ($MercyBatchesTable table) =>
                    OrderingTerm.desc(table.appliedAtUtc),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toMercyBatch(row);
  }

  StoredMercyBatch _toMercyBatch(MercyBatchRow row) => StoredMercyBatch(
    batchId: row.batchId,
    previewOperationId: row.previewOperationId,
    policyVersion: row.policyVersion,
    previewJson: row.previewJson,
    createdAtUtc: fromEpochMs(row.createdAtUtc),
    applyOperationId: row.applyOperationId,
    undoOperationId: row.undoOperationId,
    appliedSnapshotJson: row.appliedSnapshotJson,
    appliedAtUtc: row.appliedAtUtc == null
        ? null
        : fromEpochMs(row.appliedAtUtc!),
    undoneAtUtc: row.undoneAtUtc == null ? null : fromEpochMs(row.undoneAtUtc!),
  );

  @override
  Future<List<PriorityRank>> listActivePriorities() async {
    final rows = await _database
        .customSelect(
          'SELECT priority_key FROM element_schedules '
          'WHERE lifecycle != ? ORDER BY priority_key, element_id',
          variables: <Variable<Object>>[
            Variable<int>(ElementLifecycle.deleted.index),
          ],
        )
        .get();
    return <PriorityRank>[
      for (final row in rows) PriorityRank(row.read<String>('priority_key')),
    ];
  }

  @override
  Future<Map<String, CardState>> findCardStates(List<String> cardIds) async {
    if (cardIds.isEmpty) return <String, CardState>{};
    final result = <String, CardState>{};
    for (final id in cardIds) {
      final state = await findCardState(id);
      if (state != null) result[id] = state;
    }
    return result;
  }

  @override
  Future<void> saveSchedules(List<ElementSchedule> schedules) async {
    if (schedules.isEmpty) return;
    await _database.batch((Batch batch) {
      for (final schedule in schedules) {
        batch.insert(
          _database.elementSchedules,
          scheduleToCompanion(schedule),
          onConflict: DoUpdate(
            (_) => scheduleToCompanion(schedule),
            target: <Column<Object>>[
              _database.elementSchedules.elementId,
              _database.elementSchedules.elementType,
            ],
          ),
        );
      }
    });
  }

  @override
  Future<List<ElementSchedule>> listSchedules({
    required Set<ElementType> types,
    Set<ElementLifecycle>? lifecycles,
    int? limit,
    int? offset,
  }) async {
    if (types.isEmpty) return <ElementSchedule>[];
    final query = _database.select(_database.elementSchedules)
      ..where(
        ($ElementSchedulesTable t) =>
            t.elementType.isIn(types.map((ElementType e) => e.index).toList()) &
            (lifecycles == null
                ? const CustomExpression<bool>('1')
                : t.lifecycle.isIn(
                    lifecycles.map((ElementLifecycle l) => l.index).toList(),
                  )),
      )
      ..orderBy(<OrderClauseGenerator<$ElementSchedulesTable>>[
        ($ElementSchedulesTable t) => OrderingTerm.asc(t.priorityKey),
        ($ElementSchedulesTable t) => OrderingTerm.asc(t.elementId),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    final rows = await query.get();
    return <ElementSchedule>[for (final row in rows) scheduleFromRow(row)];
  }

  @override
  Future<Map<ElementType, Map<ElementLifecycle, int>>>
  countByLifecycle() async {
    final rows = await _database
        .customSelect(
          'SELECT element_type, lifecycle, COUNT(*) AS n '
          'FROM element_schedules GROUP BY element_type, lifecycle',
        )
        .get();
    final result = <ElementType, Map<ElementLifecycle, int>>{};
    for (final row in rows) {
      final type = ElementType.values[row.read<int>('element_type')];
      final lifecycle = ElementLifecycle.values[row.read<int>('lifecycle')];
      (result[type] ??= <ElementLifecycle, int>{})[lifecycle] = row.read<int>(
        'n',
      );
    }
    return result;
  }

  @override
  Future<List<ActivityRecord>> recentActivity({int limit = 50}) async {
    final rows =
        await (_database.select(_database.activityEvents)
              ..orderBy(<OrderClauseGenerator<$ActivityEventsTable>>[
                ($ActivityEventsTable t) => OrderingTerm.desc(t.atUtc),
              ])
              ..limit(limit))
            .get();
    return <ActivityRecord>[
      for (final row in rows)
        ActivityRecord(
          id: row.id,
          operationId: row.operationId,
          kind: row.kind,
          atUtc: fromEpochMs(row.atUtc),
          ref: row.elementId == null || row.elementType == null
              ? null
              : ElementRef(
                  id: row.elementId!,
                  type: ElementType.values[row.elementType!],
                ),
          durationMs: row.durationMs,
          metadata: row.metadataJson == null
              ? null
              : jsonDecode(row.metadataJson!) as Map<String, Object?>,
        ),
    ];
  }
}

/// Key/value settings.
final class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<String?> read(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where(($SettingsTable t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> write(String key, String value) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  @override
  Future<Map<String, String>> readAll() async {
    final rows = await _database.select(_database.settings).get();
    return <String, String>{for (final row in rows) row.key: row.value};
  }

  @override
  Future<void> writeAll(Map<String, String> values) async {
    if (values.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(_database.settings, <SettingsCompanion>[
        for (final entry in values.entries)
          SettingsCompanion.insert(key: entry.key, value: entry.value),
      ]);
    });
  }

  @override
  Future<void> remove(String key) async {
    await (_database.delete(
      _database.settings,
    )..where(($SettingsTable t) => t.key.equals(key))).go();
  }
}

/// Full-text search over the materialized documents and their FTS5 index.
///
/// The index is external-content: it stores terms only and reads the columns
/// back from `search_documents`. Triggers created with the schema keep the two
/// in step inside whatever transaction wrote the content, so a search can
/// never observe a half-applied import.
final class DriftSearchRepository implements SearchRepository {
  const DriftSearchRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> upsertDocument(SearchDocument document) => _database
      .into(_database.searchDocuments)
      .insertOnConflictUpdate(
        SearchDocumentsCompanion.insert(
          elementId: document.ref.id,
          elementType: document.ref.type.index,
          title: document.title,
          body: document.body,
          sourceId: Value<String?>(document.sourceId),
          updatedAtUtc: toEpochMs(document.updatedAtUtc),
        ),
      );

  @override
  Future<void> deleteDocument(ElementRef ref) async {
    await (_database.delete(_database.searchDocuments)..where(
          ($SearchDocumentsTable t) =>
              t.elementId.equals(ref.id) & t.elementType.equals(ref.type.index),
        ))
        .go();
  }

  @override
  Future<List<SearchHit>> search(
    String query, {
    int limit = 50,
    Set<ElementType>? types,
  }) async {
    if (query.trim().isEmpty) return <SearchHit>[];
    final typeFilter = types == null || types.isEmpty
        ? ''
        : 'AND d.element_type IN '
              '(${types.map((ElementType t) => t.index).join(', ')}) ';
    try {
      final rows = await _database
          .customSelect(
            'SELECT d.element_id, d.element_type, d.title, d.source_id, '
            'bm25($kSearchIndexTable) AS rank, '
            "snippet($kSearchIndexTable, 1, '[', ']', '…', 24) AS snippet "
            'FROM $kSearchIndexTable '
            'JOIN search_documents d ON d.rowid = $kSearchIndexTable.rowid '
            'WHERE $kSearchIndexTable MATCH ? $typeFilter'
            'ORDER BY rank LIMIT ?',
            variables: <Variable<Object>>[
              Variable<String>(query),
              Variable<int>(limit),
            ],
          )
          .get();
      return <SearchHit>[
        for (final row in rows)
          SearchHit(
            ref: ElementRef(
              id: row.read<String>('element_id'),
              type: ElementType.values[row.read<int>('element_type')],
            ),
            title: row.read<String>('title'),
            snippet: row.read<String?>('snippet') ?? '',
            rank: row.read<double?>('rank') ?? 0,
            sourceId: row.read<String?>('source_id'),
          ),
      ];
    } on Object {
      // FTS5 raises on malformed MATCH expressions. The query is built from
      // free text the user is still typing, so an unusable one means "no
      // results yet", never a crash.
      return <SearchHit>[];
    }
  }

  @override
  Future<void> rebuildIndex() => _database.rebuildSearchIndex();

  @override
  Future<bool> indexIsValid() => _database.searchIndexValid();

  @override
  Future<int> documentCount() async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS n FROM search_documents')
        .getSingle();
    return row.read<int>('n');
  }
}

/// Dataset identity and lineage.
final class DriftTransferRepository implements TransferRepository {
  const DriftTransferRepository(this._database, this._ids, this._deviceId);

  final AppDatabase _database;
  final IdGenerator _ids;
  final String _deviceId;

  @override
  Future<DatasetIdentity> currentIdentity() async {
    final row = await (_database.select(
      _database.datasetMeta,
    )..where(($DatasetMetaTable t) => t.id.equals(1))).getSingleOrNull();
    if (row != null) {
      return DatasetIdentity(
        datasetId: row.datasetId,
        generation: row.generation,
        writerEpoch: row.writerEpoch,
        ownerDeviceId: row.ownerDeviceId,
      );
    }
    // First write on a fresh database establishes the lineage.
    final created = DatasetIdentity(
      datasetId: _ids.newId(),
      generation: 0,
      writerEpoch: 1,
      ownerDeviceId: _deviceId,
    );
    await saveIdentity(created);
    return created;
  }

  @override
  Future<void> saveIdentity(DatasetIdentity identity) => _database
      .into(_database.datasetMeta)
      .insertOnConflictUpdate(
        DatasetMetaCompanion.insert(
          id: const Value<int>(1),
          datasetId: identity.datasetId,
          generation: identity.generation,
          writerEpoch: identity.writerEpoch,
          ownerDeviceId: identity.ownerDeviceId,
        ),
      );

  @override
  Future<DatasetIdentity> advanceGeneration() async {
    final next = (await currentIdentity()).advanced();
    await saveIdentity(next);
    return next;
  }
}
