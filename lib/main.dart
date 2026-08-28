import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:incremental_reader/src/app/app.dart';
import 'package:incremental_reader/src/app/providers.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/data/files/backup_service.dart';
import 'package:incremental_reader/src/data/platform/app_paths.dart';

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
