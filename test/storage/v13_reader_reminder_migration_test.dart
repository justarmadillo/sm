/// The v12 to v13 upgrade: the retired reader reminder key is deleted.
///
/// The key configured a reminder line the Reader no longer has. Leaving the
/// row would not break anything — the decoder ignores keys it does not know —
/// but it would leave the collection claiming to hold a setting for a feature
/// that is gone, which is exactly the evidence a future reader would use to
/// conclude the feature is still there.
library;

import 'dart:io';

import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir-v13-');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  Future<AppDatabase> openFileDatabase() async {
    final AppDatabase database = openDatabaseAt(
      File('${workspace.path}/db/$kDatabaseFileName'),
    );
    await database.customSelect('SELECT 1').getSingle();
    return database;
  }

  Future<String?> findSettingValue(AppDatabase database, String key) async {
    final rows = await database
        .customSelect("SELECT value FROM settings WHERE key = '$key'")
        .get();
    return rows.isEmpty ? null : rows.single.read<String>('value');
  }

  /// Puts the collection back at v12 with the retired key present, so the
  /// upgrade under test reads a schema that really shipped.
  Future<void> seedV12(AppDatabase database) async {
    await database.customStatement(
      'INSERT OR REPLACE INTO settings (key, value) '
      "VALUES ('reader.reminder_words', '800')",
    );
    await database.customStatement(
      'INSERT OR REPLACE INTO settings (key, value) '
      "VALUES ('study_day.zone_id', 'UTC')",
    );
    await database.customStatement('PRAGMA user_version = 12');
  }

  test('the retired reader reminder key is removed on upgrade', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV12(seeded);
    expect(
      await findSettingValue(seeded, 'reader.reminder_words'),
      '800',
      reason: 'the seed has to reproduce a collection that really had the key',
    );
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    expect(await findSettingValue(upgraded, 'reader.reminder_words'), isNull);
  });

  test('every other setting survives the upgrade', () async {
    final AppDatabase seeded = await openFileDatabase();
    await seedV12(seeded);
    await seeded.close();

    final AppDatabase upgraded = await openFileDatabase();
    addTearDown(upgraded.close);

    expect(await findSettingValue(upgraded, 'study_day.zone_id'), 'UTC');
  });

  test(
    'a collection with no reminder key upgrades without complaint',
    () async {
      final AppDatabase seeded = await openFileDatabase();
      await seeded.customStatement(
        'INSERT OR REPLACE INTO settings (key, value) '
        "VALUES ('study_day.zone_id', 'UTC')",
      );
      await seeded.customStatement('PRAGMA user_version = 12');
      await seeded.close();

      final AppDatabase upgraded = await openFileDatabase();
      addTearDown(upgraded.close);

      expect(await findSettingValue(upgraded, 'reader.reminder_words'), isNull);
      expect(await findSettingValue(upgraded, 'study_day.zone_id'), 'UTC');
    },
  );
}
