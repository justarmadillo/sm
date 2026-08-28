/// What the app promises about the full-text index.
///
/// One indexed document per element, and the hits a query returns.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:meta/meta.dart';

/// One row of the materialized search table.
@immutable
final class SearchDocument {
  const SearchDocument({
    required this.ref,
    required this.title,
    required this.body,
    required this.updatedAtUtc,
    this.sourceId,
  });

  final ElementRef ref;
  final String title;

  /// Indexed text. For a source this is the whole markdown, so a passage can
  /// be found before it has ever been extracted.
  final String body;

  final DateTime updatedAtUtc;

  /// Root source, so results group by article without a join.
  final String? sourceId;
}

/// One search hit, with the snippet that matched.
@immutable
final class SearchHit {
  const SearchHit({
    required this.ref,
    required this.title,
    required this.snippet,
    required this.rank,
    this.sourceId,
  });

  final ElementRef ref;
  final String title;

  /// Highlighted excerpt around the match, produced by FTS5.
  final String snippet;

  /// FTS5 relevance; lower is better.
  final double rank;

  final String? sourceId;
}

/// Full-text search over sources, extracts, and cards.
abstract interface class SearchRepository {
  /// Inserts or replaces one document, inside the caller's transaction.
  Future<void> upsertDocument(SearchDocument document);

  /// Removes one document and its index entry.
  Future<void> deleteDocument(ElementRef ref);

  /// Matches against the FTS5 index, best first.
  Future<List<SearchHit>> search(
    String query, {
    int limit = 50,
    Set<ElementType>? types,
  });

  /// Rebuilds the index from the materialized rows.
  Future<void> rebuildIndex();

  /// Whether the index reports itself consistent with its content table.
  Future<bool> indexIsValid();

  /// How many documents are materialized.
  Future<int> documentCount();
}
