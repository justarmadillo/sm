/// Saves and loads settings keys and values, using Drift.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs. A repository that starts making
/// policy is how scheduling rules end up spread across three folders.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/storage/contracts/settings_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Key/value settings.
final class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<String?> findValue(String key) async {
    final row = await (_database.select(
      _database.settings,
    )..where(($SettingsTable t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> saveValue(String key, String value) => _database
      .into(_database.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  @override
  Future<Map<String, String>> listAllValues() async {
    final rows = await _database.select(_database.settings).get();
    return <String, String>{for (final row in rows) row.key: row.value};
  }

  @override
  Future<void> saveAllValues(Map<String, String> values) async {
    if (values.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(_database.settings, <SettingsCompanion>[
        for (final entry in values.entries)
          SettingsCompanion.insert(key: entry.key, value: entry.value),
      ]);
    });
  }

  @override
  Future<void> deleteKey(String key) async {
    await (_database.delete(
      _database.settings,
    )..where(($SettingsTable t) => t.key.equals(key))).go();
  }
}
