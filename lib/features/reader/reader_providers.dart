/// The objects the Reader screen needs, built once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/reader/reader_command_runner.dart';
/// Runs every command the Reader and the Browser can issue.
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
