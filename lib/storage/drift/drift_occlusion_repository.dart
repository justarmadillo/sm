/// Drift-backed storage for image-occlusion metadata.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/storage/contracts/occlusion_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

/// Keeps [OcclusionRepository]'s promise in the application database.
final class DriftOcclusionRepository implements OcclusionRepository {
  const DriftOcclusionRepository(this._database);

  final AppDatabase _database;

  @override
  Future<CardOcclusion?> findCardOcclusion(String cardId) async {
    final row =
        await (_database.select(_database.cardOcclusions)..where(
              ($CardOcclusionsTable table) => table.cardId.equals(cardId),
            ))
            .getSingleOrNull();
    return row == null ? null : cardOcclusionFromRow(row);
  }

  @override
  Future<List<CardOcclusion>> listCardOcclusionsOfCards(
    List<String> cardIds,
  ) async {
    if (cardIds.isEmpty) return const <CardOcclusion>[];
    final rows = await (_database.select(
      _database.cardOcclusions,
    )..where(($CardOcclusionsTable table) => table.cardId.isIn(cardIds))).get();
    return <CardOcclusion>[for (final row in rows) cardOcclusionFromRow(row)];
  }

  @override
  Future<void> insertCardOcclusions(List<CardOcclusion> occlusions) async {
    if (occlusions.isEmpty) return;
    await _database.batch((Batch batch) {
      batch.insertAll(_database.cardOcclusions, <CardOcclusionsCompanion>[
        for (final occlusion in occlusions) cardOcclusionToCompanion(occlusion),
      ]);
    });
  }

  @override
  Future<void> updateCardOcclusion(CardOcclusion occlusion) async {
    await (_database.update(_database.cardOcclusions)..where(
          ($CardOcclusionsTable table) => table.cardId.equals(occlusion.cardId),
        ))
        .write(cardOcclusionToCompanion(occlusion));
  }

  @override
  Future<void> deleteCardOcclusion(String cardId) async {
    await (_database.delete(
      _database.cardOcclusions,
    )..where(($CardOcclusionsTable table) => table.cardId.equals(cardId))).go();
  }

  @override
  Future<List<String>> listReferencedOcclusionSha256Values() async {
    final rows =
        await (_database.selectOnly(_database.cardOcclusions)
              ..addColumns(<Expression<Object>>{
                _database.cardOcclusions.imageSha256,
              })
              ..groupBy(<Expression<Object>>[
                _database.cardOcclusions.imageSha256,
              ]))
            .get();
    return <String>[
      for (final row in rows) row.read(_database.cardOcclusions.imageSha256)!,
    ]..sort();
  }
}
