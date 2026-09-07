/// The objects the Tags screen and picker need, built once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/tags/tags_command_runner.dart';
import 'package:incremental_reader/features/tags/tags_query.dart';

/// Reads tag definitions and their direct-use counts.
final Provider<TagsQuery> tagsQueryProvider = Provider<TagsQuery>(
  (Ref ref) => TagsQuery(ref.watch(tagRepositoryProvider)),
);

/// Applies tag changes inside the shared transaction boundary.
final Provider<TagsCommandRunner> tagsCommandRunnerProvider =
    Provider<TagsCommandRunner>(
      (Ref ref) => TagsCommandRunner(
        tags: ref.watch(tagRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );
