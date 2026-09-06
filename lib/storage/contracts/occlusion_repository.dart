/// The storage promise for image-occlusion metadata owned by cards.
library;

import 'package:incremental_reader/documents/occlusion.dart';

/// Finds and changes card-owned image masks without exposing SQL.
abstract interface class OcclusionRepository {
  /// The occlusion owned by [cardId], or null.
  Future<CardOcclusion?> findCardOcclusion(String cardId);

  /// Occlusions belonging to [cardIds], in the input cards' storage order.
  Future<List<CardOcclusion>> listCardOcclusionsOfCards(List<String> cardIds);

  /// Stores a newly-created set of card occlusions.
  Future<void> insertCardOcclusions(List<CardOcclusion> occlusions);

  /// Replaces the complete mask set and image metadata for one card.
  Future<void> updateCardOcclusion(CardOcclusion occlusion);

  /// Removes the occlusion row while leaving its card intact.
  Future<void> deleteCardOcclusion(String cardId);

  /// Distinct image blobs kept live by occlusion cards.
  Future<List<String>> listReferencedOcclusionSha256Values();
}
