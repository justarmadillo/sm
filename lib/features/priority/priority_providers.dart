/// The objects the priority slider and the priority browser need.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/priority/priority_browser_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';

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
final Provider<PriorityBrowserCommandRunner>
priorityBrowserCommandRunnerProvider = Provider<PriorityBrowserCommandRunner>(
  (Ref ref) => PriorityBrowserCommandRunner(
    learning: ref.watch(learningRepositoryProvider),
    transfer: ref.watch(transferRepositoryProvider),
    transactions: ref.watch(transactionRunnerProvider),
    context: ref.watch(schedulingContextProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    diagnostics: ref.watch(diagnosticsProvider),
  ),
);

/// Priority projections for the slider and the browser.
final Provider<PriorityQuery> priorityQueryProvider = Provider<PriorityQuery>(
  (Ref ref) => PriorityQuery(
    content: ref.watch(contentRepositoryProvider),
    videos: ref.watch(videoRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    context: ref.watch(schedulingContextProvider),
  ),
);
