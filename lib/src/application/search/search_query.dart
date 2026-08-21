/// Full-text search across the whole collection.
///
/// Search is how a collection stops being write-only. Once there are a few
/// hundred extracts, "did I already make a card about this?" and "where did I
/// read that?" are the two questions asked most often, and neither is
/// answerable by scrolling a tree.
///
/// Sources are indexed in full — the whole article, not only its title — so a
/// passage can be found before it has ever been extracted.
library;

import 'package:meta/meta.dart';

import '../../domain/scheduling/element.dart';
import '../ports/repositories.dart';

/// One result row, ready to render.
@immutable
final class SearchResult {
  const SearchResult({
    required this.hit,
    required this.typeLabel,
    this.schedule,
  });

  final SearchHit hit;

  /// "Article", "Extract", or "Card".
  final String typeLabel;

  /// The element's schedule, so a result can show when it is next due and
  /// whether it is still in learning at all.
  final ElementSchedule? schedule;

  ElementRef get ref => hit.ref;

  String get title => hit.title;

  String get snippet => hit.snippet;
}

/// Runs searches and decorates the hits.
final class SearchQuery {
  const SearchQuery({
    required SearchRepository search,
    required LearningRepository learning,
  }) : _search = search,
       _learning = learning;

  final SearchRepository _search;
  final LearningRepository _learning;

  /// Matches [query] against the index.
  ///
  /// An empty or punctuation-only query returns nothing rather than
  /// everything: FTS5 would otherwise raise a syntax error on some inputs, and
  /// "all elements" is what the Library and the priority browser are for.
  Future<List<SearchResult>> run(
    String query, {
    int limit = 50,
    Set<ElementType>? types,
  }) async {
    final String prepared = prepareQuery(query);
    if (prepared.isEmpty) return const <SearchResult>[];

    final List<SearchHit> hits = await _search.search(
      prepared,
      limit: limit,
      types: types,
    );
    final results = <SearchResult>[];
    for (final SearchHit hit in hits) {
      results.add(
        SearchResult(
          hit: hit,
          typeLabel: switch (hit.ref.type) {
            ElementType.source => 'Article',
            ElementType.extract => 'Extract',
            ElementType.card => 'Card',
          },
          schedule: await _learning.findSchedule(hit.ref),
        ),
      );
    }
    return List<SearchResult>.unmodifiable(results);
  }

  /// How many elements are currently indexed.
  Future<int> indexedCount() => _search.documentCount();

  /// Whether the index agrees with its content table.
  Future<bool> indexIsValid() => _search.indexIsValid();
}

/// Turns free text into a safe FTS5 MATCH expression.
///
/// The user is typing prose, not query syntax, so every token is quoted and
/// the operators FTS5 would otherwise interpret — `"`, `*`, `:`, `^`, `-`,
/// `NEAR`, `AND`, `OR` — cannot leak through. A trailing prefix wildcard is
/// added to the last token so results appear while the user is still typing.
String prepareQuery(String raw) {
  final List<String> tokens = <String>[
    for (final String token in raw.split(RegExp(r'[^\p{L}\p{N}_]+', unicode: true)))
      if (token.isNotEmpty) token.toLowerCase(),
  ];
  if (tokens.isEmpty) return '';
  final List<String> quoted = <String>[
    for (var i = 0; i < tokens.length; i++)
      i == tokens.length - 1 ? '"${tokens[i]}"*' : '"${tokens[i]}"',
  ];
  return quoted.join(' AND ');
}
