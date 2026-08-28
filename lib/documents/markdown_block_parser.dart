/// Splits source markdown into immutable blocks with exact source offsets.
///
/// Runs once per source, at import. The output is persisted, so the parse must
/// be deterministic and its offsets must address the stored markdown exactly:
/// every anchor and extract in the collection is expressed against them.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/block_content.dart';
import 'package:incremental_reader/shared/utf8_offsets.dart';

/// Normalizes line endings so stored offsets never depend on the platform the
/// markdown was imported on.
///
/// Import stores the normalized text; offsets always address that text.
String normalizeMarkdown(String markdown) {
  if (!markdown.contains('\r')) return markdown;
  return markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

/// Parses [markdown] into blocks belonging to [sourceId].
///
/// [markdown] must already be normalized by [normalizeMarkdown].
List<Block> parseMarkdownBlocks(String markdown, {required String sourceId}) {
  final lines = _splitLines(markdown);
  final utf8Index = Utf8OffsetIndex(markdown);
  final blocks = <Block>[];
  var firstLineIndex = 0;

  /// Appends one finished block, converting absolute spans to block-local
  /// ones so a block never depends on where it sits in the document.
  void addBlock(
    BlockType type,
    int startUtf16,
    int endUtf16,
    List<Utf16Span> absoluteContentSpans, {
    int? headingLevel,
    String? codeLanguage,
    bool isOrderedListItem = false,
    String? listMarker,
    int listDepth = 0,
    int quoteDepth = 0,
  }) {
    final raw = markdown.substring(startUtf16, endUtf16);
    blocks.add(
      Block(
        id: blockId(sourceId, blocks.length),
        index: blocks.length,
        type: type,
        raw: raw,
        sourceStartUtf8: utf8Index.toUtf8(startUtf16),
        sourceEndUtf8: utf8Index.toUtf8(endUtf16),
        sourceStartUtf16: startUtf16,
        contentSpans: <Utf16Span>[
          for (final span in absoluteContentSpans)
            Utf16Span(span.start - startUtf16, span.end - startUtf16),
        ],
        headingLevel: headingLevel,
        codeLanguage: codeLanguage,
        isOrderedListItem: isOrderedListItem,
        listMarker: listMarker,
        listDepth: listDepth,
        quoteDepth: quoteDepth,
      ),
    );
  }

  while (firstLineIndex < lines.length) {
    final line = lines[firstLineIndex];
    final text = line.text(markdown);

    if (text.trim().isEmpty) {
      firstLineIndex++;
      continue;
    }

    final fence = _matchFence(text);
    if (fence != null) {
      var lineAfterBlock = firstLineIndex + 1;
      while (lineAfterBlock < lines.length &&
          !_closesFence(lines[lineAfterBlock].text(markdown), fence)) {
        lineAfterBlock++;
      }
      final contentStart = firstLineIndex + 1 <= lines.length - 1
          ? lines[firstLineIndex + 1].start
          : line.end;
      final contentEnd = lineAfterBlock > firstLineIndex + 1
          ? lines[lineAfterBlock - 1].end
          : contentStart;
      final blockEnd = lineAfterBlock < lines.length
          ? lines[lineAfterBlock].end
          : lines[lineAfterBlock - 1].end;
      addBlock(
        BlockType.codeBlock,
        line.start,
        blockEnd,
        lineAfterBlock > firstLineIndex + 1
            ? <Utf16Span>[Utf16Span(contentStart, contentEnd)]
            : const <Utf16Span>[],
        codeLanguage: fence.language.isEmpty ? null : fence.language,
      );
      firstLineIndex = lineAfterBlock + 1;
      continue;
    }

    if (text.trim() == r'$$') {
      var lineAfterBlock = firstLineIndex + 1;
      while (lineAfterBlock < lines.length &&
          lines[lineAfterBlock].text(markdown).trim() != r'$$') {
        lineAfterBlock++;
      }
      final contentStart = firstLineIndex + 1 < lines.length
          ? lines[firstLineIndex + 1].start
          : line.end;
      final contentEnd = lineAfterBlock > firstLineIndex + 1
          ? lines[lineAfterBlock - 1].end
          : contentStart;
      final blockEnd = lineAfterBlock < lines.length
          ? lines[lineAfterBlock].end
          : lines[lineAfterBlock - 1].end;
      addBlock(
        BlockType.mathBlock,
        line.start,
        blockEnd,
        lineAfterBlock > firstLineIndex + 1
            ? <Utf16Span>[Utf16Span(contentStart, contentEnd)]
            : const <Utf16Span>[],
      );
      firstLineIndex = lineAfterBlock + 1;
      continue;
    }

    final heading = _matchHeading(text);
    if (heading != null) {
      addBlock(BlockType.heading, line.start, line.end, <Utf16Span>[
        Utf16Span(
          line.start + heading.contentStart,
          line.start + heading.contentEnd,
        ),
      ], headingLevel: heading.level);
      firstLineIndex++;
      continue;
    }

    if (_isThematicBreak(text)) {
      addBlock(
        BlockType.thematicBreak,
        line.start,
        line.end,
        const <Utf16Span>[],
      );
      firstLineIndex++;
      continue;
    }

    if (_quotePrefixLength(text) != null) {
      var lineAfterBlock = firstLineIndex;
      final spans = <Utf16Span>[];
      var depth = 0;
      while (lineAfterBlock < lines.length) {
        final lineText = lines[lineAfterBlock].text(markdown);
        final prefix = _quotePrefixLength(lineText);
        if (prefix == null) break;
        depth = depth == 0 ? _quoteDepth(lineText) : depth;
        final isLast =
            lineAfterBlock + 1 >= lines.length ||
            _quotePrefixLength(lines[lineAfterBlock + 1].text(markdown)) ==
                null;
        spans.add(
          Utf16Span(
            lines[lineAfterBlock].start + prefix,
            isLast
                ? lines[lineAfterBlock].end
                : lines[lineAfterBlock].endWithBreak,
          ),
        );
        lineAfterBlock++;
      }
      addBlock(
        BlockType.quote,
        line.start,
        lines[lineAfterBlock - 1].end,
        spans,
        quoteDepth: depth,
      );
      firstLineIndex = lineAfterBlock;
      continue;
    }

    final listItem = _matchListItem(text);
    if (listItem != null) {
      var lineAfterBlock = firstLineIndex;
      final spans = <Utf16Span>[
        Utf16Span(line.start + listItem.contentStart, line.endWithBreak),
      ];
      lineAfterBlock++;
      while (lineAfterBlock < lines.length) {
        final lineText = lines[lineAfterBlock].text(markdown);
        if (lineText.trim().isEmpty) break;
        if (_matchListItem(lineText) != null) break;
        if (_startsNewBlock(lineText)) break;
        final indent = _leadingSpaces(lineText);
        // A continuation line indented past the marker keeps the marker's
        // indent; a shallower one keeps its own, so no real text is dropped.
        final keptIndent = indent >= listItem.contentStart
            ? listItem.contentStart
            : indent;
        spans.add(
          Utf16Span(
            lines[lineAfterBlock].start + keptIndent,
            lines[lineAfterBlock].endWithBreak,
          ),
        );
        lineAfterBlock++;
      }
      // Trim the trailing line break of the final content span.
      final lastSpan = spans.removeLast();
      spans.add(Utf16Span(lastSpan.start, lines[lineAfterBlock - 1].end));
      addBlock(
        BlockType.listItem,
        line.start,
        lines[lineAfterBlock - 1].end,
        spans,
        isOrderedListItem: listItem.isOrdered,
        listMarker: listItem.marker,
        listDepth: listItem.indent ~/ 2,
      );
      firstLineIndex = lineAfterBlock;
      continue;
    }

    if (text.contains('|') &&
        firstLineIndex + 1 < lines.length &&
        _isTableDelimiter(lines[firstLineIndex + 1].text(markdown))) {
      var lineAfterBlock = firstLineIndex;
      while (lineAfterBlock < lines.length &&
          lines[lineAfterBlock].text(markdown).trim().isNotEmpty &&
          lines[lineAfterBlock].text(markdown).contains('|')) {
        lineAfterBlock++;
      }
      addBlock(
        BlockType.table,
        line.start,
        lines[lineAfterBlock - 1].end,
        <Utf16Span>[Utf16Span(line.start, lines[lineAfterBlock - 1].end)],
      );
      firstLineIndex = lineAfterBlock;
      continue;
    }

    // Paragraph: runs until a blank line or the start of another block.
    var lineAfterBlock = firstLineIndex + 1;
    while (lineAfterBlock < lines.length) {
      final lineText = lines[lineAfterBlock].text(markdown);
      if (lineText.trim().isEmpty) break;
      if (_startsNewBlock(lineText)) break;
      if (_matchListItem(lineText) != null) break;
      lineAfterBlock++;
    }
    addBlock(
      BlockType.paragraph,
      line.start,
      lines[lineAfterBlock - 1].end,
      <Utf16Span>[Utf16Span(line.start, lines[lineAfterBlock - 1].end)],
    );
    firstLineIndex = lineAfterBlock;
  }

  return List<Block>.unmodifiable(blocks);
}

/// Deterministic block identifier for block [index] of [sourceId].
String blockId(String sourceId, int index) => '$sourceId:$index';

/// One line of the source markdown, addressed by UTF-16 index.
final class _SourceLine {
  const _SourceLine(this.start, this.end, this.endWithBreak);

  /// UTF-16 index of the first character.
  final int start;

  /// UTF-16 index one past the last character, excluding the line break.
  final int end;

  /// UTF-16 index one past the line break, or equal to [end] at end of input.
  final int endWithBreak;

  String text(String source) => source.substring(start, end);
}

/// Splits [source] into lines, keeping both the break-excluded and
/// break-included ends so a block can decide whether its last line's newline
/// belongs to it.
List<_SourceLine> _splitLines(String source) {
  final lines = <_SourceLine>[];
  var start = 0;
  for (var cursor = 0; cursor < source.length; cursor++) {
    if (source.codeUnitAt(cursor) == 0x0A) {
      lines.add(_SourceLine(start, cursor, cursor + 1));
      start = cursor + 1;
    }
  }
  if (start <= source.length - 1 || source.isEmpty) {
    lines.add(_SourceLine(start, source.length, source.length));
  }
  return lines;
}

/// An opening ``` or ~~~ code fence.
final class _Fence {
  const _Fence(this.marker, this.length, this.language);

  /// The single fence character, ` or ~.
  final String marker;

  /// How many times [marker] repeats. A closing fence must be at least as long.
  final int length;

  /// The info string after the fence, for example `dart`.
  final String language;
}

/// The code fence [text] opens, or null when it opens none.
_Fence? _matchFence(String text) {
  final trimmed = text.trimLeft();
  for (final marker in const <String>['```', '~~~']) {
    if (!trimmed.startsWith(marker)) continue;
    var length = 0;
    while (length < trimmed.length && trimmed[length] == marker[0]) {
      length++;
    }
    return _Fence(marker[0], length, trimmed.substring(length).trim());
  }
  return null;
}

/// Whether [text] is a closing fence for [fence].
bool _closesFence(String text, _Fence fence) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  var length = 0;
  while (length < trimmed.length && trimmed[length] == fence.marker) {
    length++;
  }
  return length >= fence.length && trimmed.substring(length).trim().isEmpty;
}

/// A heading's level, and the span of its text without the `#` syntax.
final class _Heading {
  const _Heading(this.level, this.contentStart, this.contentEnd);

  final int level;
  final int contentStart;
  final int contentEnd;
}

/// The ATX heading [text] is, or null when it is not a heading.
_Heading? _matchHeading(String text) {
  var cursor = 0;
  while (cursor < text.length && text[cursor] == ' ' && cursor < 4) {
    cursor++;
  }
  var level = 0;
  while (cursor + level < text.length && text[cursor + level] == '#') {
    level++;
  }
  if (level == 0 || level > 6) return null;
  var contentStart = cursor + level;
  if (contentStart < text.length && text[contentStart] != ' ') return null;
  while (contentStart < text.length && text[contentStart] == ' ') {
    contentStart++;
  }
  var contentEnd = text.length;
  while (contentEnd > contentStart && text[contentEnd - 1] == ' ') {
    contentEnd--;
  }
  // A closing run of hashes is syntax, not content.
  var trailing = contentEnd;
  while (trailing > contentStart && text[trailing - 1] == '#') {
    trailing--;
  }
  if (trailing < contentEnd &&
      (trailing == contentStart || text[trailing - 1] == ' ')) {
    contentEnd = trailing;
    while (contentEnd > contentStart && text[contentEnd - 1] == ' ') {
      contentEnd--;
    }
  }
  return _Heading(level, contentStart, contentEnd);
}

/// Whether [text] is a horizontal rule such as `---` or `***`.
bool _isThematicBreak(String text) {
  final trimmed = text.trim();
  if (trimmed.length < 3) return false;
  for (final marker in const <String>['-', '*', '_']) {
    if (trimmed
        .split('')
        .every((String character) => character == marker || character == ' ')) {
      final count = trimmed
          .split('')
          .where((String character) => character == marker)
          .length;
      if (count >= 3) return true;
    }
  }
  return false;
}

/// Length of the `>` prefix, including one optional following space.
int? _quotePrefixLength(String text) {
  var cursor = 0;
  while (cursor < text.length && text[cursor] == ' ' && cursor < 4) {
    cursor++;
  }
  if (cursor >= text.length || text[cursor] != '>') return null;
  while (cursor < text.length && text[cursor] == '>') {
    cursor++;
  }
  if (cursor < text.length && text[cursor] == ' ') cursor++;
  return cursor;
}

/// How many `>` characters [text] opens with, so nested quotes keep their
/// nesting level.
int _quoteDepth(String text) {
  var depth = 0;
  for (var cursor = 0; cursor < text.length; cursor++) {
    if (text[cursor] == '>') {
      depth++;
    } else if (text[cursor] != ' ') {
      break;
    }
  }
  return depth;
}

/// The marker of a list item line, and where its content begins.
final class _ListItem {
  const _ListItem({
    required this.isOrdered,
    required this.marker,
    required this.indent,
    required this.contentStart,
  });

  final bool isOrdered;
  final String marker;
  final int indent;
  final int contentStart;
}

/// The list item [text] opens, or null when it opens none.
_ListItem? _matchListItem(String text) {
  var cursor = 0;
  while (cursor < text.length && text[cursor] == ' ') {
    cursor++;
  }
  if (cursor >= text.length) return null;
  final indent = cursor;
  final ch = text[cursor];
  if (ch == '-' || ch == '*' || ch == '+') {
    if (cursor + 1 >= text.length || text[cursor + 1] != ' ') return null;
    var contentStart = cursor + 1;
    while (contentStart < text.length && text[contentStart] == ' ') {
      contentStart++;
    }
    return _ListItem(
      isOrdered: false,
      marker: ch,
      indent: indent,
      contentStart: contentStart,
    );
  }
  var digits = 0;
  while (cursor + digits < text.length &&
      _isDigit(text.codeUnitAt(cursor + digits))) {
    digits++;
  }
  if (digits == 0 || digits > 9) return null;
  final delimiterIndex = cursor + digits;
  if (delimiterIndex >= text.length) return null;
  final delimiter = text[delimiterIndex];
  if (delimiter != '.' && delimiter != ')') return null;
  if (delimiterIndex + 1 >= text.length || text[delimiterIndex + 1] != ' ') {
    return null;
  }
  var contentStart = delimiterIndex + 1;
  while (contentStart < text.length && text[contentStart] == ' ') {
    contentStart++;
  }
  return _ListItem(
    isOrdered: true,
    marker: text.substring(indent, delimiterIndex + 1),
    indent: indent,
    contentStart: contentStart,
  );
}

/// Whether [text] is a table's `|---|---|` separator row, which is what marks
/// the line above it as a table header rather than a paragraph.
bool _isTableDelimiter(String text) {
  final trimmed = text.trim();
  if (!trimmed.contains('-')) return false;
  return trimmed
      .split('')
      .every(
        (String character) =>
            character == '|' ||
            character == '-' ||
            character == ':' ||
            character == ' ',
      );
}

/// Whether [text] would begin a new block, which is how a paragraph or a list
/// item knows to stop consuming lines.
bool _startsNewBlock(String text) =>
    _matchFence(text) != null ||
    _matchHeading(text) != null ||
    _isThematicBreak(text) ||
    _quotePrefixLength(text) != null ||
    text.trim() == r'$$';

/// How many spaces [text] begins with.
int _leadingSpaces(String text) {
  var cursor = 0;
  while (cursor < text.length && text[cursor] == ' ') {
    cursor++;
  }
  return cursor;
}

/// Whether [codeUnit] is an ASCII `0`-`9`.
bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
