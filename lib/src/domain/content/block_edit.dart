/// Turning a block-scoped edit into an exact splice.
///
/// Editing is block-scoped, and that is not only a UI preference: the byte
/// range of the block is known *before* the user types a character, so the
/// resulting splice needs no diffing and has no ambiguity. Everything in this
/// file is that translation.
///
/// See `plans/reader/EDITABLE_READER.md` §11.
library;

import 'block.dart';
import 'document.dart';
import 'markdown_block_parser.dart';
import 'text_splice.dart';

/// The splice that replaces [block]'s markdown with [markdown].
///
/// Text that is blank after normalizing removes the block outright, via
/// [spliceForBlockRemoval], rather than leaving an empty paragraph behind.
TextSplice spliceForBlockEdit(
  Document document,
  Block block,
  String markdown,
) {
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
