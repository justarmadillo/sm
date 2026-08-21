/// The composition root.
///
/// Riverpod is used as the wiring mechanism, not as a service locator: every
/// dependency below this file is constructor-injected and private, so a
/// handler or repository can be built in a test with no Riverpod at all. The
/// container is where the concrete database and clock are chosen, and the only
/// place that decision is made.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/extraction/extraction_handlers.dart';
import '../application/formulation/formulation_handlers.dart';
import '../application/ports/repositories.dart';
import '../application/ports/transaction_runner.dart';
import '../application/queue/queue_query.dart';
import '../application/reader/reader_handlers.dart';
import '../application/review/review_handlers.dart';
import '../core/clock.dart';
import '../core/ids.dart';
import '../core/tracing.dart';
import '../data/database/app_database.dart';
import '../data/files/backup_service.dart';
import '../data/platform/app_paths.dart';
import '../data/repositories/drift_repositories.dart';
import '../domain/scheduling/card_scheduler.dart';
import '../domain/scheduling/interval_profile.dart';
import '../domain/scheduling/study_day.dart';

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

/// Structured diagnostics.
final Provider<DiagnosticSink> diagnosticsProvider = Provider<DiagnosticSink>(
  (Ref ref) => const NullDiagnosticSink(),
);

/// The user's study-day rules.
///
/// Fixed to UTC in v1: a configurable home zone arrives with Settings, and the
/// calendar takes its rules as an argument precisely so that change is local.
final Provider<StudyDayCalendar> studyCalendarProvider =
    Provider<StudyDayCalendar>(
      (Ref ref) => const StudyDayCalendar(zone: FixedOffsetZone.utc),
    );

/// The interval sequences that pace topics.
final Provider<IntervalProfiles> intervalProfilesProvider =
    Provider<IntervalProfiles>((Ref ref) => IntervalProfiles.defaults());

/// Pinned FSRS-6 adapter. Settings and parameter identity live in the domain
/// wrapper so a dependency upgrade cannot silently reinterpret review data.
final Provider<CardScheduler> cardSchedulerProvider = Provider<CardScheduler>(
  (Ref ref) => CardScheduler(calendar: ref.watch(studyCalendarProvider)),
);

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

/// Learning aggregate.
final Provider<LearningRepository> learningRepositoryProvider =
    Provider<LearningRepository>(
      (Ref ref) => DriftLearningRepository(ref.watch(databaseProvider)),
    );

/// Settings aggregate.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
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
final Provider<DriftLibraryQuery> libraryQueryProvider =
    Provider<DriftLibraryQuery>(
      (Ref ref) => DriftLibraryQuery(
        ref.watch(contentRepositoryProvider),
        ref.watch(learningRepositoryProvider),
        ref.watch(clockProvider),
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
final Provider<ReaderHandlers> readerHandlersProvider =
    Provider<ReaderHandlers>(
      (Ref ref) => ReaderHandlers(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        calendar: ref.watch(studyCalendarProvider),
        profiles: ref.watch(intervalProfilesProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Handlers for creating, undoing, and editing extracts.
final Provider<ExtractionHandlers> extractionHandlersProvider =
    Provider<ExtractionHandlers>(
      (Ref ref) => ExtractionHandlers(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        calendar: ref.watch(studyCalendarProvider),
        profiles: ref.watch(intervalProfilesProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Batch card formulation without mutating the parent extract.
final Provider<FormulationHandlers> formulationHandlersProvider =
    Provider<FormulationHandlers>(
      (Ref ref) => FormulationHandlers(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        calendar: ref.watch(studyCalendarProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Exactly-once FSRS review handler.
final Provider<ReviewHandlers> reviewHandlersProvider =
    Provider<ReviewHandlers>(
      (Ref ref) => ReviewHandlers(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        scheduler: ref.watch(cardSchedulerProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// Today's deterministic 4-card/1-topic projection.
final Provider<QueueQuery> queueQueryProvider = Provider<QueueQuery>(
  (Ref ref) => QueueQuery(
    content: ref.watch(contentRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    clock: ref.watch(clockProvider),
    calendar: ref.watch(studyCalendarProvider),
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
  final settings = container.read(settingsRepositoryProvider);
  final calendar = container.read(studyCalendarProvider);
  final today = calendar
      .dayOf(container.read(clockProvider).nowUtc())
      .toString();

  if (await settings.read(kLastBackupDayKey) == today) return null;

  final result = await container.read(backupServiceProvider).createBackup();
  if (result.isErr) return null;
  await settings.write(kLastBackupDayKey, today);
  return result.valueOrNull;
}
