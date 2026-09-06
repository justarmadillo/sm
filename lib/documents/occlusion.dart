/// Image-occlusion regions and presentation rules, independent of Flutter.
library;

import 'dart:convert';

import 'package:incremental_reader/shared/result.dart';
import 'package:meta/meta.dart';

/// How masks are applied while an image-occlusion card is reviewed.
enum OcclusionMode { hideAllGuessOne, hideOneGuessOne, hideAllGuessAll }

/// One rectangle expressed as fractions of its image dimensions.
@immutable
final class OcclusionRegion {
  const OcclusionRegion({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is OcclusionRegion &&
      other.id == id &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(id, left, top, width, height);
}

/// Image metadata and the complete mask set owned by one card.
@immutable
final class CardOcclusion {
  const CardOcclusion({
    required this.cardId,
    required this.imageSha256,
    required this.imageMime,
    required this.imageWidthPx,
    required this.imageHeightPx,
    required this.regions,
    required this.activeRegionId,
    required this.mode,
  });

  final String cardId;
  final String imageSha256;
  final String imageMime;
  final int imageWidthPx;
  final int imageHeightPx;
  final List<OcclusionRegion> regions;
  final String? activeRegionId;
  final OcclusionMode mode;

  /// The regions covered at the current side of review.
  ///
  /// Returning regions rather than Flutter rectangles keeps presentation
  /// policy usable by storage tests and every future renderer.
  List<OcclusionRegion> coveredRegions({required bool isAnswerRevealed}) {
    if (!isAnswerRevealed) {
      return switch (mode) {
        OcclusionMode.hideAllGuessOne ||
        OcclusionMode.hideAllGuessAll => regions,
        OcclusionMode.hideOneGuessOne =>
          regions
              .where((region) => region.id == activeRegionId)
              .toList(growable: false),
      };
    }
    return switch (mode) {
      OcclusionMode.hideAllGuessOne =>
        regions
            .where((region) => region.id != activeRegionId)
            .toList(growable: false),
      OcclusionMode.hideOneGuessOne ||
      OcclusionMode.hideAllGuessAll => const <OcclusionRegion>[],
    };
  }
}

/// Encodes the entire mask set because it is always saved as one unit.
String occlusionRegionsToJson(List<OcclusionRegion> regions) =>
    jsonEncode(<Object?>[
      for (final region in regions)
        <String, Object?>{
          'id': region.id,
          'left': region.left,
          'top': region.top,
          'width': region.width,
          'height': region.height,
        },
    ]);

/// Decodes a mask set previously written by [occlusionRegionsToJson].
List<OcclusionRegion> occlusionRegionsFromJson(String encoded) {
  return tryDecodeOcclusionRegions(encoded).unwrap();
}

/// Attempts to decode a mask set without making one damaged row fatal to a
/// list query.
Result<List<OcclusionRegion>> tryDecodeOcclusionRegions(String encoded) {
  try {
    final List<Object?> decoded = jsonDecode(encoded) as List<Object?>;
    return Ok<List<OcclusionRegion>>(<OcclusionRegion>[
      for (final Object? entry in decoded)
        _occlusionRegionFromMap(entry! as Map<String, Object?>),
    ]);
  } on Object catch (error, stackTrace) {
    return Err<List<OcclusionRegion>>(
      StorageFailure(
        'occlusion regions are undecodable',
        cause: error,
        stackTrace: stackTrace,
      ),
    );
  }
}

OcclusionRegion _occlusionRegionFromMap(Map<String, Object?> fields) =>
    OcclusionRegion(
      id: fields['id']! as String,
      left: (fields['left']! as num).toDouble(),
      top: (fields['top']! as num).toDouble(),
      width: (fields['width']! as num).toDouble(),
      height: (fields['height']! as num).toDouble(),
    );
