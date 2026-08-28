/// Work that has to finish before the first frame is drawn.
library;

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/storage/contracts/settings_repository.dart';

/// Setting key holding the day of the last successful backup.
const String kLastBackupDayKey = 'backup.last_day';

/// Takes at most one rolling backup per study day, at startup.
///
/// Startup is the only moment guaranteed to happen before the day's writes,
/// which is what makes it the right moment: the copy predates whatever the
/// session is about to do. A failure is never fatal — the user came here to
/// read, and a missing backup is reported rather than blocking the app.
Future<File?> runDailyBackupIfDue(ProviderContainer container) async {
  final SettingsRepository settings = container.read(
    settingsRepositoryProvider,
  );
  final String today = (await container.read(schedulingContextProvider).today())
      .toString();

  if (await settings.findValue(kLastBackupDayKey) == today) return null;

  final result = await container.read(backupServiceProvider).createBackup();
  if (result.isErr) return null;
  await settings.saveValue(kLastBackupDayKey, today);
  return result.valueOrNull;
}

/// Loads settings once before the first frame.
///
/// The synchronous providers in app/providers.dart read the settings store's
/// current values, so the store has to be warm before any of them is watched,
/// or the first frame would render against shipped defaults and then jump.
Future<AppSettings> warmSettings(ProviderContainer container) =>
    container.read(settingsStoreProvider).load();
