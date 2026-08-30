/// Every object the whole application shares, built in one place.
///
/// Riverpod is the wiring mechanism here, not a service locator: every
/// dependency below is constructor-injected and private, so a command
/// runner or repository can be built in a test with no Riverpod at all.
/// This file is where the concrete database, clock, and timezone rules are
/// chosen, and the only place those decisions are made.
///
/// Anything only one screen uses lives in that screen's own
/// `<feature>_providers.dart` instead.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/scheduling/effective_due_query.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_runtime_store.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/settings_store.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/fan_out_diagnostic_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/in_memory_diagnostic_sink.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/database_maintenance.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/contracts/settings_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/drift/drift_content_repository.dart';
import 'package:incremental_reader/storage/drift/drift_database_maintenance.dart';
import 'package:incremental_reader/storage/drift/drift_learning_repository.dart';
import 'package:incremental_reader/storage/drift/drift_search_repository.dart';
import 'package:incremental_reader/storage/drift/drift_settings_repository.dart';
import 'package:incremental_reader/storage/drift/drift_transaction_runner.dart';
import 'package:incremental_reader/storage/drift/drift_transfer_repository.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:incremental_reader/storage/files/rotating_log_sink.dart';
import 'package:incremental_reader/storage/platform/app_paths.dart';
import 'package:incremental_reader/storage/platform/time_zones.dart';

/// Version reported in the diagnostic log alongside the schema version.
const String kAppVersion = '1.0.0-m4';

/// The open database. Overridden at bootstrap with the real connection.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw StateError('databaseProvider must be overridden'),
);

/// Resolved application paths. Overridden at bootstrap.
final Provider<AppPaths> appPathsProvider = Provider<AppPaths>(
  (Ref ref) => throw StateError('appPathsProvider must be overridden'),
);

/// Identifier of this installation, used for dataset ownership.
final Provider<String> deviceIdProvider = Provider<String>(
  (Ref ref) => 'windows-local',
);

/// The clock every layer reads time from.
final Provider<Clock> clockProvider = Provider<Clock>(
  (Ref ref) => const SystemClock(),
);

/// Identifier generation.
final Provider<IdGenerator> idGeneratorProvider = Provider<IdGenerator>(
  (Ref ref) => UuidGenerator.create(),
);

/// The most recent diagnostic events, for the panel.
final Provider<InMemoryDiagnosticSink> diagnosticBufferProvider =
    Provider<InMemoryDiagnosticSink>((Ref ref) => InMemoryDiagnosticSink());

/// Where the rotating diagnostic log is written.
///
/// Null by default so nothing in the provider graph depends on a resolved
/// filesystem: `main` overrides it, and a test gets in-memory diagnostics
/// without having to supply application paths it does not care about.
final Provider<Directory?> logDirectoryProvider = Provider<Directory?>(
  (Ref ref) => null,
);

/// Structured diagnostics: an in-memory ring for the panel plus, once a log
/// directory is supplied, the rotating file that survives a restart.
final Provider<DiagnosticSink> diagnosticsProvider = Provider<DiagnosticSink>((
  Ref ref,
) {
  final InMemoryDiagnosticSink buffer = ref.watch(diagnosticBufferProvider);
  final Directory? directory = ref.watch(logDirectoryProvider);
  final AppSettings settings = ref
      .watch(settingsStoreProvider)
      .currentOrDefaults;
  if (directory == null || !settings.diagnostics.isLogEnabled) return buffer;
  return FanOutDiagnosticSink(<DiagnosticSink>[
    buffer,
    RotatingLogSink(
      directory: directory,
      appVersion: kAppVersion,
      maxBytes: settings.diagnostics.logMaxBytes,
      retainedFiles: settings.diagnostics.logRetainedFiles,
    ),
  ]);
});

/// Turns a stored zone identifier into offset rules.
///
/// Injected as a function so scheduling/ never imports platform timezone
/// code, and so a test can supply a fake DST transition.
final Provider<TimeZoneResolver> timeZoneResolverProvider =
    Provider<TimeZoneResolver>((Ref ref) => resolveTimeZone);

/// Reads and caches the collection's configuration.
final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (Ref ref) => SettingsStore(ref.watch(settingsRepositoryProvider)),
);

final Provider<Sm20RuntimeStore> sm20RuntimeStoreProvider =
    Provider<Sm20RuntimeStore>(
      (Ref ref) => Sm20RuntimeStore(ref.watch(settingsRepositoryProvider)),
    );

/// Builds schedulers, the calendar, and the priority scale from live settings.
final Provider<SchedulingContext> schedulingContextProvider =
    Provider<SchedulingContext>(
      (Ref ref) => SchedulingContext(
        settings: ref.watch(settingsStoreProvider),
        learning: ref.watch(learningRepositoryProvider),
        runtime: ref.watch(sm20RuntimeStoreProvider),
        clock: ref.watch(clockProvider),
        resolveZone: ref.watch(timeZoneResolverProvider),
      ),
    );

/// The study-day rules currently in force.
///
/// A synchronous convenience for widgets. Anything that decides a schedule
/// must go through [SchedulingContext] instead, which re-reads settings.
final Provider<StudyDayCalendar> studyCalendarProvider =
    Provider<StudyDayCalendar>((Ref ref) {
      final AppSettings settings = ref
          .watch(settingsStoreProvider)
          .currentOrDefaults;
      return StudyDayCalendar(
        zone: ref.watch(timeZoneResolverProvider)(settings.studyDay.zoneId),
        rollover: Duration(minutes: settings.studyDay.rolloverMinutes),
      );
    });

/// Shared transaction scope.
final Provider<TransactionRunner> transactionRunnerProvider =
    Provider<TransactionRunner>(
      (Ref ref) => DriftTransactionRunner(ref.watch(databaseProvider)),
    );

/// Content aggregate.
final Provider<ContentRepository> contentRepositoryProvider =
    Provider<ContentRepository>(
      (Ref ref) => DriftContentRepository(ref.watch(databaseProvider)),
    );

/// Learning aggregate: schedules, pacing, priority, activity, repetition log.
final Provider<LearningRepository> learningRepositoryProvider =
    Provider<LearningRepository>(
      (Ref ref) => DriftLearningRepository(ref.watch(databaseProvider)),
    );

/// Settings aggregate.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
    );

/// Full-text search aggregate.
final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>(
      (Ref ref) => DriftSearchRepository(ref.watch(databaseProvider)),
    );

/// Whole-file housekeeping: integrity, the search index, and compaction.
final Provider<DatabaseMaintenance> databaseMaintenanceProvider =
    Provider<DatabaseMaintenance>(
      (Ref ref) => DriftDatabaseMaintenance(ref.watch(databaseProvider)),
    );

/// Transfer aggregate.
final Provider<TransferRepository> transferRepositoryProvider =
    Provider<TransferRepository>(
      (Ref ref) => DriftTransferRepository(
        ref.watch(databaseProvider),
        ref.watch(idGeneratorProvider),
        ref.watch(deviceIdProvider),
      ),
    );

/// Rolling backups of the live database.
final Provider<BackupService> backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(
    database: ref.watch(databaseProvider),
    backupDirectory: ref.watch(appPathsProvider).backupDirectory,
    clock: ref.watch(clockProvider),
    diagnostics: ref.watch(diagnosticsProvider),
  ),
);

/// The one adjustment-aware "when does this come back?" for screens.
final Provider<EffectiveDueQuery> effectiveDueQueryProvider =
    Provider<EffectiveDueQuery>(
      (Ref ref) => EffectiveDueQuery(
        learning: ref.watch(learningRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
      ),
    );
