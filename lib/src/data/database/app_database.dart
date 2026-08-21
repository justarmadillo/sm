/// The application database: connection policy, schema version, migrations.
///
/// Two rules the rest of the app relies on and cannot check for itself:
/// foreign keys are enabled on *every* connection (SQLite defaults them off,
/// per connection, silently), and the live database is journalled in WAL mode
/// and never placed in a synced folder.
library;

import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Current schema version. Bump with every migration step added below.
const int kSchemaVersion = 6;

/// Name of the external-content FTS5 index over [SearchDocuments].
const String kSearchIndexTable = 'search_index';

@DriftDatabase(
  tables: <Type>[
    Sources,
    Blocks,
    Extracts,
    Cards,
    ElementSchedules,
    TopicStates,
    CardMemories,
    ReviewEvents,
    RevlogEntries,
    ScheduleAdjustments,
    SchedulerEvents,
    DailyPresentationPlans,
    MercyBatches,
    SearchDocuments,
    ActivityEvents,
    Folders,
    Settings,
    DatasetMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes(m);
      await _createSearchIndex();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Every historical path must be exercised by a migration test
      // before it ships. New steps are appended here as `if (from < n)`.
      if (from > to) {
        throw StateError(
          'database schema $from is newer than this build supports ($to)',
        );
      }
      if (from < 2) {
        // Rebuild both tables so descendant content cannot disappear via
        // an accidental physical parent delete. The app uses lifecycle
        // soft deletion; RESTRICT is the database-level backstop.
        await m.alterTable(TableMigration(extracts));
        // Cards are rebuilt once in v6 when their two legacy parent columns
        // are converted into the single typed parent coordinate.
        await _createIndexes(m);
      }
      if (from < 3) {
        // FSRS-6 represents a brand-new card as Learning with null
        // stability/difficulty and needs its intraday learning-step index.
        // The unused M0 scaffold called that state `0`; preserve any early
        // development rows by promoting it to dart-fsrs' Learning value `1`.
        await m.alterTable(
          TableMigration(
            cardMemories,
            // postpone_count arrives with M4 but has to be named here too:
            // rebuilding the table copies every column of the *current*
            // definition, and a v2 row has no value to copy for it.
            newColumns: [
              cardMemories.step,
              cardMemories.postponeCount,
              cardMemories.schedulerName,
              cardMemories.scheduledDays,
              cardMemories.fsrsStateJson,
              cardMemories.revision,
            ],
            columnTransformer: {
              cardMemories.state: const CustomExpression<int>(
                'CASE WHEN state = 0 THEN 1 ELSE state END',
              ),
              cardMemories.step: const CustomExpression<int>(
                'CASE WHEN state = 2 THEN NULL ELSE 0 END',
              ),
              cardMemories.stability: const CustomExpression<double>(
                'CASE WHEN state = 0 THEN NULL ELSE stability END',
              ),
              cardMemories.difficulty: const CustomExpression<double>(
                'CASE WHEN state = 0 THEN NULL ELSE difficulty END',
              ),
            },
          ),
        );
        await _createIndexes(m);
      }
      if (from < 4) {
        // A card's parent becomes a reference to any element instead of an
        // obligatory extract, matching SuperMemo: an item can be made
        // directly from an article, or stand alone. Existing rows already
        // name an extract and are copied across unchanged.
        if (!await _hasColumn('cards', 'source_id')) {
          await customStatement(
            'ALTER TABLE cards ADD COLUMN source_id TEXT NULL '
            'REFERENCES sources(id) ON DELETE RESTRICT',
          );
        }
        await _createIndexes(m);
      }
      if (from < 5) {
        // M4: the A-factor topic model, the universal repetition log, and
        // full-text search.
        await m.createTable(revlogEntries);
        await m.createTable(searchDocuments);
        await _addColumnIfMissing(m, elementSchedules, elementSchedules.rootId);
        for (final GeneratedColumn<Object> column in <GeneratedColumn<Object>>[
          topicStates.intervalDays,
          topicStates.aFactor,
          topicStates.yieldEwma,
          topicStates.encounters,
          topicStates.postponeCount,
          topicStates.encountersSinceLastCard,
          topicStates.lastEncounterDay,
        ]) {
          await _addColumnIfMissing(m, topicStates, column);
        }
        await _addColumnIfMissing(m, cardMemories, cardMemories.postponeCount);

        // Existing topics were paced by an interval sequence and carry only a
        // step index. Seed the A-factor model from where each one actually
        // stands, so switching pacing mode continues a half-read article
        // instead of restarting it. The sequences below are the shipped
        // defaults; a topic on an edited profile lands on the closest of them,
        // which is a one-time approximation of an interval, not of progress.
        await customStatement(
          'UPDATE topic_states SET interval_days = CASE profile_id '
          "WHEN 'focused' THEN "
          'CASE MIN(step_index, 8) WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 '
          'WHEN 3 THEN 5 WHEN 4 THEN 7 WHEN 5 THEN 10 WHEN 6 THEN 14 '
          'WHEN 7 THEN 21 ELSE 30 END '
          "WHEN 'slow' THEN "
          'CASE MIN(step_index, 7) WHEN 0 THEN 7 WHEN 1 THEN 14 WHEN 2 THEN 30 '
          'WHEN 3 THEN 60 WHEN 4 THEN 120 WHEN 5 THEN 240 WHEN 6 THEN 365 '
          'ELSE 730 END '
          "WHEN 'extract' THEN "
          'CASE MIN(step_index, 6) WHEN 0 THEN 1 WHEN 1 THEN 3 WHEN 2 THEN 7 '
          'WHEN 3 THEN 14 WHEN 4 THEN 30 WHEN 5 THEN 60 ELSE 120 END '
          'ELSE '
          'CASE MIN(step_index, 8) WHEN 0 THEN 1 WHEN 1 THEN 3 WHEN 2 THEN 7 '
          'WHEN 3 THEN 14 WHEN 4 THEN 30 WHEN 5 THEN 60 WHEN 6 THEN 120 '
          'WHEN 7 THEN 240 ELSE 365 END END, '
          'a_factor = 2.0, encounters = step_index',
        );

        // Every schedule learns its root source. An extract already stores it
        // denormalized; a card reaches it through whichever parent it has.
        await customStatement(
          'UPDATE element_schedules SET root_id = element_id '
          'WHERE element_type = 0',
        );
        await customStatement(
          'UPDATE element_schedules SET root_id = ('
          'SELECT e.source_id FROM extracts e WHERE e.id = element_id) '
          'WHERE element_type = 1',
        );
        await customStatement(
          'UPDATE element_schedules SET root_id = ('
          'SELECT COALESCE(c.source_id, ('
          'SELECT e.source_id FROM extracts e WHERE e.id = c.extract_id)) '
          'FROM cards c WHERE c.id = element_id) '
          'WHERE element_type = 2',
        );

        await _createIndexes(m);
        await _createSearchIndex();
      }
      if (from < 6) {
        // Scheduler contract migration: add typed/versioned scheduling state
        // without deleting legacy schedule or history columns.
        await m.alterTable(
          TableMigration(
            cards,
            newColumns: <GeneratedColumn<Object>>[
              cards.parentElementId,
              cards.parentElementType,
            ],
            columnTransformer: <GeneratedColumn<Object>, Expression<Object>>{
              cards.parentElementId: const CustomExpression<String>(
                'COALESCE(extract_id, source_id)',
              ),
              cards.parentElementType: const CustomExpression<int>(
                'CASE WHEN extract_id IS NOT NULL THEN 1 '
                'WHEN source_id IS NOT NULL THEN 0 ELSE NULL END',
              ),
            },
          ),
        );
        // History must outlive content-level cleanup. Rebuild the legacy
        // CASCADE foreign key as RESTRICT before importing scheduler events.
        await m.alterTable(TableMigration(reviewEvents));

        for (final GeneratedColumn<Object> column in <GeneratedColumn<Object>>[
          elementSchedules.parentElementId,
          elementSchedules.ordinal,
          elementSchedules.createdAtUtc,
          elementSchedules.updatedAtUtc,
          elementSchedules.revision,
          elementSchedules.legacyDueProvenance,
          topicStates.algorithmDueDay,
          topicStates.schedulerKind,
          topicStates.schedulerVersion,
          topicStates.policyInputSnapshot,
          topicStates.revision,
          cardMemories.schedulerName,
          cardMemories.scheduledDays,
          cardMemories.fsrsStateJson,
          cardMemories.revision,
        ]) {
          final TableInfo<Table, Object?> table = switch (column.tableName) {
            'element_schedules' => elementSchedules,
            'topic_states' => topicStates,
            'card_memories' => cardMemories,
            _ => throw StateError('unexpected scheduler column'),
          };
          await _addColumnIfMissing(m, table, column);
        }

        await m.createTable(scheduleAdjustments);
        await m.createTable(schedulerEvents);
        await m.createTable(dailyPresentationPlans);
        await m.createTable(mercyBatches);

        // Import every historical card observation into the new append-only
        // envelope. Old schemas did not persist the home-zone StudyDay at the
        // event, so retain one fixed migration bucket and mark that limitation
        // explicitly instead of pretending it is exact.
        await customStatement(
          'INSERT OR IGNORE INTO scheduler_events ('
          'id, operation_id, element_id, element_type, event_type, '
          'occurred_at_utc, study_day, study_day_zone_id, scheduler_name, '
          'scheduler_version, policy_version, state_before, state_after, '
          'algorithmic_due_before, algorithmic_due_after, metadata_json) '
          "SELECT 'migrated-review:' || r.id, r.operation_id, r.card_id, 2, "
          "CASE WHEN r.is_practice = 1 THEN 'practice_reviewed' "
          "ELSE 'card_reviewed' END, r.reviewed_at_utc, "
          'CAST((r.reviewed_at_utc - 14400000) / 86400000 AS INTEGER), '
          "COALESCE(s.zone_id, 'UTC'), 'dart-fsrs', r.scheduler_version, "
          "'legacy_import_v1', r.pre_state_json, r.post_state_json, "
          "'utc:' || json_extract(r.pre_state_json, '\$.due_at_utc_ms'), "
          "'utc:' || json_extract(r.post_state_json, '\$.due_at_utc_ms'), "
          "'{\"migration\":\"legacy_review\","
          '"snapshot_completeness":"review_state_only",'
          "\"study_day_provenance\":\"utc_minus_4h_approximation\"}' "
          'FROM review_events r LEFT JOIN element_schedules s '
          'ON s.element_id = r.card_id AND s.element_type = 2',
        );

        // All pre-v6 topic rows lack trustworthy policy provenance. Preserve
        // their exact due/interval/step and label them legacy; never infer
        // that the global setting in force today produced yesterday's row.
        await customStatement(
          "UPDATE topic_states SET scheduler_kind = 'legacy_sequence', "
          "scheduler_version = 'legacy_sequence/1', "
          'algorithm_due_day = (SELECT due_day FROM element_schedules e '
          'WHERE e.element_id = topic_states.element_id '
          'AND e.element_type = topic_states.element_type), revision = 1',
        );

        // Recover common element audit/provenance from immutable content rows.
        await customStatement(
          'UPDATE element_schedules SET parent_element_id = CASE element_type '
          'WHEN 1 THEN (SELECT parent_id FROM extracts x '
          'WHERE x.id = element_id) '
          'WHEN 2 THEN (SELECT parent_element_id FROM cards c '
          'WHERE c.id = element_id) ELSE NULL END, '
          'created_at_utc = CASE element_type '
          'WHEN 0 THEN (SELECT imported_at_utc FROM sources s '
          'WHERE s.id = element_id) '
          'WHEN 1 THEN (SELECT created_at_utc FROM extracts x '
          'WHERE x.id = element_id) '
          'WHEN 2 THEN (SELECT created_at_utc FROM cards c '
          'WHERE c.id = element_id) END, '
          'updated_at_utc = CASE element_type '
          'WHEN 0 THEN (SELECT imported_at_utc FROM sources s '
          'WHERE s.id = element_id) '
          'WHEN 1 THEN COALESCE((SELECT edited_at_utc FROM extracts x '
          'WHERE x.id = element_id), (SELECT created_at_utc FROM extracts x '
          'WHERE x.id = element_id)) '
          'WHEN 2 THEN COALESCE((SELECT edited_at_utc FROM cards c '
          'WHERE c.id = element_id), (SELECT created_at_utc FROM cards c '
          'WHERE c.id = element_id)) END, revision = 1',
        );

        // Persist the exact adapter input reconstructed from the canonical v5
        // columns; do not invent stability, difficulty, or a last review.
        await customStatement(
          "UPDATE card_memories SET scheduler_name = 'dart-fsrs', "
          'scheduled_days = CASE WHEN last_review_utc IS NULL THEN NULL '
          'ELSE MAX(0.0, (original_due_at_utc - last_review_utc) / 86400000.0) END, '
          "fsrs_state_json = json_object('state', state, 'step', step, "
          "'stability', stability, 'difficulty', difficulty, "
          "'due_at_utc_ms', due_at_utc, "
          "'last_review_at_utc_ms', last_review_utc), revision = 1",
        );

        // Canonicalize every legacy priority into one stable total order. The
        // old key and immutable ID decide rank; fixed-width keys keep it after
        // restart and remove ambiguous duplicate percentiles.
        await customStatement(
          'WITH ranked AS (SELECT element_id, element_type, '
          'ROW_NUMBER() OVER (ORDER BY priority_key, element_id, element_type) rn '
          'FROM element_schedules) UPDATE element_schedules '
          "SET priority_key = (SELECT printf('%020dV', rn) FROM ranked r "
          'WHERE r.element_id = element_schedules.element_id '
          'AND r.element_type = element_schedules.element_type)',
        );

        await _createIndexes(m);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite disables foreign keys per connection by default, so this
      // has to run on every open, not only at creation.
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );

  /// Adds [column] only when the table does not already have it.
  ///
  /// SQLite has no `ADD COLUMN IF NOT EXISTS`, and a migration that cannot be
  /// re-run is a migration that leaves the collection unopenable if it is
  /// interrupted part-way. Checking first makes each step idempotent.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, Object?> table,
    GeneratedColumn<Object> column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final bool present = rows.any(
      (QueryRow row) => row.read<String>('name') == column.name,
    );
    if (!present) await m.addColumn(table, column);
  }

  Future<void> _createIndexes(Migrator m) async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_blocks_source '
      'ON blocks (source_id, idx)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_extracts_parent '
      'ON extracts (parent_id, created_at_utc)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_extracts_source '
      'ON extracts (source_id)',
    );
    if (await _hasColumn('cards', 'parent_element_id')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_cards_parent '
        'ON cards (parent_element_id, parent_element_type)',
      );
    } else {
      if (await _hasColumn('cards', 'extract_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_cards_extract ON cards (extract_id)',
        );
      }
      if (await _hasColumn('cards', 'source_id')) {
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_cards_source ON cards (source_id)',
        );
      }
    }
    // The queue's hot path: eligible elements of a type, in priority order.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schedules_due '
      'ON element_schedules (lifecycle, element_type, due_day, priority_key)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schedules_priority '
      'ON element_schedules (priority_key)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_reviews_card '
      'ON review_events (card_id, reviewed_at_utc)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_operation '
      'ON review_events (operation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_card_memories_due '
      'ON card_memories (due_at_utc)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_operation '
      'ON activity_events (operation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_activity_at ON activity_events (at_utc)',
    );
    // "What happened to this element, in order" — the log's main query.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_revlog_element '
      'ON revlog_entries (element_id, element_type, at_utc)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_revlog_at ON revlog_entries (at_utc)',
    );
    // The optimizer's future training query: graded events only.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_revlog_type '
      'ON revlog_entries (event_type, at_utc)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_revlog_operation '
      'ON revlog_entries (operation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_schedules_root '
      'ON element_schedules (root_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_search_documents_source '
      'ON search_documents (source_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_element_identity '
      'ON element_schedules (element_id)',
    );
    if (await _hasTable('schedule_adjustments')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_adjustments_element '
        'ON schedule_adjustments (element_id, element_type, cleared_at_utc)',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_adjustments_active_exact '
        'ON schedule_adjustments (element_id, element_type) '
        'WHERE mode = 1 AND cleared_at_utc IS NULL',
      );
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_adjustments_operation_reason '
        'ON schedule_adjustments '
        '(operation_id, element_id, element_type, reason)',
      );
    }
    if (await _hasTable('scheduler_events')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_scheduler_events_element '
        'ON scheduler_events (element_id, element_type, occurred_at_utc)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_scheduler_events_operation '
        'ON scheduler_events (operation_id)',
      );
    }
  }

  Future<bool> _hasTable(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: <Variable<Object>>[Variable<String>(name)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((QueryRow row) => row.read<String>('name') == column);
  }

  /// Creates the FTS5 index and the triggers that keep it in step.
  ///
  /// External-content FTS5: the index stores no copy of the text, only the
  /// terms, and reads the columns back from `search_documents` by rowid. That
  /// makes the index disposable — [rebuildSearchIndex] restores it from the
  /// materialized rows — while the triggers keep it correct inside whatever
  /// transaction wrote the content, so a search can never see a half-applied
  /// import.
  Future<void> _createSearchIndex() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS $kSearchIndexTable USING fts5('
      'title, body, '
      "content='search_documents', content_rowid='rowid', "
      "tokenize='unicode61 remove_diacritics 2')",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS search_documents_ai '
      'AFTER INSERT ON search_documents BEGIN '
      'INSERT INTO $kSearchIndexTable(rowid, title, body) '
      'VALUES (new.rowid, new.title, new.body); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS search_documents_ad '
      'AFTER DELETE ON search_documents BEGIN '
      'INSERT INTO $kSearchIndexTable($kSearchIndexTable, rowid, title, body) '
      "VALUES ('delete', old.rowid, old.title, old.body); END",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS search_documents_au '
      'AFTER UPDATE ON search_documents BEGIN '
      'INSERT INTO $kSearchIndexTable($kSearchIndexTable, rowid, title, body) '
      "VALUES ('delete', old.rowid, old.title, old.body); "
      'INSERT INTO $kSearchIndexTable(rowid, title, body) '
      'VALUES (new.rowid, new.title, new.body); END',
    );
  }

  /// Rebuilds the full-text index from the materialized documents.
  ///
  /// Safe to run at any time: the index is derived, so this is a repair
  /// rather than a migration.
  Future<void> rebuildSearchIndex() async {
    await customStatement(
      "INSERT INTO $kSearchIndexTable($kSearchIndexTable) VALUES ('rebuild')",
    );
  }

  /// Whether the full-text index reports itself consistent with its content
  /// table. Checked by the diagnostics panel alongside the integrity check.
  Future<bool> searchIndexValid() async {
    try {
      await customStatement(
        'INSERT INTO $kSearchIndexTable($kSearchIndexTable) '
        "VALUES ('integrity-check')",
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Runs `PRAGMA integrity_check` and returns its result rows.
  ///
  /// Used before a backup is promoted and after a restore.
  Future<List<String>> integrityCheck() async {
    final rows = await customSelect('PRAGMA integrity_check').get();
    return rows.map((QueryRow r) => r.data.values.first.toString()).toList();
  }

  /// Whether the database reports no corruption.
  Future<bool> isHealthy() async {
    final result = await integrityCheck();
    return result.length == 1 && result.single == 'ok';
  }

  /// Whether every foreign key currently resolves.
  Future<bool> foreignKeysValid() async {
    final rows = await customSelect('PRAGMA foreign_key_check').get();
    return rows.isEmpty;
  }
}
