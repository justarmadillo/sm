/// Turns a rewritten document into the smallest exact replacement splice.
library;

import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/markdown_block_parser.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:incremental_reader/shared/utf8_offsets.dart';

/// Returns the unique span left after trimming an identical prefix and suffix.
///
/// The rewritten text is normalized first because [Document.parse] stores that
/// form. UTF-16 scan bounds are backed away from surrogate-pair interiors and
/// converted only through [Utf8OffsetIndex]. Identical text returns a no-op,
/// never null: null is reserved by the command runner for a missing block. The
/// invariant this preserves is that byte-identical text outside the minimal
/// span is not reported as touched, so positions and extract provenance there
/// remain trustworthy.
TextSplice spliceForDocumentRewrite(Document document, String rewritten) {
  final String normalized = normalizeMarkdown(rewritten);
  final String current = document.markdown;
  if (current == normalized) return TextSplice.delete(0, 0);

  final int shorterLength = current.length < normalized.length
      ? current.length
      : normalized.length;
  var prefixEnd = 0;
  while (prefixEnd < shorterLength &&
      current.codeUnitAt(prefixEnd) == normalized.codeUnitAt(prefixEnd)) {
    prefixEnd++;
  }
  if (_isInsideSurrogatePair(current, prefixEnd)) prefixEnd--;

  var currentSuffixStart = current.length;
  var rewrittenSuffixStart = normalized.length;
  while (currentSuffixStart > prefixEnd &&
      rewrittenSuffixStart > prefixEnd &&
      current.codeUnitAt(currentSuffixStart - 1) ==
          normalized.codeUnitAt(rewrittenSuffixStart - 1)) {
    currentSuffixStart--;
    rewrittenSuffixStart--;
  }
  if (_isInsideSurrogatePair(current, currentSuffixStart) &&
      currentSuffixStart > prefixEnd &&
      rewrittenSuffixStart > prefixEnd) {
    currentSuffixStart--;
    rewrittenSuffixStart--;
  }

  final Utf8OffsetIndex currentOffsets = Utf8OffsetIndex(current);
  return TextSplice(
    startUtf8: currentOffsets.toUtf8(prefixEnd),
    endUtf8: currentOffsets.toUtf8(currentSuffixStart),
    inserted: normalized.substring(prefixEnd, rewrittenSuffixStart),
  );
}

bool _isInsideSurrogatePair(String text, int boundary) =>
    boundary > 0 &&
    boundary < text.length &&
    _isHighSurrogate(text.codeUnitAt(boundary - 1)) &&
    _isLowSurrogate(text.codeUnitAt(boundary));

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;
