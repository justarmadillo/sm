/// Classifies collection failures before the provider graph is constructed.
library;

import 'dart:io';

import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

enum StartupFailureKind {
  corruptDatabase,
  schemaTooNew,
  unreadable,
  backupFailed,
}

/// A startup failure that recovery can explain without a live database.
@immutable
final class StartupFailure extends AppFailure {
  const StartupFailure(this.kind, super.message, {super.cause});

  final StartupFailureKind kind;
}

/// Opens a healthy collection only after raw SQLite checks and migration backup.
Future<Result<AppDatabase>> openCollectionOrFail({
  required File databaseFile,
  required Directory backupDirectory,
}) async {
  final bool isFresh =
      !databaseFile.existsSync() || databaseFile.lengthSync() == 0;
  if (!isFresh) {
    final StartupFailure? rawFailure = _inspectExistingDatabase(databaseFile);
    if (rawFailure != null) return Err<AppDatabase>(rawFailure);

    final Result<File?> backup = createPreMigrationBackupIfNeeded(
      databaseFile: databaseFile,
      backupDirectory: backupDirectory,
      targetSchemaVersion: kSchemaVersion,
    );
    if (backup.isErr) {
      return Err<AppDatabase>(
        StartupFailure(
          StartupFailureKind.backupFailed,
          backup.failureOrNull!.message,
          cause: backup.failureOrNull!.cause,
        ),
      );
    }
  }

  AppDatabase? database;
  try {
    database = openDatabaseAt(databaseFile);
    await database.customSelect('SELECT 1').get();
    return Ok<AppDatabase>(database);
  } on Object catch (error) {
    await database?.close();
    return Err<AppDatabase>(
      StartupFailure(
        StartupFailureKind.unreadable,
        'The collection could not be opened.',
        cause: error,
      ),
    );
  }
}

StartupFailure? _inspectExistingDatabase(File databaseFile) {
  sqlite.Database? rawDatabase;
  try {
    rawDatabase = sqlite.sqlite3.open(databaseFile.path);
  } on Object catch (error) {
    return StartupFailure(
      StartupFailureKind.unreadable,
      'The collection database could not be read.',
      cause: error,
    );
  }
  try {
    final sqlite.ResultSet check = rawDatabase.select('PRAGMA quick_check');
    final List<String> findings = check
        .map((sqlite.Row row) => row.values.first.toString())
        .toList();
    if (findings.length != 1 || findings.single != 'ok') {
      return StartupFailure(
        StartupFailureKind.corruptDatabase,
        'The collection database is corrupt: ${findings.join('; ')}',
      );
    }
    if (rawDatabase.userVersion > kSchemaVersion) {
      return StartupFailure(
        StartupFailureKind.schemaTooNew,
        'This collection was written by a newer version of the app.',
      );
    }
    return null;
  } on Object catch (error) {
    final StartupFailureKind kind =
        error is sqlite.SqliteException &&
            error.resultCode == sqlite.SqlError.SQLITE_NOTADB &&
            !_hasSqliteHeader(databaseFile)
        ? StartupFailureKind.unreadable
        : StartupFailureKind.corruptDatabase;
    return StartupFailure(
      kind,
      kind == StartupFailureKind.unreadable
          ? 'The collection database could not be read.'
          : 'The collection database is corrupt.',
      cause: error,
    );
  } finally {
    rawDatabase.close();
  }
}

bool _hasSqliteHeader(File file) {
  const List<int> signature = <int>[
    83,
    81,
    76,
    105,
    116,
    101,
    32,
    102,
    111,
    114,
    109,
    97,
    116,
    32,
    51,
    0,
  ];
  final RandomAccessFile openFile = file.openSync();
  try {
    final List<int> bytes = openFile.readSync(signature.length);
    if (bytes.length != signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  } finally {
    openFile.closeSync();
  }
}
