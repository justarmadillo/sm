/// The objects the Browser screen needs, built once.
///
/// Everything here is assembled from the shared objects in app/providers.dart;
/// the screen itself never constructs a repository or a scheduler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_command_runner.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/features/browser/element_content_query.dart';

/// The tree: every element, nested and ordered as the user has filed it.
final Provider<BrowserTreeQuery> browserTreeQueryProvider =
    Provider<BrowserTreeQuery>(
      (Ref ref) => BrowserTreeQuery(
        content: ref.watch(contentRepositoryProvider),
        videos: ref.watch(videoRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
      ),
    );

/// Runs the moves the Browser can make — up, down, nest, lift, drop — and the
/// one deletion that is permanent.
final Provider<BrowserCommandRunner> browserCommandRunnerProvider =
    Provider<BrowserCommandRunner>(
      (Ref ref) => BrowserCommandRunner(
        tree: ref.watch(browserTreeQueryProvider),
        content: ref.watch(contentRepositoryProvider),
        videos: ref.watch(videoRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        search: ref.watch(searchRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
        transfer: ref.watch(transferRepositoryProvider),
        transactions: ref.watch(transactionRunnerProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
        diagnostics: ref.watch(diagnosticsProvider),
      ),
    );

/// The body of any single element, for the Browser detail pane.
final Provider<ElementContentQuery> elementContentQueryProvider =
    Provider<ElementContentQuery>(
      (Ref ref) => ElementContentQuery(
        content: ref.watch(contentRepositoryProvider),
        videos: ref.watch(videoRepositoryProvider),
      ),
    );
