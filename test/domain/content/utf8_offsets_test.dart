import 'dart:convert';

import 'package:incremental_reader/src/core/utf8_offsets.dart';
import 'package:test/test.dart';

void main() {
  group('utf8Length', () {
    test('matches the real encoder for mixed scripts', () {
      const samples = <String>[
        '',
        'plain ascii',
        'café',
        '日本語のテキスト',
        'emoji 👍🏽 and 🇯🇵 flags',
        'math ∫ ∑ ≈',
        'mixed café 日本 👍 end',
      ];
      for (final sample in samples) {
        expect(
          utf8Length(sample),
          utf8.encode(sample).length,
          reason: 'utf8Length disagreed on "$sample"',
        );
      }
    });
  });

  group('Utf8OffsetIndex', () {
    test('byteLength matches the real encoder', () {
      final index = Utf8OffsetIndex('a café 日本 👍 z');
      expect(index.byteLength, utf8.encode(index.text).length);
    });

    test('toUtf8 agrees with encoding every prefix', () {
      const text = 'a café 日本語 👍 end';
      final index = Utf8OffsetIndex(text);
      for (var i = 0; i <= text.length; i++) {
        // Indices that split a surrogate pair are not code-point boundaries;
        // encoding such a prefix substitutes U+FFFD, so there is nothing to
        // compare against. They are covered by the surrogate test below.
        if (i < text.length && _isLowSurrogate(text.codeUnitAt(i))) continue;
        expect(
          index.toUtf8(i),
          utf8.encode(text.substring(0, i)).length,
          reason: 'prefix length mismatch at UTF-16 index $i',
        );
      }
    });

    test('round-trips every code point boundary', () {
      const text = 'a café 日本語 👍 end';
      final index = Utf8OffsetIndex(text);
      for (final rune in text.runes.toList()) {
        expect(rune, isNonNegative);
      }
      var utf16 = 0;
      while (utf16 <= text.length) {
        final bytes = index.toUtf8(utf16);
        expect(index.toUtf16(bytes), utf16, reason: 'round trip at $utf16');
        // Step by whole code points so surrogate halves are never targeted.
        if (utf16 == text.length) break;
        final unit = text.codeUnitAt(utf16);
        utf16 += (unit >= 0xD800 && unit <= 0xDBFF) ? 2 : 1;
      }
    });

    test('an offset inside a multi-byte sequence resolves to its start', () {
      const text = '日本';
      final index = Utf8OffsetIndex(text);
      expect(index.toUtf16(0), 0);
      expect(index.toUtf16(1), 0);
      expect(index.toUtf16(2), 0);
      expect(index.toUtf16(3), 1);
      expect(index.toUtf16(6), 2);
    });

    test('a surrogate pair is never split', () {
      const text = 'a👍b';
      final index = Utf8OffsetIndex(text);
      // 'a' = 1 byte, thumbs up = 4 bytes, 'b' = 1 byte.
      expect(index.byteLength, 6);
      expect(index.toUtf8(1), 1);
      // Both halves of the pair share the start of the 4-byte sequence.
      expect(index.toUtf8(2), 1);
      expect(index.toUtf8(3), 5);
      expect(index.toUtf16(1), 1);
      expect(index.toUtf16(3), 1);
      expect(index.toUtf16(5), 3);
    });

    test('clamps out-of-range inputs', () {
      final index = Utf8OffsetIndex('abc');
      expect(index.toUtf8(-5), 0);
      expect(index.toUtf8(99), 3);
      expect(index.toUtf16(-5), 0);
      expect(index.toUtf16(99), 3);
    });
  });
}

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
