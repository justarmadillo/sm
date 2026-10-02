/// Builds the objects the custom study screen needs, once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_providers.dart';
import 'package:incremental_reader/features/custom_study/custom_study_command_runner.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';

/// The inherited-tag population query, constructed once per provider scope.
final Provider<CustomStudyQuery> customStudyQueryProvider =
    Provider<CustomStudyQuery>(
      (Ref ref) => CustomStudyQuery(
        tree: ref.watch(browserTreeQueryProvider),
        learning: ref.watch(learningRepositoryProvider),
        cramScope: ref.watch(cramScopeQueryProvider),
        context: ref.watch(schedulingContextProvider),
        clock: ref.watch(clockProvider),
      ),
    );

/// Saves, changes, and deletes decks inside the shared command boundary.
final Provider<CustomStudyCommandRunner> customStudyCommandRunnerProvider =
    Provider<CustomStudyCommandRunner>(
      (Ref ref) => CustomStudyCommandRunner(
        decks: ref.watch(customDeckRepositoryProvider),
        tags: ref.watch(tagRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );
