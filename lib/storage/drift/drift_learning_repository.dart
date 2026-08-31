/// Saves and loads schedules, priority, and the repetition log, using Drift.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs. A repository that starts making
/// policy is how scheduling rules end up spread across three folders.
library;

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

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
  Future<void> deleteReviewsForCard(String cardId) async {
    await (_database.delete(
      _database.reviewEvents,
    )..where(($ReviewEventsTable table) => table.cardId.equals(cardId))).go();
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
  Future<void> deleteCardState(String cardId) async {
    await (_database.delete(
      _database.cardMemories,
    )..where(($CardMemoriesTable table) => table.cardId.equals(cardId))).go();
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
  Future<List<ElementSchedule>> listSchedulesByPriority({
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
          type: record.type,
          atUtc: toEpochMs(record.atUtc),
          durationMs: Value<int?>(record.durationMs),
          metadataJson: Value<String?>(
            record.metadata == null ? null : jsonEncode(record.metadata),
          ),
        ),
      );

  @override
  Future<bool> hasActivity(String operationId, String type) async {
    final row = await _database
        .customSelect(
          'SELECT 1 AS present FROM activity_events '
          'WHERE operation_id = ? AND type = ? LIMIT 1',
          variables: <Variable<Object>>[
            Variable<String>(operationId),
            Variable<String>(type),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> appendReviewLog(ReviewLogEntry entry) => _database
      .into(_database.revlogEntries)
      .insert(reviewLogToCompanion(entry));

  @override
  Future<void> appendReviewLogBatch(List<ReviewLogEntry> entries) async {
    if (entries.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAll(_database.revlogEntries, <RevlogEntriesCompanion>[
        for (final entry in entries) reviewLogToCompanion(entry),
      ]);
    });
  }

  @override
  Future<List<ReviewLogEntry>> listReviewLogForElement(
    ElementRef ref, {
    int? limit,
  }) async {
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
    return <ReviewLogEntry>[for (final row in rows) reviewLogFromRow(row)];
  }

  @override
  Future<List<ReviewLogEntry>> listReviewLogForOperation(
    String operationId,
  ) async {
    final rows =
        await (_database.select(_database.revlogEntries)
              ..where(
                ($RevlogEntriesTable t) => t.operationId.equals(operationId),
              )
              ..orderBy(<OrderClauseGenerator<$RevlogEntriesTable>>[
                ($RevlogEntriesTable t) => OrderingTerm.asc(t.atUtc),
                ($RevlogEntriesTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return <ReviewLogEntry>[for (final row in rows) reviewLogFromRow(row)];
  }

  @override
  Future<List<ReviewLogEntry>> listRecentReviewLog({int limit = 100}) async {
    final rows =
        await (_database.select(_database.revlogEntries)
              ..orderBy(<OrderClauseGenerator<$RevlogEntriesTable>>[
                ($RevlogEntriesTable t) => OrderingTerm.desc(t.atUtc),
              ])
              ..limit(limit))
            .get();
    return <ReviewLogEntry>[for (final row in rows) reviewLogFromRow(row)];
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
  Future<Map<ReviewLogEventType, int>> countReviewLogEventsOn(
    StudyDay day,
  ) async {
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
    return <ReviewLogEventType, int>{
      for (final row in rows)
        ReviewLogEventType.fromValue(row.read<int>('event_type')): row
            .read<int>('n'),
    };
  }

  @override
  Future<ReviewRecord?> findLastReview(String cardId) =>
      _findLastUnundoneReview(cardId);

  @override
  Future<ReviewRecord?> findLastReviewInCollection() =>
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
  Future<List<ActivityRecord>> listRecentActivity({int limit = 50}) async {
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
          type: row.type,
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
