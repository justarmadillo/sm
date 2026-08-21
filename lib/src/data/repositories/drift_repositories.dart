/// Drift-backed implementations of the application's repository ports.
///
/// These hold SQL and mapping, nothing else. No repository decides an
/// interval, a lifecycle transition, or whether an operation is allowed —
/// those are the handlers' and the domain's jobs. A repository that starts
/// making policy is how scheduling logic ends up spread across three layers.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../application/ports/repositories.dart';
import '../../application/ports/transaction_runner.dart';
import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../domain/content/card.dart';
import '../../domain/content/document.dart';
import '../../domain/content/extract.dart';
import '../../domain/content/reader_anchor.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/transfer/dataset_lineage.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

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
    // a stale projection from a fresh one.
    await _database.customStatement(
      'UPDATE sources SET title = ?, pace = ?, marker_block_id = ?, '
      'marker_offset = ?, soft_block_id = ?, soft_offset = ?, folder_id = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[
        source.title,
        source.pace.index,
        source.resume.marker?.blockId,
        source.resume.marker?.utf8Offset,
        source.resume.softPosition?.blockId,
        source.resume.softPosition?.utf8Offset,
        source.folderId,
        source.id,
      ],
    );
  }

  @override
  Future<Source?> setResumeMarker(String sourceId, ReaderAnchor anchor) async {
    await _database.customStatement(
      'UPDATE sources SET marker_block_id = ?, marker_offset = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[anchor.blockId, anchor.utf8Offset, sourceId],
    );
    return findSource(sourceId);
  }

  @override
  Future<Source?> setSoftPosition(String sourceId, ReaderAnchor anchor) async {
    await _database.customStatement(
      'UPDATE sources SET soft_block_id = ?, soft_offset = ?, '
      'revision = revision + 1 WHERE id = ?',
      <Object?>[anchor.blockId, anchor.utf8Offset, sourceId],
    );
    return findSource(sourceId);
  }

  @override
  Future<Source?> confirmSoftPosition(String sourceId) async {
    await _database.customStatement(
      'UPDATE sources SET marker_block_id = soft_block_id, '
      'marker_offset = soft_offset, revision = revision + 1 '
      'WHERE id = ? AND soft_block_id IS NOT NULL',
      <Object?>[sourceId],
    );
    return findSource(sourceId);
  }

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
              ..where(($CardsTable t) => t.extractId.equals(extractId))
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
              ..where(($CardsTable t) => t.sourceId.equals(sourceId))
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
                    table.dueAtUtc.isSmallerOrEqualValue(nowMs) &
                    (table.deferredUntilUtc.isNull() |
                        table.deferredUntilUtc.isSmallerOrEqualValue(nowMs)),
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
    return TopicState(
      schedule: schedule,
      profileId: pacing.profileId,
      stepIndex: pacing.stepIndex,
    );
  }

  @override
  Future<Map<ElementRef, TopicState>> findTopics(List<ElementRef> refs) async {
    if (refs.isEmpty) return <ElementRef, TopicState>{};
    final ids = refs.map((ElementRef r) => r.id).toList();
    final placeholders = List<String>.filled(ids.length, '?').join(', ');
    final rows = await _database
        .customSelect(
          'SELECT s.element_id, s.element_type, s.priority_key, s.lifecycle, '
          's.due_day, s.original_due_day, s.deferred_until, s.deferral_kind, '
          's.zone_id, t.profile_id, t.step_index '
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
      final deferred = row.read<int?>('deferred_until');
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
          deferredUntil: deferred == null
              ? null
              : studyDayFromEpochDay(deferred, zoneId),
          deferralKind: DeferralKind.values[row.read<int>('deferral_kind')],
        ),
        profileId: row.read<String>('profile_id'),
        stepIndex: row.read<int>('step_index'),
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
  Future<List<ElementSchedule>> listEligible({
    required StudyDay day,
    required Set<ElementType> types,
  }) async {
    if (types.isEmpty) return <ElementSchedule>[];
    final rows =
        await (_database.select(_database.elementSchedules)
              ..where(
                ($ElementSchedulesTable t) =>
                    t.lifecycle.equals(ElementLifecycle.active.index) &
                    t.elementType.isIn(
                      types.map((ElementType e) => e.index).toList(),
                    ) &
                    t.dueDay.isSmallerOrEqualValue(day.epochDay) &
                    (t.deferredUntil.isNull() |
                        t.deferredUntil.isSmallerOrEqualValue(day.epochDay)),
              )
              ..orderBy(<OrderClauseGenerator<$ElementSchedulesTable>>[
                ($ElementSchedulesTable t) => OrderingTerm.asc(t.priorityKey),
              ]))
            .get();
    return <ElementSchedule>[for (final row in rows) scheduleFromRow(row)];
  }

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
  Future<void> setPriorities(Map<ElementRef, PriorityRank> ranks) async {
    if (ranks.isEmpty) return;
    await _database.batch((Batch batch) {
      for (final entry in ranks.entries) {
        batch.update(
          _database.elementSchedules,
          ElementSchedulesCompanion(
            priorityKey: Value<String>(entry.value.orderKey),
          ),
          where: ($ElementSchedulesTable t) =>
              t.elementId.equals(entry.key.id) &
              t.elementType.equals(entry.key.type.index),
        );
      }
    });
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

/// Reads the Library projection: sources with their schedules and counts.
final class DriftLibraryQuery {
  const DriftLibraryQuery(this._content, this._learning, this._clock);

  final ContentRepository _content;
  final LearningRepository _learning;
  // Held so the projection can be extended with due-today flags without
  // changing every call site.
  final Clock _clock;

  /// Every source with the scheduling facts the Library shows.
  Future<List<LibraryEntry>> listEntries() async {
    final sources = await _content.listSources();
    if (sources.isEmpty) return <LibraryEntry>[];

    final refs = <ElementRef>[
      for (final source in sources)
        ElementRef(id: source.id, type: ElementType.source),
    ];
    final topics = await _learning.findTopics(refs);
    final counts = await _content.countExtractsBySource(
      sources.map((Source s) => s.id).toList(),
    );

    final entries = <LibraryEntry>[];
    for (final source in sources) {
      final topic = topics[ElementRef(id: source.id, type: ElementType.source)];
      if (topic == null) continue;
      entries.add(
        LibraryEntry(
          source: source,
          topic: topic,
          extractCount: counts[source.id] ?? 0,
        ),
      );
    }
    return entries;
  }

  /// The current instant, exposed so callers share one clock.
  DateTime nowUtc() => _clock.nowUtc();
}
