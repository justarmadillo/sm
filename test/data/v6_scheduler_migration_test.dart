/// Scheduler-contract schema and v5-to-v6 migration coverage.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  late Directory workspace;
  late File databaseFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_v6_scheduler_');
    databaseFile = File('${workspace.path}/db/$kDatabaseFileName');
  });

  tearDown(() {
    try {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can briefly retain SQLite's WAL handles after close.
    }
  });

  Future<AppDatabase> open() async {
    final AppDatabase database = openDatabaseAt(databaseFile);
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  group('fresh v6 scheduler schema', () {
    test('review history restricts parent deletion', () async {
      final AppDatabase database = await open();
      addTearDown(database.close);

      await database.customStatement(
        'INSERT INTO cards (id, parent_element_id, parent_element_type, kind, '
        'front, back, created_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['card', null, null, 0, 'q', 'a', 1000],
      );
      await _insertReview(database, id: 'review', cardId: 'card');

      final List<QueryRow> foreignKeys = await database
          .customSelect("PRAGMA foreign_key_list('review_events')")
          .get();
      final QueryRow cardForeignKey = foreignKeys.singleWhere(
        (QueryRow row) => row.read<String>('from') == 'card_id',
      );
      expect(cardForeignKey.read<String>('on_delete'), 'RESTRICT');

      await expectLater(
        database.customStatement("DELETE FROM cards WHERE id = 'card'"),
        throwsA(isA<Object>()),
      );
      expect(
        await database.customSelect('SELECT * FROM review_events').get(),
        hasLength(1),
        reason: 'content cleanup must not cascade-delete scheduler history',
      );
    });

    test('adjustment constraints and partial indexes enforce typed state',
        () async {
      final AppDatabase database = await open();
      addTearDown(database.close);

      final Map<String, String> indexes = <String, String>{
        for (final QueryRow row in await database.customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'schedule_adjustments'",
        ).get())
          row.read<String>('name'): row.read<String>('sql'),
      };
      expect(indexes, contains('idx_adjustments_active_exact'));
      expect(
        indexes['idx_adjustments_active_exact'],
        contains('WHERE mode = 1 AND cleared_at_utc IS NULL'),
      );
      expect(indexes, contains('idx_adjustments_operation_reason'));

      Future<void> insert({
        required String id,
        required String operationId,
        required int elementType,
        required int mode,
        required int reason,
        int? notBeforeAtUtc,
        int? notBeforeStudyDay,
        int? scheduledForAtUtc,
        int? scheduledForStudyDay,
      }) => database.customStatement(
        'INSERT INTO schedule_adjustments (id, element_id, element_type, '
        'mode, reason, not_before_at_utc, not_before_study_day, '
        'scheduled_for_at_utc, scheduled_for_study_day, zone_id, '
        'operation_id, policy_version, created_at_utc, created_study_day, '
        'created_zone_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          id,
          'element',
          elementType,
          mode,
          reason,
          notBeforeAtUtc,
          notBeforeStudyDay,
          scheduledForAtUtc,
          scheduledForStudyDay,
          elementType == 2 ? null : 'Europe/Berlin',
          operationId,
          'schedule_adjustments_v1',
          1000,
          20000,
          'Europe/Berlin',
        ],
      );

      await insert(
        id: 'exact-1',
        operationId: 'op-exact-1',
        elementType: 2,
        mode: 1,
        reason: 4,
        scheduledForAtUtc: 2000,
      );
      await expectLater(
        insert(
          id: 'exact-2',
          operationId: 'op-exact-2',
          elementType: 2,
          mode: 1,
          reason: 4,
          scheduledForAtUtc: 3000,
        ),
        throwsA(isA<Object>()),
        reason: 'an element may have at most one active exact override',
      );
      await database.customStatement(
        "UPDATE schedule_adjustments SET cleared_at_utc = 1500, "
        "cleared_by_operation_id = 'clear-op' WHERE id = 'exact-1'",
      );
      await insert(
        id: 'exact-2',
        operationId: 'op-exact-2',
        elementType: 2,
        mode: 1,
        reason: 4,
        scheduledForAtUtc: 3000,
      );

      await expectLater(
        insert(
          id: 'wrong-domain',
          operationId: 'op-wrong-domain',
          elementType: 0,
          mode: 0,
          reason: 0,
          notBeforeAtUtc: 4000,
        ),
        throwsA(isA<Object>()),
        reason: 'topics use StudyDay values rather than UTC instants',
      );
      await expectLater(
        insert(
          id: 'wrong-shape',
          operationId: 'op-wrong-shape',
          elementType: 2,
          mode: 1,
          reason: 4,
          notBeforeAtUtc: 4000,
        ),
        throwsA(isA<Object>()),
        reason: 'an exact override cannot persist a lower-bound value',
      );
    });
  });

  group('v5 to v6 scheduler migration', () {
    test('preserves canonical schedules and imports append-only history',
        () async {
      await _createV5Fixture(databaseFile);

      final AppDatabase migrated = await open();
      addTearDown(migrated.close);

      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        kSchemaVersion,
      );
      expect(await migrated.isHealthy(), isTrue);
      expect(await migrated.foreignKeysValid(), isTrue);

      final List<QueryRow> topics = await migrated.customSelect(
        'SELECT t.element_id, t.step_index, t.interval_days, t.a_factor, '
        't.algorithm_due_day, t.scheduler_kind, t.scheduler_version, '
        's.due_day, s.original_due_day, s.legacy_due_provenance '
        'FROM topic_states t JOIN element_schedules s '
        'ON s.element_id = t.element_id AND s.element_type = t.element_type '
        'ORDER BY t.element_id',
      ).get();
      expect(topics, hasLength(3));

      final QueryRow source = topics.singleWhere(
        (QueryRow row) => row.read<String>('element_id') == 's1',
      );
      expect(source.read<int>('step_index'), 5);
      expect(source.read<double>('interval_days'), 12.75);
      expect(source.read<double>('a_factor'), 3.4);
      expect(source.read<int>('algorithm_due_day'), 20001);
      expect(source.read<int>('due_day'), 20001);
      expect(source.read<int>('original_due_day'), 20001);
      expect(source.read<String>('scheduler_kind'), 'legacy_sequence');
      expect(source.read<String>('scheduler_version'), 'legacy_sequence/1');

      final QueryRow extract = topics.singleWhere(
        (QueryRow row) => row.read<String>('element_id') == 'x1',
      );
      expect(extract.read<int>('step_index'), 3);
      expect(extract.read<double>('interval_days'), 7.25);
      expect(extract.read<double>('a_factor'), 2.2);
      expect(extract.read<int>('algorithm_due_day'), 20003);

      final QueryRow damaged = topics.singleWhere(
        (QueryRow row) => row.read<String>('element_id') == 's-damaged',
      );
      expect(damaged.read<int>('algorithm_due_day'), 20100);
      expect(damaged.read<int>('due_day'), 20100);
      expect(damaged.read<int>('original_due_day'), 19999);
      expect(
        damaged.read<int>('legacy_due_provenance'),
        1,
        reason: 'a contradictory legacy canonical due must be flagged rather '
            'than silently presented as trustworthy history',
      );

      final Map<String, (String?, int?)> parents = <String, (String?, int?)>{
        for (final QueryRow row in await migrated.customSelect(
          'SELECT id, parent_element_id, parent_element_type FROM cards',
        ).get())
          row.read<String>('id'): (
            row.read<String?>('parent_element_id'),
            row.read<int?>('parent_element_type'),
          ),
      };
      expect(parents['c-extract'], ('x1', 1));
      expect(parents['c-source'], ('s1', 0));
      expect(parents['c-standalone'], (null, null));

      final QueryRow reviewedMemory = await migrated.customSelect(
        "SELECT * FROM card_memories WHERE card_id = 'c-extract'",
      ).getSingle();
      expect(reviewedMemory.read<double>('stability'), 17.125);
      expect(reviewedMemory.read<double>('difficulty'), 4.875);
      expect(reviewedMemory.read<int>('state'), 2);
      expect(reviewedMemory.read<int?>('step'), isNull);
      expect(reviewedMemory.read<int>('reps'), 9);
      expect(reviewedMemory.read<int>('lapses'), 2);
      expect(reviewedMemory.read<int>('last_review_utc'), 1700000000123);
      expect(reviewedMemory.read<int>('due_at_utc'), 1701234567890);
      expect(reviewedMemory.read<String>('scheduler_name'), 'dart-fsrs');
      expect(reviewedMemory.read<int>('revision'), 1);
      expect(
        reviewedMemory.read<double>('scheduled_days'),
        closeTo((1701234567890 - 1700000000123) / 86400000, 1e-12),
      );
      expect(
        jsonDecode(reviewedMemory.read<String>('fsrs_state_json')),
        <String, Object?>{
          'state': 2,
          'step': null,
          'stability': 17.125,
          'difficulty': 4.875,
          'due_at_utc_ms': 1701234567890,
          'last_review_at_utc_ms': 1700000000123,
        },
      );

      final QueryRow newMemory = await migrated.customSelect(
        "SELECT * FROM card_memories WHERE card_id = 'c-source'",
      ).getSingle();
      expect(newMemory.read<int>('state'), 1);
      expect(newMemory.read<int>('step'), 0);
      expect(newMemory.read<double?>('stability'), isNull);
      expect(newMemory.read<double?>('difficulty'), isNull);
      expect(newMemory.read<int?>('last_review_utc'), isNull);
      expect(newMemory.read<double?>('scheduled_days'), isNull);
      expect(
        jsonDecode(newMemory.read<String>('fsrs_state_json')),
        <String, Object?>{
          'state': 1,
          'step': 0,
          'stability': null,
          'difficulty': null,
          'due_at_utc_ms': 1700200000000,
          'last_review_at_utc_ms': null,
        },
      );

      final List<QueryRow> reviews = await migrated
          .customSelect('SELECT * FROM review_events ORDER BY id')
          .get();
      expect(reviews, hasLength(2));
      expect(reviews.map((QueryRow row) => row.read<String>('id')), <String>[
        'review-graded',
        'review-practice',
      ]);

      final List<QueryRow> imported = await migrated.customSelect(
        'SELECT * FROM scheduler_events ORDER BY id',
      ).get();
      expect(imported, hasLength(2));
      final QueryRow graded = imported.singleWhere(
        (QueryRow row) => row.read<String>('id') ==
            'migrated-review:review-graded',
      );
      expect(graded.read<String>('operation_id'), 'legacy-op-graded');
      expect(graded.read<String>('event_type'), 'card_reviewed');
      expect(graded.read<String>('policy_version'), 'legacy_import_v1');
      expect(graded.read<String>('study_day_zone_id'), 'Europe/Berlin');
      expect(graded.read<String>('algorithmic_due_before'), 'utc:1700100000000');
      expect(graded.read<String>('algorithmic_due_after'), 'utc:1701234567890');
      expect(
        jsonDecode(graded.read<String>('metadata_json')),
        containsPair('snapshot_completeness', 'review_state_only'),
      );
      expect(
        imported.singleWhere(
          (QueryRow row) => row.read<String>('id') ==
              'migrated-review:review-practice',
        ).read<String>('event_type'),
        'practice_reviewed',
      );

      expect(
        await migrated.customSelect('SELECT * FROM schedule_adjustments').get(),
        isEmpty,
        reason: 'legacy deferral fields alone are not enough history to invent '
            'typed adjustment audit records',
      );
    });

    test('produces stable total priority order and upgraded FK parity',
        () async {
      await _createV5Fixture(databaseFile);
      AppDatabase migrated = await open();

      Future<Map<String, String>> priorities(AppDatabase database) async =>
          <String, String>{
            for (final QueryRow row in await database.customSelect(
              'SELECT element_id, priority_key FROM element_schedules '
              'ORDER BY priority_key',
            ).get())
              row.read<String>('element_id'): row.read<String>('priority_key'),
          };

      final Map<String, String> beforeRestart = await priorities(migrated);
      expect(beforeRestart.keys, <String>[
        'c-extract',
        's-damaged',
        's1',
        'x1',
        'c-source',
        'c-standalone',
      ]);
      expect(beforeRestart.values.toSet(), hasLength(beforeRestart.length));

      final Map<String, String> reviewFk = await _foreignKeyActions(
        migrated,
        'review_events',
      );
      final Map<String, String> memoryFk = await _foreignKeyActions(
        migrated,
        'card_memories',
      );
      expect(reviewFk['card_id'], 'RESTRICT');
      expect(
        memoryFk['card_id'],
        'RESTRICT',
        reason: 'an upgraded collection must have the same scheduler '
            'integrity constraints as a fresh v6 collection',
      );

      await migrated.close();
      migrated = await open();
      addTearDown(migrated.close);
      expect(await priorities(migrated), beforeRestart);
    });
  });
}

Future<Map<String, String>> _foreignKeyActions(
  AppDatabase database,
  String table,
) async => <String, String>{
  for (final QueryRow row in await database
      .customSelect('PRAGMA foreign_key_list($table)')
      .get())
    row.read<String>('from'): row.read<String>('on_delete'),
};

Future<void> _insertReview(
  AppDatabase database, {
  required String id,
  required String cardId,
}) => database.customStatement(
  'INSERT INTO review_events (id, card_id, reviewed_at_utc, rating, '
  'pre_state_json, post_state_json, elapsed_ms, scheduler_version, '
  'parameters_version, is_practice, operation_id) '
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
  <Object?>[
    id,
    cardId,
    1700100000000,
    3,
    '{"due_at_utc_ms":1700000000000}',
    '{"due_at_utc_ms":1700200000000}',
    1000,
    'legacy-fsrs',
    'legacy-parameters',
    0,
    'op-$id',
  ],
);

Future<void> _createV5Fixture(File file) async {
  final AppDatabase current = openDatabaseAt(file);
  await current.customSelect('SELECT 1').getSingle();
  await current.close();

  file.parent.createSync(recursive: true);
  final sqlite.Database legacy = sqlite.sqlite3.open(file.path);
  try {
    legacy.execute('PRAGMA foreign_keys = OFF');
    legacy.execute('BEGIN IMMEDIATE');
    try {
      for (final String table in <String>[
        'schedule_adjustments',
        'scheduler_events',
        'daily_presentation_plans',
        'mercy_batches',
        'review_events',
        'card_memories',
        'topic_states',
        'element_schedules',
        'cards',
      ]) {
        legacy.execute('DROP TABLE IF EXISTS $table');
      }

      legacy.execute(_v5CardsSql);
      legacy.execute(_v5SchedulesSql);
      legacy.execute(_v5TopicStatesSql);
      legacy.execute(_v5CardMemoriesSql);
      legacy.execute(_v5ReviewEventsSql);
      _seedV5Rows(legacy);
      legacy.userVersion = 5;
      legacy.execute('COMMIT');
    } on Object {
      legacy.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    legacy.close();
  }
}

void _seedV5Rows(sqlite.Database database) {
  database.execute('''
    INSERT INTO sources
      (id, title, markdown, content_hash, word_count, imported_at_utc, pace,
       revision)
    VALUES
      ('s1', 'Source', 'body', '${'a' * 64}', 20, 1000, 1, 1),
      ('s-damaged', 'Damaged', 'body', '${'b' * 64}', 20, 900, 1, 1)
  ''');
  database.execute('''
    INSERT INTO extracts
      (id, markdown, source_id, parent_id, parent_is_source, start_block_id,
       start_offset, end_block_id, end_offset, selected_text_hash,
       created_at_utc, edited_at_utc)
    VALUES
      ('x1', 'passage', 's1', 's1', 1, 'block', 0, 'block', 7,
       '${'c' * 64}', 1100, 1200)
  ''');
  database.execute('''
    INSERT INTO cards
      (id, extract_id, source_id, kind, front, back, cloze_ordinal,
       created_at_utc, edited_at_utc)
    VALUES
      ('c-extract', 'x1', NULL, 0, 'q1', 'a1', NULL, 1300, 1400),
      ('c-source', NULL, 's1', 0, 'q2', 'a2', NULL, 1500, NULL),
      ('c-standalone', NULL, NULL, 0, 'q3', 'a3', NULL, 1600, NULL)
  ''');
  database.execute('''
    INSERT INTO element_schedules
      (element_id, element_type, priority_key, lifecycle, due_day,
       original_due_day, deferred_until, deferral_kind, root_id, zone_id)
    VALUES
      ('s1', 0, 'K', 0, 20001, 20001, NULL, 0, 's1', 'Europe/Berlin'),
      ('s-damaged', 0, 'K', 0, 20100, 19999, NULL, 0, 's-damaged',
       'Europe/Berlin'),
      ('x1', 1, 'K', 0, 20003, 20003, 20010, 1, 's1', 'Europe/Berlin'),
      ('c-extract', 2, 'A', 0, 20004, 20004, NULL, 0, 's1',
       'Europe/Berlin'),
      ('c-source', 2, 'Z', 0, 20005, 20005, NULL, 0, 's1',
       'Europe/Berlin'),
      ('c-standalone', 2, 'Z', 0, 20006, 20006, NULL, 0, NULL,
       'Europe/Berlin')
  ''');
  database.execute('''
    INSERT INTO topic_states
      (element_id, element_type, profile_id, step_index, interval_days,
       a_factor, yield_ewma, encounters, postpone_count,
       encounters_since_last_card, last_encounter_day)
    VALUES
      ('s1', 0, 'normal', 5, 12.75, 3.4, 1.25, 5, 2, 1, 19990),
      ('s-damaged', 0, 'normal', 8, 91.5, 2.75, 0.5, 8, 0, 8, 19998),
      ('x1', 1, 'extract', 3, 7.25, 2.2, 2.5, 3, 1, 0, 19995)
  ''');
  database.execute('''
    INSERT INTO card_memories
      (card_id, stability, difficulty, state, step, reps, lapses,
       last_review_utc, due_at_utc, original_due_at_utc, deferred_until_utc,
       postpone_count, scheduler_version, parameters_version)
    VALUES
      ('c-extract', 17.125, 4.875, 2, NULL, 9, 2, 1700000000123,
       1701234567890, 1701234567890, 1702000000000, 4,
       'fsrs-old-exact', 'params-old-exact'),
      ('c-source', NULL, NULL, 1, 0, 0, 0, NULL, 1700200000000,
       1700200000000, NULL, 0, 'fsrs-old-new', 'params-old-new')
  ''');
  database.execute('''
    INSERT INTO review_events
      (id, card_id, reviewed_at_utc, rating, pre_state_json, post_state_json,
       elapsed_ms, scheduler_version, parameters_version, is_practice,
       operation_id)
    VALUES
      ('review-graded', 'c-extract', 1700100000000, 3,
       '{"due_at_utc_ms":1700100000000,"marker":"before"}',
       '{"due_at_utc_ms":1701234567890,"marker":"after"}', 1234,
       'fsrs-old-exact', 'params-old-exact', 0, 'legacy-op-graded'),
      ('review-practice', 'c-extract', 1700200000000, 4,
       '{"due_at_utc_ms":1701234567890}',
       '{"due_at_utc_ms":1701234567890}', 4321,
       'fsrs-old-exact', 'params-old-exact', 1, 'legacy-op-practice')
  ''');
}

const String _v5CardsSql = '''
  CREATE TABLE cards (
    id TEXT NOT NULL PRIMARY KEY,
    extract_id TEXT NULL REFERENCES extracts(id) ON DELETE RESTRICT,
    source_id TEXT NULL REFERENCES sources(id) ON DELETE RESTRICT,
    kind INTEGER NOT NULL CHECK (kind BETWEEN 0 AND 1),
    front TEXT NOT NULL,
    back TEXT NOT NULL,
    cloze_ordinal INTEGER NULL,
    created_at_utc INTEGER NOT NULL,
    edited_at_utc INTEGER NULL,
    CHECK ((kind = 1) = (cloze_ordinal IS NOT NULL)),
    CHECK (extract_id IS NULL OR source_id IS NULL)
  )
''';

const String _v5SchedulesSql = '''
  CREATE TABLE element_schedules (
    element_id TEXT NOT NULL,
    element_type INTEGER NOT NULL CHECK (element_type BETWEEN 0 AND 2),
    priority_key TEXT NOT NULL CHECK (length(priority_key) BETWEEN 1 AND 128),
    lifecycle INTEGER NOT NULL CHECK (lifecycle BETWEEN 0 AND 4),
    due_day INTEGER NOT NULL,
    original_due_day INTEGER NOT NULL,
    deferred_until INTEGER NULL,
    deferral_kind INTEGER NOT NULL DEFAULT 0 CHECK (deferral_kind BETWEEN 0 AND 2),
    root_id TEXT NULL,
    zone_id TEXT NOT NULL,
    PRIMARY KEY (element_id, element_type),
    CHECK ((deferred_until IS NULL) = (deferral_kind = 0))
  )
''';

const String _v5TopicStatesSql = '''
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
''';

const String _v5CardMemoriesSql = '''
  CREATE TABLE card_memories (
    card_id TEXT NOT NULL PRIMARY KEY REFERENCES cards(id) ON DELETE CASCADE,
    stability REAL NULL,
    difficulty REAL NULL,
    state INTEGER NOT NULL CHECK (state BETWEEN 1 AND 3),
    step INTEGER NULL CHECK (step >= 0),
    reps INTEGER NOT NULL DEFAULT 0 CHECK (reps >= 0),
    lapses INTEGER NOT NULL DEFAULT 0 CHECK (lapses >= 0),
    last_review_utc INTEGER NULL,
    due_at_utc INTEGER NOT NULL,
    original_due_at_utc INTEGER NOT NULL,
    deferred_until_utc INTEGER NULL,
    postpone_count INTEGER NOT NULL DEFAULT 0 CHECK (postpone_count >= 0),
    scheduler_version TEXT NOT NULL,
    parameters_version TEXT NOT NULL,
    CHECK ((state = 2 AND step IS NULL) OR
      (state IN (1, 3) AND step IS NOT NULL)),
    CHECK ((stability IS NULL) = (difficulty IS NULL)),
    CHECK (lapses <= reps),
    CHECK ((reps = 0 AND stability IS NULL AND difficulty IS NULL AND
      last_review_utc IS NULL) OR (reps > 0 AND stability IS NOT NULL AND
      difficulty IS NOT NULL AND last_review_utc IS NOT NULL))
  )
''';

const String _v5ReviewEventsSql = '''
  CREATE TABLE review_events (
    id TEXT NOT NULL PRIMARY KEY,
    card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    reviewed_at_utc INTEGER NOT NULL,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 4),
    pre_state_json TEXT NOT NULL,
    post_state_json TEXT NOT NULL,
    elapsed_ms INTEGER NULL,
    scheduler_version TEXT NOT NULL,
    parameters_version TEXT NOT NULL,
    is_practice INTEGER NOT NULL DEFAULT 0 CHECK (is_practice IN (0, 1)),
    operation_id TEXT NOT NULL
  )
''';
