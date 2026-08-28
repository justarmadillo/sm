/// The objects the Library screen needs, built once.
///
/// Everything here is assembled from the shared objects in app/providers.dart;
/// the screen itself never constructs a repository or a scheduler.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/library/content_tree_query.dart';
/// Library read projection.
/// The knowledge tree: every element nested under the one it came from.
final Provider<ContentTreeQuery> contentTreeQueryProvider =
    Provider<ContentTreeQuery>(
      (Ref ref) => ContentTreeQuery(
        content: ref.watch(contentRepositoryProvider),
        learning: ref.watch(learningRepositoryProvider),
        context: ref.watch(schedulingContextProvider),
      ),
    );
