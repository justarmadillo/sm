/// Turns provenance into what the reader actually sees on the page.
///
/// SuperMemo leaves extracted passages visibly marked inside the article, and
/// that mark is load-bearing: it is the only way to tell, mid-chapter, which
/// sentences have already been processed. Extraction never edits the text, so
/// the mark has to be recomputed from each extract's anchors every time the
/// document is rendered.
library;

import '../../../app/theme.dart';
import '../../../domain/content/block.dart';
import '../../../domain/content/document.dart';
import '../../../domain/content/extract.dart';
import 'block_span_builder.dart';

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

  for (final extract in extracts) {
    final start = extract.provenance.startAnchor;
    final end = extract.provenance.endAnchor;
    final startIndex = document.indexOfBlock(start.blockId);
    final endIndex = document.indexOfBlock(end.blockId);
    if (startIndex == null || endIndex == null || endIndex < startIndex) {
      // An extract taken from another extract, or from a stale document
      // version. Provenance is still intact; it simply has nothing to paint
      // here.
      continue;
    }

    final focused = extract.id == focusedExtractId;
    for (var index = startIndex; index <= endIndex; index++) {
      final block = document.blocks[index];
      final text = block.renderedText;
      final from = index == startIndex
          ? block.utf8ToRendered(start.utf8Offset)
          : 0;
      final to = index == endIndex
          ? block.utf8ToRendered(end.utf8Offset)
          : text.length;
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
  final startIndex = document.indexOfBlock(
    extract.provenance.startAnchor.blockId,
  );
  final endIndex = document.indexOfBlock(extract.provenance.endAnchor.blockId);
  if (startIndex == null || endIndex == null) return false;
  return blockIndex >= startIndex && blockIndex <= endIndex;
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
    final startIndex = document.indexOfBlock(
      extract.provenance.startAnchor.blockId,
    );
    final endIndex = document.indexOfBlock(
      extract.provenance.endAnchor.blockId,
    );
    if (startIndex == null || endIndex == null || endIndex < startIndex) {
      continue;
    }
    for (var index = startIndex; index <= endIndex; index++) {
      final Block block = document.blocks[index];
      counts[block.id] = (counts[block.id] ?? 0) + 1;
    }
  }
  return counts;
}
