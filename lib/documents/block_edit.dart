/// Turning a block-scoped edit into an exact splice.
///
/// Editing is block-scoped, and that is not only a UI preference: the byte
/// range of the block is known *before* the user types a character, so the
/// resulting splice needs no diffing and has no ambiguity. Everything in this
/// file is that translation.
///
/// See `plans/reader/EDITABLE_READER.md` §11.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';
import 'package:incremental_reader/documents/outline.dart';
import 'package:incremental_reader/documents/text_splice.dart';

/// The splice that replaces [block]'s markdown with [markdown].
///
/// Text that is blank after normalizing removes the block outright, via
/// [spliceForBlockRemoval], rather than leaving an empty paragraph behind.
TextSplice spliceForBlockEdit(Document document, Block block, String markdown) {
  final normalized = normalizeMarkdown(markdown);
  if (normalized.trim().isEmpty) return spliceForBlockRemoval(document, block);
  return TextSplice(
    startUtf8: block.sourceStartUtf8,
    endUtf8: block.sourceEndUtf8,
    inserted: normalized,
  );
}

/// The splice that removes [block], separator included.
///
/// The blank line that followed the block goes with it, so removing a middle
/// paragraph leaves the two survivors properly separated rather than run
/// together. A last block instead takes the separator that preceded it, and a
/// document's only block takes everything, leaving an empty source rather than
/// a stray blank line.
TextSplice spliceForBlockRemoval(Document document, Block block) {
  final index = document.indexOfBlock(block.id);
  if (index == null) {
    return TextSplice.delete(block.sourceStartUtf8, block.sourceEndUtf8);
  }
  final blocks = document.blocks;
  if (index + 1 < blocks.length) {
    return TextSplice.delete(
      block.sourceStartUtf8,
      blocks[index + 1].sourceStartUtf8,
    );
  }
  if (index > 0) {
    return TextSplice.delete(
      blocks[index - 1].sourceEndUtf8,
      block.sourceEndUtf8,
    );
  }
  return TextSplice.delete(0, document.lengthUtf8);
}

/// The splice that inserts [markdown] as a new block after [block].
///
/// Placed at the start of the following block so the new text lands *after*
/// the separator that already exists, and carries its own separator with it.
TextSplice spliceForBlockInsertion(
  Document document,
  Block block,
  String markdown,
) {
  final normalized = normalizeMarkdown(markdown).trim();
  final index = document.indexOfBlock(block.id);
  if (normalized.isEmpty || index == null) {
    return TextSplice.insert(block.sourceEndUtf8, '');
  }
  if (index + 1 < document.blocks.length) {
    return TextSplice.insert(
      document.blocks[index + 1].sourceStartUtf8,
      '$normalized\n\n',
    );
  }
  return TextSplice.insert(block.sourceEndUtf8, '\n\n$normalized');
}

/// The splice that swaps a heading's whole section with the sibling section
/// above or below it.
///
/// Both sections are contiguous and adjacent — a sibling is by definition the
/// next heading of the same level, with nothing shallower between them — so
/// the two of them plus the separator between are one unbroken range, and the
/// move is a single replacement of that range by the same text in the other
/// order. That matters: one splice is what every position and every extract
/// range already knows how to be migrated across.
///
/// Null when [blockId] is not a heading, or when there is no sibling that way.
TextSplice? spliceForSectionSwap(
  Document document,
  String blockId, {
  required bool shouldMoveUp,
}) {
  final outline = outlineOf(document);
  final entry = outlineEntryOf(outline, blockId);
  if (entry == null) return null;
  final neighbour = shouldMoveUp
      ? previousSiblingOf(outline, entry)
      : nextSiblingOf(outline, entry);
  if (neighbour == null) return null;

  final first = shouldMoveUp ? neighbour : entry;
  final second = shouldMoveUp ? entry : neighbour;
  return TextSplice(
    startUtf8: first.sectionStartUtf8,
    endUtf8: second.sectionEndUtf8,
    inserted:
        document.markdownSlice(second.sectionStartUtf8, second.sectionEndUtf8) +
        document.markdownSlice(first.sectionEndUtf8, second.sectionStartUtf8) +
        document.markdownSlice(first.sectionStartUtf8, first.sectionEndUtf8),
  );
}
