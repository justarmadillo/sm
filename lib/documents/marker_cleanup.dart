/// Removes the HTML the Marker PDF converter leaves in its markdown.
///
/// The Reader shows HTML as the literal text it is, so a Marker heading would
/// read `<span id="page-2-0"></span>3.1 Methods` on the page and in the
/// outline. Each rule below removes one tag Marker is known to write, and only
/// outside code and math, where a tag is content rather than noise.
///
/// Applied to opened files only, never to typed or pasted text: a tag the
/// user wrote by hand is theirs to keep.
library;

import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';

/// [markdown] with Marker's page anchors, anchor links, superscript,
/// subscript, bold, and table line-break tags replaced by what they mean.
String cleanMarkerMarkdown(String markdown) {
  final String normalized = normalizeMarkdown(markdown);
  final StringBuffer cleaned = StringBuffer();
  var copiedUpTo = 0;
  for (final Block block in parseMarkdownBlocks(
    normalized,
    sourceId: 'marker-cleanup',
  )) {
    if (block.type == BlockType.codeBlock ||
        block.type == BlockType.mathBlock) {
      continue;
    }
    cleaned
      ..write(normalized.substring(copiedUpTo, block.sourceStartUtf16))
      ..write(_cleanBlock(block));
    copiedUpTo = block.sourceStartUtf16 + block.raw.length;
  }
  cleaned.write(normalized.substring(copiedUpTo));
  return cleaned.toString();
}

String _cleanBlock(Block block) {
  var text = _withoutPageAnchors(block.raw);
  text = _withoutAnchorLinks(text);
  text = _withScriptCharacters(text);
  text = _withMarkdownBold(text);
  if (block.type == BlockType.table) text = _withoutCellLineBreaks(text);
  return text;
}

/// Marker marks every position a link might jump to with an empty span.
String _withoutPageAnchors(String text) =>
    text.replaceAll(RegExp(r'<span id="[^"]*"></span>'), '');

/// A link to one of those positions has nowhere to go in the Reader, so only
/// its text is kept. An image is left alone even when its link starts with #.
String _withoutAnchorLinks(String text) => text.replaceAllMapped(
  RegExp(r'(?<!!)\[((?:\\.|[^\]\\])*)\]\(#[^)]*\)'),
  (Match match) => match.group(1)!,
);

const Map<String, String> _superscripts = <String, String>{
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', //
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', //
  '+': '⁺', '-': '⁻', '−': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
};

const Map<String, String> _subscripts = <String, String>{
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', //
  '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉', //
  '+': '₊', '-': '₋', '−': '₋', '=': '₌', '(': '₍', ')': '₎',
};

/// Footnote markers and formulas read as `note¹` and `CO₂`, not as tags.
String _withScriptCharacters(String text) => text.replaceAllMapped(
  RegExp(r'<(sup|sub)>(.*?)</\1>'),
  (Match match) => _spelledIn(
    match.group(2)!,
    match.group(1) == 'sup' ? _superscripts : _subscripts,
  ),
);

/// [inner] spelled in [characters], or [inner] unchanged when any of its
/// characters has no such form: half a word in superscript reads worse than
/// none of it.
String _spelledIn(String inner, Map<String, String> characters) {
  final StringBuffer spelled = StringBuffer();
  for (final String character in inner.split('')) {
    final String? scriptCharacter = characters[character];
    if (scriptCharacter == null) return inner;
    spelled.write(scriptCharacter);
  }
  return spelled.toString();
}

/// Marker bolds table cells with `<b>`. Markdown bold only opens against a
/// word, so spaces just inside the tag move outside the stars.
String _withMarkdownBold(String text) =>
    text.replaceAllMapped(RegExp(r'<b>(\s*)(.*?)(\s*)</b>'), (Match match) {
      final String leadingSpace = match.group(1)!;
      final String inner = match.group(2)!;
      final String trailingSpace = match.group(3)!;
      if (inner.isEmpty) return '$leadingSpace$trailingSpace';
      return '$leadingSpace**$inner**$trailingSpace';
    });

/// A line break inside a table cell has no markdown form; a space keeps the
/// words on either side of it apart.
String _withoutCellLineBreaks(String text) =>
    text.replaceAll(RegExp(r'<br\s*/?>'), ' ');
