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
const int kSchemaVersion = 4;

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
            newColumns: [cardMemories.step],
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
