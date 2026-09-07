/// The v16 to v17 upgrade widens card types and preserves existing clozes.
library;

import 'dart:io';

import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v17-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openDatabase() async {
    final database = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  Future<void> seedV16(AppDatabase database) async {
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database.customStatement('DROP TABLE card_occlusions');
    await database.customStatement('DROP TABLE cards');
    await database.customStatement('''
      CREATE TABLE cards (
        id TEXT NOT NULL PRIMARY KEY,
        parent_element_id TEXT NULL,
        parent_element_type INTEGER NULL CHECK(parent_element_type IN (0, 1, 3)),
        type INTEGER NOT NULL CHECK(type BETWEEN 0 AND 1),
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        cloze_ordinal INTEGER NULL,
        created_at_utc INTEGER NOT NULL,
        edited_at_utc INTEGER NULL,
        CHECK ((type = 1) = (cloze_ordinal IS NOT NULL)),
        CHECK ((parent_element_id IS NULL) = (parent_element_type IS NULL))
      )
    ''');
    await database.customStatement(
      "INSERT INTO cards VALUES ('old-cloze', NULL, NULL, 1, "
      "'{{c1::Paris}}', '', 1, 1000, NULL)",
    );
    await database.customStatement('PRAGMA user_version = 16');
  }

  test(
    'old cloze survives and only appended card types are accepted',
    () async {
      final seeded = await openDatabase();
      await seedV16(seeded);
      await seeded.close();

      final upgraded = await openDatabase();
      addTearDown(upgraded.close);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.single, kSchemaVersion);
      final old = await upgraded
          .customSelect("SELECT front FROM cards WHERE id = 'old-cloze'")
          .getSingle();
      expect(old.read<String>('front'), '{{c1::Paris}}');
      final videoColumns = await upgraded
          .customSelect('PRAGMA table_info(videos)')
          .get();
      expect(
        videoColumns.map((row) => row.read<String>('name')),
        contains('thumbnail_url'),
      );

      await upgraded.customStatement(
        'INSERT INTO cards (id, type, front, back, created_at_utc) '
        "VALUES ('occlusion', 3, '', '', 1000)",
      );
      await expectLater(
        upgraded.customStatement(
          'INSERT INTO cards (id, type, front, back, created_at_utc) '
          "VALUES ('future', 4, '', '', 1000)",
        ),
        throwsA(isA<Object>()),
      );
    },
  );
}
