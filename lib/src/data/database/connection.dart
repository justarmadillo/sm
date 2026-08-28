/// Opening the live database and its in-memory test twin.
///
/// The live file belongs in platform-local application storage and must never
/// sit in Syncthing, OneDrive, Drive, or any other synced folder: a sync
/// client copying WAL files out from under SQLite corrupts the database, and
/// the corruption surfaces much later than the copy.
library;

import 'dart:io';

import 'package:drift/native.dart';

import 'package:incremental_reader/src/data/database/app_database.dart';

/// File name of the live database inside the application support directory.
const String kDatabaseFileName = 'incremental_reader.sqlite';

/// Opens the live database at [file], creating parent directories as needed.
AppDatabase openDatabaseAt(File file) {
  file.parent.createSync(recursive: true);
  return AppDatabase(NativeDatabase(file, setup: _applyConnectionPragmas));
}

/// Opens a private in-memory database, for tests and diagnostics.
AppDatabase openInMemoryDatabase() =>
    AppDatabase(NativeDatabase.memory(setup: _applyConnectionPragmas));

/// Pragmas that must be set before Drift issues any statement.
void _applyConnectionPragmas(dynamic database) {
  // ignore: avoid_dynamic_calls
  database.execute('PRAGMA foreign_keys = ON');
}
