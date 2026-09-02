/// The storage promise for image metadata referenced by source markdown.
library;

import 'package:incremental_reader/documents/source_asset.dart';

/// Finds and changes source-owned image metadata without exposing SQL.
abstract interface class SourceAssetRepository {
  /// The asset with [id], or null.
  Future<SourceAsset?> findSourceAsset(String id);

  /// The asset [sourceId] addresses through [srcRef], or null.
  Future<SourceAsset?> findSourceAssetByReference(
    String sourceId,
    String srcRef,
  );

  /// Every image reference owned by [sourceId], in import order.
  Future<List<SourceAsset>> listSourceAssets(String sourceId);

  /// Every reference to the immutable blob with [sha256].
  Future<List<SourceAsset>> listSourceAssetsBySha256(String sha256);

  /// Distinct available blob hashes needed for a complete collection backup.
  Future<List<String>> listAvailableSourceAssetSha256Values();

  /// How many image references [sourceId] owns.
  Future<int> countSourceAssets(String sourceId);

  /// How many source references keep the blob with [sha256] live.
  Future<int> countSourceAssetsBySha256(String sha256);

  /// Stores one newly imported image reference.
  Future<void> insertSourceAsset(SourceAsset asset);

  /// Removes one source reference. Blob deletion is a separate file concern.
  Future<void> deleteSourceAsset(String id);
}
