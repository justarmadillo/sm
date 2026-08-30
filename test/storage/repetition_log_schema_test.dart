/// The M4 schema: the repetition log, the A-factor columns, and the migration
/// that carries an M3 collection across without restarting anything.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';
import 'package:incremental_reader/storage/drift/drift_learning_repository.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_m4_schema_');
  });

  tearDown(() {
    try {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    } on FileSystemException {
      // The OS reclaims it; a locked file must not fail the suite.
    }
  });

  Future<AppDatabase> openFileDatabase() async {
    final AppDatabase db = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await db.customSelect('SELECT 1').getSingle();
    return db;
  }

  /// One source with a schedule and pacing row, as M3 would have left it.
  Future<void> seedM3Collection(
    AppDatabase db, {
    bool withM4Columns = false,
  }) async {
    await _addLegacyCardParentColumns(db);
    await db.customStatement(
      'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
      'imported_at_utc, revision) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>['s1', 'Chapter', '# Chapter', 'a' * 64, 12, 1000, 1],
    );
    await db.customStatement(
      'INSERT INTO extracts (id, markdown, source_id, parent_id, '
      'parent_is_source, start_utf8, end_utf8, selected_text_hash, '
      'created_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>['x1', 'passage', 's1', 's1', 1, 0, 7, 'b' * 64, 1000],
    );
    await db.customStatement(
      'INSERT INTO cards (id, extract_id, type, front, back, created_at_utc) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      <Object?>['c1', 'x1', 0, 'Q?', 'A.', 1000],
    );
    for (final (String id, int type) in <(String, int)>[
      ('s1', 0),
      ('x1', 1),
      ('c1', 2),
    ]) {
      await db.customStatement(
        'INSERT INTO element_schedules (element_id, element_type, '
        'priority_key, lifecycle, due_day, original_due_day, zone_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[id, type, 'V', 0, 20000, 20000, 'UTC'],
      );
    }
    // Recreate the retired topic row explicitly. The current application no
    // longer exposes these columns at runtime; they exist here only as an
    // on-disk fixture for the one-time upgrade path.
    await db.customStatement('DROP TABLE topic_states');
    await db.customStatement(
      withM4Columns
          ? '''
        CREATE TABLE topic_states (
          element_id TEXT NOT NULL,
          element_type INTEGER NOT NULL CHECK (element_type BETWEEN 0 AND 1),
          profile_id TEXT NOT NULL,
          step_index INTEGER NOT NULL CHECK (step_index >= 0),
          interval_days REAL NOT NULL DEFAULT 0 CHECK (interval_days >= 0),
          a_factor REAL NOT NULL DEFAULT 0 CHECK (a_factor >= 0),
          yield_ewma REAL NOT NULL DEFAULT 0 CHECK (yield_ewma >= 0),
          encounters INTEGER NOT NULL DEFAULT 0 CHECK (encounters >= 0),
          postpone_count INTEGER NOT NULL DEFAULT 0 CHECK (postpone_count >= 0),
          encounters_since_last_card INTEGER NOT NULL DEFAULT 0
            CHECK (encounters_since_last_card >= 0),
          last_encounter_day INTEGER NULL,
          PRIMARY KEY (element_id, element_type)
        )
      '''
          : '''
        CREATE TABLE topic_states (
          element_id TEXT NOT NULL,
          element_type INTEGER NOT NULL CHECK (element_type BETWEEN 0 AND 1),
          profile_id TEXT NOT NULL,
          step_index INTEGER NOT NULL CHECK (step_index >= 0),
          PRIMARY KEY (element_id, element_type)
        )
      ''',
    );

    // A half-read article, four steps into the normal sequence.
    await db.customStatement(
      'INSERT INTO topic_states (element_id, element_type, profile_id, '
      'step_index) VALUES (?, ?, ?, ?)',
      <Object?>['s1', 0, 'normal', 4],
    );
    await db.customStatement(
      'INSERT INTO topic_states (element_id, element_type, profile_id, '
      'step_index) VALUES (?, ?, ?, ?)',
      <Object?>['x1', 1, 'extract', 2],
    );
  }

  group('the repetition log', () {
    test('accepts a grade only on a graded event', () async {
      final AppDatabase db = await openFileDatabase();
      addTearDown(db.close);

      Future<void> insert(int eventType, int? grade) => db.customStatement(
        'INSERT INTO revlog_entries (id, operation_id, element_id, '
        'element_type, event_type, at_utc, grade) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['r$eventType$grade', 'op', 'e1', 2, eventType, 1000, grade],
      );

      await insert(ReviewLogEventType.review.value, 3);
      await insert(ReviewLogEventType.practice.value, 1);
      await insert(ReviewLogEventType.postpone.value, null);

      await expectLater(
        insert(ReviewLogEventType.postpone.value, 3),
        throwsA(isA<Object>()),
        reason:
            'a grade on a postpone would poison an optimizer’s training '
            'set, so SQL refuses it as well as Dart',
      );
    });

    test('round-trips a full entry through the mappers', () async {
      final AppDatabase db = await openFileDatabase();
      addTearDown(db.close);
      final DriftLearningRepository learning = DriftLearningRepository(db);

      const ElementRef ref = ElementRef(id: 'c1', type: ElementType.card);
      final ReviewLogEntry entry = ReviewLogEntry(
        id: 'r1',
        operationId: 'op-1',
        ref: ref,
        eventType: ReviewLogEventType.review,
        atUtc: DateTime.utc(2026, 3, 5, 10),
        grade: 3,
        elapsedDays: 12.5,
        scheduledDays: 10,
        durationMs: 2400,
        postponeCount: 2,
        schedulerVersion: 'v',
        parametersVersion: 'p',
        before: ReviewLogSnapshot(
          dueAtUtc: DateTime.utc(2026, 3, 1),
          stability: 9.5,
          difficulty: 5.25,
          learningState: 2,
          repetitionCount: 3,
          lapses: 1,
          priorityKey: 'M',
          pressure: 0.25,
          lifecycle: 0,
        ),
        after: ReviewLogSnapshot(
          dueAtUtc: DateTime.utc(2026, 3, 20),
          stability: 18.75,
          difficulty: 5.1,
          learningState: 2,
          priorityKey: 'M',
          pressure: 0.25,
          lifecycle: 0,
        ),
        metadata: const <String, Object?>{'a_factor': 2.1},
      );

      await learning.appendReviewLog(entry);
      final ReviewLogEntry restored = (await learning.listReviewLogForElement(
        ref,
      )).single;

      expect(restored.id, entry.id);
      expect(restored.operationId, entry.operationId);
      expect(restored.eventType, entry.eventType);
      expect(restored.atUtc, entry.atUtc);
      expect(restored.grade, 3);
      expect(restored.elapsedDays, 12.5);
      expect(restored.scheduledDays, 10);
      expect(restored.durationMs, 2400);
      expect(restored.postponeCount, 2);
      expect(restored.before, entry.before);
      expect(restored.after, entry.after);
      expect(restored.metadata, entry.metadata);
      expect(restored.feedsOptimizer, isTrue);
    });

    test(
      'separates what an optimizer may train on from what it may not',
      () async {
        final AppDatabase db = await openFileDatabase();
        addTearDown(db.close);
        final DriftLearningRepository learning = DriftLearningRepository(db);

        const ElementRef ref = ElementRef(id: 'c1', type: ElementType.card);
        var counter = 0;
        Future<void> log(ReviewLogEventType type, {int? grade}) =>
            learning.appendReviewLog(
              ReviewLogEntry(
                id: 'r${counter++}',
                operationId: 'op-$counter',
                ref: ref,
                eventType: type,
                atUtc: DateTime.utc(2026, 3, 5, 10),
                grade: grade,
              ),
            );

        await log(ReviewLogEventType.review, grade: 3);
        await log(ReviewLogEventType.practice, grade: 4);
        await log(ReviewLogEventType.postpone);
        await log(ReviewLogEventType.autoPostpone);
        await log(ReviewLogEventType.bury);

        final List<ReviewLogEntry> all = await learning.listReviewLogForElement(
          ref,
        );
        expect(all, hasLength(5));
        expect(all.where((ReviewLogEntry e) => e.feedsOptimizer), hasLength(1));
        expect(
          all.where((ReviewLogEntry e) => e.eventType.isDeferral),
          hasLength(3),
        );
      },
    );

    test('is queryable by day for the diagnostics panel', () async {
      final AppDatabase db = await openFileDatabase();
      addTearDown(db.close);
      final DriftLearningRepository learning = DriftLearningRepository(db);

      const ElementRef ref = ElementRef(id: 'c1', type: ElementType.card);
      final DateTime day = DateTime.utc(2026, 3, 5, 10);
      for (var i = 0; i < 3; i++) {
        await learning.appendReviewLog(
          ReviewLogEntry(
            id: 'r$i',
            operationId: 'op-$i',
            ref: ref,
            eventType: ReviewLogEventType.autoPostpone,
            atUtc: day,
          ),
        );
      }

      final counts = await learning.countReviewLogEventsOn(
        studyDayFromEpochDay(day.millisecondsSinceEpoch ~/ 86400000, 'UTC'),
      );
      expect(counts[ReviewLogEventType.autoPostpone], 3);
    });
  });

  group('the version-4 migration', () {
    test('carries an M3 collection to the A-factor model without restarting '
        'anything', () async {
      final File file = File('${workspace.path}/db/$kDatabaseFileName');
      final AppDatabase old = await openFileDatabase();
      await seedM3Collection(old);
      // Strip the M4 columns so the database really looks like version 4.
      // The index over root_id has to go first: SQLite refuses to drop a
      // column an index still references.
      await old.customStatement('DROP INDEX IF EXISTS idx_schedules_root');
      for (final (String table, String column) in <(String, String)>[
        ('element_schedules', 'root_id'),
        ('card_memories', 'postpone_count'),
      ]) {
        await old.customStatement('ALTER TABLE $table DROP COLUMN $column');
      }
      await old.customStatement('DROP TABLE IF EXISTS revlog_entries');
      await old.customStatement('DROP TABLE IF EXISTS search_documents');
      await old.customStatement('DROP TABLE IF EXISTS $kSearchIndexTable');
      await old.customStatement('PRAGMA user_version = 4');
      await old.close();

      final AppDatabase migrated = openDatabaseAt(file);
      addTearDown(migrated.close);
      await migrated.customSelect('SELECT 1').get();

      final version = await migrated
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.first, kSchemaVersion);

      // The half-read article keeps its place when the intermediate M4 state
      // is converted into the sole SM20 row.
      final source = await migrated
          .customSelect(
            'SELECT status, repetition_count, stored_interval, a_factor_raw '
            'FROM topic_states '
            "WHERE element_id = 's1'",
          )
          .getSingle();
      expect(source.read<int>('status'), 1);
      expect(source.read<int>('repetition_count'), 4);
      expect(source.read<int>('stored_interval'), 30);
      expect(real48FromHex(source.read<String>('a_factor_raw')).value, 2.0);

      final extract = await migrated
          .customSelect(
            'SELECT repetition_count, stored_interval FROM topic_states '
            "WHERE element_id = 'x1'",
          )
          .getSingle();
      expect(extract.read<int>('repetition_count'), 2);
      expect(extract.read<int>('stored_interval'), 7);
    });

    test('gives every element its root article', () async {
      final File file = File('${workspace.path}/db/$kDatabaseFileName');
      final AppDatabase old = await openFileDatabase();
      await seedM3Collection(old);
      await old.customStatement('DROP INDEX IF EXISTS idx_schedules_root');
      await old.customStatement(
        'ALTER TABLE element_schedules DROP COLUMN root_id',
      );
      await old.customStatement('PRAGMA user_version = 4');
      await old.close();

      final AppDatabase migrated = openDatabaseAt(file);
      addTearDown(migrated.close);
      await migrated.customSelect('SELECT 1').get();

      final rows = await migrated
          .customSelect('SELECT element_id, root_id FROM element_schedules')
          .get();
      expect(rows, hasLength(3));
      for (final QueryRow row in rows) {
        expect(
          row.read<String?>('root_id'),
          's1',
          reason: '${row.read<String>('element_id')} should reach its article',
        );
      }
    });

    test('is re-runnable, so an interrupted upgrade is not fatal', () async {
      final File file = File('${workspace.path}/db/$kDatabaseFileName');
      final AppDatabase db = await openFileDatabase();
      await seedM3Collection(db, withM4Columns: true);
      // Every M4 column is already present; claiming version 4 makes the
      // migration run again over a database that is really at version 5.
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();

      final AppDatabase migrated = openDatabaseAt(file);
      addTearDown(migrated.close);
      await expectLater(migrated.customSelect('SELECT 1').get(), completes);

      final version = await migrated
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.first, kSchemaVersion);
    });
  });
}

/// Restores the retired `extract_id`/`source_id` pair so a suite can seed the
/// pre-v6 shape these migrations were written against. The v6 step rebuilds
/// the table and drops them again, which is exactly what is under test.
Future<void> _addLegacyCardParentColumns(AppDatabase database) async {
  for (final String column in <String>['extract_id', 'source_id']) {
    final List<QueryRow> info = await database
        .customSelect('PRAGMA table_info(cards)')
        .get();
    final bool present = info.any(
      (QueryRow row) => row.read<String>('name') == column,
    );
    if (!present) {
      await database.customStatement(
        'ALTER TABLE cards ADD COLUMN $column TEXT NULL',
      );
    }
  }
  // The indexes the old schema carried over those columns. A rebuild replays
  // every index attached to the table, so leaving them out of the fixture
  // hides the exact failure that upgrading a real collection produces.
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_cards_extract ON cards (extract_id)',
  );
  await database.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_cards_source ON cards (source_id)',
  );
}
