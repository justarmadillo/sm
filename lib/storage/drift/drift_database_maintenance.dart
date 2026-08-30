/// Compacts and repairs the database file, using Drift.
///
/// SQL and pragmas, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs.
library;

import 'package:incremental_reader/storage/contracts/database_maintenance.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Whole-file housekeeping: check, repair what is derived, compact.
final class DriftDatabaseMaintenance implements DatabaseMaintenance {
  const DriftDatabaseMaintenance(this._database);

  final AppDatabase _database;

  /// The order below is the whole design, so it is worth stating:
  ///
  /// 1. Check first. Compacting a corrupt file rewrites the corruption into a
  ///    tidier corruption, and the user finds out later rather than now.
  /// 2. Repair the search index before compacting, because a rebuild writes
  ///    the pages that step three is about to reclaim.
  /// 3. Fold the write-ahead log back into the file. `VACUUM` cannot reclaim
  ///    what is still only in the WAL, so skipping this makes the compaction
  ///    look like it achieved nothing.
  /// 4. `VACUUM` rewrites the file without its free pages.
  /// 5. `ANALYZE` last, so the statistics describe the file that now exists
  ///    rather than the one that did.
  @override
  Future<DatabaseMaintenanceReport> optimize() async {
    final int bytesBefore = await _fileBytes();
    final List<String> problems = await _check();

    final bool wasSearchIndexRebuilt = !await _database
        .isSearchIndexInStepWithContent();
    if (wasSearchIndexRebuilt) {
      await _database.rebuildSearchIndex();
    }
    await _database.optimizeSearchIndex();

    await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    await _database.customStatement('VACUUM');
    await _database.customStatement('ANALYZE');

    return DatabaseMaintenanceReport(
      bytesBefore: bytesBefore,
      bytesAfter: await _fileBytes(),
      problems: problems,
      wasSearchIndexRebuilt: wasSearchIndexRebuilt,
    );
  }

  /// What the collection reports about itself, in the user's words rather than
  /// SQLite's.
  ///
  /// A foreign key that no longer resolves is listed separately from a corrupt
  /// page because the two mean different things: the first is a row pointing
  /// at something deleted, the second is the file itself being unreadable.
  Future<List<String>> _check() async {
    final List<String> problems = <String>[];

    final List<String> integrity = await _database.integrityCheck();
    if (integrity.length != 1 || integrity.single != 'ok') {
      problems.addAll(integrity);
    }
    if (!await _database.foreignKeysValid()) {
      problems.add('Some rows point at elements that are no longer there.');
    }
    return problems;
  }

  /// Size of the database file, asked of SQLite rather than of the filesystem.
  ///
  /// The file on disk is only part of the answer while a write-ahead log sits
  /// beside it, and this class runs either side of a checkpoint.
  Future<int> _fileBytes() async {
    final int pageCount = await _pragmaInt('page_count');
    final int pageSize = await _pragmaInt('page_size');
    return pageCount * pageSize;
  }

  Future<int> _pragmaInt(String pragma) async {
    final rows = await _database.customSelect('PRAGMA $pragma').get();
    if (rows.isEmpty) return 0;
    return rows.single.data.values.first as int;
  }
}
