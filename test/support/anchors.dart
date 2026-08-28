/// Building reader anchors in tests without hand-computing byte offsets.
///
/// Anchors are document-space byte offsets, but a test almost always wants to
/// say "twelve bytes into this block" or "where this word starts". These
/// helpers do the one addition so a test that means the same thing after the
/// coordinate change still reads the same way.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/inline_markup.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';

/// An anchor [offsetInBlock] bytes into [block].
ReaderAnchor anchorIn(
  Block block,
  int offsetInBlock, {
  int contentRevision = kInitialContentRevision,
}) => ReaderAnchor(
  utf8Offset: block.sourceStartUtf8 + offsetInBlock,
  contentRevision: contentRevision,
);

/// An anchor at the very start of [block].
ReaderAnchor anchorAtBlockStart(
  Block block, {
  int contentRevision = kInitialContentRevision,
}) => anchorIn(block, 0, contentRevision: contentRevision);

/// An anchor at the rendered index [renderedIndex] of [block].
ReaderAnchor anchorAtRendered(
  Block block,
  int renderedIndex, {
  RenderedEdge edge = RenderedEdge.leading,
  int contentRevision = kInitialContentRevision,
}) => anchorIn(
  block,
  block.renderedToUtf8(renderedIndex, edge: edge),
  contentRevision: contentRevision,
);
