/// Objects used only by the image-occlusion editor.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/occlusion/occlusion_command_runner.dart';

final Provider<OcclusionCommandRunner> occlusionCommandRunnerProvider =
    Provider<OcclusionCommandRunner>(
      (Ref ref) => OcclusionCommandRunner(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        occlusions: ref.watch(occlusionRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        context: ref.watch(schedulingContextProvider),
        files: ref.watch(sourceAssetFileStoreProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );
