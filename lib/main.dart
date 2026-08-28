/// Where the app starts.
///
/// Four things have to happen before the first frame, in this order: find the
/// folders, copy the database if a migration is about to run, open it, and
/// load the user's settings. Everything after that is wired in
/// `app/providers.dart` and drawn by `app/incremental_reader_app.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/incremental_reader_app.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/app/startup_tasks.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/platform/app_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final paths = await AppPaths.resolve();
  paths.ensureCreated();
  final migrationBackup = createPreMigrationBackupIfNeeded(
    databaseFile: paths.databaseFile,
    backupDirectory: paths.backupDirectory,
    targetSchemaVersion: kSchemaVersion,
  );
  if (migrationBackup.isErr) {
    throw StateError(migrationBackup.failureOrNull!.message);
  }
  final database = openDatabaseAt(paths.databaseFile);

  final container = ProviderContainer(
    overrides: <Override>[
      appPathsProvider.overrideWithValue(paths),
      databaseProvider.overrideWithValue(database),
      logDirectoryProvider.overrideWithValue(paths.logDirectory),
    ],
  );

  // Settings first: the synchronous providers read a cached configuration,
  // so warming the store before the first frame stops the app rendering
  // against shipped defaults and then jumping to the user's own values.
  await warmSettings(container);

  // A rolling backup before the session writes anything, so the copy on disk
  // always predates the day's changes.
  await runDailyBackupIfDue(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const IncrementalReaderApp(),
    ),
  );
}
