/// The parsed form of one source's markdown at one content revision.
///
/// A [Document] owns the block list and every coordinate conversion the Reader
/// and extraction need. All of it is pure: nothing here mounts a widget, so
/// anchors resolve for blocks that are not currently rendered.
///
/// Blocks are a *derived cache*. Their ids are positional and carry no meaning
/// outside this object — nothing persisted refers to them — so re-parsing after
/// an edit is free to renumber them. Positions are byte offsets into
/// the markdown, which survive re-parsing unchanged.
library;

import '../../core/utf8_offsets.dart';
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
    this.contentRevision = kInitialContentRevision,
  }) : blocks = List<Block>.unmodifiable(blocks),
       _indexById = <String, int>{
         for (var i = 0; i < blocks.length; i++) blocks[i].id: i,
       };

  /// Parses [markdown] for [sourceId], normalizing line endings first.
  factory Document.parse({
    required String sourceId,
    required String markdown,
    int contentRevision = kInitialContentRevision,
  }) {
    final normalized = normalizeMarkdown(markdown);
    return Document(
      sourceId: sourceId,
      markdown: normalized,
      blocks: parseMarkdownBlocks(normalized, sourceId: sourceId),
      contentRevision: contentRevision,
    );
  }

  /// Owning source.
  final String sourceId;

  /// Normalized source markdown. Offsets address this exact string.
  final String markdown;

  /// Revision of [markdown]. Anchors resolved here are stamped with it.
  final int contentRevision;

  /// Blocks in document order.
  final List<Block> blocks;

  final Map<String, int> _indexById;

  Utf8OffsetIndex? _utf8Index;

  /// UTF-8 index over the whole [markdown], built on first use.
  Utf8OffsetIndex get utf8Index => _utf8Index ??= Utf8OffsetIndex(markdown);

  /// Total UTF-8 length of the document.
  int get lengthUtf8 => utf8Index.byteLength;

  /// Whether the document has no blocks.
  bool get isEmpty => blocks.isEmpty;

  /// The block with [id], or null when it does not belong to this document.
  ///
  /// Block ids are ephemeral. Use this for rendering and hit-testing only,
  /// never to resolve anything that was persisted.
  Block? blockById(String id) {
    final index = _indexById[id];
    return index == null ? null : blocks[index];
  }

  /// Position of block [id] in document order, or null when unknown.
  int? indexOfBlock(String id) => _indexById[id];

  /// An anchor at the very start of the document.
  ReaderAnchor get startAnchor =>
      ReaderAnchor(utf8Offset: 0, contentRevision: contentRevision);

  /// An anchor at the very end of the document.
  ReaderAnchor get endAnchor => ReaderAnchor(
    utf8Offset: blocks.isEmpty ? 0 : blocks.last.sourceEndUtf8,
    contentRevision: contentRevision,
  );

  /// An anchor at [documentUtf8Offset], snapped into the nearest block.
  ///
  /// An offset falling in the whitespace between two blocks resolves to the
  /// start of the following block, so a gap is never addressable and two
  /// anchors that mean the same place compare equal.
  ReaderAnchor anchorAt(int documentUtf8Offset) => ReaderAnchor(
    utf8Offset: canonicalOffset(documentUtf8Offset),
    contentRevision: contentRevision,
  );

  /// [documentUtf8Offset] snapped into the nearest block.
  int canonicalOffset(int documentUtf8Offset) {
    if (blocks.isEmpty) return 0;
    final offset = documentUtf8Offset.clamp(0, lengthUtf8);
    if (offset <= blocks.first.sourceStartUtf8) {
      return blocks.first.sourceStartUtf8;
    }
    final index = _blockIndexAtOrBefore(offset);
    final block = blocks[index];
    if (offset <= block.sourceEndUtf8) return offset;
    // Landed in the gap after this block; move to the next block's start.
    if (index + 1 < blocks.length) return blocks[index + 1].sourceStartUtf8;
    return block.sourceEndUtf8;
  }

  /// The block containing [documentUtf8Offset], or null for an empty document.
  ///
  /// An offset in the gap between two blocks belongs to the following block,
  /// matching [canonicalOffset].
  Block? blockAtOffset(int documentUtf8Offset) {
    if (blocks.isEmpty) return null;
    final offset = canonicalOffset(documentUtf8Offset);
    return blocks[_blockIndexAtOrBefore(offset)];
  }

  /// Index of the block containing [documentUtf8Offset], or null when empty.
  int? blockIndexAtOffset(int documentUtf8Offset) {
    if (blocks.isEmpty) return null;
    return _blockIndexAtOrBefore(canonicalOffset(documentUtf8Offset));
  }

  /// The block [anchor] points into, or null when it cannot be resolved.
  Block? blockForAnchor(ReaderAnchor anchor) =>
      blockAtOffset(anchor.utf8Offset);

  /// Whether [anchor] addresses a place inside this document.
  ///
  /// Revision is not checked here: a caller holding an older anchor must
  /// migrate it forward first. See `SourceEditJournal`.
  bool containsAnchor(ReaderAnchor anchor) =>
      !isEmpty &&
      anchor.utf8Offset >= 0 &&
      anchor.utf8Offset <= lengthUtf8 &&
      canonicalOffset(anchor.utf8Offset) == anchor.utf8Offset;

  /// Document-absolute UTF-8 offset of [anchor], or null when unresolvable.
  ///
  /// Retained so callers read as coordinate conversions rather than field
  /// access; in document space the conversion is the identity.
  int? documentOffsetOf(ReaderAnchor anchor) =>
      containsAnchor(anchor) ? anchor.utf8Offset : null;

  /// Whether [a] comes before [b] in document order.
  bool isBefore(ReaderAnchor a, ReaderAnchor b) => a.utf8Offset < b.utf8Offset;

  /// Whether both ends of [range] land in the same block.
  bool isSameBlock(SelectionRange range) {
    final start = blockIndexAtOffset(range.startUtf8);
    if (start == null) return false;
    // The exclusive end of a range that stops exactly at a block boundary
    // belongs to the block it closes, not to the one that follows.
    final end = blockIndexAtOffsetTrailing(range.endUtf8);
    return start == end;
  }

  /// Block index for the *exclusive* end of a range.
  ///
  /// An end offset sitting exactly on a block's start belongs to the previous
  /// block, which is the one the range actually covered.
  int? blockIndexAtOffsetTrailing(int documentUtf8Offset) {
    if (blocks.isEmpty) return null;
    final offset = documentUtf8Offset.clamp(0, lengthUtf8);
    final index = _blockIndexAtOrBefore(offset);
    final block = blocks[index];
    if (offset <= block.sourceStartUtf8 && index > 0) return index - 1;
    return index;
  }

  /// The exact markdown between [start] and [end], inclusive of block breaks.
  ///
  /// Returns an empty string when the range is inverted or unresolvable.
  /// Ranges spanning blocks include the original separators, so the result
  /// round-trips to the same text on re-parse.
  String markdownBetween(ReaderAnchor start, ReaderAnchor end) =>
      markdownSlice(start.utf8Offset, end.utf8Offset);

  /// The exact markdown of the byte range `[startUtf8, endUtf8)`.
  String markdownSlice(int startUtf8, int endUtf8) {
    if (endUtf8 <= startUtf8) return '';
    final from = utf8Index.toUtf16(startUtf8.clamp(0, lengthUtf8));
    final to = utf8Index.toUtf16(endUtf8.clamp(0, lengthUtf8));
    if (to <= from) return '';
    return markdown.substring(from, to);
  }

  /// The exact markdown covered by [range].
  String markdownForRange(SelectionRange range) =>
      markdownSlice(range.startUtf8, range.endUtf8);

  /// Standalone Markdown that renders the same selected passage.
  ///
  /// One block only. The exact raw source slice and hash remain in [range] for
  /// provenance; this fragment repairs formatting delimiters at its boundaries
  /// so the passage renders on its own.
  String markdownFragmentForRange(SelectionRange range) {
    if (!isSameBlock(range)) return '';
    final block = blockAtOffset(range.startUtf8);
    if (block == null) return '';
    final start = block.utf8ToRendered(
      _blockRelative(block, range.startUtf8),
    );
    final end = block.utf8ToRendered(_blockRelative(block, range.endUtf8));
    return block.markdownFragmentForRendered(start, end);
  }

  /// Blocks touched by the range from [start] to [end], in document order.
  List<Block> blocksBetween(ReaderAnchor start, ReaderAnchor end) {
    if (blocks.isEmpty) return const <Block>[];
    final a = blockIndexAtOffset(start.utf8Offset);
    final b = blockIndexAtOffset(end.utf8Offset);
    if (a == null || b == null) return const <Block>[];
    final from = a <= b ? a : b;
    final to = a <= b ? b : a;
    return blocks.sublist(from, to + 1);
  }

  /// Words of rendered text between [start] and [end].
  ///
  /// Counted over what the reader sees, not over the markdown, so syntax does
  /// not inflate the reminder line's sense of how far the session has gone.
  int wordsBetween(ReaderAnchor start, ReaderAnchor end) =>
      wordsInRange(start.utf8Offset, end.utf8Offset);

  /// Words of rendered text in the byte range `[startUtf8, endUtf8)`.
  int wordsInRange(int startUtf8, int endUtf8) {
    if (blocks.isEmpty || endUtf8 <= startUtf8) return 0;
    final startIndex = blockIndexAtOffset(startUtf8);
    final endIndex = blockIndexAtOffset(endUtf8);
    if (startIndex == null || endIndex == null || endIndex < startIndex) {
      return 0;
    }
    var words = 0;
    for (var i = startIndex; i <= endIndex; i++) {
      final block = blocks[i];
      final from = i == startIndex
          ? block.utf8ToRendered(_blockRelative(block, startUtf8))
          : 0;
      final to = i == endIndex
          ? block.utf8ToRendered(_blockRelative(block, endUtf8))
          : block.renderedText.length;
      if (to <= from) continue;
      words += countWords(block.renderedText.substring(from, to));
    }
    return words;
  }

  /// Words of rendered text not covered by any of [ranges].
  ///
  /// Answers "is there anything left to mine?". A source whose text has all
  /// been promoted into extracts has nothing more to give, which — together
  /// with the reading position having reached the end — is the only condition
  /// under which a source may close itself. Reaching the end alone never is:
  /// an article can be read through and still deserve another pass.
  int wordsOutside(List<(ReaderAnchor, ReaderAnchor)> ranges) {
    final covered = <int, List<(int, int)>>{};
    for (final (ReaderAnchor a, ReaderAnchor b) in ranges) {
      final bool forward = a.utf8Offset <= b.utf8Offset;
      final ReaderAnchor start = forward ? a : b;
      final ReaderAnchor end = forward ? b : a;
      final int? from = blockIndexAtOffset(start.utf8Offset);
      final int? to = blockIndexAtOffset(end.utf8Offset);
      if (from == null || to == null) continue;

      for (var i = from; i <= to; i++) {
        final Block block = blocks[i];
        final int lo = i == from
            ? block.utf8ToRendered(_blockRelative(block, start.utf8Offset))
            : 0;
        final int hi = i == to
            ? block.utf8ToRendered(_blockRelative(block, end.utf8Offset))
            : block.renderedText.length;
        if (hi <= lo) continue;
        (covered[i] ??= <(int, int)>[]).add((lo, hi));
      }
    }

    var words = 0;
    for (var i = 0; i < blocks.length; i++) {
      final String text = blocks[i].renderedText;
      final List<(int, int)>? spans = covered[i];
      if (spans == null) {
        words += countWords(text);
        continue;
      }
      spans.sort(((int, int) x, (int, int) y) => x.$1.compareTo(y.$1));
      var cursor = 0;
      for (final (int lo, int hi) in spans) {
        if (lo > cursor) words += countWords(text.substring(cursor, lo));
        if (hi > cursor) cursor = hi;
      }
      if (cursor < text.length) words += countWords(text.substring(cursor));
    }
    return words;
  }

  /// The anchor roughly [words] of rendered text after [from].
  ///
  /// Resolves to a block boundary, which is close enough for a reminder line
  /// and avoids implying a precision the count does not have.
  ReaderAnchor? anchorAfterWords(ReaderAnchor from, int words) {
    final startIndex = blockIndexAtOffset(from.utf8Offset);
    if (startIndex == null) return null;
    var remaining = words;
    for (var i = startIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final start = i == startIndex
          ? block.utf8ToRendered(_blockRelative(block, from.utf8Offset))
          : 0;
      final text = block.renderedText;
      if (start >= text.length) continue;
      final blockWords = countWords(text.substring(start));
      if (blockWords >= remaining) {
        return ReaderAnchor(
          utf8Offset: block.sourceStartUtf8,
          contentRevision: contentRevision,
        );
      }
      remaining -= blockWords;
    }
    return null;
  }

  /// [documentUtf8Offset] expressed relative to [block], clamped to it.
  int _blockRelative(Block block, int documentUtf8Offset) =>
      (documentUtf8Offset - block.sourceStartUtf8).clamp(0, block.lengthUtf8);

  /// Index of the last block whose start is at or before [offset].
  int _blockIndexAtOrBefore(int offset) {
    var low = 0;
    var high = blocks.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (blocks[mid].sourceStartUtf8 <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}
