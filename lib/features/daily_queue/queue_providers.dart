/// The objects today's study queue needs, built once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/daily_queue/mercy_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_command_runner.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';

/// The daily queue transaction, the manual stage commands, and Mercy.
final Provider<QueueCommandRunner> queueCommandRunnerProvider =
    Provider<QueueCommandRunner>(
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

/// Mercy: preview, apply, and exact batch undo.
final Provider<MercyCommandRunner> mercyCommandRunnerProvider =
    Provider<MercyCommandRunner>(
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
    videos: ref.watch(videoRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    commandRunner: ref.watch(queueCommandRunnerProvider),
    context: ref.watch(schedulingContextProvider),
    clock: ref.watch(clockProvider),
  ),
);
