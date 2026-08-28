/// Saves and queries the full-text index, using Drift.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed -- those are the
/// command runners' and the schedulers' jobs. A repository that starts making
/// policy is how scheduling rules end up spread across three folders.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

/// Full-text search over the materialized documents and their FTS5 index.
///
/// The index is external-content: it stores terms only and reads the columns
/// back from `search_documents`. Triggers created with the schema keep the two
/// in step inside whatever transaction wrote the content, so a search can
/// never observe a half-applied import.
final class DriftSearchRepository implements SearchRepository {
  const DriftSearchRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> upsertDocument(SearchDocument document) => _database
      .into(_database.searchDocuments)
      .insertOnConflictUpdate(
        SearchDocumentsCompanion.insert(
          elementId: document.ref.id,
          elementType: document.ref.type.index,
          title: document.title,
          body: document.body,
          sourceId: Value<String?>(document.sourceId),
          updatedAtUtc: toEpochMs(document.updatedAtUtc),
        ),
      );

  @override
  Future<void> deleteDocument(ElementRef ref) async {
    await (_database.delete(_database.searchDocuments)..where(
          ($SearchDocumentsTable t) =>
              t.elementId.equals(ref.id) & t.elementType.equals(ref.type.index),
        ))
        .go();
  }

  @override
  Future<List<SearchHit>> search(
    String query, {
    int limit = 50,
    Set<ElementType>? types,
  }) async {
    if (query.trim().isEmpty) return <SearchHit>[];
    final typeFilter = types == null || types.isEmpty
        ? ''
        : 'AND d.element_type IN '
              '(${types.map((ElementType t) => t.index).join(', ')}) ';
    try {
      final rows = await _database
          .customSelect(
            'SELECT d.element_id, d.element_type, d.title, d.source_id, '
            'bm25($kSearchIndexTable) AS rank, '
            "snippet($kSearchIndexTable, 1, '[', ']', '…', 24) AS snippet "
            'FROM $kSearchIndexTable '
            'JOIN search_documents d ON d.rowid = $kSearchIndexTable.rowid '
            'WHERE $kSearchIndexTable MATCH ? $typeFilter'
            'ORDER BY rank LIMIT ?',
            variables: <Variable<Object>>[
              Variable<String>(query),
              Variable<int>(limit),
            ],
          )
          .get();
      return <SearchHit>[
        for (final row in rows)
          SearchHit(
            ref: ElementRef(
              id: row.read<String>('element_id'),
              type: ElementType.values[row.read<int>('element_type')],
            ),
            title: row.read<String>('title'),
            snippet: row.read<String?>('snippet') ?? '',
            rank: row.read<double?>('rank') ?? 0,
            sourceId: row.read<String?>('source_id'),
          ),
      ];
    } on Object {
      // FTS5 raises on malformed MATCH expressions. The query is built from
      // free text the user is still typing, so an unusable one means "no
      // results yet", never a crash.
      return <SearchHit>[];
    }
  }

  @override
  Future<void> rebuildIndex() => _database.rebuildSearchIndex();

  @override
  Future<bool> indexIsValid() => _database.searchIndexValid();

  @override
  Future<int> documentCount() async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS n FROM search_documents')
        .getSingle();
    return row.read<int>('n');
  }
}
