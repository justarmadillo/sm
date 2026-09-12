/// The v18 to v19 upgrade adds card Extra and preserves occlusion remarks.
library;

import 'dart:io';

import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v19-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openDatabase() async {
    final AppDatabase database = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  test('adds Extra and moves existing occlusion remarks into it', () async {
    final AppDatabase seeded = await openDatabase();
    await seeded.customStatement('PRAGMA foreign_keys = OFF');
    await seeded.customStatement('DROP TABLE cards');
    await seeded.customStatement('''
      CREATE TABLE cards (
        id TEXT NOT NULL PRIMARY KEY,
        parent_element_id TEXT NULL,
        parent_element_type INTEGER NULL CHECK(parent_element_type IN (0, 1, 3)),
        type INTEGER NOT NULL CHECK(type BETWEEN 0 AND 3),
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        cloze_ordinal INTEGER NULL,
        context_before INTEGER NULL,
        context_after INTEGER NULL,
        created_at_utc INTEGER NOT NULL,
        edited_at_utc INTEGER NULL,
        CHECK ((type IN (1, 2)) = (cloze_ordinal IS NOT NULL)),
        CHECK ((type = 2) = (context_before IS NOT NULL)),
        CHECK ((type = 2) = (context_after IS NOT NULL)),
        CHECK ((parent_element_id IS NULL) = (parent_element_type IS NULL))
      )
    ''');
    await seeded.customStatement(
      'INSERT INTO cards (id, type, front, back, created_at_utc) VALUES '
      "('qa', 0, 'Question', 'Answer', 1000), "
      "('occlusion', 3, 'Header', 'Old remarks', 1000)",
    );
    await seeded.customStatement('PRAGMA user_version = 18');
    await seeded.close();

    final AppDatabase upgraded = await openDatabase();
    addTearDown(upgraded.close);
    final rows = await upgraded
        .customSelect('SELECT id, back, extra FROM cards ORDER BY id')
        .get();

    expect(rows.first.read<String>('id'), 'occlusion');
    expect(rows.first.read<String>('back'), '');
    expect(rows.first.read<String>('extra'), 'Old remarks');
    expect(rows.last.read<String>('back'), 'Answer');
    expect(rows.last.read<String>('extra'), '');
  });
}
