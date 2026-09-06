/// Pure image-occlusion serialization and mask-presentation rules.
library;

import 'package:incremental_reader/documents/occlusion.dart';
import 'package:test/test.dart';

void main() {
  const regions = <OcclusionRegion>[
    OcclusionRegion(id: 'a', left: 0.1, top: 0.2, width: 0.3, height: 0.4),
    OcclusionRegion(id: 'b', left: 0.5, top: 0.6, width: 0.2, height: 0.1),
  ];

  CardOcclusion occlusion(OcclusionMode mode, String? activeRegionId) =>
      CardOcclusion(
        cardId: 'card',
        imageSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        imageMime: 'image/png',
        imageWidthPx: 100,
        imageHeightPx: 100,
        regions: regions,
        activeRegionId: activeRegionId,
        mode: mode,
      );

  test('region JSON round-trips normalized coordinates', () {
    expect(occlusionRegionsFromJson(occlusionRegionsToJson(regions)), regions);
  });

  test('hide-all guess-one uncovers only the active answer', () {
    final card = occlusion(OcclusionMode.hideAllGuessOne, 'a');
    expect(card.coveredRegions(isAnswerRevealed: false), regions);
    expect(card.coveredRegions(isAnswerRevealed: true), <OcclusionRegion>[
      regions[1],
    ]);
  });

  test('hide-one and guess-all reveal every answer region', () {
    final hideOne = occlusion(OcclusionMode.hideOneGuessOne, 'b');
    expect(hideOne.coveredRegions(isAnswerRevealed: false), <OcclusionRegion>[
      regions[1],
    ]);
    expect(hideOne.coveredRegions(isAnswerRevealed: true), isEmpty);

    final guessAll = occlusion(OcclusionMode.hideAllGuessAll, null);
    expect(guessAll.coveredRegions(isAnswerRevealed: false), regions);
    expect(guessAll.coveredRegions(isAnswerRevealed: true), isEmpty);
  });
}
