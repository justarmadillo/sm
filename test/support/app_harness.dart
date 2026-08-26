/// One wired application stack, for handler and query tests.
///
/// Builds every handler against a real in-memory database, a fake clock, and
/// deterministic ids — with no Riverpod anywhere, which is the property the
/// composition root exists to preserve. Tests that need different tunables
/// call `applySettings` rather than reaching into a scheduler, because that is
/// how the running app changes them too.
library;

import 'package:incremental_reader/src/application/browser/browser_handlers.dart';
import 'package:incremental_reader/src/application/diagnostics/diagnostics_query.dart';
import 'package:incremental_reader/src/application/diagnostics/scheduler_metrics_query.dart';
import 'package:incremental_reader/src/application/extraction/extraction_handlers.dart';
import 'package:incremental_reader/src/application/formulation/formulation_handlers.dart';
import 'package:incremental_reader/src/application/priority/priority_handlers.dart';
import 'package:incremental_reader/src/application/priority/priority_query.dart';
import 'package:incremental_reader/src/application/queue/queue_handlers.dart';
import 'package:incremental_reader/src/application/queue/queue_query.dart';
import 'package:incremental_reader/src/application/reader/reader_handlers.dart';
import 'package:incremental_reader/src/application/review/review_handlers.dart';
import 'package:incremental_reader/src/application/scheduling/effective_due_query.dart';
import 'package:incremental_reader/src/application/scheduling/mercy_handlers.dart';
import 'package:incremental_reader/src/application/scheduling/scheduling_context.dart';
import 'package:incremental_reader/src/application/search/search_query.dart';
import 'package:incremental_reader/src/application/settings/settings_store.dart';
import 'package:incremental_reader/src/application/settings/sm20_runtime_store.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/ids.dart';
import 'package:incremental_reader/src/core/tracing.dart';
import 'package:incremental_reader/src/data/database/app_database.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/data/repositories/drift_repositories.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';

/// A fully wired application stack over an in-memory database.
final class AppHarness {
  AppHarness({
    AppDatabase? database,
    FakeClock? clock,
    this.operationPrefix = 'op',
    TimeZoneRules zone = FixedOffsetZone.utc,
  }) : database = database ?? openInMemoryDatabase(),
       clock = clock ?? FakeClock(DateTime.utc(2026, 3, 5, 10)),
       _zone = zone {
    content = DriftContentRepository(this.database);
    learning = DriftLearningRepository(this.database);
    settings = DriftSettingsRepository(this.database);
    search = DriftSearchRepository(this.database);
    transfer = DriftTransferRepository(
      this.database,
      FakeIdGenerator(prefix: 'dataset-$operationPrefix'),
      'test-device',
    );
    transactions = DriftTransactionRunner(this.database);
    settingsStore = SettingsStore(settings);
    runtimeStore = Sm20RuntimeStore(settings);
    context = SchedulingContext(
      settings: settingsStore,
      learning: learning,
      runtime: runtimeStore,
      clock: this.clock,
      // A fixed zone by default: a test that wants a DST transition supplies
      // its own rules rather than depending on where the machine is.
      resolveZone: (String _) => _zone,
    );
  }

  final AppDatabase database;
  final FakeClock clock;
  final String operationPrefix;
  final TimeZoneRules _zone;

  late final DriftContentRepository content;
  late final DriftLearningRepository learning;
  late final DriftSettingsRepository settings;
  late final DriftSearchRepository search;
  late final DriftTransferRepository transfer;
  late final DriftTransactionRunner transactions;
  late final SettingsStore settingsStore;
  late final Sm20RuntimeStore runtimeStore;
  late final SchedulingContext context;

  /// Collects every diagnostic event the handlers emit.
  final RecordingDiagnosticSink diagnostics = RecordingDiagnosticSink();

  late final ReaderHandlers reader = ReaderHandlers(
    content: content,
    learning: learning,
    search: search,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'reader-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final ExtractionHandlers extraction = ExtractionHandlers(
    content: content,
    learning: learning,
    search: search,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'extract-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final FormulationHandlers formulation = FormulationHandlers(
    content: content,
    learning: learning,
    search: search,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'card-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final ReviewHandlers review = ReviewHandlers(
    content: content,
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'review-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final PriorityHandlers priority = PriorityHandlers(
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'priority-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final QueueHandlers queue = QueueHandlers(
    content: content,
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'queue-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final BrowserHandlers browser = BrowserHandlers(
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'browser-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final MercyHandlers mercy = MercyHandlers(
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    queue: queue,
    ids: FakeIdGenerator(prefix: 'mercy-$operationPrefix'),
  );

  late final SchedulerMetricsQuery metrics = SchedulerMetricsQuery(
    learning: learning,
    context: context,
    queue: queue,
  );

  late final QueueQuery queueQuery = QueueQuery(
    content: content,
    learning: learning,
    handlers: queue,
    context: context,
    clock: clock,
  );

  late final PriorityQuery priorityQuery = PriorityQuery(
    content: content,
    learning: learning,
    context: context,
  );

  late final EffectiveDueQuery effectiveDue = EffectiveDueQuery(
    learning: learning,
    context: context,
  );

  late final SearchQuery searchQuery = SearchQuery(
    search: search,
    learning: learning,
    effectiveDue: effectiveDue,
  );

  late final DiagnosticsQuery diagnosticsQuery = DiagnosticsQuery(
    learning: learning,
    content: content,
    search: search,
    context: context,
  );

  int _operations = 0;

  /// A fresh operation id, as a ViewModel would mint one per user action.
  OperationId operation() => OperationId('$operationPrefix-${++_operations}');

  /// The study day the clock currently falls in.
  Future<StudyDay> today() => context.today();

  /// Persists [next] and drops every cached copy of the old configuration.
  Future<void> applySettings(AppSettings next) async {
    final result = await settingsStore.save(next);
    if (result.isErr) {
      throw StateError('could not apply settings: ${result.failureOrNull}');
    }
  }

  /// Applies a change to the current settings.
  Future<void> tuneSettings(
    AppSettings Function(AppSettings current) change,
  ) async => applySettings(change(await settingsStore.load()));

  Future<void> close() => database.close();
}
