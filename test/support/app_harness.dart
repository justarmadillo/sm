/// One wired application stack, for handler and query tests.
///
/// Builds every handler against a real in-memory database, a fake clock, and
/// deterministic ids — with no Riverpod anywhere, which is the property the
/// composition root exists to preserve. Tests that need different tunables
/// call `applySettings` rather than reaching into a scheduler, because that is
/// how the running app changes them too.
library;

import 'package:incremental_reader/features/browser/browser_command_runner.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/daily_queue/mercy_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/diagnostics/diagnostics_query.dart';
import 'package:incremental_reader/features/diagnostics/scheduler_metrics_query.dart';
import 'package:incremental_reader/features/extract/extract_command_runner.dart';
import 'package:incremental_reader/features/extract/formulation_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_browser_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
import 'package:incremental_reader/features/search/search_query.dart';
import 'package:incremental_reader/features/video/video_command_runner.dart';
import 'package:incremental_reader/scheduling/effective_due_query.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_runtime_store.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/settings_store.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_content_repository.dart';
import 'package:incremental_reader/storage/drift/drift_learning_repository.dart';
import 'package:incremental_reader/storage/drift/drift_search_repository.dart';
import 'package:incremental_reader/storage/drift/drift_settings_repository.dart';
import 'package:incremental_reader/storage/drift/drift_transaction_runner.dart';
import 'package:incremental_reader/storage/drift/drift_transfer_repository.dart';
import 'package:incremental_reader/storage/drift/drift_video_repository.dart';

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
    videos = DriftVideoRepository(this.database);
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
  late final DriftVideoRepository videos;
  late final DriftLearningRepository learning;
  late final DriftSettingsRepository settings;
  late final DriftSearchRepository search;
  late final DriftTransferRepository transfer;
  late final DriftTransactionRunner transactions;
  late final SettingsStore settingsStore;
  late final Sm20RuntimeStore runtimeStore;
  late final SchedulingContext context;

  /// Collects every diagnostic event the command runners emit.
  final RecordingDiagnosticSink diagnostics = RecordingDiagnosticSink();

  late final ReaderCommandRunner reader = ReaderCommandRunner(
    content: content,
    videos: videos,
    learning: learning,
    search: search,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'reader-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final ExtractCommandRunner extraction = ExtractCommandRunner(
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

  late final FormulationCommandRunner formulation = FormulationCommandRunner(
    content: content,
    videos: videos,
    learning: learning,
    search: search,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'card-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final ReviewCommandRunner review = ReviewCommandRunner(
    content: content,
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'review-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final PriorityCommandRunner priority = PriorityCommandRunner(
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'priority-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final QueueCommandRunner queue = QueueCommandRunner(
    content: content,
    learning: learning,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'queue-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final PriorityBrowserCommandRunner browser =
      PriorityBrowserCommandRunner(
        learning: learning,
        transfer: transfer,
        transactions: transactions,
        context: context,
        clock: clock,
        ids: FakeIdGenerator(prefix: 'browser-$operationPrefix'),
        diagnostics: diagnostics,
      );

  /// The Browser's tree, and the moves that rearrange it.
  ///
  /// Named for filing rather than for the screen, because [browser] above is
  /// SM20's priority browser and the two have nothing to do with each other.
  late final BrowserTreeQuery browserTree = BrowserTreeQuery(
    content: content,
    videos: videos,
    learning: learning,
  );

  late final BrowserCommandRunner filing = BrowserCommandRunner(
    tree: browserTree,
    content: content,
    videos: videos,
    learning: learning,
    search: search,
    context: context,
    transfer: transfer,
    transactions: transactions,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'filing-$operationPrefix'),
    diagnostics: diagnostics,
  );

  /// Importing videos and cutting clips out of them.
  late final VideoCommandRunner video = VideoCommandRunner(
    videos: videos,
    learning: learning,
    search: search,
    transfer: transfer,
    transactions: transactions,
    context: context,
    clock: clock,
    ids: FakeIdGenerator(prefix: 'video-$operationPrefix'),
    diagnostics: diagnostics,
  );

  late final MercyCommandRunner mercy = MercyCommandRunner(
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
    videos: videos,
    learning: learning,
    commandRunner: queue,
    context: context,
    clock: clock,
  );

  late final PriorityQuery priorityQuery = PriorityQuery(
    content: content,
    videos: videos,
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
    videos: videos,
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

  /// Every scheduling row, serialized, ordered, and comparable.
  ///
  /// Exists for one assertion: that a command which must not touch the
  /// schedule did not touch it. Comparing whole rows is deliberate — a check
  /// that only looked at due dates would miss an interval, a repetition
  /// count, or a lifecycle quietly changing underneath.
  Future<String> schedulingSnapshot() async {
    final buffer = StringBuffer();
    for (final table in <String>[
      'element_schedules',
      'topic_states',
      'card_memories',
      'revlog_entries',
      'scheduler_events',
      'review_events',
      'mercy_batches',
    ]) {
      final rows = await database.customSelect('SELECT * FROM $table').get();
      final serialized = <String>[
        for (final row in rows)
          (row.data.entries.toList()..sort(
                (MapEntry<String, Object?> a, MapEntry<String, Object?> b) =>
                    a.key.compareTo(b.key),
              ))
              .map((MapEntry<String, Object?> e) => '\${e.key}=\${e.value}')
              .join(','),
      ]..sort();
      buffer.writeln('$table: ${serialized.join(' | ')}');
    }
    return buffer.toString();
  }

  Future<void> close() => database.close();
}
