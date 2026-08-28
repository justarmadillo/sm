/// The objects the Review screen needs, built once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/review/review_command_runner.dart';
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
