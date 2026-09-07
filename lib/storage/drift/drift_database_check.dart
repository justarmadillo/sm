/// Drift implementation of the atomic collection check and repair pass.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/storage/contracts/database_check.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

const String _elementIdentity = '''
WITH element_identity(element_id, element_type) AS (
  SELECT id, 0 FROM sources
  UNION ALL SELECT id, 1 FROM extracts
  UNION ALL SELECT id, 2 FROM cards
  UNION ALL SELECT id, 3 FROM video_elements
)
''';

/// Repairs relationships SQLite cannot express as ordinary foreign keys.
final class DriftDatabaseCheck implements DatabaseCheck {
  const DriftDatabaseCheck(
    this._database,
    this._transactions,
    this._diagnostics, {
    Clock clock = const SystemClock(),
  }) : _clock = clock;

  final AppDatabase _database;
  final TransactionRunner _transactions;
  final DiagnosticSink _diagnostics;
  final Clock _clock;

  @override
  Future<DatabaseCheckReport> repairIntegrity() async {
    final List<String> corruption = await _database.quickCheck();
    if (corruption.length != 1 || corruption.single != 'ok') {
      return DatabaseCheckReport(
        outcome: DatabaseCheckOutcome.corrupt,
        findings: const <DatabaseCheckFinding>[],
        corruption: corruption,
      );
    }

    final List<DatabaseCheckFinding> findings = await _transactions.run(
      () async {
        final List<DatabaseCheckFinding> found = <DatabaseCheckFinding>[];
        await _repairSearchDocumentOrphans(found);
        await _repairElementTagOrphans(found);
        await _repairSchedulesWithoutElements(found);
        await _repairElementsWithoutSchedules(found);
        await _repairCardParents(found);
        await _repairScheduleParents(found);
        await _repairScheduleRoots(found);
        await _repairTopicStateOrphans(found);
        await _repairLastReviewInstants(found);
        await _repairFsrsState(found);
        await _repairTopicNumbers(found);
        await _reportUndecodableContent(found);
        await _reportOrphanedLogs(found);
        await _repairSearchIndex(found);
        return found;
      },
    );
    _diagnostics.record(
      DiagnosticEvent(
        level: findings.isEmpty
            ? DiagnosticLevel.info
            : DiagnosticLevel.warning,
        name: 'database.check.completed',
        timestampUtc: _clock.nowUtc(),
        fields: <String, Object?>{
          'findings': findings.length,
          'affectedRows': findings.fold<int>(
            0,
            (int total, DatabaseCheckFinding finding) => total + finding.count,
          ),
        },
      ),
    );
    return DatabaseCheckReport(
      outcome:
          findings.any((DatabaseCheckFinding finding) => finding.wasRepaired)
          ? DatabaseCheckOutcome.repaired
          : DatabaseCheckOutcome.sound,
      findings: findings,
    );
  }

  Future<void> _repairSearchDocumentOrphans(
    List<DatabaseCheckFinding> findings,
  ) async {
    final String where = '''
NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = search_documents.element_id
    AND identity.element_type = search_documents.element_type
)''';
    await _repair(
      findings,
      name: 'search_document_orphan',
      description: 'Search rows without content were removed.',
      countSql:
          '$_elementIdentity SELECT COUNT(*) AS count FROM search_documents WHERE $where',
      repairSql: '$_elementIdentity DELETE FROM search_documents WHERE $where',
    );
  }

  Future<void> _repairElementTagOrphans(
    List<DatabaseCheckFinding> findings,
  ) async {
    const String where = '''NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = element_tags.element_id
    AND identity.element_type = element_tags.element_type
)''';
    await _repair(
      findings,
      name: 'element_tag_orphan',
      description: 'Tag links without content were removed.',
      countSql:
          '$_elementIdentity SELECT COUNT(*) AS count FROM element_tags WHERE $where',
      repairSql: '$_elementIdentity DELETE FROM element_tags WHERE $where',
    );
  }

  Future<void> _repairSchedulesWithoutElements(
    List<DatabaseCheckFinding> findings,
  ) async {
    final String where = '''
NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = element_schedules.element_id
    AND identity.element_type = element_schedules.element_type
)''';
    final int count = await _count(
      '$_elementIdentity SELECT COUNT(*) AS count FROM element_schedules WHERE $where',
    );
    if (count == 0) return;
    await _database.customStatement('''
$_elementIdentity
DELETE FROM topic_states WHERE NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = topic_states.element_id
    AND identity.element_type = topic_states.element_type
)''');
    await _database.customStatement('''
$_elementIdentity
DELETE FROM card_memories WHERE card_id IN (
  SELECT element_id FROM element_schedules
  WHERE element_type = 2 AND $where
)''');
    await _database.customStatement(
      '$_elementIdentity DELETE FROM element_schedules WHERE $where',
    );
    findings.add(
      DatabaseCheckFinding(
        name: 'schedule_without_element',
        description: 'Schedules without content were removed.',
        count: count,
        wasRepaired: true,
      ),
    );
  }

  Future<void> _repairElementsWithoutSchedules(
    List<DatabaseCheckFinding> findings,
  ) async {
    final int count = await _count('''
$_elementIdentity
SELECT COUNT(*) AS count FROM element_identity identity
WHERE NOT EXISTS (
  SELECT 1 FROM element_schedules schedule
  WHERE schedule.element_id = identity.element_id
    AND schedule.element_type = identity.element_type
)''');
    if (count == 0) return;
    await _insertMissingSchedules('sources', 0, 'imported_at_utc', 'id');
    await _insertMissingSchedules('extracts', 1, 'created_at_utc', 'source_id');
    await _insertMissingSchedules('cards', 2, 'created_at_utc', 'NULL');
    await _insertMissingSchedules(
      'video_elements',
      3,
      'created_at_utc',
      'NULL',
    );
    findings.add(
      DatabaseCheckFinding(
        name: 'element_without_schedule',
        description: 'Invisible content was returned to the active schedule.',
        count: count,
        wasRepaired: true,
      ),
    );
  }

  Future<void> _insertMissingSchedules(
    String table,
    int elementType,
    String createdColumn,
    String rootExpression,
  ) => _database.customStatement('''
INSERT INTO element_schedules (
  element_id, element_type, priority_key, lifecycle, due_day,
  original_due_day, root_id, created_at_utc, updated_at_utc, zone_id
)
SELECT id, $elementType, 'U', 0, CAST($createdColumn / 86400000 AS INTEGER),
  CAST($createdColumn / 86400000 AS INTEGER), $rootExpression,
  $createdColumn, $createdColumn, 'UTC'
FROM $table content
WHERE NOT EXISTS (
  SELECT 1 FROM element_schedules schedule
  WHERE schedule.element_id = content.id
    AND schedule.element_type = $elementType
)''');

  Future<void> _repairCardParents(List<DatabaseCheckFinding> findings) async {
    const String where = '''parent_element_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = cards.parent_element_id
    AND identity.element_type = cards.parent_element_type
)''';
    await _repair(
      findings,
      name: 'card_parent_missing',
      description: 'Cards with missing parents were made standalone.',
      countSql:
          '$_elementIdentity SELECT COUNT(*) AS count FROM cards WHERE $where',
      repairSql:
          '$_elementIdentity UPDATE cards SET parent_element_id = NULL, parent_element_type = NULL WHERE $where',
    );
  }

  Future<void> _repairScheduleParents(
    List<DatabaseCheckFinding> findings,
  ) async {
    const String where = '''parent_element_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = element_schedules.parent_element_id
)''';
    await _repair(
      findings,
      name: 'schedule_parent_missing',
      description:
          'Elements with missing filing parents were moved to the root.',
      countSql:
          '$_elementIdentity SELECT COUNT(*) AS count FROM element_schedules WHERE $where',
      repairSql:
          '$_elementIdentity UPDATE element_schedules SET parent_element_id = NULL WHERE $where',
    );
  }

  Future<void> _repairScheduleRoots(List<DatabaseCheckFinding> findings) async {
    const String where = '''root_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM sources WHERE sources.id = element_schedules.root_id
)''';
    final int count = await _count(
      'SELECT COUNT(*) AS count FROM element_schedules WHERE $where',
    );
    if (count == 0) return;
    await _database.customStatement('''
UPDATE element_schedules SET root_id = CASE element_type
  WHEN 0 THEN (SELECT id FROM sources WHERE id = element_schedules.element_id)
  WHEN 1 THEN (SELECT source_id FROM extracts WHERE id = element_schedules.element_id)
  WHEN 2 THEN (
    SELECT CASE card.parent_element_type
      WHEN 0 THEN card.parent_element_id
      WHEN 1 THEN (SELECT source_id FROM extracts WHERE id = card.parent_element_id)
      ELSE NULL END
    FROM cards card WHERE card.id = element_schedules.element_id
  )
  ELSE NULL END
WHERE $where''');
    findings.add(
      DatabaseCheckFinding(
        name: 'schedule_root_missing',
        description: 'Missing source roots were reconstructed where possible.',
        count: count,
        wasRepaired: true,
      ),
    );
  }

  Future<void> _repairTopicStateOrphans(
    List<DatabaseCheckFinding> findings,
  ) async {
    const String where = '''NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = topic_states.element_id
    AND identity.element_type = topic_states.element_type
) OR NOT EXISTS (
  SELECT 1 FROM element_schedules schedule
  WHERE schedule.element_id = topic_states.element_id
    AND schedule.element_type = topic_states.element_type
)''';
    await _repair(
      findings,
      name: 'topic_state_orphan',
      description: 'Topic state without matching content was removed.',
      countSql:
          '$_elementIdentity SELECT COUNT(*) AS count FROM topic_states WHERE $where',
      repairSql: '$_elementIdentity DELETE FROM topic_states WHERE $where',
    );
  }

  Future<void> _repairFsrsState(List<DatabaseCheckFinding> findings) async {
    final List<QueryRow> rows = await _database
        .customSelect('SELECT * FROM card_memories')
        .get();
    var count = 0;
    for (final QueryRow queryRow in rows) {
      final CardMemoryRow row = _database.cardMemories.map(queryRow.data);
      final String canonical = cardMemoryFromRowIgnoringStoredJson(
        row,
      ).canonicalFsrsJson();
      final String? stored = row.fsrsStateJson;
      bool disagrees;
      try {
        disagrees =
            stored == null || jsonEncode(jsonDecode(stored)) != canonical;
      } on Object {
        disagrees = true;
      }
      if (!disagrees) continue;
      count++;
      await _database.customStatement(
        'UPDATE card_memories SET fsrs_state_json = ? WHERE card_id = ?',
        <Object?>[canonical, row.cardId],
      );
    }
    if (count > 0) {
      findings.add(
        DatabaseCheckFinding(
          name: 'fsrs_state_disagrees',
          description:
              'Card scheduler snapshots were rebuilt from typed state.',
          count: count,
          wasRepaired: true,
        ),
      );
    }
  }

  Future<void> _repairLastReviewInstants(
    List<DatabaseCheckFinding> findings,
  ) async {
    const String where = '''EXISTS (
  SELECT 1 FROM review_events review WHERE review.card_id = card_memories.card_id
) AND last_review_utc IS NOT (
  SELECT MAX(reviewed_at_utc) FROM review_events review
  WHERE review.card_id = card_memories.card_id
)''';
    await _repair(
      findings,
      name: 'card_last_review_disagrees_with_log',
      description: 'Card last-review times were restored from review history.',
      countSql: 'SELECT COUNT(*) AS count FROM card_memories WHERE $where',
      repairSql: '''UPDATE card_memories SET last_review_utc = (
  SELECT MAX(reviewed_at_utc) FROM review_events review
  WHERE review.card_id = card_memories.card_id
) WHERE $where''',
    );
  }

  Future<void> _repairTopicNumbers(List<DatabaseCheckFinding> findings) async {
    final List<TopicStateRow> rows = await _database
        .select(_database.topicStates)
        .get();
    var aFactorCount = 0;
    for (final TopicStateRow row in rows) {
      final double value = real48FromHex(row.aFactorRaw).value;
      if (value >= 1.01 && value <= 6.0) continue;
      final double clamped = value.clamp(1.01, 6.0).toDouble();
      await _database.customStatement(
        'UPDATE topic_states SET a_factor_raw = ? '
        'WHERE element_id = ? AND element_type = ?',
        <Object?>[
          DelphiReal48.fromDouble(clamped).toString(),
          row.elementId,
          row.elementType,
        ],
      );
      aFactorCount++;
    }
    if (aFactorCount > 0) {
      findings.add(
        DatabaseCheckFinding(
          name: 'topic_state_afactor_out_of_range',
          description: 'Topic A-factors were returned to their valid range.',
          count: aFactorCount,
          wasRepaired: true,
        ),
      );
    }
    await _repair(
      findings,
      name: 'topic_state_lapses_exceed_reps',
      description: 'Topic lapse counts were capped at repetition counts.',
      countSql:
          'SELECT COUNT(*) AS count FROM topic_states WHERE lapse_count > repetition_count',
      repairSql:
          'UPDATE topic_states SET lapse_count = repetition_count WHERE lapse_count > repetition_count',
    );
  }

  Future<void> _reportUndecodableContent(
    List<DatabaseCheckFinding> findings,
  ) async {
    var count = 0;
    for (final BlockRow row in await _database.select(_database.blocks).get()) {
      if (tryDecodeContentSpans(row.contentSpans).isErr) count++;
    }
    for (final CardOcclusionRow row
        in await _database.select(_database.cardOcclusions).get()) {
      if (tryDecodeOcclusionRegions(row.regionsJson).isErr) count++;
    }
    for (final RevlogRow row
        in await _database.select(_database.revlogEntries).get()) {
      if (row.metadataJson != null &&
          tryDecodeReviewLogMetadata(row.metadataJson!).isErr) {
        count++;
      }
    }
    for (final SchedulerEventRow row
        in await _database.select(_database.schedulerEvents).get()) {
      for (final String? json in <String?>[
        row.stateBefore,
        row.stateAfter,
        row.metadataJson,
      ]) {
        if (json != null && tryDecodeSchedulerState(json).isErr) count++;
      }
    }
    for (final MercyBatchRow row
        in await _database.select(_database.mercyBatches).get()) {
      if (row.appliedSnapshotJson != null &&
          tryDecodeMercyAppliedBatch(row.appliedSnapshotJson!).isErr) {
        count++;
      }
    }
    if (count > 0) {
      findings.add(
        DatabaseCheckFinding(
          name: 'content_undecodable',
          description: 'Some stored structured content could not be decoded.',
          count: count,
          wasRepaired: false,
        ),
      );
    }
  }

  Future<void> _reportOrphanedLogs(List<DatabaseCheckFinding> findings) async {
    for (final ({String table, String name, String description}) log
        in <({String table, String name, String description})>[
          (
            table: 'revlog_entries',
            name: 'review_log_without_element',
            description:
                'Review history refers to content that is no longer present.',
          ),
          (
            table: 'scheduler_events',
            name: 'scheduler_event_without_element',
            description:
                'Scheduler history refers to content that is no longer present.',
          ),
          (
            table: 'activity_events',
            name: 'activity_event_without_element',
            description:
                'Activity history refers to content that is no longer present.',
          ),
        ]) {
      final int count = await _count('''
$_elementIdentity
SELECT COUNT(*) AS count FROM ${log.table} event
WHERE event.element_id IS NOT NULL AND NOT EXISTS (
  SELECT 1 FROM element_identity identity
  WHERE identity.element_id = event.element_id
    AND identity.element_type = event.element_type
)''');
      if (count > 0) {
        findings.add(
          DatabaseCheckFinding(
            name: log.name,
            description: log.description,
            count: count,
            wasRepaired: false,
          ),
        );
      }
    }
  }

  Future<void> _repairSearchIndex(List<DatabaseCheckFinding> findings) async {
    if (await _database.isSearchIndexInStepWithContent()) return;
    await _database.rebuildSearchIndex();
    findings.add(
      const DatabaseCheckFinding(
        name: 'search_index_out_of_step',
        description: 'The search index was rebuilt from collection content.',
        count: 1,
        wasRepaired: true,
      ),
    );
  }

  Future<void> _repair(
    List<DatabaseCheckFinding> findings, {
    required String name,
    required String description,
    required String countSql,
    required String repairSql,
  }) async {
    final int count = await _count(countSql);
    if (count == 0) return;
    await _database.customStatement(repairSql);
    findings.add(
      DatabaseCheckFinding(
        name: name,
        description: description,
        count: count,
        wasRepaired: true,
      ),
    );
  }

  Future<int> _count(String sql) async {
    final QueryRow row = await _database.customSelect(sql).getSingle();
    return row.read<int>('count');
  }
}
