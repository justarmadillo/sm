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
  _InlineParser(this.content);

  /// The block content text being parsed. Every offset this parser reports is
  /// an index into this string.
  final String content;
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
    var cursor = start;
    var plainStart = start;

    void flushPlain(int upTo) {
      if (upTo <= plainStart) return;
      // A soft line break inside a paragraph renders as a space. Length is
      // unchanged, so the run stays a one-to-one mapping onto its source.
      final raw = content.substring(plainStart, upTo);
      final text = raw.contains('\n') ? raw.replaceAll('\n', ' ') : raw;
      _emit(text, plainStart, upTo, styles, href: href);
    }

    while (cursor < end) {
      final codeUnit = content.codeUnitAt(cursor);

      if (codeUnit == _kBackslash &&
          cursor + 1 < end &&
          _isEscapable(content[cursor + 1])) {
        flushPlain(cursor);
        _emit(content[cursor + 1], cursor, cursor + 2, styles, href: href);
        cursor += 2;
        plainStart = cursor;
        continue;
      }

      if (codeUnit == _kBacktick) {
        final span = _scanCodeSpan(cursor, end);
        if (span != null) {
          flushPlain(cursor);
          _emit(
            content.substring(span.innerStart, span.innerEnd),
            span.innerStart,
            span.innerEnd,
            <InlineStyle>{...styles, InlineStyle.code},
            href: href,
          );
          cursor = span.end;
          plainStart = cursor;
          continue;
        }
      }

      if (codeUnit == _kDollar) {
        final span = _scanMath(cursor, end);
        if (span != null) {
          flushPlain(cursor);
          final tex = content.substring(span.innerStart, span.innerEnd);
          _emit(
            tex,
            span.innerStart,
            span.innerEnd,
            <InlineStyle>{...styles, InlineStyle.math},
            href: href,
            math: tex,
          );
          cursor = span.end;
          plainStart = cursor;
          continue;
        }
      }

      if (codeUnit == _kBang &&
          cursor + 1 < end &&
          content.codeUnitAt(cursor + 1) == _kOpenBracket) {
        final link = _scanLink(cursor + 1, end);
        if (link != null) {
          flushPlain(cursor);
          final alt = content.substring(link.textStart, link.textEnd);
          _emit(
            alt.isEmpty ? kObjectReplacement : alt,
            cursor,
            link.end,
            <InlineStyle>{...styles, InlineStyle.image},
            href: href,
            imageUrl: link.destination,
          );
          cursor = link.end;
          plainStart = cursor;
          continue;
        }
      }

      if (codeUnit == _kOpenBracket) {
        final link = _scanLink(cursor, end);
        if (link != null) {
          flushPlain(cursor);
          parseRange(link.textStart, link.textEnd, <InlineStyle>{
            ...styles,
            InlineStyle.link,
          }, link.destination);
          cursor = link.end;
          plainStart = cursor;
          continue;
        }
      }

      if (codeUnit == _kTilde &&
          cursor + 1 < end &&
          content.codeUnitAt(cursor + 1) == _kTilde) {
        final close = _findClosingDelimiter(cursor + 2, end, '~~');
        if (close != null) {
          flushPlain(cursor);
          parseRange(cursor + 2, close, <InlineStyle>{
            ...styles,
            InlineStyle.strikethrough,
          }, href);
          cursor = close + 2;
          plainStart = cursor;
          continue;
        }
      }

      if (codeUnit == _kAsterisk || codeUnit == _kUnderscore) {
        final marker = content[cursor];
        final isDouble =
            cursor + 1 < end && content.codeUnitAt(cursor + 1) == codeUnit;
        final delimiter = isDouble ? marker * 2 : marker;
        if (_canOpenEmphasis(cursor, delimiter, end)) {
          final close = _findEmphasisCloser(
            cursor + delimiter.length,
            end,
            delimiter,
          );
          if (close != null) {
            flushPlain(cursor);
            parseRange(cursor + delimiter.length, close, <InlineStyle>{
              ...styles,
              isDouble ? InlineStyle.strong : InlineStyle.emphasis,
            }, href);
            cursor = close + delimiter.length;
            plainStart = cursor;
            continue;
          }
        }
      }

      cursor++;
    }
    flushPlain(end);
  }

  /// Whether a `\` before [character] escapes it into literal text.
  bool _isEscapable(String character) => _kEscapable.contains(character);

  /// Whether the delimiter at [delimiterStart] can open emphasis: it is
  /// followed by a non-whitespace character, and for `_` also not mid-word.
  bool _canOpenEmphasis(int delimiterStart, String delimiter, int end) {
    final after = delimiterStart + delimiter.length;
    if (after >= end) return false;
    if (_isWhitespace(content.codeUnitAt(after))) return false;
    if (delimiter.codeUnitAt(0) == _kUnderscore && delimiterStart > 0) {
      // `snake_case` must not become emphasis.
      if (_isWordCharacter(content.codeUnitAt(delimiterStart - 1))) {
        return false;
      }
    }
    return true;
  }

  /// Index of the closing emphasis [delimiter] in `[from, end)`, or null.
  int? _findEmphasisCloser(int from, int end, String delimiter) {
    final closerIndex = _findClosingDelimiter(from, end, delimiter);
    if (closerIndex == null) return null;
    if (closerIndex == from) return null; // empty emphasis is literal text
    if (_isWhitespace(content.codeUnitAt(closerIndex - 1))) return null;
    if (delimiter.codeUnitAt(0) == _kUnderscore &&
        closerIndex + delimiter.length < end) {
      if (_isWordCharacter(
        content.codeUnitAt(closerIndex + delimiter.length),
      )) {
        return null;
      }
    }
    return closerIndex;
  }

  /// Index of [delimiter] in `[from, end)`, skipping escapes and code spans.
  int? _findClosingDelimiter(int from, int end, String delimiter) {
    final firstCharacter = delimiter.codeUnitAt(0);
    var cursor = from;
    while (cursor < end) {
      final codeUnit = content.codeUnitAt(cursor);
      if (codeUnit == _kBackslash && cursor + 1 < end) {
        cursor += 2;
        continue;
      }
      if (codeUnit == _kBacktick) {
        final span = _scanCodeSpan(cursor, end);
        if (span != null) {
          cursor = span.end;
          continue;
        }
      }
      if (codeUnit == firstCharacter && content.startsWith(delimiter, cursor)) {
        // A longer run of the same character is not this delimiter's closer
        // unless the delimiter itself is the longer form.
        if (delimiter.length == 1 &&
            cursor + 1 < end &&
            content.codeUnitAt(cursor + 1) == firstCharacter) {
          cursor += 2;
          continue;
        }
        return cursor;
      }
      cursor++;
    }
    return null;
  }

  /// Scans a backtick code span starting at [start].
  _DelimitedSpan? _scanCodeSpan(int start, int end) {
    var runEnd = start;
    while (runEnd < end && content.codeUnitAt(runEnd) == _kBacktick) {
      runEnd++;
    }
    final runLength = runEnd - start;
    var scan = runEnd;
    while (scan < end) {
      if (content.codeUnitAt(scan) != _kBacktick) {
        scan++;
        continue;
      }
      var closeEnd = scan;
      while (closeEnd < end && content.codeUnitAt(closeEnd) == _kBacktick) {
        closeEnd++;
      }
      if (closeEnd - scan == runLength) {
        return _DelimitedSpan(
          innerStart: runEnd,
          innerEnd: scan,
          end: closeEnd,
        );
      }
      scan = closeEnd;
    }
    return null;
  }

  /// Scans an inline `$...$` math span starting at [start], or null when this
  /// `$` opens display math, a spaced-out price, or nothing that closes.
  _DelimitedSpan? _scanMath(int start, int end) {
    if (start + 1 >= end) return null;
    if (content.codeUnitAt(start + 1) == _kDollar) {
      return null; // display math, not inline
    }
    if (_isWhitespace(content.codeUnitAt(start + 1))) return null;
    var scan = start + 1;
    while (scan < end) {
      final codeUnit = content.codeUnitAt(scan);
      if (codeUnit == _kBackslash && scan + 1 < end) {
        scan += 2;
        continue;
      }
      if (codeUnit == _kNewline) return null;
      if (codeUnit == _kDollar &&
          !_isWhitespace(content.codeUnitAt(scan - 1))) {
        return _DelimitedSpan(
          innerStart: start + 1,
          innerEnd: scan,
          end: scan + 1,
        );
      }
      scan++;
    }
    return null;
  }

  /// Scans `[text](destination)` starting at the `[` at [start], or null when
  /// the brackets or parentheses never balance.
  _Link? _scanLink(int start, int end) {
    var bracketDepth = 0;
    var scan = start;
    var textEnd = -1;
    while (scan < end) {
      final codeUnit = content.codeUnitAt(scan);
      if (codeUnit == _kBackslash && scan + 1 < end) {
        scan += 2;
        continue;
      }
      if (codeUnit == _kBacktick) {
        final span = _scanCodeSpan(scan, end);
        if (span != null) {
          scan = span.end;
          continue;
        }
      }
      if (codeUnit == _kOpenBracket) {
        bracketDepth++;
      } else if (codeUnit == _kCloseBracket) {
        bracketDepth--;
        if (bracketDepth == 0) {
          textEnd = scan;
          break;
        }
      }
      scan++;
    }
    if (textEnd < 0) return null;
    if (textEnd + 1 >= end || content.codeUnitAt(textEnd + 1) != _kOpenParen) {
      return null;
    }

    var destinationScan = textEnd + 2;
    var parenDepth = 1;
    while (destinationScan < end) {
      final codeUnit = content.codeUnitAt(destinationScan);
      if (codeUnit == _kBackslash && destinationScan + 1 < end) {
        destinationScan += 2;
        continue;
      }
      if (codeUnit == _kOpenParen) {
        parenDepth++;
      } else if (codeUnit == _kCloseParen) {
        parenDepth--;
        if (parenDepth == 0) {
          return _Link(
            textStart: start + 1,
            textEnd: textEnd,
            destination: _cleanDestination(
              content.substring(textEnd + 2, destinationScan),
            ),
            end: destinationScan + 1,
          );
        }
      }
      destinationScan++;
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

/// Whether [codeUnit] is a space, tab, newline, or carriage return.
bool _isWhitespace(int codeUnit) =>
    codeUnit == 0x20 ||
    codeUnit == 0x09 ||
    codeUnit == _kNewline ||
    codeUnit == 0x0D;

/// Whether [codeUnit] is a digit, an ASCII letter, or any non-ASCII
/// character. Used to keep `snake_case` from turning into emphasis.
bool _isWordCharacter(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) ||
    (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
    (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
    codeUnit >= 0x80;

final class _DelimitedSpan {
  const _DelimitedSpan({
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
