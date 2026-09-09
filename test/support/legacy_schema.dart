/// Fixtures that put the database back into a shape a past version wrote.
///
/// A migration test has to start from the schema the migration was written
/// against, and the current `tables.dart` cannot produce it — the whole point
/// of the migration is that the old shape is gone. These helpers rebuild that
/// shape by hand so the upgrade under test has something real to upgrade.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Restores the retired `extract_id`/`source_id` pair so a suite can seed the
/// pre-v6 shape these migrations were written against. The v6 step rebuilds
/// the table and drops them again, which is exactly what is under test.
Future<void> addLegacyCardParentColumns(AppDatabase database) async {
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
