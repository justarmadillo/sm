/// Saves and loads custom-study decks, using Drift.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

/// Drift implementation of the custom-deck storage contract.
final class DriftCustomDeckRepository implements CustomDeckRepository {
  const DriftCustomDeckRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<CustomDeck>> listDecks() async {
    final List<CustomDeckRow> rows =
        await (_database.select(_database.customDecks)
              ..orderBy(<OrderClauseGenerator<$CustomDecksTable>>[
                ($CustomDecksTable decks) =>
                    OrderingTerm.asc(decks.nameLowercase),
              ]))
            .get();
    final Map<String, List<CustomDeckTagRow>> linksByDeck =
        <String, List<CustomDeckTagRow>>{};
    for (final CustomDeckTagRow link
        in await _database.select(_database.customDeckTags).get()) {
      linksByDeck
          .putIfAbsent(link.deckId, () => <CustomDeckTagRow>[])
          .add(link);
    }
    return <CustomDeck>[
      for (final CustomDeckRow row in rows)
        customDeckFromRows(
          row,
          linksByDeck[row.id] ?? const <CustomDeckTagRow>[],
        ),
    ];
  }

  @override
  Future<CustomDeck?> findDeck(String id) =>
      _findDeckWhere(($CustomDecksTable decks) => decks.id.equals(id));

  @override
  Future<CustomDeck?> findDeckByLowercaseName(String lowercaseName) =>
      _findDeckWhere(
        ($CustomDecksTable decks) => decks.nameLowercase.equals(lowercaseName),
      );

  @override
  Future<void> insertDeck(CustomDeck deck) async {
    await _database
        .into(_database.customDecks)
        .insert(customDeckToCompanion(deck));
    await _insertTagLinks(deck);
  }

  @override
  Future<void> updateDeck(CustomDeck deck) async {
    await (_database.update(_database.customDecks)
          ..where(($CustomDecksTable decks) => decks.id.equals(deck.id)))
        .write(customDeckToCompanion(deck));
    await (_database.delete(_database.customDeckTags)
          ..where(($CustomDeckTagsTable links) => links.deckId.equals(deck.id)))
        .go();
    await _insertTagLinks(deck);
  }

  @override
  Future<void> deleteDeck(String id) async {
    await (_database.delete(
      _database.customDecks,
    )..where(($CustomDecksTable decks) => decks.id.equals(id))).go();
  }

  /// Inserts the surviving tag first and ignores the clash, so a deck that
  /// already names [toTagId] keeps the role it gave it; the source links go
  /// when the merged tags are deleted.
  @override
  Future<void> updateDeckTagReferences({
    required Set<String> fromTagIds,
    required String toTagId,
  }) async {
    if (fromTagIds.isEmpty) return;
    final List<CustomDeckTagRow> links = await (_database.select(
      _database.customDeckTags,
    )..where(($CustomDeckTagsTable link) => link.tagId.isIn(fromTagIds))).get();
    await _database.batch((Batch batch) {
      for (final CustomDeckTagRow link in links) {
        batch.insert(
          _database.customDeckTags,
          CustomDeckTagsCompanion.insert(
            deckId: link.deckId,
            tagId: toTagId,
            role: link.role,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  Future<CustomDeck?> _findDeckWhere(
    Expression<bool> Function($CustomDecksTable decks) rowMatches,
  ) async {
    final CustomDeckRow? row = await (_database.select(
      _database.customDecks,
    )..where(rowMatches)).getSingleOrNull();
    if (row == null) return null;
    final List<CustomDeckTagRow> links = await (_database.select(
      _database.customDeckTags,
    )..where(($CustomDeckTagsTable link) => link.deckId.equals(row.id))).get();
    return customDeckFromRows(row, links);
  }

  Future<void> _insertTagLinks(CustomDeck deck) async {
    final List<CustomDeckTagsCompanion> links = customDeckTagsToCompanions(
      deck,
    );
    if (links.isEmpty) return;
    await _database.batch(
      (Batch batch) => batch.insertAll(_database.customDeckTags, links),
    );
  }
}
