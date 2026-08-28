/// Exact numeric primitives used by the SuperMemo 20 scheduler clone.
///
/// These routines deliberately preserve SM20's storage rounding, one global
/// random stream, and observable sort-tie behavior. They must not be replaced
/// with Dart's default rounding, [double] fields in place of Real48 bytes, a
/// feature-local random generator, or a library sort.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

const int _uint32Mask = 0xffffffff;
const int _uint16Mask = 0xffff;
const double _uint32Unit = 1 / 4294967296.0;

/// Rounds [value] to the nearest integer, resolving exact ties toward even.
///
/// Dart's [double.round] resolves ties away from zero, so it is not compatible
/// with the default SSE conversion used by SM20.
int sm20RoundEven(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'must be finite');
  }

  final int lower = value.floor();
  final double fraction = value - lower;
  if (fraction < 0.5) return lower;
  if (fraction > 0.5) return lower + 1;
  return lower.isEven ? lower : lower + 1;
}

/// An immutable raw six-byte Delphi `Real48` value.
///
/// Equality is byte equality. This matters for migrated records: exponent-zero
/// payloads all decode as zero, but their raw bytes need not be canonical.
@immutable
final class DelphiReal48 {
  const DelphiReal48._(this._payload);

  /// Reads exactly six little-endian bytes without canonicalizing them.
  factory DelphiReal48.fromBytes(List<int> bytes) {
    if (bytes.length != 6) {
      throw ArgumentError.value(bytes.length, 'bytes.length', 'must be 6');
    }

    var payload = 0;
    for (var index = 0; index < bytes.length; index++) {
      final int byte = bytes[index];
      if (byte < 0 || byte > 0xff) {
        throw RangeError.range(byte, 0, 0xff, 'bytes[$index]');
      }
      payload |= byte << (index * 8);
    }
    return DelphiReal48._(payload);
  }

  /// Encodes a finite IEEE-754 double with Delphi Real48's rounding behavior.
  factory DelphiReal48.fromDouble(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }

    final ByteData data = ByteData(8)..setFloat64(0, value, Endian.little);
    final int bits = data.getUint64(0, Endian.little);
    final int exponent64 = (bits >>> 52) & 0x7ff;
    var exponent48 = exponent64 - 0x37e;
    final int sign = bits >>> 63;
    final int fraction = bits & ((1 << 52) - 1);
    var mantissa = fraction >>> 13;
    final int discarded = fraction & 0x1fff;

    // Delphi rounds every exact half upward here; it is not ties-to-even.
    if (discarded > 0x0fff) {
      mantissa += 1;
      if (mantissa > (1 << 39) - 1) {
        mantissa = 0;
        exponent48 += 1;
      }
    }

    if (exponent48 < 0) exponent48 = 0;
    if (exponent48 > 0xff) {
      throw RangeError.range(exponent48, 0, 0xff, 'Real48 exponent');
    }

    final int payload = exponent48 | (mantissa << 8) | (sign << 47);
    return DelphiReal48._(payload);
  }

  final int _payload;

  /// The raw unsigned 48-bit little-endian payload.
  int get payload => _payload;

  /// A fresh copy of the raw six-byte little-endian representation.
  Uint8List get bytes {
    final Uint8List result = Uint8List(6);
    for (var index = 0; index < result.length; index++) {
      result[index] = (_payload >>> (index * 8)) & 0xff;
    }
    return result;
  }

  /// Decodes this Real48 into an IEEE-754 double.
  double get value {
    final int exponent48 = _payload & 0xff;
    if (exponent48 == 0) return 0.0;

    final int mantissa = (_payload >>> 8) & ((1 << 39) - 1);
    final int sign = (_payload >>> 47) & 1;
    final int exponent64 = exponent48 + 0x37e;
    final int bits = (sign << 63) | (exponent64 << 52) | (mantissa << 13);
    final ByteData data = ByteData(8)..setUint64(0, bits, Endian.little);
    return data.getFloat64(0, Endian.little);
  }

  @override
  bool operator ==(Object other) =>
      other is DelphiReal48 && other._payload == _payload;

  @override
  int get hashCode => _payload.hashCode;

  @override
  String toString() =>
      bytes.map((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// A persistable snapshot of SM20's one-word global random state.
@immutable
final class Sm20RandomNumberGeneratorState {
  /// Creates a state from an unsigned 32-bit [seed].
  factory Sm20RandomNumberGeneratorState(int seed) {
    RangeError.checkValueInInterval(seed, 0, _uint32Mask, 'seed');
    return Sm20RandomNumberGeneratorState._(seed);
  }

  const Sm20RandomNumberGeneratorState._(this.seed);

  /// The unsigned 32-bit Delphi seed.
  final int seed;

  @override
  bool operator ==(Object other) =>
      other is Sm20RandomNumberGeneratorState && other.seed == seed;

  @override
  int get hashCode => seed.hashCode;

  @override
  String toString() =>
      'Sm20RandomNumberGeneratorState(0x${seed.toRadixString(16).padLeft(8, '0')})';
}

/// SM20's mutable, application-wide Delphi random stream.
///
/// A pseudo-random number generator (PRNG): given the same starting seed it
/// replays the exact same sequence of numbers, which is why the seed is
/// persisted. That reproducibility is what lets a randomized queue or a Mercy
/// batch be undone and re-derived rather than guessed at.
///
/// Pass the same instance to every scheduling subsystem. [drawCount] is
/// diagnostic and intentionally not part of the persisted state.
final class Sm20RandomNumberGenerator {
  /// Starts at unsigned 32-bit [seed].
  Sm20RandomNumberGenerator({int seed = 0})
    : _seed = Sm20RandomNumberGeneratorState(seed).seed;

  /// Continues from a persisted [state].
  Sm20RandomNumberGenerator.fromState(Sm20RandomNumberGeneratorState state)
    : _seed = state.seed;

  int _seed;
  int _drawCount = 0;

  /// The current unsigned 32-bit seed.
  int get seed => _seed;

  /// A persistable snapshot of [seed].
  Sm20RandomNumberGeneratorState get state =>
      Sm20RandomNumberGeneratorState._(_seed);

  /// Number of values consumed since construction or [restore].
  int get drawCount => _drawCount;

  /// Advances and returns the next unsigned 32-bit state.
  int advance() {
    _seed = (_multiplyLowUint32(_seed, 0x08088405) + 1) & _uint32Mask;
    _drawCount += 1;
    return _seed;
  }

  /// Delphi `Random()`, in the half-open interval `[0, 1)`.
  double nextDouble() => advance() * _uint32Unit;

  /// Delphi `Random(N)`: the high word of the unsigned 32-by-32 product.
  ///
  /// Unlike Dart's general-purpose random API, an [upperBound] of zero is
  /// valid, returns zero, and still consumes one PRNG value.
  int nextInt(int upperBound) {
    RangeError.checkValueInInterval(upperBound, 0, _uint32Mask, 'upperBound');
    return _highUint32Product(advance(), upperBound);
  }

  /// Restores the global stream and resets only its diagnostic draw counter.
  void restore(Sm20RandomNumberGeneratorState state) {
    _seed = state.seed;
    _drawCount = 0;
  }
}

/// SM20's exact two-draw random interval dispersion.
double sm20Spread({
  required double center,
  required double width,
  required Sm20RandomNumberGenerator randomNumbers,
}) {
  // The order is part of the contract, including the apparently redundant
  // non-negative clamp after the center-relative upper clamp.
  var adjustedWidth = math.max(width, 4.0);
  adjustedWidth = math.min(adjustedWidth, center + 4.0);
  adjustedWidth = math.max(adjustedWidth, 0.0);
  adjustedWidth = math.min(adjustedWidth, 100.0);

  final double first = randomNumbers.nextDouble();
  var z = -10.857763300760043 * math.log(1 - (first / 2) * 1.979793637145314);

  final double second = randomNumbers.nextDouble();
  if (second > 0.5) z = -z;

  return math.max(1.0, center + (z / 50) * adjustedWidth);
}

/// Sorts [values] by descending integer key with SM20's exact heap ties.
///
/// This is an in-place, one-based min-heap followed by extraction. Equal
/// children choose the left child and an equal child never swaps with its
/// parent, so this is intentionally not a stable library sort.
void sm20HeapSortDescendingInPlace<T>(
  List<T> values, {
  required int Function(T value) keyOf,
}) {
  final int count = values.length;
  if (count < 2) return;

  void swap(int first, int second) {
    final T value = values[first - 1];
    values[first - 1] = values[second - 1];
    values[second - 1] = value;
  }

  void downHeap(int start, int end) {
    var parent = start;
    while (parent * 2 <= end) {
      final int left = parent * 2;
      final int right = left + 1;
      var child = left;
      if (right <= end && keyOf(values[right - 1]) < keyOf(values[left - 1])) {
        child = right;
      }

      if (keyOf(values[child - 1]) >= keyOf(values[parent - 1])) return;
      swap(parent, child);
      parent = child;
    }
  }

  for (var index = count ~/ 2; index >= 1; index--) {
    downHeap(index, count);
  }
  for (var end = count; end >= 2; end--) {
    swap(1, end);
    downHeap(1, end - 1);
  }
}

/// Low 32 bits of an unsigned 32-by-32 product using exact 16-bit limbs.
int _multiplyLowUint32(int left, int right) {
  final int leftLow = left & _uint16Mask;
  final int leftHigh = left >>> 16;
  final int rightLow = right & _uint16Mask;
  final int rightHigh = right >>> 16;
  final int lowProduct = leftLow * rightLow;
  final int cross = (leftLow * rightHigh + leftHigh * rightLow) & _uint16Mask;
  return (lowProduct + (cross << 16)) & _uint32Mask;
}

/// High 32 bits of an unsigned 32-by-32 product using exact 16-bit limbs.
int _highUint32Product(int left, int right) {
  final int leftLow = left & _uint16Mask;
  final int leftHigh = left >>> 16;
  final int rightLow = right & _uint16Mask;
  final int rightHigh = right >>> 16;
  final int lowProduct = leftLow * rightLow;
  final int middle =
      leftHigh * rightLow + leftLow * rightHigh + (lowProduct >>> 16);
  return (leftHigh * rightHigh + (middle >>> 16)) & _uint32Mask;
}
