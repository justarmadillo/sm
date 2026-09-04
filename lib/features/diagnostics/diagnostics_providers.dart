/// The objects the diagnostics panel needs, built once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/daily_queue/queue_providers.dart';
import 'package:incremental_reader/features/diagnostics/diagnostics_query.dart';
import 'package:incremental_reader/features/diagnostics/scheduler_metrics_query.dart';

/// Scheduler safety metrics for the diagnostics panel.
final Provider<SchedulerMetricsQuery> schedulerMetricsQueryProvider =
    Provider<SchedulerMetricsQuery>(
      (Ref ref) => SchedulerMetricsQuery(
        learning: ref.watch(learningRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
        queue: ref.watch(queueCommandRunnerProvider),
      ),
    );

/// The development diagnostics panel's read model.
final Provider<DiagnosticsQuery> diagnosticsQueryProvider =
    Provider<DiagnosticsQuery>(
      (Ref ref) => DiagnosticsQuery(
        learning: ref.watch(learningRepositoryProvider),
        content: ref.watch(contentRepositoryProvider),
        videos: ref.watch(videoRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
      ),
    );
