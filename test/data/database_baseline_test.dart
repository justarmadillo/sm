import 'dart:io';

import 'package:drift/drift.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/data/files/backup_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_db_test_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openFileDatabase() async {
    final db = openDatabaseAt(File('${workspace.path}/db/$kDatabaseFileName'));
    // Force the connection open so beforeOpen pragmas run.
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<void> seed(AppDatabase db) async {
    await db.customStatement(
      'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
      'imported_at_utc, pace, revision) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>['s1', 'Fixture', '# Title', 'a' * 64, 2, 0, 1, 1],
    );
    await db.customStatement(
      'INSERT INTO element_schedules (element_id, element_type, priority_key, '
      'lifecycle, due_day, original_due_day, zone_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      <Object?>['s1', 0, 'V', 0, 20000, 20000, 'UTC'],
    );
  }

  group('schema baseline', () {
    test('creates every table at the current version', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);

      final tables = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' "
            // FTS5 creates its own shadow tables; they are an implementation
            // detail of the index and are asserted separately below.
            "AND name NOT LIKE '$kSearchIndexTable%' ORDER BY name",
          )
          .get();
      final names = tables.map((QueryRow r) => r.read<String>('name')).toList();

      expect(names, <String>[
        'activity_events',
        'blocks',
        'card_memories',
        'cards',
        'dataset_meta',
        'element_schedules',
        'extracts',
        'folders',
        'mercy_batches',
        'review_events',
        'revlog_entries',
        'scheduler_events',
        'search_documents',
        'settings',
        'sources',
        'topic_states',
      ]);

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.first, kSchemaVersion);
    });

    test('the full-text index is created and consistent', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);

      final index = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            'AND name = ?',
            variables: <Variable<Object>>[Variable<String>(kSearchIndexTable)],
          )
          .get();
      expect(index, hasLength(1));
      expect(await db.searchIndexValid(), isTrue);

      // The triggers are what keep the index in step inside whatever
      // transaction wrote the content, so a search can never observe a
      // half-applied import.
      final triggers = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'trigger' "
            "AND name LIKE 'search_documents_%' ORDER BY name",
          )
          .get();
      expect(triggers.map((QueryRow r) => r.read<String>('name')), <String>[
        'search_documents_ad',
        'search_documents_ai',
        'search_documents_au',
      ]);
    });

    test('foreign keys are enforced on the connection', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);

      final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(pragma.data.values.first, 1);

      // blocks.source_id references a source that does not exist.
      await expectLater(
        db.customStatement(
          'INSERT INTO blocks (id, source_id, idx, type, raw, start_utf8, '
          'end_utf8, start_utf16, content_spans, ordered, list_depth, '
          'quote_depth) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>['b1', 'ghost', 0, 0, 'x', 0, 1, 0, '[]', 0, 0, 0],
        ),
        throwsA(isA<Object>()),
      );
    });

    test('deleting a source cascades to its blocks', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);
      await seed(db);
      await db.customStatement(
        'INSERT INTO blocks (id, source_id, idx, type, raw, start_utf8, '
        'end_utf8, start_utf16, content_spans, ordered, list_depth, '
        'quote_depth) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['s1:0', 's1', 0, 1, '# Title', 0, 7, 0, '[[2,7]]', 0, 0, 0],
      );

      await db.customStatement("DELETE FROM sources WHERE id = 's1'");
      final blocks = await db
          .customSelect('SELECT COUNT(*) AS n FROM blocks')
          .getSingle();
      expect(blocks.read<int>('n'), 0);
    });

    test('check constraints reject impossible rows', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);
      await seed(db);

      // A resume marker must have both its columns or neither.
      await expectLater(
        db.customStatement(
          "UPDATE sources SET marker_block_id = 's1:0' WHERE id = 's1'",
        ),
        throwsA(isA<Object>()),
        reason: 'half a resume marker must be rejected',
      );

      // Lifecycle is an enum index, not a free integer.
      await expectLater(
        db.customStatement(
          "UPDATE element_schedules SET lifecycle = 9 WHERE element_id = 's1'",
        ),
        throwsA(isA<Object>()),
      );
    });

    test('a Q&A card may not carry a cloze ordinal', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);
      await seed(db);
      await db.customStatement(
        'INSERT INTO extracts (id, markdown, source_id, parent_id, '
        'parent_is_source, start_block_id, start_offset, end_block_id, '
        'end_offset, selected_text_hash, created_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'e1',
          'text',
          's1',
          's1',
          1,
          's1:0',
          0,
          's1:0',
          4,
          'b' * 64,
          0,
        ],
      );

      await expectLater(
        db.customStatement(
          'INSERT INTO cards (id, parent_element_id, parent_element_type, '
          'kind, front, back, cloze_ordinal, created_at_utc) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>['c1', 'e1', 1, 0, 'q', 'a', 1, 0],
        ),
        throwsA(isA<Object>()),
      );

      // The cloze form is accepted.
      await db.customStatement(
        'INSERT INTO cards (id, parent_element_id, parent_element_type, '
        'kind, front, back, cloze_ordinal, created_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['c2', 'e1', 1, 1, '{{c1::x}}', '', 1, 0],
      );
    });

    test(
      'the version-1 migration preserves rows and restrictive ancestry',
      () async {
        final file = File('${workspace.path}/db/$kDatabaseFileName');
        final old = await openFileDatabase();
        await seed(old);
        await old.customStatement('PRAGMA user_version = 1');
        await old.close();

        final migrated = openDatabaseAt(file);
        addTearDown(migrated.close);
        await migrated.customSelect('SELECT 1').get();

        final sourceCount = await migrated
            .customSelect('SELECT COUNT(*) AS n FROM sources')
            .getSingle();
        expect(sourceCount.read<int>('n'), 1);
        final version = await migrated
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(version.data.values.first, kSchemaVersion);

        for (final table in <String>['extracts', 'cards']) {
          final keys = await migrated
              .customSelect('PRAGMA foreign_key_list($table)')
              .get();
          expect(
            keys.map((row) => row.read<String>('on_delete')),
            everyElement('RESTRICT'),
          );
        }
        final indexes = await migrated
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_extracts_parent'",
            )
            .get();
        expect(indexes, hasLength(1));
      },
    );

    test('rejects opening a database written by a newer build', () async {
      final file = File('${workspace.path}/db/$kDatabaseFileName');
      final db = openDatabaseAt(file);
      await db.customSelect('SELECT 1').get();
      await db.customStatement('PRAGMA user_version = 99');
      await db.close();

      final reopened = openDatabaseAt(file);
      addTearDown(reopened.close);
      await expectLater(
        reopened.customSelect('SELECT 1').get(),
        throwsA(isA<Object>()),
        reason: 'a newer schema must be rejected, not silently downgraded',
      );
    });
  });

  group('backups', () {
    test('takes a validated snapshot before a pending migration', () async {
      final db = await openFileDatabase();
      await seed(db);
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      final result = createPreMigrationBackupIfNeeded(
        databaseFile: File('${workspace.path}/db/$kDatabaseFileName'),
        backupDirectory: Directory('${workspace.path}/backups'),
        targetSchemaVersion: kSchemaVersion,
        clock: FakeClock(DateTime.utc(2026, 3, 5, 9)),
      );

      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final backup = result.unwrap()!;
      expect(backup.path, endsWith('premigration-20260305090000.sqlite'));
      final copy = sqlite.sqlite3.open(backup.path);
      addTearDown(copy.close);
      expect(
        copy.userVersion,
        1,
        reason: 'the snapshot must predate migration',
      );
      expect(copy.select('SELECT COUNT(*) AS n FROM sources').first['n'], 1);
    });

    test('produces a validated, restorable copy', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);
      await seed(db);

      final clock = FakeClock(DateTime.utc(2026, 3, 5, 9));
      final diagnostics = RecordingDiagnosticSink();
      final service = BackupService(
        database: db,
        backupDirectory: Directory('${workspace.path}/backups'),
        clock: clock,
        diagnostics: diagnostics,
      );

      final result = await service.createBackup();
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      final backup = result.unwrap();
      expect(backup.existsSync(), isTrue);
      expect(backup.path, endsWith('backup-20260305090000.sqlite'));
      expect(diagnostics.named('backup.created'), hasLength(1));

      // No partial files survive a successful run.
      expect(
        service.directory.listSync().where(
          (FileSystemEntity e) => e.path.endsWith('.partial'),
        ),
        isEmpty,
      );

      // The copy is a real database holding the same rows.
      final restored = openDatabaseAt(backup);
      addTearDown(restored.close);
      expect(await restored.isHealthy(), isTrue);
      final row = await restored
          .customSelect(
            'SELECT title FROM sources WHERE id = ?',
            variables: <Variable<Object>>[Variable<String>('s1')],
          )
          .getSingle();
      expect(row.read<String>('title'), 'Fixture');
    });

    test(
      'a backup taken while writing continues is still consistent',
      () async {
        final db = await openFileDatabase();
        addTearDown(db.close);
        await seed(db);

        final service = BackupService(
          database: db,
          backupDirectory: Directory('${workspace.path}/backups'),
          clock: FakeClock(DateTime.utc(2026, 3, 5, 9)),
        );

        final backupFuture = service.createBackup();
        await db.customStatement(
          "UPDATE sources SET title = 'Changed' WHERE id = 's1'",
        );
        final backup = (await backupFuture).unwrap();

        final restored = openDatabaseAt(backup);
        addTearDown(restored.close);
        expect(await restored.isHealthy(), isTrue);
        expect(await restored.foreignKeysValid(), isTrue);
      },
    );

    test('retention keeps one copy per day and per month', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);
      await seed(db);

      final clock = FakeClock(DateTime.utc(2026, 1, 1, 8));
      final service = BackupService(
        database: db,
        backupDirectory: Directory('${workspace.path}/backups'),
        clock: clock,
        retention: const BackupRetention(daily: 3, monthly: 2),
      );

      // Two backups a day for five consecutive days.
      for (var day = 0; day < 5; day++) {
        for (final hour in <int>[8, 20]) {
          clock.setTo(DateTime.utc(2026, 1, 1 + day, hour));
          expect((await service.createBackup()).isOk, isTrue);
        }
      }

      final kept = service.listBackups().map(_stampOf).toList();
      // Three daily keepers (the newest per day) plus the month's newest,
      // which is already one of them.
      expect(kept, <String>[
        '20260105200000',
        '20260104200000',
        '20260103200000',
      ]);
    });

    test(
      'pre-migration copies are retained separately from daily ones',
      () async {
        final db = await openFileDatabase();
        addTearDown(db.close);
        await seed(db);

        final clock = FakeClock(DateTime.utc(2026, 1, 1, 8));
        final service = BackupService(
          database: db,
          backupDirectory: Directory('${workspace.path}/backups'),
          clock: clock,
          retention: const BackupRetention(
            daily: 1,
            monthly: 1,
            preMigration: 2,
          ),
        );

        clock.setTo(DateTime.utc(2026, 1, 1, 7));
        await service.createBackup(kind: BackupKind.preMigration);
        clock.setTo(DateTime.utc(2026, 1, 2, 7));
        await service.createBackup(kind: BackupKind.preMigration);
        // Several daily rotations must not evict the pre-migration copies.
        for (var day = 1; day <= 4; day++) {
          clock.setTo(DateTime.utc(2026, 1, day, 9));
          await service.createBackup();
        }

        expect(
          service.listBackups(kind: BackupKind.preMigration),
          hasLength(2),
        );
        expect(service.listBackups(kind: BackupKind.daily), hasLength(1));
      },
    );

    test('a failure leaves the previous backup untouched', () async {
      final db = await openFileDatabase();
      addTearDown(db.close);
      await seed(db);

      final clock = FakeClock(DateTime.utc(2026, 3, 5, 9));
      final service = BackupService(
        database: db,
        backupDirectory: Directory('${workspace.path}/backups'),
        clock: clock,
      );
      final good = (await service.createBackup()).unwrap();
      final goodBytes = good.lengthSync();

      // Closing the database makes the next VACUUM INTO fail.
      await db.close();
      clock.advance(const Duration(days: 1));
      final failed = await service.createBackup();

      expect(failed.isErr, isTrue);
      expect(good.existsSync(), isTrue);
      expect(good.lengthSync(), goodBytes);
      expect(
        service.directory.listSync().where(
          (FileSystemEntity e) => e.path.endsWith('.partial'),
        ),
        isEmpty,
        reason: 'a failed backup must not leave a staging file behind',
      );
    });
  });
}

String _stampOf(File file) {
  final name = file.path.split(RegExp(r'[/\\]')).last;
  return name.substring(name.indexOf('-') + 1, name.lastIndexOf('.sqlite'));
}
