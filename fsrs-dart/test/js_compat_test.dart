/// The JavaScript semantics the port depends on.
///
/// These are the places where a "close enough" Dart equivalent would silently
/// change a schedule: half-rounding, 32-bit coercion inside the PRNG, and
/// number formatting, which feeds the fuzz seed.
library;

import 'package:fsrs_dart/fsrs.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  test('jsRound rounds halves toward positive infinity', () {
    expect(jsRound(0.5), 1);
    expect(jsRound(1.5), 2);
    expect(jsRound(2.5), 3);
    expect(jsRound(-0.5), 0, reason: 'Dart would give -1 here');
    expect(jsRound(-1.5), -1, reason: 'Dart would give -2 here');
    expect(jsRound(-2.4), -2);
    expect(jsRound(2.4), 2);
    expect(jsRound(-2.6), -3);
  });

  test('toUint32 and toInt32 coerce like JavaScript', () {
    expect(toUint32(0), 0);
    expect(toUint32(4294967295.9), 4294967295);
    expect(toUint32(4294967296), 0);
    expect(toUint32(-1), 4294967295);
    expect(toUint32(double.nan), 0);
    expect(toUint32(double.infinity), 0);
    expect(toInt32(2147483647.2), 2147483647);
    expect(toInt32(2147483648), -2147483648);
    expect(toInt32(-1.9), -1);
    expect(toInt32(4294967297), 1);
  });

  test('jsParseInt accepts a trailing suffix and leading sign', () {
    expect(jsParseInt('10'), 10);
    expect(jsParseInt('  42abc'), 42);
    expect(jsParseInt('-7'), -7);
    expect(jsParseInt('+7'), 7);
    expect(jsParseInt('1.5'), 1);
    expect(jsParseInt('abc'), isNull);
    expect(jsParseInt(''), isNull);
  });

  test('jsNumOrZero applies JavaScript truthiness', () {
    expect(jsNumOrZero(null), 0);
    expect(jsNumOrZero(double.nan), 0);
    expect(jsNumOrZero(0), 0);
    expect(jsNumOrZero(-0.0), 0);
    expect(jsNumOrZero(1.5), 1.5);
  });

  test('jsNumberToString matches String(number)', () {
    final vectors = loadVectors('ts_fsrs_vectors.json');
    for (final entry in vectors['js_number_strings']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final value = (row['value']! as num).toDouble();
      expect(jsNumberToString(value), row['text'], reason: '$row');
    }
  });

  test('jsNumberToString handles the non-finite cases', () {
    expect(jsNumberToString(double.nan), 'NaN');
    expect(jsNumberToString(double.infinity), 'Infinity');
    expect(jsNumberToString(double.negativeInfinity), '-Infinity');
    expect(jsNumberToString(-0.0), '0');
  });

  test('roundTo keeps eight decimals', () {
    expect(roundTo(2.118103970459016, 8), 2.11810397);
    expect(roundTo(0.0028476847546917263, 8), 0.00284768);
    // Verified against Math.round(-1.234567895 * 1e8) / 1e8 in Node.
    expect(roundTo(-1.234567895, 8), -1.2345679);
  });
}
