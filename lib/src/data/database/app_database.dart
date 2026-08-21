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
const int kSchemaVersion = 5;

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
        await m.alterTable(TableMigration(cards));
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
            newColumns: [cardMemories.step, cardMemories.postponeCount],
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
        await m.alterTable(
          TableMigration(
            cards,
            newColumns: <GeneratedColumn<Object>>[cards.sourceId],
          ),
        );
        await _createIndexes(m);
      }
      if (from < 5) {
        // M4: the A-factor topic model, the universal repetition log, and
        // full-text search.
        await m.createTable(revlogEntries);
        await m.createTable(searchDocuments);
        await _addColumnIfMissing(m, elementSchedules, elementSchedules.rootId);
        for (final GeneratedColumn<Object> column
            in <GeneratedColumn<Object>>[
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
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cards_extract ON cards (extract_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cards_source ON cards (source_id)',
    );
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
