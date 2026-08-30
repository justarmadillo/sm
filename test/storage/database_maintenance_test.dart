/// Optimizing a collection: it compacts, it repairs, and it changes nothing.
///
/// The whole value of this operation rests on one promise — that running it is
/// never a decision the user could regret — so what is tested here is mostly
/// that the rows on the far side are the rows that went in.
library;

import 'dart:io';

import 'package:incremental_reader/storage/contracts/database_maintenance.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_database_maintenance.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;
  late AppDatabase database;
  late DatabaseMaintenance maintenance;

  setUp(() async {
    workspace = Directory.systemTemp.createTempSync('ir-maintenance-');
    database = openDatabaseAt(File('${workspace.path}/db/$kDatabaseFileName'));
    await database.customSelect('SELECT 1').getSingle();
    maintenance = DriftDatabaseMaintenance(database);
  });

  tearDown(() async {
    await database.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  /// Writes [count] searchable documents, each large enough that deleting them
  /// leaves free pages a compaction can actually hand back.
  ///
  /// [firstIndex] moves the element ids along, so a test can write a second
  /// batch without colliding with the primary key of the first.
  Future<void> writeSearchDocuments(int count, {int firstIndex = 0}) async {
    final String body = 'chlorophyll absorbs light ' * 400;
    for (var offset = 0; offset < count; offset++) {
      final int index = firstIndex + offset;
      await database.customStatement(
        'INSERT INTO search_documents '
        '(element_id, element_type, title, body, source_id, updated_at_utc) '
        "VALUES ('e$index', 0, 'Article $index', '$body', NULL, 0)",
      );
    }
  }

  Future<int> countSearchDocuments() async {
    final rows = await database
        .customSelect('SELECT COUNT(*) AS total FROM search_documents')
        .getSingle();
    return rows.read<int>('total');
  }

  Future<int> countSearchIndexMatches(String term) async {
    final rows = await database
        .customSelect(
          'SELECT COUNT(*) AS total FROM $kSearchIndexTable '
          "WHERE $kSearchIndexTable MATCH '$term'",
        )
        .getSingle();
    return rows.read<int>('total');
  }

  test('a fresh collection reports itself sound', () async {
    final DatabaseMaintenanceReport report = await maintenance.optimize();

    expect(report.isHealthy, isTrue);
    expect(report.problems, isEmpty);
    expect(report.wasSearchIndexRebuilt, isFalse);
  });

  test('space freed by deleted elements is handed back', () async {
    await writeSearchDocuments(60);
    await maintenance.optimize();

    await database.customStatement('DELETE FROM search_documents');
    final DatabaseMaintenanceReport report = await maintenance.optimize();

    expect(report.isHealthy, isTrue);
    expect(
      report.bytesReclaimed,
      greaterThan(0),
      reason: 'sixty deleted articles leave free pages VACUUM can return',
    );
    expect(report.bytesAfter, lessThan(report.bytesBefore));
  });

  test('every row and every search term survives the pass', () async {
    await writeSearchDocuments(12);

    await maintenance.optimize();

    expect(await countSearchDocuments(), 12);
    expect(await countSearchIndexMatches('chlorophyll'), 12);
  });

  test('reclaimed bytes are never reported as negative', () async {
    await writeSearchDocuments(4);
    final DatabaseMaintenanceReport report = await maintenance.optimize();

    expect(report.bytesReclaimed, greaterThanOrEqualTo(0));
  });

  test(
    'a search index that has fallen behind its content is rebuilt',
    () async {
      // Writing content while the insert trigger is missing is how an
      // external-content index really drifts: the rows are there, the terms
      // never were, and nothing reports it because neither table is wrong on
      // its own.
      await database.customStatement('DROP TRIGGER search_documents_ai');
      await writeSearchDocuments(8);
      expect(await countSearchIndexMatches('chlorophyll'), 0);

      final DatabaseMaintenanceReport report = await maintenance.optimize();

      expect(report.wasSearchIndexRebuilt, isTrue);
      expect(report.isHealthy, isTrue);
      expect(await countSearchIndexMatches('chlorophyll'), 8);
    },
  );

  test('the collection is still usable after optimizing', () async {
    await writeSearchDocuments(3);
    await maintenance.optimize();

    await writeSearchDocuments(1, firstIndex: 3);

    expect(await countSearchDocuments(), 4);
    expect(await database.isHealthy(), isTrue);
    expect(await database.foreignKeysValid(), isTrue);
  });
}
