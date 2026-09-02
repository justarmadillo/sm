/// Metadata for one image reference embedded in a source's markdown.
library;

import 'package:meta/meta.dart';

/// Whether the immutable image bytes are available to the Reader.
///
/// Enum order is the on-disk representation. Append new states; never reorder
/// the existing values.
enum SourceAssetState { ok, missing, failed }

/// One source-owned reference to an immutable, content-addressed image.
@immutable
final class SourceAsset {
  SourceAsset({
    required this.id,
    required this.sourceId,
    required this.srcRef,
    required this.sha256,
    required this.mime,
    required this.widthPx,
    required this.heightPx,
    required this.byteSize,
    required this.state,
    required DateTime importedAtUtc,
  }) : importedAtUtc = importedAtUtc.toUtc() {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'must not be empty');
    if (sourceId.isEmpty) {
      throw ArgumentError.value(sourceId, 'sourceId', 'must not be empty');
    }
    if (srcRef.isEmpty) {
      throw ArgumentError.value(srcRef, 'srcRef', 'must not be empty');
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw ArgumentError.value(
        sha256,
        'sha256',
        'must be 64 lowercase hexadecimal characters',
      );
    }
    if (!mime.startsWith('image/') || mime.length <= 'image/'.length) {
      throw ArgumentError.value(mime, 'mime', 'must be an image MIME type');
    }
    if (widthPx <= 0) {
      throw ArgumentError.value(widthPx, 'widthPx', 'must be positive');
    }
    if (heightPx <= 0) {
      throw ArgumentError.value(heightPx, 'heightPx', 'must be positive');
    }
    if (byteSize <= 0) {
      throw ArgumentError.value(byteSize, 'byteSize', 'must be positive');
    }
  }

  final String id;
  final String sourceId;

  /// The portable reference stored verbatim in the source's markdown.
  final String srcRef;

  /// Lowercase hexadecimal SHA-256 of the encoded image bytes.
  final String sha256;

  final String mime;
  final int widthPx;
  final int heightPx;
  final int byteSize;
  final SourceAssetState state;
  final DateTime importedAtUtc;

  @override
  bool operator ==(Object other) => other is SourceAsset && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
