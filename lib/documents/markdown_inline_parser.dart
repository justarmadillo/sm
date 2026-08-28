/// Inline markdown parser that preserves exact source coordinates.
///
/// This deliberately does not use a general markdown library: those produce an
/// AST without reliable character offsets, and the Reader's whole extraction
/// contract depends on knowing precisely which source characters produced each
/// rendered character. The supported subset is the one the plan calls for:
/// emphasis, strong, inline code, strikethrough, links, images, inline math,
/// and backslash escapes.
library;

import 'package:incremental_reader/documents/inline_markup.dart';

/// Parses the inline markup of one block's content text.
InlineLayout parseInlineMarkup(String content) {
  if (content.isEmpty) return InlineLayout.empty;
  final parser = _InlineParser(content);
  parser.parseRange(0, content.length, const <InlineStyle>{}, null);
  return parser.build();
}

const int _kBackslash = 0x5C; // \
const int _kBacktick = 0x60; // `
const int _kAsterisk = 0x2A; // *
const int _kUnderscore = 0x5F; // _
const int _kTilde = 0x7E; // ~
const int _kDollar = 0x24; // $
const int _kBang = 0x21; // !
const int _kOpenBracket = 0x5B; // [
const int _kCloseBracket = 0x5D; // ]
const int _kOpenParen = 0x28; // (
const int _kCloseParen = 0x29; // )
const int _kNewline = 0x0A;

/// Placeholder character standing in for an inline image in rendered text.
const String kObjectReplacement = '￼';

const String _kEscapable =
    r'\`*_{}[]()#+-.!|~$<>"'
    "'";

final class _InlineParser {
  _InlineParser(this.s);

  final String s;
  final List<InlineSegment> _segments = <InlineSegment>[];
  final StringBuffer _rendered = StringBuffer();
  int _renderedLength = 0;

  InlineLayout build() => InlineLayout(
    plainText: _rendered.toString(),
    segments: List<InlineSegment>.unmodifiable(_segments),
  );

  void _emit(
    String text,
    int contentStart,
    int contentEnd,
    Set<InlineStyle> styles, {
    String? href,
    String? imageUrl,
    String? math,
  }) {
    if (text.isEmpty) return;
    _segments.add(
      InlineSegment(
        text: text,
        renderedStart: _renderedLength,
        contentStart: contentStart,
        contentEnd: contentEnd,
        styles: styles,
        linkHref: href,
        imageUrl: imageUrl,
        math: math,
      ),
    );
    _rendered.write(text);
    _renderedLength += text.length;
  }

  /// Parses `[start, end)` under the inherited [styles] and link [href].
  void parseRange(int start, int end, Set<InlineStyle> styles, String? href) {
    var i = start;
    var plainStart = start;

    void flushPlain(int upTo) {
      if (upTo <= plainStart) return;
      // A soft line break inside a paragraph renders as a space. Length is
      // unchanged, so the run stays a one-to-one mapping onto its source.
      final raw = s.substring(plainStart, upTo);
      final text = raw.contains('\n') ? raw.replaceAll('\n', ' ') : raw;
      _emit(text, plainStart, upTo, styles, href: href);
    }

    while (i < end) {
      final unit = s.codeUnitAt(i);

      if (unit == _kBackslash && i + 1 < end && _isEscapable(s[i + 1])) {
        flushPlain(i);
        _emit(s[i + 1], i, i + 2, styles, href: href);
        i += 2;
        plainStart = i;
        continue;
      }

      if (unit == _kBacktick) {
        final span = _scanCodeSpan(i, end);
        if (span != null) {
          flushPlain(i);
          _emit(
            s.substring(span.innerStart, span.innerEnd),
            span.innerStart,
            span.innerEnd,
            <InlineStyle>{...styles, InlineStyle.code},
            href: href,
          );
          i = span.end;
          plainStart = i;
          continue;
        }
      }

      if (unit == _kDollar) {
        final span = _scanMath(i, end);
        if (span != null) {
          flushPlain(i);
          final tex = s.substring(span.innerStart, span.innerEnd);
          _emit(
            tex,
            span.innerStart,
            span.innerEnd,
            <InlineStyle>{...styles, InlineStyle.math},
            href: href,
            math: tex,
          );
          i = span.end;
          plainStart = i;
          continue;
        }
      }

      if (unit == _kBang &&
          i + 1 < end &&
          s.codeUnitAt(i + 1) == _kOpenBracket) {
        final link = _scanLink(i + 1, end);
        if (link != null) {
          flushPlain(i);
          final alt = s.substring(link.textStart, link.textEnd);
          _emit(
            alt.isEmpty ? kObjectReplacement : alt,
            i,
            link.end,
            <InlineStyle>{...styles, InlineStyle.image},
            href: href,
            imageUrl: link.destination,
          );
          i = link.end;
          plainStart = i;
          continue;
        }
      }

      if (unit == _kOpenBracket) {
        final link = _scanLink(i, end);
        if (link != null) {
          flushPlain(i);
          parseRange(link.textStart, link.textEnd, <InlineStyle>{
            ...styles,
            InlineStyle.link,
          }, link.destination);
          i = link.end;
          plainStart = i;
          continue;
        }
      }

      if (unit == _kTilde && i + 1 < end && s.codeUnitAt(i + 1) == _kTilde) {
        final close = _findCloser(i + 2, end, '~~');
        if (close != null) {
          flushPlain(i);
          parseRange(i + 2, close, <InlineStyle>{
            ...styles,
            InlineStyle.strikethrough,
          }, href);
          i = close + 2;
          plainStart = i;
          continue;
        }
      }

      if (unit == _kAsterisk || unit == _kUnderscore) {
        final marker = s[i];
        final isDouble = i + 1 < end && s.codeUnitAt(i + 1) == unit;
        final delimiter = isDouble ? marker * 2 : marker;
        if (_canOpen(i, delimiter, end)) {
          final close = _findEmphasisCloser(
            i + delimiter.length,
            end,
            delimiter,
          );
          if (close != null) {
            flushPlain(i);
            parseRange(i + delimiter.length, close, <InlineStyle>{
              ...styles,
              isDouble ? InlineStyle.strong : InlineStyle.emphasis,
            }, href);
            i = close + delimiter.length;
            plainStart = i;
            continue;
          }
        }
      }

      i++;
    }
    flushPlain(end);
  }

  bool _isEscapable(String ch) => _kEscapable.contains(ch);

  /// True when a delimiter at [i] is left-flanking: it is followed by a
  /// non-whitespace character, and for `_` also not intraword.
  bool _canOpen(int i, String delimiter, int end) {
    final after = i + delimiter.length;
    if (after >= end) return false;
    if (_isWhitespace(s.codeUnitAt(after))) return false;
    if (delimiter.codeUnitAt(0) == _kUnderscore && i > 0) {
      // `snake_case` must not become emphasis.
      if (_isWordCharacter(s.codeUnitAt(i - 1))) return false;
    }
    return true;
  }

  /// Index of the closing emphasis [delimiter] in `[from, end)`, or null.
  int? _findEmphasisCloser(int from, int end, String delimiter) {
    final close = _findCloser(from, end, delimiter);
    if (close == null) return null;
    if (close == from) return null; // empty emphasis is literal text
    if (_isWhitespace(s.codeUnitAt(close - 1))) return null;
    if (delimiter.codeUnitAt(0) == _kUnderscore &&
        close + delimiter.length < end) {
      if (_isWordCharacter(s.codeUnitAt(close + delimiter.length))) return null;
    }
    return close;
  }

  /// Index of [delimiter] in `[from, end)`, skipping escapes and code spans.
  int? _findCloser(int from, int end, String delimiter) {
    final first = delimiter.codeUnitAt(0);
    var i = from;
    while (i < end) {
      final unit = s.codeUnitAt(i);
      if (unit == _kBackslash && i + 1 < end) {
        i += 2;
        continue;
      }
      if (unit == _kBacktick) {
        final span = _scanCodeSpan(i, end);
        if (span != null) {
          i = span.end;
          continue;
        }
      }
      if (unit == first && s.startsWith(delimiter, i)) {
        // A longer run of the same character is not this delimiter's closer
        // unless the delimiter itself is the longer form.
        if (delimiter.length == 1 &&
            i + 1 < end &&
            s.codeUnitAt(i + 1) == first) {
          i += 2;
          continue;
        }
        return i;
      }
      i++;
    }
    return null;
  }

  /// Scans a backtick code span starting at [i].
  _Span? _scanCodeSpan(int i, int end) {
    var runEnd = i;
    while (runEnd < end && s.codeUnitAt(runEnd) == _kBacktick) {
      runEnd++;
    }
    final runLength = runEnd - i;
    var j = runEnd;
    while (j < end) {
      if (s.codeUnitAt(j) != _kBacktick) {
        j++;
        continue;
      }
      var closeEnd = j;
      while (closeEnd < end && s.codeUnitAt(closeEnd) == _kBacktick) {
        closeEnd++;
      }
      if (closeEnd - j == runLength) {
        return _Span(innerStart: runEnd, innerEnd: j, end: closeEnd);
      }
      j = closeEnd;
    }
    return null;
  }

  /// Scans an inline `$...$` math span starting at [i].
  _Span? _scanMath(int i, int end) {
    if (i + 1 >= end) return null;
    if (s.codeUnitAt(i + 1) == _kDollar) {
      return null; // display math, not inline
    }
    if (_isWhitespace(s.codeUnitAt(i + 1))) return null;
    var j = i + 1;
    while (j < end) {
      final unit = s.codeUnitAt(j);
      if (unit == _kBackslash && j + 1 < end) {
        j += 2;
        continue;
      }
      if (unit == _kNewline) return null;
      if (unit == _kDollar && !_isWhitespace(s.codeUnitAt(j - 1))) {
        return _Span(innerStart: i + 1, innerEnd: j, end: j + 1);
      }
      j++;
    }
    return null;
  }

  /// Scans `[text](destination)` starting at the `[` at [i].
  _Link? _scanLink(int i, int end) {
    var depth = 0;
    var j = i;
    var textEnd = -1;
    while (j < end) {
      final unit = s.codeUnitAt(j);
      if (unit == _kBackslash && j + 1 < end) {
        j += 2;
        continue;
      }
      if (unit == _kBacktick) {
        final span = _scanCodeSpan(j, end);
        if (span != null) {
          j = span.end;
          continue;
        }
      }
      if (unit == _kOpenBracket) {
        depth++;
      } else if (unit == _kCloseBracket) {
        depth--;
        if (depth == 0) {
          textEnd = j;
          break;
        }
      }
      j++;
    }
    if (textEnd < 0) return null;
    if (textEnd + 1 >= end || s.codeUnitAt(textEnd + 1) != _kOpenParen) {
      return null;
    }

    var k = textEnd + 2;
    var parenDepth = 1;
    while (k < end) {
      final unit = s.codeUnitAt(k);
      if (unit == _kBackslash && k + 1 < end) {
        k += 2;
        continue;
      }
      if (unit == _kOpenParen) {
        parenDepth++;
      } else if (unit == _kCloseParen) {
        parenDepth--;
        if (parenDepth == 0) {
          return _Link(
            textStart: i + 1,
            textEnd: textEnd,
            destination: _cleanDestination(s.substring(textEnd + 2, k)),
            end: k + 1,
          );
        }
      }
      k++;
    }
    return null;
  }

  /// Strips an optional `"title"` and surrounding angle brackets.
  String _cleanDestination(String raw) {
    var value = raw.trim();
    final quote = value.indexOf('"');
    if (quote > 0) value = value.substring(0, quote).trim();
    if (value.startsWith('<') && value.endsWith('>') && value.length >= 2) {
      value = value.substring(1, value.length - 1);
    }
    return value;
  }
}

bool _isWhitespace(int unit) =>
    unit == 0x20 || unit == 0x09 || unit == _kNewline || unit == 0x0D;

bool _isWordCharacter(int unit) =>
    (unit >= 0x30 && unit <= 0x39) ||
    (unit >= 0x41 && unit <= 0x5A) ||
    (unit >= 0x61 && unit <= 0x7A) ||
    unit >= 0x80;

final class _Span {
  const _Span({
    required this.innerStart,
    required this.innerEnd,
    required this.end,
  });

  final int innerStart;
  final int innerEnd;
  final int end;
}

final class _Link {
  const _Link({
    required this.textStart,
    required this.textEnd,
    required this.destination,
    required this.end,
  });

  final int textStart;
  final int textEnd;
  final String destination;
  final int end;
}
