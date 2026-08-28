/// Immutable derived blocks of a source document.
///
/// A source is an immutable snapshot of markdown. Blocks are derived from it
/// once, at import, and never change afterwards: block identity and source
/// offsets are the coordinate system every anchor, extract, and provenance
/// record is expressed in.
library;

import 'package:incremental_reader/src/core/utf8_offsets.dart';
import 'package:incremental_reader/src/domain/content/block_content.dart';
import 'package:incremental_reader/src/domain/content/inline_markup.dart';
import 'package:incremental_reader/src/domain/content/markdown_inline_parser.dart';

/// Structural kind of a block.
enum BlockType {
  paragraph,
  heading,
  codeBlock,
  mathBlock,
  quote,
  listItem,
  table,
  thematicBreak,
}

/// One immutable block of a source document.
///
/// Not `const`-constructible: [inline] and the UTF-8 index are memoized on
/// first use so a 50k-word document pays for inline parsing only on the blocks
/// the reader actually mounts. Every field is either final or a memoized
/// derivation of final state, so instances are observationally immutable.
final class Block {
  Block({
    required this.id,
    required this.index,
    required this.type,
    required this.raw,
    required this.sourceStartUtf8,
    required this.sourceEndUtf8,
    required this.sourceStartUtf16,
    required List<Utf16Span> contentSpans,
    this.headingLevel,
    this.codeLanguage,
    this.ordered = false,
    this.listMarker,
    this.listDepth = 0,
    this.quoteDepth = 0,
  }) : _contentSpans = List<Utf16Span>.unmodifiable(contentSpans);

  /// Stable identifier, unique within the source and never reused.
  final String id;

  /// Zero-based position of this block in the document.
  final int index;

  final BlockType type;

  /// Exact source substring this block was derived from.
  final String raw;

  /// UTF-8 offset of [raw] within the whole source markdown.
  final int sourceStartUtf8;

  /// UTF-8 offset one past the end of [raw] within the source markdown.
  final int sourceEndUtf8;

  /// UTF-16 index of [raw] within the source markdown.
  ///
  /// Kept alongside the UTF-8 offsets so slicing the document string never
  /// has to search for the block.
  final int sourceStartUtf16;

  /// Heading level 1..6, for [BlockType.heading].
  final int? headingLevel;

  /// Info string of a fenced code block, when present.
  final String? codeLanguage;

  /// Whether a [BlockType.listItem] belongs to an ordered list.
  final bool ordered;

  /// Literal list marker, for example `-` or `3.`.
  final String? listMarker;

  /// Nesting depth of a list item, zero for top level.
  final int listDepth;

  /// Nesting depth of a blockquote, zero when not quoted.
  final int quoteDepth;

  final List<Utf16Span> _contentSpans;

  BlockContent? _content;
  InlineLayout? _inline;
  Utf8OffsetIndex? _utf8Index;

  /// Ranges of [raw] that hold renderable content, excluding line syntax.
  List<Utf16Span> get contentSpans => _contentSpans;

  /// Content characters with their raw-text provenance.
  BlockContent get content =>
      _content ??= BlockContent.fromSpans(raw, _contentSpans);

  /// Rendered runs and their mapping back to content coordinates.
  ///
  /// Code and math blocks are verbatim: their content is not inline-parsed.
  InlineLayout get inline => _inline ??= _buildInline();

  /// UTF-8 index over [raw], built on first use.
  Utf8OffsetIndex get utf8Index => _utf8Index ??= Utf8OffsetIndex(raw);

  /// Text the reader displays for this block.
  String get renderedText => inline.plainText;

  /// UTF-8 length of [raw].
  int get lengthUtf8 => sourceEndUtf8 - sourceStartUtf8;

  /// UTF-16 index one past the end of [raw] within the source markdown.
  int get sourceEndUtf16 => sourceStartUtf16 + raw.length;

  InlineLayout _buildInline() {
    final text = content.text;
    if (type == BlockType.codeBlock || type == BlockType.mathBlock) {
      if (text.isEmpty) return InlineLayout.empty;
      final style = type == BlockType.codeBlock
          ? InlineStyle.code
          : InlineStyle.math;
      return InlineLayout(
        plainText: text,
        segments: <InlineSegment>[
          InlineSegment(
            text: text,
            renderedStart: 0,
            contentStart: 0,
            contentEnd: text.length,
            styles: <InlineStyle>{style},
            math: type == BlockType.mathBlock ? text : null,
          ),
        ],
      );
    }
    return parseInlineMarkup(text);
  }

  /// Block-relative UTF-8 offset that rendered index [renderedIndex] came from.
  ///
  /// [edge] decides which run owns a position between two runs. Use
  /// [RenderedEdge.trailing] for the exclusive end of a range.
  int renderedToUtf8(
    int renderedIndex, {
    RenderedEdge edge = RenderedEdge.leading,
  }) {
    final contentIndex = inline.contentIndexForRendered(
      renderedIndex,
      edge: edge,
    );
    final rawIndex = content.rawIndexAt(contentIndex);
    return utf8Index.toUtf8(rawIndex);
  }

  /// Block-relative UTF-8 range that rendered `[start, end)` came from.
  (int, int) sourceRangeForRendered(int startRendered, int endRendered) => (
    renderedToUtf8(startRendered),
    renderedToUtf8(endRendered, edge: RenderedEdge.trailing),
  );

  /// Exact markdown behind the rendered range `[start, end)`.
  String rawSliceForRendered(int startRendered, int endRendered) {
    final (int start, int end) = sourceRangeForRendered(
      startRendered,
      endRendered,
    );
    return rawSlice(start, end);
  }

  /// Valid, self-contained Markdown for rendered `[start, end)`.
  ///
  /// Provenance continues to point at the exact raw source slice. Extract text
  /// is a separate concern: delimiters that sit just outside the visible
  /// selection are reconstructed so the fragment renders on its own instead
  /// of producing broken text such as `bold**, *italic`.
  String markdownFragmentForRendered(int startRendered, int endRendered) {
    final start = startRendered.clamp(0, renderedText.length);
    final end = endRendered.clamp(0, renderedText.length);
    if (end <= start) return '';

    final selected = renderedText.substring(start, end);
    if (type == BlockType.codeBlock) {
      final language = codeLanguage ?? '';
      return '```$language\n$selected\n```';
    }
    if (type == BlockType.mathBlock) return '\$\$\n$selected\n\$\$';

    final buffer = StringBuffer();
    for (final segment in inline.segments) {
      final from = start > segment.renderedStart
          ? start
          : segment.renderedStart;
      final to = end < segment.renderedEnd ? end : segment.renderedEnd;
      if (to <= from) continue;
      final piece = segment.text.substring(
        from - segment.renderedStart,
        to - segment.renderedStart,
      );
      buffer.write(_standaloneSegmentMarkdown(piece, segment));
    }
    return buffer.toString();
  }

  /// Rendered index corresponding to block-relative UTF-8 offset [utf8Offset].
  int utf8ToRendered(int utf8Offset) {
    final rawIndex = utf8Index.toUtf16(utf8Offset);
    final contentIndex = content.contentIndexForRaw(rawIndex);
    return inline.renderedIndexForContent(contentIndex);
  }

  /// Exact markdown between two block-relative UTF-8 offsets.
  String rawSlice(int startUtf8, int endUtf8) {
    final start = utf8Index.toUtf16(startUtf8);
    final end = utf8Index.toUtf16(endUtf8);
    if (end <= start) return '';
    return raw.substring(start, end);
  }

  @override
  bool operator ==(Object other) => other is Block && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Block($id ${type.name} $sourceStartUtf8..$sourceEndUtf8)';
}

String _standaloneSegmentMarkdown(String text, InlineSegment segment) {
  final styles = segment.styles;
  if (styles.contains(InlineStyle.image)) {
    final alt = text == kObjectReplacement ? '' : _escapeMarkdown(text);
    final url = _angleDestination(segment.imageUrl ?? '');
    return '![$alt]($url)';
  }

  var result = _escapeMarkdown(text);
  if (styles.contains(InlineStyle.code)) result = _codeSpan(text);
  if (styles.contains(InlineStyle.math)) result = '\$$text\$';
  if (styles.contains(InlineStyle.strikethrough)) result = '~~$result~~';
  if (styles.contains(InlineStyle.emphasis)) result = '*$result*';
  if (styles.contains(InlineStyle.strong)) result = '**$result**';
  if (styles.contains(InlineStyle.link)) {
    result = '[$result](${_angleDestination(segment.linkHref ?? '')})';
  }
  return result;
}

String _escapeMarkdown(String text) => text.replaceAllMapped(
  RegExp(r'([\\`*_{}\[\]()<>#+.!|])'),
  (Match match) => '\\${match.group(1)}',
);

String _angleDestination(String destination) =>
    '<${destination.replaceAll('>', '%3E')}>';

String _codeSpan(String text) {
  var longest = 0;
  for (final match in RegExp(r'`+').allMatches(text)) {
    if (match.group(0)!.length > longest) longest = match.group(0)!.length;
  }
  final fence = '`' * (longest + 1);
  return '$fence$text$fence';
}
