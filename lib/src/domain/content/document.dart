/// The parsed, immutable form of one source's markdown.
///
/// A [Document] owns the block list and every coordinate conversion the Reader
/// and extraction need. All of it is pure: nothing here mounts a widget, so
/// anchors resolve for blocks that are not currently rendered.
library;

import 'block.dart';
import 'markdown_block_parser.dart';
import 'reader_anchor.dart';
import 'source.dart';

/// Blocks of one source plus the markdown they were derived from.
final class Document {
  Document({
    required this.sourceId,
    required this.markdown,
    required List<Block> blocks,
  }) : blocks = List<Block>.unmodifiable(blocks),
       _indexById = <String, int>{
         for (var i = 0; i < blocks.length; i++) blocks[i].id: i,
       };

  /// Parses [markdown] for [sourceId], normalizing line endings first.
  factory Document.parse({required String sourceId, required String markdown}) {
    final normalized = normalizeMarkdown(markdown);
    return Document(
      sourceId: sourceId,
      markdown: normalized,
      blocks: parseMarkdownBlocks(normalized, sourceId: sourceId),
    );
  }

  /// Owning source.
  final String sourceId;

  /// Normalized source markdown. Offsets address this exact string.
  final String markdown;

  /// Blocks in document order.
  final List<Block> blocks;

  final Map<String, int> _indexById;

  /// Whether the document has no blocks.
  bool get isEmpty => blocks.isEmpty;

  /// The block with [id], or null when it does not belong to this document.
  Block? blockById(String id) {
    final index = _indexById[id];
    return index == null ? null : blocks[index];
  }

  /// Position of block [id] in document order, or null when unknown.
  int? indexOfBlock(String id) => _indexById[id];

  /// An anchor at the very start of the document.
  ReaderAnchor? get startAnchor => blocks.isEmpty
      ? null
      : ReaderAnchor(blockId: blocks.first.id, utf8Offset: 0);

  /// An anchor at the very end of the document.
  ReaderAnchor? get endAnchor => blocks.isEmpty
      ? null
      : ReaderAnchor(
          blockId: blocks.last.id,
          utf8Offset: blocks.last.lengthUtf8,
        );

  /// Document-absolute UTF-8 offset of [anchor], or null when unresolvable.
  int? documentOffsetOf(ReaderAnchor anchor) {
    final block = blockById(anchor.blockId);
    if (block == null) return null;
    if (anchor.utf8Offset < 0 || anchor.utf8Offset > block.lengthUtf8) {
      return null;
    }
    return block.sourceStartUtf8 + anchor.utf8Offset;
  }

  /// Whether [anchor] is a canonical coordinate in this document.
  bool containsAnchor(ReaderAnchor anchor) => documentOffsetOf(anchor) != null;

  /// Anchor for a document-absolute UTF-8 offset.
  ///
  /// An offset falling between blocks resolves to the start of the following
  /// block, so whitespace between blocks is never addressable.
  ReaderAnchor? anchorAtDocumentOffset(int documentUtf8Offset) {
    if (blocks.isEmpty) return null;
    if (documentUtf8Offset <= blocks.first.sourceStartUtf8) return startAnchor;
    var low = 0;
    var high = blocks.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (blocks[mid].sourceStartUtf8 <= documentUtf8Offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    final block = blocks[low];
    if (documentUtf8Offset > block.sourceEndUtf8) {
      // Landed in the gap after this block; move to the next block's start.
      if (low + 1 < blocks.length) {
        return ReaderAnchor(blockId: blocks[low + 1].id, utf8Offset: 0);
      }
      return ReaderAnchor(blockId: block.id, utf8Offset: block.lengthUtf8);
    }
    return ReaderAnchor(
      blockId: block.id,
      utf8Offset: documentUtf8Offset - block.sourceStartUtf8,
    );
  }

  /// Whether [a] comes before [b] in document order.
  bool isBefore(ReaderAnchor a, ReaderAnchor b) {
    final indexA = _indexById[a.blockId];
    final indexB = _indexById[b.blockId];
    if (indexA == null || indexB == null) return false;
    if (indexA != indexB) return indexA < indexB;
    return a.utf8Offset < b.utf8Offset;
  }

  /// The exact markdown between [start] and [end], inclusive of block breaks.
  ///
  /// Returns an empty string when either anchor is unknown or the range is
  /// inverted. Ranges spanning blocks include the original separators, so the
  /// result round-trips to the same text on re-parse.
  String markdownBetween(ReaderAnchor start, ReaderAnchor end) {
    final from = documentOffsetOf(start);
    final to = documentOffsetOf(end);
    if (from == null || to == null || to <= from) return '';
    final startBlock = blockById(start.blockId)!;
    final endBlock = blockById(end.blockId)!;
    if (identical(startBlock, endBlock)) {
      return startBlock.rawSlice(start.utf8Offset, end.utf8Offset);
    }
    final startUtf16 = _documentUtf16For(startBlock, start.utf8Offset);
    final endUtf16 = _documentUtf16For(endBlock, end.utf8Offset);
    return markdown.substring(startUtf16, endUtf16);
  }

  /// The exact markdown covered by [range].
  String markdownForRange(SelectionRange range) =>
      markdownBetween(range.startAnchor, range.endAnchor);

  /// Standalone Markdown that renders the same selected passage.
  ///
  /// M2 deliberately accepts one block only. The exact raw source slice and
  /// hash remain in [range] for provenance; this fragment repairs formatting
  /// delimiters at its boundaries for independent display and processing.
  String markdownFragmentForRange(SelectionRange range) {
    if (!range.isSameBlock) return '';
    final block = blockById(range.startAnchor.blockId);
    if (block == null ||
        !containsAnchor(range.startAnchor) ||
        !containsAnchor(range.endAnchor)) {
      return '';
    }
    final start = block.utf8ToRendered(range.startAnchor.utf8Offset);
    final end = block.utf8ToRendered(range.endAnchor.utf8Offset);
    return block.markdownFragmentForRendered(start, end);
  }

  /// Blocks touched by the range from [start] to [end], in document order.
  List<Block> blocksBetween(ReaderAnchor start, ReaderAnchor end) {
    final indexA = _indexById[start.blockId];
    final indexB = _indexById[end.blockId];
    if (indexA == null || indexB == null) return const <Block>[];
    final from = indexA <= indexB ? indexA : indexB;
    final to = indexA <= indexB ? indexB : indexA;
    return blocks.sublist(from, to + 1);
  }

  /// Words of rendered text between [start] and [end].
  ///
  /// Counted over what the reader sees, not over the markdown, so syntax does
  /// not inflate the reminder line's sense of how far the session has gone.
  int wordsBetween(ReaderAnchor start, ReaderAnchor end) {
    final startIndex = _indexById[start.blockId];
    final endIndex = _indexById[end.blockId];
    if (startIndex == null || endIndex == null || endIndex < startIndex) {
      return 0;
    }
    var words = 0;
    for (var i = startIndex; i <= endIndex; i++) {
      final block = blocks[i];
      final from = i == startIndex ? block.utf8ToRendered(start.utf8Offset) : 0;
      final to = i == endIndex
          ? block.utf8ToRendered(end.utf8Offset)
          : block.renderedText.length;
      if (to <= from) continue;
      words += countWords(block.renderedText.substring(from, to));
    }
    return words;
  }

  /// The anchor roughly [words] of rendered text after [from].
  ///
  /// Resolves to a block boundary, which is close enough for a reminder line
  /// and avoids implying a precision the count does not have.
  ReaderAnchor? anchorAfterWords(ReaderAnchor from, int words) {
    final startIndex = _indexById[from.blockId];
    if (startIndex == null) return null;
    var remaining = words;
    for (var i = startIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final start = i == startIndex ? block.utf8ToRendered(from.utf8Offset) : 0;
      final text = block.renderedText;
      if (start >= text.length) continue;
      final blockWords = countWords(text.substring(start));
      if (blockWords >= remaining) {
        return ReaderAnchor(blockId: block.id, utf8Offset: 0);
      }
      remaining -= blockWords;
    }
    return null;
  }

  int _documentUtf16For(Block block, int blockUtf8Offset) =>
      block.sourceStartUtf16 + block.utf8Index.toUtf16(blockUtf8Offset);
}
