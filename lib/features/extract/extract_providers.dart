/// The objects the Extract screen and its formulation dialog need.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/extract/extract_command_runner.dart';
import 'package:incremental_reader/features/extract/formulation_command_runner.dart';
/// Runs the commands for creating, undoing, and editing extracts.
final Provider<ExtractCommandRunner> extractCommandRunnerProvider =
    Provider<ExtractCommandRunner>(
      (Ref ref) => ExtractCommandRunner(
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
