/// The objects the Video screen and its dialogs need.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/video/video_command_runner.dart';

/// Runs the commands for importing videos and cutting clips out of them.
final Provider<VideoCommandRunner> videoCommandRunnerProvider =
    Provider<VideoCommandRunner>(
      (Ref ref) => VideoCommandRunner(
        videos: ref.watch(videoRepositoryProvider),
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
