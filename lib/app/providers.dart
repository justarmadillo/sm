/// The composition root.
///
/// Riverpod is used as the wiring mechanism, not as a service locator: every
/// dependency below this file is constructor-injected and private, so a
/// handler or repository can be built in a test with no Riverpod at all. The
/// container is where the concrete database, clock, and timezone rules are
/// chosen, and the only place those decisions are made.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/daily_queue/mercy_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/diagnostics/diagnostics_query.dart';
import 'package:incremental_reader/features/diagnostics/scheduler_metrics_query.dart';
import 'package:incremental_reader/features/extract/extraction_command_runner.dart';
import 'package:incremental_reader/features/extract/formulation_command_runner.dart';
import 'package:incremental_reader/features/library/content_tree_query.dart';
import 'package:incremental_reader/features/priority/browser_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
import 'package:incremental_reader/features/search/search_query.dart';
import 'package:incremental_reader/scheduling/effective_due_query.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_runtime_store.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/settings_store.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/contracts/repositories.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/drift/drift_repositories.dart';
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
  if (directory == null || !settings.diagnostics.logEnabled) return buffer;
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
/// Injected as a function so the domain and application layers never import
/// platform timezone code, and so a test can supply a fake DST transition.
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

/// Transfer aggregate.
final Provider<TransferRepository> transferRepositoryProvider =
    Provider<TransferRepository>(
      (Ref ref) => DriftTransferRepository(
        ref.watch(databaseProvider),
        ref.watch(idGeneratorProvider),
        ref.watch(deviceIdProvider),
      ),
    );

/// Library read projection.
/// The knowledge tree: every element nested under the one it came from.
final Provider<ContentTreeQuery> contentTreeQueryProvider =
    Provider<ContentTreeQuery>(
      (Ref ref) => ContentTreeQuery(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
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

/// Handlers for every Reader and Library mutation.
final Provider<ReaderCommandRunner> readerCommandRunnerProvider =
    Provider<ReaderCommandRunner>(
      (Ref ref) => ReaderCommandRunner(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Handlers for creating, undoing, and editing extracts.
final Provider<ExtractionCommandRunner> extractionCommandRunnerProvider =
    Provider<ExtractionCommandRunner>(
      (Ref ref) => ExtractionCommandRunner(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Batch card formulation without mutating the parent extract.
final Provider<FormulationCommandRunner> formulationCommandRunnerProvider =
    Provider<FormulationCommandRunner>(
      (Ref ref) => FormulationCommandRunner(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Exactly-once FSRS review handler, plus undo, edit, and burying.
final Provider<ReviewCommandRunner> reviewCommandRunnerProvider =
    Provider<ReviewCommandRunner>(
      (Ref ref) => ReviewCommandRunner(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Relative priority: slider, browser, and bulk spread.
final Provider<PriorityCommandRunner> priorityCommandRunnerProvider =
    Provider<PriorityCommandRunner>(
      (Ref ref) => PriorityCommandRunner(
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// SM20's browser Learning command group.
final Provider<BrowserCommandRunner> browserCommandRunnerProvider =
    Provider<BrowserCommandRunner>(
      (Ref ref) => BrowserCommandRunner(
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// The daily queue transaction, the manual stage commands, and Mercy.
final Provider<QueueCommandRunner> queueCommandRunnerProvider = Provider<QueueCommandRunner>(
  (Ref ref) => QueueCommandRunner(
    content: ref.watch(contentRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    transfer: ref.watch(transferRepositoryProvider),
    transactions: ref.watch(transactionRunnerProvider),
    context: ref.watch(schedulingContextProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
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

/// Scheduler safety metrics for the diagnostics panel.
final Provider<SchedulerMetricsQuery> schedulerMetricsQueryProvider =
    Provider<SchedulerMetricsQuery>(
      (Ref ref) => SchedulerMetricsQuery(
        learning: ref.watch(learningRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
        queue: ref.watch(queueCommandRunnerProvider),
      ),
    );

/// Mercy: preview, apply, and exact batch undo.
final Provider<MercyCommandRunner> mercyCommandRunnerProvider = Provider<MercyCommandRunner>(
  (Ref ref) => MercyCommandRunner(
    learning: ref.watch(learningRepositoryProvider),
    transfer: ref.watch(transferRepositoryProvider),
    transactions: ref.watch(transactionRunnerProvider),
    context: ref.watch(schedulingContextProvider),
    queue: ref.watch(queueCommandRunnerProvider),
    ids: ref.watch(idGeneratorProvider),
  ),
);

/// Today's admitted, mixed, and randomized queue.
final Provider<QueueQuery> queueQueryProvider = Provider<QueueQuery>(
  (Ref ref) => QueueQuery(
    content: ref.watch(contentRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    commandRunner: ref.watch(queueCommandRunnerProvider),
    context: ref.watch(schedulingContextProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Priority projections for the slider and the browser.
final Provider<PriorityQuery> priorityQueryProvider = Provider<PriorityQuery>(
  (Ref ref) => PriorityQuery(
    content: ref.watch(contentRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    context: ref.watch(schedulingContextProvider),
  ),
);

/// Full-text search across the collection.
final Provider<SearchQuery> searchQueryProvider = Provider<SearchQuery>(
  (Ref ref) => SearchQuery(
    search: ref.watch(searchRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    effectiveDue: ref.watch(effectiveDueQueryProvider),
  ),
);

/// The development diagnostics panel's read model.
final Provider<DiagnosticsQuery> diagnosticsQueryProvider =
    Provider<DiagnosticsQuery>(
      (Ref ref) => DiagnosticsQuery(
        learning: ref.watch(learningRepositoryProvider),
        content: ref.watch(contentRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
      ),
    );

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

  if (await settings.read(kLastBackupDayKey) == today) return null;

  final result = await container.read(backupServiceProvider).createBackup();
  if (result.isErr) return null;
  await settings.write(kLastBackupDayKey, today);
  return result.valueOrNull;
}

/// Loads settings once before the first frame.
///
/// The synchronous providers above read [SettingsStore.currentOrDefaults], so
/// the store has to be warm before any of them is watched, or the first frame
/// would render against shipped defaults and then jump.
Future<AppSettings> warmSettings(ProviderContainer container) =>
    container.read(settingsStoreProvider).load();
