/// Verifies that startup failures are classified before Drift reaches the UI.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:incremental_reader/app/startup_gate.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  late Directory workspace;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('ir_startup_gate_test_');
  });

  tearDown(() {
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('opens a missing collection as a fresh install', () async {
    final Result<AppDatabase> result = await openCollectionOrFail(
      databaseFile: File('${workspace.path}/db/collection.sqlite'),
      backupDirectory: Directory('${workspace.path}/backups'),
    );

    expect(result.isOk, isTrue);
    await result.unwrap().close();
  });

  test('rejects a schema written by a newer app', () async {
    final File file = File('${workspace.path}/newer.sqlite');
    final sqlite.Database raw = sqlite.sqlite3.open(file.path);
    raw.userVersion = kSchemaVersion + 1;
    raw.close();

    final Result<AppDatabase> result = await openCollectionOrFail(
      databaseFile: file,
      backupDirectory: Directory('${workspace.path}/backups'),
    );

    expect(_failureKind(result), StartupFailureKind.schemaTooNew);
  });

  test('reports a file SQLite cannot read', () async {
    final File file = File('${workspace.path}/unreadable.sqlite')
      ..writeAsStringSync('not a sqlite database');

    final Result<AppDatabase> result = await openCollectionOrFail(
      databaseFile: file,
      backupDirectory: Directory('${workspace.path}/backups'),
    );

    expect(_failureKind(result), StartupFailureKind.unreadable);
  });

  test('reports page corruption without opening Drift', () async {
    final File file = File('${workspace.path}/corrupt.sqlite');
    final AppDatabase database = openDatabaseAt(file);
    await database.customSelect('SELECT 1').get();
    await database.close();
    final Uint8List bytes = file.readAsBytesSync();
    bytes.fillRange(4096, 4608, 0xff);
    file.writeAsBytesSync(bytes);

    final Result<AppDatabase> result = await openCollectionOrFail(
      databaseFile: file,
      backupDirectory: Directory('${workspace.path}/backups'),
    );

    expect(_failureKind(result), StartupFailureKind.corruptDatabase);
  });

  test('blocks migration when its required backup cannot be written', () async {
    final File file = File('${workspace.path}/old.sqlite');
    final sqlite.Database raw = sqlite.sqlite3.open(file.path);
    raw.userVersion = kSchemaVersion - 1;
    raw.close();
    final File blockedBackupPath = File('${workspace.path}/backups')
      ..writeAsStringSync('not a directory');

    final Result<AppDatabase> result = await openCollectionOrFail(
      databaseFile: file,
      backupDirectory: Directory(blockedBackupPath.path),
    );

    expect(_failureKind(result), StartupFailureKind.backupFailed);
  });
}

StartupFailureKind? _failureKind(Result<AppDatabase> result) {
  final failure = result.failureOrNull;
  return failure is StartupFailure ? failure.kind : null;
}
