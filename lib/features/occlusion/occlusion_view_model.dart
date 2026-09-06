/// Immutable state and validation for the image-occlusion editor.
library;

import 'package:flutter/foundation.dart';
import 'package:incremental_reader/documents/occlusion.dart';

@immutable
final class OcclusionEditorState {
  const OcclusionEditorState({
    this.regions = const <OcclusionRegion>[],
    this.mode = OcclusionMode.hideAllGuessOne,
    this.header = '',
    this.remarks = '',
    this.isBusy = false,
  });

  final List<OcclusionRegion> regions;
  final OcclusionMode mode;
  final String header;
  final String remarks;
  final bool isBusy;
}
