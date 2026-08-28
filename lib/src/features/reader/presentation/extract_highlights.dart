/// Turns provenance into what the reader actually sees on the page.
///
/// SuperMemo leaves extracted passages visibly marked inside the article, and
/// that mark is load-bearing: it is the only way to tell, mid-chapter, which
/// sentences have already been processed. Extraction never edits the text, so
/// the mark has to be recomputed from each extract's recorded byte range every
/// time the document is rendered.
///
/// An extract whose provenance has degraded is not painted. A stale range no
/// longer describes the passage the extract holds, and a wash drawn over the
/// wrong sentence is a worse answer than no wash at all.
library;

import 'package:incremental_reader/src/app/theme.dart';
import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/extract.dart';
import 'package:incremental_reader/src/domain/content/reader_coordinates.dart';
import 'package:incremental_reader/src/features/reader/presentation/block_span_builder.dart';

/// Persistent extract washes for every block of [document], keyed by block id.
///
/// [focusedExtractId] names the extract the user just chose in the side panel;
/// it is painted in the stronger wash so "go to this extract" lands on
/// something the eye can find, instead of only scrolling near it.
Map<String, List<BlockHighlight>> buildExtractHighlights(
  Document document,
  List<Extract> extracts, {
  String? focusedExtractId,
}) {
  final result = <String, List<BlockHighlight>>{};
  final coordinates = ReaderCoordinates(document);

  for (final extract in extracts) {
    final range = _paintableRange(document, extract);
    if (range == null) continue;
    final (int startIndex, int endIndex) = range;

    final focused = extract.id == focusedExtractId;
    for (var index = startIndex; index <= endIndex; index++) {
      final block = document.blocks[index];
      final (int from, int to) = coordinates.renderedRangeForDocument(
        block,
        extract.provenance.startUtf8,
        extract.provenance.endUtf8,
      );
      if (to <= from) continue;

      (result[block.id] ??= <BlockHighlight>[]).add(
        BlockHighlight(
          start: from,
          end: to,
          color: focused ? AppColors.extractFocusWash : AppColors.extractWash,
          underlineColor: AppColors.extractInk.withValues(
            alpha: focused ? 0.9 : 0.45,
          ),
        ),
      );
    }
  }

  // The focused extract is painted last in insertion order, so lift it to the
  // front: the span builder resolves overlaps by taking the first match.
  if (focusedExtractId != null) {
    for (final entry in result.entries) {
      entry.value.sort((BlockHighlight a, BlockHighlight b) {
        final aFocused = a.color == AppColors.extractFocusWash;
        final bFocused = b.color == AppColors.extractFocusWash;
        if (aFocused == bFocused) return 0;
        return aFocused ? -1 : 1;
      });
    }
  }

  return result;
}

/// The extracts covering [blockId], in list order.
///
/// Used when the gutter mark is clicked: the mark appears beside every block
/// an extract touches, so the context it opens has to match.
List<Extract> extractsCoveringBlock(
  Document document,
  List<Extract> extracts,
  String blockId,
) {
  final index = document.indexOfBlock(blockId);
  if (index == null) return const <Extract>[];
  return <Extract>[
    for (final extract in extracts)
      if (_covers(document, extract, index)) extract,
  ];
}

bool _covers(Document document, Extract extract, int blockIndex) {
  final range = _paintableRange(document, extract);
  if (range == null) return false;
  return blockIndex >= range.$1 && blockIndex <= range.$2;
}

/// Where a block's extract marks belong in the gutter, keyed by block id.
///
/// Every block an extract *covers* is marked, not only the one it starts in:
/// a passage spanning a paragraph break has been processed along its whole
/// length, and a gutter that says otherwise is lying.
Map<String, int> extractMarksByCoveredBlock(
  Document document,
  List<Extract> extracts,
) {
  final counts = <String, int>{};
  for (final extract in extracts) {
    final range = _paintableRange(document, extract);
    if (range == null) continue;
    for (var index = range.$1; index <= range.$2; index++) {
      final Block block = document.blocks[index];
      counts[block.id] = (counts[block.id] ?? 0) + 1;
    }
  }
  return counts;
}

/// Block index range this extract may be drawn over, or null when it may not.
///
/// Returns null for an extract taken from another extract — its range
/// addresses that parent's text, not this document — and for one whose link
/// back has degraded.
(int, int)? _paintableRange(Document document, Extract extract) {
  final provenance = extract.provenance;
  if (!provenance.parentIsSource) return null;
  if (provenance.parentId != document.sourceId) return null;
  if (!provenance.isIntact) return null;
  if (provenance.endUtf8 <= provenance.startUtf8) return null;

  final startIndex = document.blockIndexAtOffset(provenance.startUtf8);
  final endIndex = document.blockIndexAtOffsetTrailing(provenance.endUtf8);
  if (startIndex == null || endIndex == null || endIndex < startIndex) {
    return null;
  }
  return (startIndex, endIndex);
}
