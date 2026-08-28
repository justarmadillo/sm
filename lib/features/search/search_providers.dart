/// The objects the Search screen needs, built once.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/search/search_query.dart';
/// Full-text search across the collection.
final Provider<SearchQuery> searchQueryProvider = Provider<SearchQuery>(
  (Ref ref) => SearchQuery(
    search: ref.watch(searchRepositoryProvider),
    learning: ref.watch(learningRepositoryProvider),
    effectiveDue: ref.watch(effectiveDueQueryProvider),
  ),
);
