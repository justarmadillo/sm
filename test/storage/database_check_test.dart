/// Verifies that logical database repairs are atomic and idempotent.
library;

import 'dart:io';

import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/storage/contracts/database_check.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_database_check.dart';
import 'package:incremental_reader/storage/drift/drift_transaction_runner.dart';
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_database_check_test_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('fresh collection is sound', () async {
    final database = openDatabaseAt(
      File('${workspace.path}/collection.sqlite'),
    );
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    final check = DriftDatabaseCheck(
      database,
      DriftTransactionRunner(database),
      RecordingDiagnosticSink(),
    );

    final DatabaseCheckReport report = await check.checkAndRepair();

    expect(report.outcome, DatabaseCheckOutcome.sound);
    expect(report.findings, isEmpty);
  });

  test('removes an orphaned schedule and second pass is empty', () async {
    final database = openDatabaseAt(
      File('${workspace.path}/collection.sqlite'),
    );
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    await database.customStatement('''
INSERT INTO element_schedules (
  element_id, element_type, priority_key, lifecycle, due_day,
  original_due_day, zone_id
) VALUES ('missing', 1, 'U', 0, 0, 0, 'UTC')''');
    final check = DriftDatabaseCheck(
      database,
      DriftTransactionRunner(database),
      RecordingDiagnosticSink(),
    );

    final DatabaseCheckReport first = await check.checkAndRepair();
    final DatabaseCheckReport second = await check.checkAndRepair();

    expect(
      first.findings
          .singleWhere(
            (DatabaseCheckFinding finding) =>
                finding.name == 'schedule_without_element',
          )
          .count,
      1,
    );
    expect(second.findings, isEmpty);
    expect(await database.select(database.elementSchedules).get(), isEmpty);
  });

  test('rolls every repair back when a later repair fails', () async {
    final database = openDatabaseAt(
      File('${workspace.path}/collection.sqlite'),
    );
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    await database.customStatement('''
INSERT INTO element_schedules (
  element_id, element_type, priority_key, lifecycle, due_day,
  original_due_day, zone_id
) VALUES ('missing', 1, 'U', 0, 0, 0, 'UTC')''');
    await database.customStatement('DROP TABLE search_index');
    final check = DriftDatabaseCheck(
      database,
      DriftTransactionRunner(database),
      RecordingDiagnosticSink(),
    );

    await expectLater(check.checkAndRepair(), throwsA(isA<Object>()));

    expect(
      await database.select(database.elementSchedules).get(),
      hasLength(1),
    );
  });
}
