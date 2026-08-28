library;

import 'dart:typed_data';

import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:test/test.dart';

void main() {
  group('sm20RoundEven', () {
    test('rounds exact positive and negative ties toward even', () {
      expect(sm20RoundEven(0.5), 0);
      expect(sm20RoundEven(1.5), 2);
      expect(sm20RoundEven(2.5), 2);
      expect(sm20RoundEven(3.5), 4);
      expect(sm20RoundEven(-0.5), 0);
      expect(sm20RoundEven(-1.5), -2);
      expect(sm20RoundEven(-2.5), -2);
      expect(sm20RoundEven(-3.5), -4);
    });

    test('rounds values on either side of a tie normally', () {
      expect(sm20RoundEven(2.499999999), 2);
      expect(sm20RoundEven(2.500000001), 3);
      expect(sm20RoundEven(-2.500000001), -3);
      expect(sm20RoundEven(-2.499999999), -2);
    });

    test('rejects values that cannot be converted to an integer', () {
      expect(() => sm20RoundEven(double.nan), throwsArgumentError);
      expect(() => sm20RoundEven(double.infinity), throwsArgumentError);
      expect(() => sm20RoundEven(double.negativeInfinity), throwsArgumentError);
    });
  });

  group('DelphiReal48', () {
    const List<(double, String)> vectors = <(double, String)>[
      (0.0, '000000000000'),
      (1.0, '810000000000'),
      (1.01, '817b14ae4701'),
      (1.2, '819a99999919'),
      (2.0, '820000000000'),
      (3.0, '820000000040'),
      (6.0, '830000000040'),
    ];

    test('encodes every executable-derived byte vector', () {
      for (final (double value, String expectedHex) in vectors) {
        expect(
          DelphiReal48.fromDouble(value).toString(),
          expectedHex,
          reason: '$value',
        );
      }
    });

    test('decodes every byte vector and survives a Real48 round trip', () {
      for (final (double expected, String sourceHex) in vectors) {
        final DelphiReal48 stored = DelphiReal48.fromBytes(_hex(sourceHex));
        expect(stored.value, closeTo(expected, 2e-12), reason: sourceHex);
        expect(
          DelphiReal48.fromDouble(stored.value),
          stored,
          reason: sourceHex,
        );
      }
    });

    test('uses upward rather than banker rounding at an exact half', () {
      final double exactHalf = _doubleFromBits((0x3ff << 52) | 0x1000);
      // The retained mantissa is initially even zero. Ties-to-even would keep
      // it there; Delphi Real48 increments it to one.
      expect(DelphiReal48.fromDouble(exactHalf).toString(), '810100000000');
    });

    test('carries a rounded mantissa into the exponent', () {
      final double immediatelyBelowTwo = _doubleFromBits(
        (0x3ff << 52) | ((1 << 52) - 1),
      );
      expect(
        DelphiReal48.fromDouble(immediatelyBelowTwo).toString(),
        '820000000000',
      );
    });

    test('preserves sign and exponent-zero raw payloads byte for byte', () {
      expect(DelphiReal48.fromDouble(-1).toString(), '810000000080');

      final Uint8List source = Uint8List.fromList(_hex('00ffffffff80'));
      final DelphiReal48 nonCanonicalZero = DelphiReal48.fromBytes(source);
      source[1] = 0;
      expect(nonCanonicalZero.toString(), '00ffffffff80');
      expect(nonCanonicalZero.value, 0.0);
      expect(nonCanonicalZero, isNot(DelphiReal48.fromDouble(0)));

      final Uint8List returned = nonCanonicalZero.bytes;
      returned[1] = 0;
      expect(nonCanonicalZero.toString(), '00ffffffff80');
    });

    test('underflows an IEEE subnormal and rejects Real48 overflow', () {
      expect(DelphiReal48.fromDouble(_doubleFromBits(1)).value, 0.0);
      expect(
        () => DelphiReal48.fromDouble(
          _doubleFromBits((0x7fe << 52) | ((1 << 52) - 1)),
        ),
        throwsRangeError,
      );
    });

    test('validates its finite input and exact raw byte shape', () {
      expect(() => DelphiReal48.fromDouble(double.nan), throwsArgumentError);
      expect(
        () => DelphiReal48.fromDouble(double.infinity),
        throwsArgumentError,
      );
      expect(() => DelphiReal48.fromBytes(<int>[0, 0]), throwsArgumentError);
      expect(
        () => DelphiReal48.fromBytes(<int>[0, 0, 0, 0, 0, 256]),
        throwsRangeError,
      );
      expect(
        () => DelphiReal48.fromBytes(<int>[0, 0, 0, 0, 0, -1]),
        throwsRangeError,
      );
    });
  });

  group('Sm20RandomNumberGenerator', () {
    test('matches all six seed-zero advanced states', () {
      final Sm20RandomNumberGenerator randomNumbers =
          Sm20RandomNumberGenerator();
      expect(
        <int>[for (var draw = 0; draw < 6; draw++) randomNumbers.advance()],
        <int>[1, 134775814, 3698175007, 870078620, 1172187917, 2884733762],
      );
      expect(randomNumbers.seed, 2884733762);
      expect(randomNumbers.state, Sm20RandomNumberGeneratorState(2884733762));
      expect(randomNumbers.drawCount, 6);
    });

    test('Random returns the advanced state multiplied by two to minus 32', () {
      final Sm20RandomNumberGenerator randomNumbers =
          Sm20RandomNumberGenerator();
      expect(randomNumbers.nextDouble(), 1 / 4294967296.0);
      expect(randomNumbers.seed, 1);
      expect(randomNumbers.drawCount, 1);
    });

    test('Random(N) uses the unsigned high product', () {
      final Sm20RandomNumberGenerator ordinary = Sm20RandomNumberGenerator(
        seed: 1,
      );
      expect(ordinary.nextInt(1000), 31);
      expect(ordinary.seed, 134775814);

      final Sm20RandomNumberGenerator highWords = Sm20RandomNumberGenerator(
        seed: 0xffffffff,
      );
      expect(highWords.nextInt(0xffffffff), 4160191483);
      expect(highWords.seed, 4160191484);
    });

    test('Random(0) returns zero but still consumes its draw', () {
      final Sm20RandomNumberGenerator randomNumbers = Sm20RandomNumberGenerator(
        seed: 123456789,
      );
      expect(randomNumbers.nextInt(0), 0);
      expect(randomNumbers.seed, 2335298922);
      expect(randomNumbers.drawCount, 1);
    });

    test('a persisted state continues the same global sequence', () {
      final Sm20RandomNumberGenerator original = Sm20RandomNumberGenerator()
        ..advance()
        ..advance();
      final Sm20RandomNumberGeneratorState checkpoint = original.state;
      final int expected = original.advance();

      final Sm20RandomNumberGenerator resumed =
          Sm20RandomNumberGenerator.fromState(checkpoint);
      expect(resumed.advance(), expected);
      expect(resumed.drawCount, 1);

      resumed.restore(checkpoint);
      expect(resumed.drawCount, 0);
      expect(resumed.advance(), expected);
    });

    test('rejects values outside the unsigned 32-bit domain', () {
      expect(() => Sm20RandomNumberGenerator(seed: -1), throwsRangeError);
      expect(
        () => Sm20RandomNumberGenerator(seed: 0x100000000),
        throwsRangeError,
      );
      expect(() => Sm20RandomNumberGenerator().nextInt(-1), throwsRangeError);
      expect(
        () => Sm20RandomNumberGenerator().nextInt(0x100000000),
        throwsRangeError,
      );
    });
  });

  group('sm20Spread', () {
    test('reproduces every seed-zero next-interval dispersion vector', () {
      const List<(double, double, int)> cases = <(double, double, int)>[
        (8, 8, 8),
        (2, 1, 2),
        (20, 10, 20),
        (300, 200, 300),
        (101, 1, 101),
      ];
      for (final (double center, double width, int expected) in cases) {
        final Sm20RandomNumberGenerator randomNumbers =
            Sm20RandomNumberGenerator();
        expect(
          sm20RoundEven(
            sm20Spread(
              center: center,
              width: width,
              randomNumbers: randomNumbers,
            ),
          ),
          expected,
          reason: 'center=$center width=$width',
        );
        expect(randomNumbers.seed, 134775814);
        expect(randomNumbers.drawCount, 2);
      }
    });

    test('applies the sign draw and exact logarithmic curve', () {
      final Sm20RandomNumberGenerator randomNumbers = Sm20RandomNumberGenerator(
        seed: 1,
      );
      expect(
        sm20Spread(center: 20, width: 10, randomNumbers: randomNumbers),
        closeTo(19.93147538794108, 1e-12),
      );
      expect(randomNumbers.seed, 3698175007);
      expect(randomNumbers.drawCount, 2);
    });

    test('honors the ordered width clamps and absolute floor', () {
      final Sm20RandomNumberGenerator capped = Sm20RandomNumberGenerator(
        seed: 123456789,
      );
      final Sm20RandomNumberGenerator explicitHundred =
          Sm20RandomNumberGenerator(seed: 123456789);
      expect(
        sm20Spread(center: 300, width: 200, randomNumbers: capped),
        sm20Spread(center: 300, width: 100, randomNumbers: explicitHundred),
      );

      final Sm20RandomNumberGenerator centerRelative =
          Sm20RandomNumberGenerator();
      expect(
        sm20Spread(center: -10, width: 500, randomNumbers: centerRelative),
        1,
      );
      expect(centerRelative.drawCount, 2);
    });

    test('every call consumes exactly two values from the shared stream', () {
      final Sm20RandomNumberGenerator randomNumbers =
          Sm20RandomNumberGenerator();
      sm20Spread(center: 8, width: 8, randomNumbers: randomNumbers);
      sm20Spread(center: 8, width: 8, randomNumbers: randomNumbers);
      expect(randomNumbers.seed, 870078620);
      expect(randomNumbers.drawCount, 4);
    });
  });

  group('sm20HeapSortDescendingInPlace', () {
    test('sorts integer keys in descending order', () {
      final List<_KeyedValue> values = <_KeyedValue>[
        const _KeyedValue('a', 2),
        const _KeyedValue('b', -1),
        const _KeyedValue('c', 8),
        const _KeyedValue('d', 3),
      ];
      sm20HeapSortDescendingInPlace(
        values,
        keyOf: (_KeyedValue value) => value.key,
      );
      expect(values.map((_KeyedValue value) => value.id), <String>[
        'c',
        'd',
        'a',
        'b',
      ]);
    });

    test('chooses the left child when child keys tie', () {
      final List<_KeyedValue> values = <_KeyedValue>[
        const _KeyedValue('a', 2),
        const _KeyedValue('b', 1),
        const _KeyedValue('c', 1),
        const _KeyedValue('d', 2),
      ];
      sm20HeapSortDescendingInPlace(
        values,
        keyOf: (_KeyedValue value) => value.key,
      );
      // A stable descending sort would end b,c. Choosing the right child on
      // equality would produce d,a,b,c. SM20 produces this exact identity order.
      expect(values.map((_KeyedValue value) => value.id), <String>[
        'a',
        'd',
        'c',
        'b',
      ]);
    });

    test('does not swap an equal child with its parent', () {
      final List<_KeyedValue> values = <_KeyedValue>[
        const _KeyedValue('a', 1),
        const _KeyedValue('b', 1),
        const _KeyedValue('c', 1),
      ];
      sm20HeapSortDescendingInPlace(
        values,
        keyOf: (_KeyedValue value) => value.key,
      );
      expect(values.map((_KeyedValue value) => value.id), <String>[
        'b',
        'c',
        'a',
      ]);
    });

    test('leaves zero- and one-element inputs alone', () {
      var keyReads = 0;
      final List<_KeyedValue> empty = <_KeyedValue>[];
      final List<_KeyedValue> single = <_KeyedValue>[
        const _KeyedValue('only', 4),
      ];
      int keyOf(_KeyedValue value) {
        keyReads += 1;
        return value.key;
      }

      sm20HeapSortDescendingInPlace(empty, keyOf: keyOf);
      sm20HeapSortDescendingInPlace(single, keyOf: keyOf);
      expect(single.single.id, 'only');
      expect(keyReads, 0);
    });
  });
}

List<int> _hex(String value) => <int>[
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];

double _doubleFromBits(int bits) {
  final ByteData data = ByteData(8)..setUint64(0, bits, Endian.little);
  return data.getFloat64(0, Endian.little);
}

final class _KeyedValue {
  const _KeyedValue(this.id, this.key);

  final String id;
  final int key;
}
