/// The objects the Library screen needs, built once.
///
/// Everything here is assembled from the shared objects in app/providers.dart;
/// the screen itself never constructs a repository or a scheduler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/library/element_content_query.dart';
import 'package:incremental_reader/features/library/library_tree_query.dart';
/// Library read projection.
/// The knowledge tree: every element nested under the one it came from.
final Provider<LibraryTreeQuery> libraryTreeQueryProvider =
    Provider<LibraryTreeQuery>(
      (Ref ref) => LibraryTreeQuery(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
      ),
    );

/// The body of any single element, for the Contents detail pane.
final Provider<ElementContentQuery> elementContentQueryProvider =
    Provider<ElementContentQuery>(
      (Ref ref) =>
          ElementContentQuery(content: ref.watch(contentRepositoryProvider)),
    );
