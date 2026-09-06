/// Commands that create scheduled cards from masked image regions.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/command_base.dart';

/// Creates one card per region, or one card for guess-all mode.
final class CreateOcclusionCards extends AppCommand {
  CreateOcclusionCards(
    super.operationId, {
    required this.parent,
    required this.image,
    required this.regions,
    required this.mode,
    required this.header,
    required this.remarks,
    super.timestampUtc,
  });

  final CardParent? parent;
  final SourceImageImport image;
  final List<OcclusionRegion> regions;
  final OcclusionMode mode;
  final String header;
  final String remarks;
}

/// Replaces one occlusion card's wording, mode, and complete mask set.
final class EditOcclusionCard extends AppCommand {
  EditOcclusionCard(
    super.operationId, {
    required this.cardId,
    required this.regions,
    required this.mode,
    required this.header,
    required this.remarks,
    super.timestampUtc,
  });

  final String cardId;
  final List<OcclusionRegion> regions;
  final OcclusionMode mode;
  final String header;
  final String remarks;
}
