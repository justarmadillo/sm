/// The v17 to v18 upgrade adds empty tag tables without rewriting content.
library;

import 'dart:io';

import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v18-');
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

  test('adds tags and preserves existing rows', () async {
    final AppDatabase seeded = await openDatabase();
    await seeded.customStatement(
      'INSERT INTO sources (id, title, markdown, content_hash, word_count, '
      "imported_at_utc, revision) VALUES ('source', 'Title', 'Body', "
      "'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 1, 0, 1)",
    );
    await seeded.customStatement('DROP TABLE element_tags');
    await seeded.customStatement('DROP TABLE tags');
    await seeded.customStatement('PRAGMA user_version = 17');
    await seeded.close();

    final AppDatabase upgraded = await openDatabase();
    addTearDown(upgraded.close);
    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, kSchemaVersion);
    for (final String table in <String>['tags', 'element_tags']) {
      final rows = await upgraded
          .customSelect('PRAGMA table_info($table)')
          .get();
      expect(rows, isNotEmpty);
    }
    final source = await upgraded
        .customSelect("SELECT title FROM sources WHERE id = 'source'")
        .getSingle();
    expect(source.read<String>('title'), 'Title');

    await upgraded.customStatement(
      "INSERT INTO tags VALUES ('one', 'Cardio', 'cardio', 0, 0)",
    );
    await expectLater(
      upgraded.customStatement(
        "INSERT INTO tags VALUES ('two', 'cardio', 'cardio', 0, 0)",
      ),
      throwsA(isA<Object>()),
    );
  });
}
