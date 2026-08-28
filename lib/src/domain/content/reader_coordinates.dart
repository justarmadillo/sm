/// The single place rendered screen positions become stored document offsets.
///
/// Four coordinate spaces exist, and only the first is ever persisted:
///
/// 1. **document** — UTF-8 byte offset into `Document.markdown`;
/// 2. **block-raw** — UTF-16 index into `Block.raw`;
/// 3. **block-content** — UTF-16 index into `BlockContent.text`, with per-line
///    syntax such as `> ` or `## ` removed;
/// 4. **rendered** — UTF-16 index into `InlineLayout.plainText`, which is what
///    the user actually sees and selects.
///
/// Every link of that chain already exists on [Block] and [Document]. The
/// reason to funnel them through one object is that walking the chain by hand
/// at each call site is how the ends drift apart: selection, extraction,
/// highlighting, and the editor must agree on the conversion exactly, or an
/// extract records provenance that is a character or two off and nothing ever
/// says so.
///
/// See `plans/reader/EDITABLE_READER.md` §3.
library;

import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/inline_markup.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';

/// Converts between rendered positions and document offsets.
final class ReaderCoordinates {
  const ReaderCoordinates(this.document);

  final Document document;

  /// Document offset of [renderedIndex] within [block].
  ///
  /// [edge] decides which run owns a position sitting between two runs. Use
  /// [RenderedEdge.trailing] for the exclusive end of a range.
  int documentOffsetForRendered(
    Block block,
    int renderedIndex, {
    RenderedEdge edge = RenderedEdge.leading,
  }) =>
      block.sourceStartUtf8 + block.renderedToUtf8(renderedIndex, edge: edge);

  /// Rendered index within [block] for [documentUtf8Offset].
  int renderedIndexForDocument(Block block, int documentUtf8Offset) {
    final relative = (documentUtf8Offset - block.sourceStartUtf8).clamp(
      0,
      block.lengthUtf8,
    );
    return block.utf8ToRendered(relative);
  }

  /// Document byte range covered by rendered `[start, end)` of [block].
  (int, int) documentRangeForRendered(
    Block block,
    int startRendered,
    int endRendered,
  ) => (
    documentOffsetForRendered(block, startRendered),
    documentOffsetForRendered(block, endRendered, edge: RenderedEdge.trailing),
  );

  /// An anchor at rendered [renderedIndex] of [block].
  ReaderAnchor anchorForRendered(
    Block block,
    int renderedIndex, {
    RenderedEdge edge = RenderedEdge.leading,
  }) => ReaderAnchor(
    utf8Offset: documentOffsetForRendered(block, renderedIndex, edge: edge),
    contentRevision: document.contentRevision,
  );

  /// The selection range covering rendered `[start, end)` across two blocks.
  ///
  /// [startBlock] and [endBlock] may be the same block. The hash is taken over
  /// the exact markdown the range covers, including any block separators, so
  /// provenance can be re-verified byte for byte after a later edit.
  SelectionRange rangeForRendered({
    required Block startBlock,
    required int startRendered,
    required Block endBlock,
    required int endRendered,
  }) {
    final start = documentOffsetForRendered(startBlock, startRendered);
    final end = documentOffsetForRendered(
      endBlock,
      endRendered,
      edge: RenderedEdge.trailing,
    );
    final from = start <= end ? start : end;
    final to = start <= end ? end : start;
    return SelectionRange.of(
      startAnchor: ReaderAnchor(
        utf8Offset: from,
        contentRevision: document.contentRevision,
      ),
      endAnchor: ReaderAnchor(
        utf8Offset: to,
        contentRevision: document.contentRevision,
      ),
      markdown: document.markdownSlice(from, to),
    );
  }

  /// Rendered range of [block] covered by the document range `[start, end)`.
  ///
  /// Clamped to the block, so a range spanning several blocks yields the part
  /// this block contributes.
  (int, int) renderedRangeForDocument(
    Block block,
    int startUtf8,
    int endUtf8,
  ) {
    final from = startUtf8 <= block.sourceStartUtf8
        ? 0
        : renderedIndexForDocument(block, startUtf8);
    final to = endUtf8 >= block.sourceEndUtf8
        ? block.renderedText.length
        : renderedIndexForDocument(block, endUtf8);
    return (from, to < from ? from : to);
  }
}
