/// The v19 to v20 upgrade adds empty custom-deck tables without rewriting
/// anything that was already stored.
library;

import 'dart:io';

import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v20-');
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

  Future<AppDatabase> upgradedFromV19() async {
    final AppDatabase seeded = await openDatabase();
    await seeded.customStatement(
      "INSERT INTO tags VALUES ('pharm', 'Pharmacology', 'pharmacology', 0, 0)",
    );
    await seeded.customStatement('DROP TABLE custom_deck_tags');
    await seeded.customStatement('DROP TABLE custom_decks');
    await seeded.customStatement('PRAGMA user_version = 19');
    await seeded.close();
    return openDatabase();
  }

  test('adds the deck tables and keeps existing tags', () async {
    final AppDatabase upgraded = await upgradedFromV19();
    addTearDown(upgraded.close);

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, kSchemaVersion);
    for (final String table in <String>['custom_decks', 'custom_deck_tags']) {
      expect(
        await upgraded.customSelect('PRAGMA table_info($table)').get(),
        isNotEmpty,
      );
    }
    final tag = await upgraded
        .customSelect("SELECT name FROM tags WHERE id = 'pharm'")
        .getSingle();
    expect(tag.read<String>('name'), 'Pharmacology');
  });

  test('deleting a tag removes it from every deck', () async {
    final AppDatabase upgraded = await upgradedFromV19();
    addTearDown(upgraded.close);

    await upgraded.customStatement(
      'INSERT INTO custom_decks (id, name, name_lowercase, tag_match, '
      'element_types, should_reschedule, session_limit, study_order, '
      "is_due_only, created_at_utc, updated_at_utc) VALUES ('deck', 'Pharm', "
      "'pharm', 0, 15, 1, NULL, 0, 0, 0, 0)",
    );
    await upgraded.customStatement(
      "INSERT INTO custom_deck_tags VALUES ('deck', 'pharm', 0)",
    );
    await upgraded.customStatement("DELETE FROM tags WHERE id = 'pharm'");

    expect(
      await upgraded.customSelect('SELECT * FROM custom_deck_tags').get(),
      isEmpty,
    );
  });

  test('the upgrade is safe to run twice', () async {
    final AppDatabase upgraded = await upgradedFromV19();
    await upgraded.customStatement('PRAGMA user_version = 19');
    await upgraded.close();

    final AppDatabase again = await openDatabase();
    addTearDown(again.close);
    final version = await again.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, kSchemaVersion);
  });
}
