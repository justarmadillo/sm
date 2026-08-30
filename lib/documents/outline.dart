/// The headings of a document, and the stretch of text each one owns.
///
/// The Reader's outline panel is not a table of contents drawn beside the
/// article: it is the article's own heading lines, listed. Renaming an entry,
/// indenting it, or moving it therefore has to become an edit to the markdown,
/// and that is what this file makes possible — it works out, for one heading,
/// exactly which bytes belong to it.
///
/// A heading owns everything after it up to the next heading of the same level
/// or a shallower one. That is the ordinary reading of a document's structure,
/// and it is what makes "move this section down" mean the whole section rather
/// than one line.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:meta/meta.dart';

/// One heading, with the stretch of document it owns.
@immutable
final class OutlineEntry {
  const OutlineEntry({
    required this.blockId,
    required this.level,
    required this.text,
    required this.position,
    required this.sectionStartUtf8,
    required this.sectionEndUtf8,
    required this.sectionLastBlockId,
  });

  /// The heading block itself, for the commands that edit or remove it.
  final String blockId;

  /// 1 for `#`, 6 for `######`.
  final int level;

  /// The heading's words, without the leading hashes.
  final String text;

  /// Where this entry sits in the outline, top to bottom, counting from zero.
  final int position;

  /// First byte of the heading line.
  final int sectionStartUtf8;

  /// One past the last byte of the last block this heading owns.
  ///
  /// Stops before the blank line that separates this section from the next,
  /// so a section can be lifted out and put back without collecting or losing
  /// separators.
  final int sectionEndUtf8;

  /// Last block inside the section, which is the heading itself when the
  /// section has no body. What a new sibling heading is inserted after.
  final String sectionLastBlockId;
}

/// The document's headings, top to bottom.
List<OutlineEntry> outlineOf(Document document) {
  final List<Block> blocks = document.blocks;
  final List<int> headingIndexes = <int>[
    for (int index = 0; index < blocks.length; index++)
      if (blocks[index].type == BlockType.heading) index,
  ];

  final List<OutlineEntry> entries = <OutlineEntry>[];
  for (var position = 0; position < headingIndexes.length; position++) {
    final int blockIndex = headingIndexes[position];
    final Block heading = blocks[blockIndex];
    final int level = heading.headingLevel ?? 1;

    // Walk forward to the first heading that this one does not contain. The
    // block before it is where the section ends.
    var lastIndex = blocks.length - 1;
    for (var scan = position + 1; scan < headingIndexes.length; scan++) {
      final Block next = blocks[headingIndexes[scan]];
      if ((next.headingLevel ?? 1) <= level) {
        lastIndex = headingIndexes[scan] - 1;
        break;
      }
    }

    entries.add(
      OutlineEntry(
        blockId: heading.id,
        level: level,
        text: heading.renderedText,
        position: position,
        sectionStartUtf8: heading.sourceStartUtf8,
        sectionEndUtf8: blocks[lastIndex].sourceEndUtf8,
        sectionLastBlockId: blocks[lastIndex].id,
      ),
    );
  }
  return entries;
}

/// The markdown line for a heading of [level] reading [text].
String headingMarkdown({required int level, required String text}) =>
    '${'#' * level.clamp(1, 6)} ${text.trim()}';

/// The entry immediately above [entry] at the same level, under the same
/// parent, or null when [entry] is the first of its group.
///
/// The search stops at the first shallower heading, because that heading is
/// the parent: the entry before it belongs to a different branch, and swapping
/// with it would move a section out from under the heading it sits below.
OutlineEntry? previousSiblingOf(
  List<OutlineEntry> outline,
  OutlineEntry entry,
) {
  for (var scan = entry.position - 1; scan >= 0; scan--) {
    if (outline[scan].level < entry.level) return null;
    if (outline[scan].level == entry.level) return outline[scan];
  }
  return null;
}

/// The entry immediately below [entry] at the same level, under the same
/// parent, or null when [entry] is the last of its group.
OutlineEntry? nextSiblingOf(List<OutlineEntry> outline, OutlineEntry entry) {
  for (var scan = entry.position + 1; scan < outline.length; scan++) {
    if (outline[scan].level < entry.level) return null;
    if (outline[scan].level == entry.level) return outline[scan];
  }
  return null;
}

/// The entry for [blockId], or null when that block is not a heading.
OutlineEntry? outlineEntryOf(List<OutlineEntry> outline, String blockId) {
  for (final OutlineEntry entry in outline) {
    if (entry.blockId == blockId) return entry;
  }
  return null;
}
