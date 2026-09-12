/// Image-occlusion repository round-trip and ownership tests.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_content_repository.dart';
import 'package:incremental_reader/storage/drift/drift_occlusion_repository.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips and cascades when its card is deleted', () async {
    final database = openInMemoryDatabase();
    addTearDown(database.close);
    final content = DriftContentRepository(database);
    final repository = DriftOcclusionRepository(database);
    final card = Card.imageOcclusion(
      id: 'card',
      parent: null,
      header: 'Anatomy',
      extra: 'Left atrium',
      createdAtUtc: DateTime.utc(2026),
    );
    const expected = CardOcclusion(
      cardId: 'card',
      imageSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      imageMime: 'image/png',
      imageWidthPx: 640,
      imageHeightPx: 480,
      regions: <OcclusionRegion>[
        OcclusionRegion(
          id: 'region',
          left: 0.1,
          top: 0.2,
          width: 0.3,
          height: 0.4,
        ),
      ],
      activeRegionId: 'region',
      mode: OcclusionMode.hideAllGuessOne,
    );

    await content.insertCards(<Card>[card]);
    await repository.insertCardOcclusions(const <CardOcclusion>[expected]);

    final actual = await repository.findCardOcclusion(card.id);
    expect(actual?.cardId, expected.cardId);
    expect(actual?.regions, expected.regions);
    expect(await repository.listReferencedOcclusionSha256Values(), <String>[
      expected.imageSha256,
    ]);

    await content.deleteCard(card.id);
    expect(await repository.findCardOcclusion(card.id), isNull);
  });
}
