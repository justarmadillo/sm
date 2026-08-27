/// The application database: connection policy, schema version, migrations.
///
/// Two rules the rest of the app relies on and cannot check for itself:
/// foreign keys are enabled on *every* connection (SQLite defaults them off,
/// per connection, silently), and the live database is journalled in WAL mode
/// and never placed in a synced folder.
library;

import 'package:drift/drift.dart';

import '../../core/utf8_offsets.dart';
import '../../domain/content/document.dart';
import '../../domain/content/reader_anchor.dart';
import '../../domain/scheduling/sm20_numeric.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// Current schema version. Bump with every migration step added below.
const int kSchemaVersion = 12;

/// Name of the external-content FTS5 index over [SearchDocuments].
const String kSearchIndexTable = 'search_index';

@DriftDatabase(
  tables: <Type>[
    Sources,
    SourceEdits,
    Blocks,
    Extracts,
    Cards,
    ElementSchedules,
    TopicStates,
    CardMemories,
    ReviewEvents,
    RevlogEntries,
    SchedulerEvents,
    MercyBatches,
    SearchDocuments,
    ActivityEvents,
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
        final bool hasLegacyTopicShape = await _hasColumn(
          'topic_states',
          'profile_id',
        );
        if (hasLegacyTopicShape) {
          // These are historical v5 columns. They are intentionally not part
          // of the current Drift table shape, but old collections still have
          // to be advanced through v5 before the v8 rebuild can convert them.
          await _addRawColumnIfMissing(
            'topic_states',
            'interval_days',
            'REAL NOT NULL DEFAULT 0 CHECK (interval_days >= 0)',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'a_factor',
            'REAL NOT NULL DEFAULT 0 CHECK (a_factor >= 0)',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'yield_ewma',
            'REAL NOT NULL DEFAULT 0 CHECK (yield_ewma >= 0)',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'encounters',
            'INTEGER NOT NULL DEFAULT 0 CHECK (encounters >= 0)',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'postpone_count',
            'INTEGER NOT NULL DEFAULT 0 CHECK (postpone_count >= 0)',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'encounters_since_last_card',
            'INTEGER NOT NULL DEFAULT 0 '
                'CHECK (encounters_since_last_card >= 0)',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'last_encounter_day',
            'INTEGER NULL',
          );
        }
        await _addColumnIfMissing(m, cardMemories, cardMemories.postponeCount);

        // Existing topics were paced by an interval sequence and carry only a
        // step index. Seed the A-factor model from where each one actually
        // stands, so switching pacing mode continues a half-read article
        // instead of restarting it. The sequences below are the shipped
        // defaults; a topic on an edited profile lands on the closest of them,
        // which is a one-time approximation of an interval, not of progress.
        if (hasLegacyTopicShape) {
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
        }

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
        // A card's article is reached through whichever parentage the file on
        // disk actually has. A collection upgraded step by step still has the
        // v3 pair of columns here; one restored from a later build, or opened
        // by a build that already ran the v6 rebuild, has the single typed
        // parent instead. Naming a column that is not there aborts the whole
        // upgrade, so ask first.
        if (await _hasColumn('cards', 'extract_id')) {
          await customStatement(
            'UPDATE element_schedules SET root_id = ('
            'SELECT COALESCE(c.source_id, ('
            'SELECT e.source_id FROM extracts e WHERE e.id = c.extract_id)) '
            'FROM cards c WHERE c.id = element_id) '
            'WHERE element_type = 2',
          );
        } else {
          await customStatement(
            'UPDATE element_schedules SET root_id = ('
            'SELECT CASE c.parent_element_type '
            'WHEN 0 THEN c.parent_element_id '
            'WHEN 1 THEN (SELECT e.source_id FROM extracts e '
            'WHERE e.id = c.parent_element_id) END '
            'FROM cards c WHERE c.id = element_id) '
            'WHERE element_type = 2',
          );
        }

        await _createIndexes(m);
        await _createSearchIndex();
      }
      if (from < 6) {
        // Scheduler contract migration: add typed/versioned scheduling state
        // without deleting legacy schedule or history columns.
        // Drop the indexes that name the columns this step retires. Drift's
        // table rebuild replays every index it finds attached to the old
        // table, so an index over `extract_id` would be recreated against the
        // new shape and abort the whole upgrade. `_createIndexes` puts the
        // replacement (`idx_cards_parent`) back at the end of the block.
        await customStatement('DROP INDEX IF EXISTS idx_cards_extract');
        await customStatement('DROP INDEX IF EXISTS idx_cards_source');

        // Re-runnable: an interrupted upgrade, or a file that already carries
        // the typed parent, must not try to read the retired pair again.
        if (await _hasColumn('cards', 'extract_id')) {
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
        }
        // History and canonical memory must outlive content-level cleanup.
        // Both tables were created with CASCADE before the contract, which
        // meant deleting a card silently erased the evidence of every review
        // it had ever had. Rebuild them with the RESTRICT the current schema
        // declares, so an upgraded collection has the same integrity as a
        // fresh one.
        await m.alterTable(TableMigration(reviewEvents));

        for (final GeneratedColumn<Object> column in <GeneratedColumn<Object>>[
          elementSchedules.parentElementId,
          elementSchedules.ordinal,
          elementSchedules.createdAtUtc,
          elementSchedules.updatedAtUtc,
          elementSchedules.revision,
          elementSchedules.legacyDueProvenance,
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

        final bool hasPreSm20TopicShape = !await _hasColumn(
          'topic_states',
          'status',
        );
        if (hasPreSm20TopicShape) {
          // Historical v6 topic provenance. As with the v5 fields above,
          // these exist only long enough for a pre-v8 database to complete
          // its ordered migrations and are removed by the SM20 rebuild.
          await _addRawColumnIfMissing(
            'topic_states',
            'algorithm_due_day',
            'INTEGER NULL',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'scheduler_kind',
            "TEXT NOT NULL DEFAULT 'topic_afactor_v1'",
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'scheduler_version',
            "TEXT NOT NULL DEFAULT 'topic_afactor_v1/1'",
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'policy_input_snapshot',
            'TEXT NULL',
          );
          await _addRawColumnIfMissing(
            'topic_states',
            'revision',
            'INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1)',
          );
        }

        // Rebuilt after the new columns exist, or the copy would name a
        // column the old table does not have yet.
        await m.alterTable(TableMigration(cardMemories));

        await m.createTable(schedulerEvents);
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
        if (hasPreSm20TopicShape) {
          await customStatement(
            "UPDATE topic_states SET scheduler_kind = 'legacy_sequence', "
            "scheduler_version = 'legacy_sequence/1', "
            'algorithm_due_day = (SELECT due_day FROM element_schedules e '
            'WHERE e.element_id = topic_states.element_id '
            'AND e.element_type = topic_states.element_type), revision = 1',
          );
        }

        // Where a legacy row's visible due date contradicts the original due
        // it claims to have come from, the provenance is unknowable: some
        // earlier build overwrote the canonical date to implement a
        // postponement. Keep the date the user can see, and mark it as
        // unknown rather than presenting a fabricated history as fact.
        // The deferral columns are gone from the current schema, so an old
        // file may or may not still have them at this point in the chain.
        final bool hadDeferral = await _hasColumn(
          'element_schedules',
          'deferred_until',
        );
        await customStatement(
          'UPDATE element_schedules SET legacy_due_provenance = 1 '
          'WHERE element_type IN (0, 1) AND due_day <> original_due_day'
          '${hadDeferral ? ' AND deferred_until IS NULL' : ''}',
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

      if (from < 7) {
        // The typed-adjustment scheduler is retired. Do not translate its
        // predecessor into another compatibility representation: clear the
        // old coordinates before SM20 becomes the sole scheduling policy.
        if (await _hasColumn('element_schedules', 'deferred_until')) {
          await customStatement(
            'UPDATE element_schedules SET deferred_until = NULL, '
            'deferral_kind = 0 WHERE deferred_until IS NOT NULL',
          );
        }
        if (await _hasColumn('card_memories', 'deferred_until_utc')) {
          await customStatement(
            'UPDATE card_memories SET deferred_until_utc = NULL '
            'WHERE deferred_until_utc IS NOT NULL',
          );
        }

        // Mercy undo restores from a stored snapshot rather than recomputing,
        // so the column has to exist before the first batch can be applied.
        await _addColumnIfMissing(
          m,
          mercyBatches,
          mercyBatches.appliedSnapshotJson,
        );

        await _createIndexes(m);
      }

      if (from < 8) {
        // Replace the retired sequence/A-factor topic row with the sole SM20
        // record. This is a one-time data conversion, not a runtime legacy
        // scheduler: after this rebuild no old scheduler discriminator or
        // policy column remains in the live schema.
        await _migrateTopicStatesToSm20(m);
        // These tables belonged to the superseded scheduler and are not part
        // of the SM20 schema. A database upgraded from v6/v7 must not retain
        // them merely because SQLite otherwise leaves unmentioned tables in
        // place.
        await customStatement('DROP TABLE IF EXISTS schedule_adjustments');
        await customStatement('DROP TABLE IF EXISTS daily_presentation_plans');
        await _createIndexes(m);
      }

      if (from < 9) {
        // Retire the deferral overlay and the two dead lifecycle states in
        // one step, because they are one decision: SM20 expresses a
        // postponement as a low-level reschedule of the canonical due date,
        // and it knows only pending, memorized, dismissed, and deleted.
        //
        // The renumbering has to run before the rebuild. A table rebuild
        // installs the *current* definition, whose lifecycle CHECK is
        // 0..2, so copying rows that still carry the old 0..4 numbering
        // would abort the whole upgrade.
        //
        // A suspended element becomes dismissed rather than active on
        // purpose: it was taken out of the queue deliberately, and silently
        // returning that work would repeat the mistake v7 avoided when it
        // refused to drop stored deferrals.
        await customStatement(
          'UPDATE element_schedules SET lifecycle = CASE lifecycle '
          'WHEN 0 THEN 0 WHEN 4 THEN 2 ELSE 1 END',
        );
        // v7 already cleared the deferral values; this drops the columns.
        // They need a rebuild rather than DROP COLUMN because the retired
        // CHECK constraint named both of them.
        await m.alterTable(TableMigration(elementSchedules));
        await m.alterTable(TableMigration(cardMemories));
        await _createIndexes(m);
      }
      if (from < 10) {
        // Drop the reading-pace column. Pace selected one of three fixed
        // interval ladders, which is a scheduler this app no longer has: SM20
        // derives every topic interval from A and the section 5.2 formula, so
        // the value could not influence anything and keeping it would only
        // invite a future reader to wire it back up.
        await m.alterTable(TableMigration(sources));
        await _createIndexes(m);
      }
      if (from < 11) {
        // Drop the folder layer. The tree the app shows is the content's own
        // provenance — an extract under the text it was cut from — and the
        // folder table was never written by anything: no command created a
        // folder and no query read one. Schema that only looks like a feature
        // is worse than none, because the next reader assumes it works.
        await customStatement('DROP TABLE IF EXISTS folders');
        await m.alterTable(TableMigration(sources));
        await _createIndexes(m);
      }
      if (from < 12) {
        // Reader positions stop naming a block and start naming a place.
        //
        // Block ids are positional (`sourceId:index`), so they were only ever
        // stable while the text was. The moment a source becomes editable,
        // inserting one paragraph re-points every anchor below it at its
        // neighbour's text — with no error and no way for the user to tell.
        // Document byte offsets survive re-parsing, and an edit moves them by
        // an amount the edit itself reports.
        //
        // See plans/reader/EDITABLE_READER.md sections 2, 4, and 9.6.
        await _migrateAnchorsToDocumentSpace(m);
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

  /// Adds a column used only by an intermediate historical migration.
  ///
  /// Current Drift tables deliberately omit retired scheduler fields, so an
  /// old file must be stepped through their raw SQL shape before v8 can read
  /// and convert those values.
  Future<void> _addRawColumnIfMissing(
    String table,
    String column,
    String declaration,
  ) async {
    if (!await _hasColumn(table, column)) {
      await customStatement(
        'ALTER TABLE $table ADD COLUMN $column $declaration',
      );
    }
  }

  Future<void> _migrateTopicStatesToSm20(Migrator m) async {
    if (!await _hasTable('topic_states')) {
      await m.createTable(topicStates);
      return;
    }
    if (await _hasColumn('topic_states', 'status')) return;

    final List<QueryRow> rows = await customSelect(
      'SELECT t.element_id, t.element_type, t.interval_days, t.a_factor, '
      't.encounters, t.postpone_count, t.encounters_since_last_card, '
      't.last_encounter_day, t.revision, e.lifecycle '
      'FROM topic_states t LEFT JOIN element_schedules e '
      'ON e.element_id = t.element_id AND e.element_type = t.element_type '
      'ORDER BY t.element_id, t.element_type',
    ).get();

    await customStatement(
      'ALTER TABLE topic_states RENAME TO topic_states_v7_legacy',
    );
    await m.createTable(topicStates);

    for (final QueryRow row in rows) {
      final int lifecycle = row.read<int?>('lifecycle') ?? 0;
      final int oldEncounters = row.read<int>('encounters');
      final int repetitions = oldEncounters.clamp(0, 65535);
      // Pre-v9 lifecycle indices: active 0, suspended 1, dismissed 2,
      // finished 3, deleted 4. v9 renumbers them; this step runs first and
      // must keep reading the old numbering.
      final int status = switch (lifecycle) {
        4 => 3, // deleted
        1 || 2 || 3 => 2, // suspended, dismissed, or finished
        _ => repetitions == 0 ? 0 : 1, // pending or memorized
      };

      final double legacyInterval = row.read<double>('interval_days');
      final int storedInterval = repetitions == 0 || !legacyInterval.isFinite
          ? 0
          : sm20RoundEven(legacyInterval).clamp(0, 44530);
      final double legacyA = row.read<double>('a_factor');
      final double convertedA = !legacyA.isFinite || legacyA <= 0
          ? 1.2
          : legacyA.clamp(1.01, 6.0);
      final int postponements = row
          .read<int>('postpone_count')
          .clamp(0, 0x7fffffff);
      final int encountersSinceLastCard = row
          .read<int>('encounters_since_last_card')
          .clamp(0, 0x7fffffff);
      final int revision = row.read<int>('revision').clamp(1, 0x7fffffff);

      await customStatement(
        'INSERT INTO topic_states ('
        'element_id, element_type, status, repetition_count, lapse_count, '
        'stored_interval, last_review_day, a_factor_raw, '
        'last_interval_ratio_raw, history_block_id, '
        'recent_postponement_count, total_postponement_count, '
        'learning_control, encounters_since_last_card, revision) '
        'VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?, 0, ?, ?, 0, ?, ?)',
        <Object?>[
          row.read<String>('element_id'),
          row.read<int>('element_type'),
          status,
          repetitions,
          storedInterval,
          row.read<int?>('last_encounter_day'),
          DelphiReal48.fromDouble(convertedA).toString(),
          DelphiReal48.fromDouble(0).toString(),
          postponements,
          postponements,
          encountersSinceLastCard,
          revision,
        ],
      );
    }

    await customStatement('DROP TABLE topic_states_v7_legacy');
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

  /// Converts every stored `(blockId, offsetInBlock)` pair into a document
  /// byte offset, and records how much of each extract's provenance survived.
  ///
  /// Nothing is guessed. An anchor whose block no longer exists — a row left
  /// by an interrupted import, or one written before a parser change — becomes
  /// an explicit orphan rather than a plausible-looking position. That follows
  /// the precedent set when v6 refused to invent a due date for a legacy row
  /// it could not interpret: an invented value is worse than an absent one,
  /// because the user cannot tell it is wrong.
  Future<void> _migrateAnchorsToDocumentSpace(Migrator m) async {
    if (!await _hasTable('sources')) return;

    await _addRawColumnIfMissing(
      'sources',
      'content_revision',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addRawColumnIfMissing('sources', 'marker_utf8', 'INTEGER NULL');
    await _addRawColumnIfMissing('sources', 'marker_revision', 'INTEGER NULL');
    await _addRawColumnIfMissing('sources', 'soft_utf8', 'INTEGER NULL');
    await _addRawColumnIfMissing('sources', 'soft_revision', 'INTEGER NULL');
    await _addRawColumnIfMissing('extracts', 'start_utf8', 'INTEGER NULL');
    await _addRawColumnIfMissing('extracts', 'end_utf8', 'INTEGER NULL');
    await _addRawColumnIfMissing(
      'extracts',
      'anchor_revision',
      'INTEGER NOT NULL DEFAULT 1',
    );
    await _addRawColumnIfMissing(
      'extracts',
      'provenance_state',
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addRawColumnIfMissing(
      'extracts',
      'content_revision',
      'INTEGER NOT NULL DEFAULT 1',
    );

    // The old columns are the signal that this file still needs converting.
    // Their absence means an earlier run of this step already finished.
    if (await _hasColumn('sources', 'marker_block_id')) {
      await _convertSourceMarkers();
    }
    if (await _hasColumn('extracts', 'start_block_id')) {
      await _convertExtractProvenance();
    }

    // A row whose anchors could not be resolved still has to satisfy the new
    // NOT NULL definition before the table is rebuilt around it.
    await customStatement(
      'UPDATE extracts SET start_utf8 = COALESCE(start_utf8, 0), '
      'end_utf8 = COALESCE(end_utf8, 0)',
    );

    if (!await _hasTable('source_edits')) await m.createTable(sourceEdits);

    // Rebuilds install the current definitions: the retired block columns
    // disappear and the new CHECK constraints take effect. Both tables need a
    // rebuild rather than DROP COLUMN because the retired constraints named
    // the retired columns.
    await m.alterTable(TableMigration(sources));
    await m.alterTable(TableMigration(extracts));
  }

  /// Rewrites both reading positions of every source as document offsets.
  Future<void> _convertSourceMarkers() async {
    final Map<String, int> blockStarts = await _blockStartOffsets();
    final List<QueryRow> rows = await customSelect(
      'SELECT id, marker_block_id, marker_offset, soft_block_id, soft_offset '
      'FROM sources',
    ).get();

    for (final QueryRow row in rows) {
      final int? marker = _documentOffset(
        blockStarts,
        row.read<String?>('marker_block_id'),
        row.read<int?>('marker_offset'),
      );
      final int? soft = _documentOffset(
        blockStarts,
        row.read<String?>('soft_block_id'),
        row.read<int?>('soft_offset'),
      );
      await customStatement(
        'UPDATE sources SET marker_utf8 = ?, marker_revision = ?, '
        'soft_utf8 = ?, soft_revision = ? WHERE id = ?',
        <Object?>[
          marker,
          marker == null ? null : kInitialContentRevision,
          soft,
          soft == null ? null : kInitialContentRevision,
          row.read<String>('id'),
        ],
      );
    }
  }

  /// Rewrites every extract's recorded range, and grades what survived.
  Future<void> _convertExtractProvenance() async {
    final Map<String, int> sourceBlockStarts = await _blockStartOffsets();
    final Map<String, String> parentText = <String, String>{};
    final Map<String, Map<String, int>> extractBlockStarts =
        <String, Map<String, int>>{};

    for (final QueryRow row in await customSelect(
      'SELECT id, markdown FROM sources',
    ).get()) {
      parentText[row.read<String>('id')] = row.read<String>('markdown');
    }
    final List<QueryRow> extracts = await customSelect(
      'SELECT id, markdown, parent_id, parent_is_source, start_block_id, '
      'start_offset, end_block_id, end_offset, selected_text_hash '
      'FROM extracts',
    ).get();
    for (final QueryRow row in extracts) {
      parentText[row.read<String>('id')] = row.read<String>('markdown');
    }

    for (final QueryRow row in extracts) {
      final String parentId = row.read<String>('parent_id');
      final bool parentIsSource = row.read<int>('parent_is_source') != 0;

      final Map<String, int> starts;
      if (parentIsSource) {
        starts = sourceBlockStarts;
      } else {
        // Extracts never had persisted blocks: their anchors addressed a
        // document parsed on demand from the extract's own markdown, so the
        // same parse has to be repeated here to read the old coordinates.
        starts = extractBlockStarts.putIfAbsent(parentId, () {
          final String text = parentText[parentId] ?? '';
          final Document parsed = Document.parse(
            sourceId: parentId,
            markdown: text,
          );
          return <String, int>{
            for (final block in parsed.blocks) block.id: block.sourceStartUtf8,
          };
        });
      }

      final int? start = _documentOffset(
        starts,
        row.read<String?>('start_block_id'),
        row.read<int?>('start_offset'),
      );
      final int? end = _documentOffset(
        starts,
        row.read<String?>('end_block_id'),
        row.read<int?>('end_offset'),
      );

      // 0 verbatim, 1 stale, 2 orphaned.
      var state = 2;
      var startUtf8 = 0;
      var endUtf8 = 0;
      if (start != null && end != null && end >= start) {
        startUtf8 = start;
        endUtf8 = end;
        final String text = parentText[parentId] ?? '';
        final String slice = _sliceByUtf8(text, start, end);
        state = hashSelection(slice) == row.read<String>('selected_text_hash')
            ? 0
            : 1;
      }

      await customStatement(
        'UPDATE extracts SET start_utf8 = ?, end_utf8 = ?, '
        'anchor_revision = ?, provenance_state = ?, content_revision = ? '
        'WHERE id = ?',
        <Object?>[
          startUtf8,
          endUtf8,
          kInitialContentRevision,
          state,
          kInitialContentRevision,
          row.read<String>('id'),
        ],
      );
    }
  }

  Future<Map<String, int>> _blockStartOffsets() async {
    if (!await _hasTable('blocks')) return <String, int>{};
    final List<QueryRow> rows = await customSelect(
      'SELECT id, start_utf8 FROM blocks',
    ).get();
    return <String, int>{
      for (final QueryRow row in rows)
        row.read<String>('id'): row.read<int>('start_utf8'),
    };
  }

  static int? _documentOffset(
    Map<String, int> blockStarts,
    String? blockId,
    int? offset,
  ) {
    if (blockId == null || offset == null) return null;
    final int? start = blockStarts[blockId];
    if (start == null) return null;
    return start + offset;
  }

  static String _sliceByUtf8(String text, int startUtf8, int endUtf8) {
    if (endUtf8 <= startUtf8) return '';
    final Utf8OffsetIndex index = Utf8OffsetIndex(text);
    final int from = index.toUtf16(startUtf8.clamp(0, index.byteLength));
    final int to = index.toUtf16(endUtf8.clamp(0, index.byteLength));
    if (to <= from) return '';
    return text.substring(from, to);
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
