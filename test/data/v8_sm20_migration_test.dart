/// One-time conversion from the retired topic scheduler row to sole SM20.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/domain/scheduling/sm20_numeric.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;
  late File databaseFile;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_v8_sm20_');
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

  test('fresh schema contains only the exact SM20 topic record', () async {
    final AppDatabase database = await open();
    addTearDown(database.close);

    final Set<String> columns = <String>{
      for (final QueryRow row
          in await database
              .customSelect('PRAGMA table_info(topic_states)')
              .get())
        row.read<String>('name'),
    };
    expect(columns, <String>{
      'element_id',
      'element_type',
      'status',
      'repetition_count',
      'lapse_count',
      'stored_interval',
      'last_review_day',
      'a_factor_raw',
      'last_interval_ratio_raw',
      'history_block_id',
      'recent_postponement_count',
      'total_postponement_count',
      'learning_control',
      'encounters_since_last_card',
      'revision',
    });

    await expectLater(
      database.customStatement(
        'INSERT INTO topic_states (element_id, element_type, status, '
        "a_factor_raw) VALUES ('bad', 0, 0, '1234')",
      ),
      throwsA(isA<Object>()),
      reason: 'Real48 payloads must be exactly six persisted bytes',
    );
  });

  test(
    'v7 rows convert deterministically without a legacy runtime mode',
    () async {
      AppDatabase database = await open();
      // Seed the shape this test claims to migrate from. The live table no
      // longer accepts the retired suspended/finished lifecycle numbering, so
      // stamping an old user_version over the current schema would exercise a
      // schema that never existed.
      await database.customStatement('DROP TABLE element_schedules');
      await database.customStatement(_v7ElementSchedulesSql);
      for (final (String id, int lifecycle) in <(String, int)>[
        ('pending', 0),
        ('memorized', 0),
        ('dismissed', 2),
        ('deleted', 4),
      ]) {
        await database.customStatement(
          'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
          'imported_at_utc, revision) VALUES (?, ?, ?, ?, 1, 0, 1)',
          <Object?>[id, id, id, id.padRight(64, '0')],
        );
        await database.customStatement(
          'INSERT INTO element_schedules (element_id, element_type, '
          'priority_key, lifecycle, due_day, original_due_day, zone_id) '
          'VALUES (?, 0, ?, ?, 21000, 20999, ?)',
          <Object?>[id, 'V$id', lifecycle, 'UTC'],
        );
      }

      await database.customStatement('DROP TABLE topic_states');
      await database.customStatement(_v7TopicStatesSql);
      await database.customStatement(
        'CREATE TABLE schedule_adjustments (id TEXT PRIMARY KEY)',
      );
      await database.customStatement(
        'CREATE TABLE daily_presentation_plans (id TEXT PRIMARY KEY)',
      );
      await database.customStatement('''
      INSERT INTO topic_states
        (element_id, element_type, profile_id, step_index, interval_days,
         a_factor, yield_ewma, encounters, postpone_count,
         encounters_since_last_card, last_encounter_day,
         algorithm_due_day, scheduler_kind, scheduler_version,
         policy_input_snapshot, revision)
      VALUES
        ('pending', 0, 'normal', 0, 0, 0, 0, 0, 2, 0, NULL,
         21000, 'topic_afactor_v1', 'old', NULL, 2),
        ('memorized', 0, 'normal', 9, 44530.5, 9, 0, 70000, 7, 4, 20800,
         21000, 'topic_afactor_v1', 'old', NULL, 9),
        ('dismissed', 0, 'normal', 3, 8.5, 2.5, 0, 3, 1, 1, 20700,
         21000, 'legacy_sequence', 'old', NULL, 4),
        ('deleted', 0, 'normal', 2, 4, 1.1, 0, 2, 0, 2, 20600,
         21000, 'legacy_sequence', 'old', NULL, 3)
    ''');
      await database.customStatement('PRAGMA user_version = 7');
      await database.close();

      database = await open();
      addTearDown(database.close);
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        kSchemaVersion,
      );

      final Map<String, QueryRow> rows = <String, QueryRow>{
        for (final QueryRow row
            in await database
                .customSelect('SELECT * FROM topic_states ORDER BY element_id')
                .get())
          row.read<String>('element_id'): row,
      };

      expect(rows['pending']!.read<int>('status'), 0);
      expect(rows['pending']!.read<int>('stored_interval'), 0);
      expect(
        _real48(rows['pending']!.read<String>('a_factor_raw')),
        closeTo(1.2, 1e-10),
      );
      expect(rows['pending']!.read<int>('recent_postponement_count'), 2);
      expect(rows['pending']!.read<int>('total_postponement_count'), 2);

      expect(rows['memorized']!.read<int>('status'), 1);
      expect(rows['memorized']!.read<int>('repetition_count'), 65535);
      expect(rows['memorized']!.read<int>('stored_interval'), 44530);
      expect(_real48(rows['memorized']!.read<String>('a_factor_raw')), 6.0);
      expect(rows['memorized']!.read<int>('last_review_day'), 20800);
      expect(rows['memorized']!.read<int>('encounters_since_last_card'), 4);
      expect(rows['memorized']!.read<int>('revision'), 9);

      expect(rows['dismissed']!.read<int>('status'), 2);
      expect(rows['deleted']!.read<int>('status'), 3);
      expect(
        rows.values.map(
          (QueryRow row) => row.read<String>('last_interval_ratio_raw'),
        ),
        everyElement('000000000000'),
      );

      final Set<String> columns = <String>{
        for (final QueryRow row
            in await database
                .customSelect('PRAGMA table_info(topic_states)')
                .get())
          row.read<String>('name'),
      };
      expect(columns, isNot(contains('scheduler_kind')));
      expect(columns, isNot(contains('profile_id')));
      expect(columns, isNot(contains('interval_days')));

      final List<QueryRow> retiredTables = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('schedule_adjustments', 'daily_presentation_plans')",
          )
          .get();
      expect(retiredTables, isEmpty);
    },
  );
}

double _real48(String hex) => DelphiReal48.fromBytes(<int>[
  for (var offset = 0; offset < hex.length; offset += 2)
    int.parse(hex.substring(offset, offset + 2), radix: 16),
]).value;

/// The pre-v10 shared schedule row, including the retired deferral columns
/// and the five-value lifecycle numbering.
const String _v7ElementSchedulesSql = '''
  CREATE TABLE element_schedules (
    element_id TEXT NOT NULL,
    element_type INTEGER NOT NULL CHECK (element_type BETWEEN 0 AND 2),
    priority_key TEXT NOT NULL,
    lifecycle INTEGER NOT NULL CHECK (lifecycle BETWEEN 0 AND 4),
    due_day INTEGER NOT NULL,
    original_due_day INTEGER NOT NULL,
    deferred_until INTEGER NULL,
    deferral_kind INTEGER NOT NULL DEFAULT 0 CHECK (deferral_kind BETWEEN 0 AND 2),
    root_id TEXT NULL,
    parent_element_id TEXT NULL,
    ordinal INTEGER NULL,
    created_at_utc INTEGER NULL,
    updated_at_utc INTEGER NULL,
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
    legacy_due_provenance INTEGER NOT NULL DEFAULT 0
      CHECK (legacy_due_provenance BETWEEN 0 AND 1),
    zone_id TEXT NOT NULL,
    PRIMARY KEY (element_id, element_type),
    CHECK ((deferred_until IS NULL) = (deferral_kind = 0))
  )
''';

const String _v7TopicStatesSql = '''
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
    algorithm_due_day INTEGER NULL,
    scheduler_kind TEXT NOT NULL DEFAULT 'topic_afactor_v1',
    scheduler_version TEXT NOT NULL DEFAULT 'topic_afactor_v1/1',
    policy_input_snapshot TEXT NULL,
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision >= 1),
    PRIMARY KEY (element_id, element_type)
  )
''';
