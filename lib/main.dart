import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/data/database/app_database.dart';
import 'src/data/database/connection.dart';
import 'src/data/files/backup_service.dart';
import 'src/data/platform/app_paths.dart';

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
