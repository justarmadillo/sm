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
  var i = 0;

  void add(
    BlockType type,
    int startUtf16,
    int endUtf16,
    List<Utf16Span> absoluteContentSpans, {
    int? headingLevel,
    String? codeLanguage,
    bool ordered = false,
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
        ordered: ordered,
        listMarker: listMarker,
        listDepth: listDepth,
        quoteDepth: quoteDepth,
      ),
    );
  }

  while (i < lines.length) {
    final line = lines[i];
    final text = line.text(markdown);

    if (text.trim().isEmpty) {
      i++;
      continue;
    }

    final fence = _matchFence(text);
    if (fence != null) {
      var j = i + 1;
      while (j < lines.length &&
          !_closesFence(lines[j].text(markdown), fence)) {
        j++;
      }
      final contentStart = i + 1 <= lines.length - 1
          ? lines[i + 1].start
          : line.end;
      final contentEnd = j > i + 1 ? lines[j - 1].end : contentStart;
      final blockEnd = j < lines.length ? lines[j].end : lines[j - 1].end;
      add(
        BlockType.codeBlock,
        line.start,
        blockEnd,
        j > i + 1
            ? <Utf16Span>[Utf16Span(contentStart, contentEnd)]
            : const <Utf16Span>[],
        codeLanguage: fence.language.isEmpty ? null : fence.language,
      );
      i = j + 1;
      continue;
    }

    if (text.trim() == r'$$') {
      var j = i + 1;
      while (j < lines.length && lines[j].text(markdown).trim() != r'$$') {
        j++;
      }
      final contentStart = i + 1 < lines.length ? lines[i + 1].start : line.end;
      final contentEnd = j > i + 1 ? lines[j - 1].end : contentStart;
      final blockEnd = j < lines.length ? lines[j].end : lines[j - 1].end;
      add(
        BlockType.mathBlock,
        line.start,
        blockEnd,
        j > i + 1
            ? <Utf16Span>[Utf16Span(contentStart, contentEnd)]
            : const <Utf16Span>[],
      );
      i = j + 1;
      continue;
    }

    final heading = _matchHeading(text);
    if (heading != null) {
      add(BlockType.heading, line.start, line.end, <Utf16Span>[
        Utf16Span(
          line.start + heading.contentStart,
          line.start + heading.contentEnd,
        ),
      ], headingLevel: heading.level);
      i++;
      continue;
    }

    if (_isThematicBreak(text)) {
      add(BlockType.thematicBreak, line.start, line.end, const <Utf16Span>[]);
      i++;
      continue;
    }

    if (_quotePrefixLength(text) != null) {
      var j = i;
      final spans = <Utf16Span>[];
      var depth = 0;
      while (j < lines.length) {
        final lineText = lines[j].text(markdown);
        final prefix = _quotePrefixLength(lineText);
        if (prefix == null) break;
        depth = depth == 0 ? _quoteDepth(lineText) : depth;
        final isLast =
            j + 1 >= lines.length ||
            _quotePrefixLength(lines[j + 1].text(markdown)) == null;
        spans.add(
          Utf16Span(
            lines[j].start + prefix,
            isLast ? lines[j].end : lines[j].endWithBreak,
          ),
        );
        j++;
      }
      add(
        BlockType.quote,
        line.start,
        lines[j - 1].end,
        spans,
        quoteDepth: depth,
      );
      i = j;
      continue;
    }

    final listItem = _matchListItem(text);
    if (listItem != null) {
      var j = i;
      final spans = <Utf16Span>[
        Utf16Span(line.start + listItem.contentStart, line.endWithBreak),
      ];
      j++;
      while (j < lines.length) {
        final lineText = lines[j].text(markdown);
        if (lineText.trim().isEmpty) break;
        if (_matchListItem(lineText) != null) break;
        if (_startsNewBlock(lineText)) break;
        final indent = _leadingSpaces(lineText);
        final keep = indent >= listItem.contentStart ? listItem.contentStart : indent;
        spans.add(Utf16Span(lines[j].start + keep, lines[j].endWithBreak));
        j++;
      }
      // Trim the trailing line break of the final content span.
      final last = spans.removeLast();
      spans.add(Utf16Span(last.start, lines[j - 1].end));
      add(
        BlockType.listItem,
        line.start,
        lines[j - 1].end,
        spans,
        ordered: listItem.ordered,
        listMarker: listItem.marker,
        listDepth: listItem.indent ~/ 2,
      );
      i = j;
      continue;
    }

    if (text.contains('|') &&
        i + 1 < lines.length &&
        _isTableDelimiter(lines[i + 1].text(markdown))) {
      var j = i;
      while (j < lines.length &&
          lines[j].text(markdown).trim().isNotEmpty &&
          lines[j].text(markdown).contains('|')) {
        j++;
      }
      add(BlockType.table, line.start, lines[j - 1].end, <Utf16Span>[
        Utf16Span(line.start, lines[j - 1].end),
      ]);
      i = j;
      continue;
    }

    // Paragraph: runs until a blank line or the start of another block.
    var j = i + 1;
    while (j < lines.length) {
      final lineText = lines[j].text(markdown);
      if (lineText.trim().isEmpty) break;
      if (_startsNewBlock(lineText)) break;
      if (_matchListItem(lineText) != null) break;
      j++;
    }
    add(BlockType.paragraph, line.start, lines[j - 1].end, <Utf16Span>[
      Utf16Span(line.start, lines[j - 1].end),
    ]);
    i = j;
  }

  return List<Block>.unmodifiable(blocks);
}

/// Deterministic block identifier for block [index] of [sourceId].
String blockId(String sourceId, int index) => '$sourceId:$index';

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

List<_SourceLine> _splitLines(String source) {
  final lines = <_SourceLine>[];
  var start = 0;
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) {
      lines.add(_SourceLine(start, i, i + 1));
      start = i + 1;
    }
  }
  if (start <= source.length - 1 || source.isEmpty) {
    lines.add(_SourceLine(start, source.length, source.length));
  }
  return lines;
}

final class _Fence {
  const _Fence(this.marker, this.length, this.language);

  final String marker;
  final int length;
  final String language;
}

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

bool _closesFence(String text, _Fence fence) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  var length = 0;
  while (length < trimmed.length && trimmed[length] == fence.marker) {
    length++;
  }
  return length >= fence.length && trimmed.substring(length).trim().isEmpty;
}

final class _Heading {
  const _Heading(this.level, this.contentStart, this.contentEnd);

  final int level;
  final int contentStart;
  final int contentEnd;
}

_Heading? _matchHeading(String text) {
  var i = 0;
  while (i < text.length && text[i] == ' ' && i < 4) {
    i++;
  }
  var level = 0;
  while (i + level < text.length && text[i + level] == '#') {
    level++;
  }
  if (level == 0 || level > 6) return null;
  var contentStart = i + level;
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

bool _isThematicBreak(String text) {
  final trimmed = text.trim();
  if (trimmed.length < 3) return false;
  for (final marker in const <String>['-', '*', '_']) {
    if (trimmed.split('').every((String c) => c == marker || c == ' ')) {
      final count = trimmed.split('').where((String c) => c == marker).length;
      if (count >= 3) return true;
    }
  }
  return false;
}

/// Length of the `>` prefix, including one optional following space.
int? _quotePrefixLength(String text) {
  var i = 0;
  while (i < text.length && text[i] == ' ' && i < 4) {
    i++;
  }
  if (i >= text.length || text[i] != '>') return null;
  while (i < text.length && text[i] == '>') {
    i++;
  }
  if (i < text.length && text[i] == ' ') i++;
  return i;
}

int _quoteDepth(String text) {
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == '>') {
      depth++;
    } else if (text[i] != ' ') {
      break;
    }
  }
  return depth;
}

final class _ListItem {
  const _ListItem({
    required this.ordered,
    required this.marker,
    required this.indent,
    required this.contentStart,
  });

  final bool ordered;
  final String marker;
  final int indent;
  final int contentStart;
}

_ListItem? _matchListItem(String text) {
  var i = 0;
  while (i < text.length && text[i] == ' ') {
    i++;
  }
  if (i >= text.length) return null;
  final indent = i;
  final ch = text[i];
  if (ch == '-' || ch == '*' || ch == '+') {
    if (i + 1 >= text.length || text[i + 1] != ' ') return null;
    var contentStart = i + 1;
    while (contentStart < text.length && text[contentStart] == ' ') {
      contentStart++;
    }
    return _ListItem(
      ordered: false,
      marker: ch,
      indent: indent,
      contentStart: contentStart,
    );
  }
  var digits = 0;
  while (i + digits < text.length && _isDigit(text.codeUnitAt(i + digits))) {
    digits++;
  }
  if (digits == 0 || digits > 9) return null;
  final delimiterIndex = i + digits;
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
    ordered: true,
    marker: text.substring(indent, delimiterIndex + 1),
    indent: indent,
    contentStart: contentStart,
  );
}

bool _isTableDelimiter(String text) {
  final trimmed = text.trim();
  if (!trimmed.contains('-')) return false;
  return trimmed
      .split('')
      .every((String c) => c == '|' || c == '-' || c == ':' || c == ' ');
}

bool _startsNewBlock(String text) =>
    _matchFence(text) != null ||
    _matchHeading(text) != null ||
    _isThematicBreak(text) ||
    _quotePrefixLength(text) != null ||
    text.trim() == r'$$';

int _leadingSpaces(String text) {
  var i = 0;
  while (i < text.length && text[i] == ' ') {
    i++;
  }
  return i;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;
