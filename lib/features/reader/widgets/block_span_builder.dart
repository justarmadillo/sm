/// Turns a block's inline layout into Flutter spans.
///
/// The one invariant that matters: the flattened plain text of the produced
/// [TextSpan] must equal the block's rendered text, character for character.
/// The Reader reads character offsets straight out of the laid-out paragraph
/// and hands them to the domain, so any span that adds or drops a character —
/// an ellipsis, a bullet, a trailing newline — would silently corrupt every
/// anchor taken from that block.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/inline_markup.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// A highlighted character range within one block's rendered text.
@immutable
final class BlockHighlight {
  const BlockHighlight({
    required this.start,
    required this.end,
    required this.color,
    this.underlineColor,
  });

  final int start;
  final int end;
  final Color color;

  /// Optional rule drawn under the range.
  ///
  /// A wash alone is ambiguous on a page that also washes the live selection;
  /// the rule is what makes an extracted passage recognisable at a glance
  /// without shouting louder than the text.
  final Color? underlineColor;

  bool get isEmpty => end <= start;

  @override
  bool operator ==(Object other) =>
      other is BlockHighlight &&
      other.start == start &&
      other.end == end &&
      other.color == color &&
      other.underlineColor == underlineColor;

  @override
  int get hashCode => Object.hash(start, end, color, underlineColor);
}

/// Builds the span tree for [block] under [typography].
///
/// [highlights] are applied on top of inline styling by splitting runs at
/// their boundaries, which keeps the flattened text unchanged.
TextSpan buildBlockSpan(
  Block block,
  ReaderTypography typography, {
  List<BlockHighlight> highlights = const <BlockHighlight>[],
}) {
  final base = _baseStyleFor(block, typography);
  final children = <InlineSpan>[];

  for (final segment in block.inline.segments) {
    final style = _styleForSegment(segment, base, typography);
    for (final piece in _splitByHighlights(segment, highlights)) {
      children.add(
        TextSpan(text: piece.text, style: _applyHighlight(style, piece.mark)),
      );
    }
  }

  return TextSpan(style: base, children: children);
}

/// Height of [block]'s first rendered line under [typography].
///
/// The gutter uses it to sit its mark beside the *text*: a block's box starts
/// half a line above the glyphs, so a mark aligned to the box reads as
/// floating above the line it is supposed to point at.
double blockFirstLineHeight(Block block, ReaderTypography typography) {
  final style = _baseStyleFor(block, typography);
  return (style.fontSize ?? typography.fontSize) * (style.height ?? 1.0);
}

/// Base style for a whole block.
TextStyle _baseStyleFor(Block block, ReaderTypography typography) =>
    switch (block.type) {
      BlockType.heading => typography.heading(block.headingLevel ?? 1),
      BlockType.codeBlock => typography.code,
      BlockType.mathBlock => typography.code.copyWith(
        fontStyle: FontStyle.italic,
      ),
      BlockType.quote => typography.body.copyWith(color: AppColors.muted),
      _ => typography.body,
    };

TextStyle _styleForSegment(
  InlineSegment segment,
  TextStyle base,
  ReaderTypography typography,
) {
  var style = base;
  if (segment.styles.contains(InlineStyle.strong)) {
    style = style.copyWith(fontWeight: FontWeight.w700);
  }
  if (segment.styles.contains(InlineStyle.emphasis)) {
    style = style.copyWith(fontStyle: FontStyle.italic);
  }
  if (segment.styles.contains(InlineStyle.strikethrough)) {
    style = style.copyWith(decoration: TextDecoration.lineThrough);
  }
  if (segment.styles.contains(InlineStyle.code)) {
    style = style.copyWith(
      fontFamily: typography.code.fontFamily,
      fontSize: typography.code.fontSize,
      backgroundColor: AppColors.codeBackground,
    );
  }
  if (segment.styles.contains(InlineStyle.math)) {
    style = style.copyWith(
      fontFamily: typography.code.fontFamily,
      fontStyle: FontStyle.italic,
    );
  }
  if (segment.styles.contains(InlineStyle.link)) {
    style = style.copyWith(
      color: AppColors.accent,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.accent.withValues(alpha: 0.4),
    );
  }
  if (segment.styles.contains(InlineStyle.image)) {
    style = style.copyWith(color: AppColors.muted);
  }
  return style;
}

/// One piece of a segment, optionally carrying the highlight covering it.
final class _TextRun {
  const _TextRun(this.text, this.mark);

  final String text;
  final BlockHighlight? mark;
}

/// Paints [mark] over an inline style without touching its metrics.
TextStyle _applyHighlight(TextStyle style, BlockHighlight? mark) {
  if (mark == null) return style;
  final underline = mark.underlineColor;
  if (underline == null) {
    return style.copyWith(backgroundColor: mark.color);
  }
  return style.copyWith(
    backgroundColor: mark.color,
    decoration: TextDecoration.underline,
    decorationColor: underline,
    decorationThickness: 1.4,
  );
}

/// Splits [segment] at every highlight boundary that falls inside it.
List<_TextRun> _splitByHighlights(
  InlineSegment segment,
  List<BlockHighlight> highlights,
) {
  if (highlights.isEmpty) {
    return <_TextRun>[_TextRun(segment.text, null)];
  }

  final cuts = <int>{segment.renderedStart, segment.renderedEnd};
  for (final highlight in highlights) {
    if (highlight.isEmpty) continue;
    if (highlight.start > segment.renderedStart &&
        highlight.start < segment.renderedEnd) {
      cuts.add(highlight.start);
    }
    if (highlight.end > segment.renderedStart &&
        highlight.end < segment.renderedEnd) {
      cuts.add(highlight.end);
    }
  }
  final boundaries = cuts.toList()..sort();

  final pieces = <_TextRun>[];
  for (var i = 0; i < boundaries.length - 1; i++) {
    final start = boundaries[i];
    final end = boundaries[i + 1];
    if (end <= start) continue;
    pieces.add(
      _TextRun(
        segment.text.substring(
          start - segment.renderedStart,
          end - segment.renderedStart,
        ),
        _highlightAt(start, highlights),
      ),
    );
  }
  return pieces;
}

/// The first highlight covering [index]. Callers order the list by priority,
/// so a live selection painted over an extract still wins.
BlockHighlight? _highlightAt(int index, List<BlockHighlight> highlights) {
  for (final highlight in highlights) {
    if (!highlight.isEmpty &&
        index >= highlight.start &&
        index < highlight.end) {
      return highlight;
    }
  }
  return null;
}
