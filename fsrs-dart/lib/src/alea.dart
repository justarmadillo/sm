/// The Alea PRNG, ported from ts-fsrs (which ports davidbau/seedrandom).
///
/// FSRS uses it for interval fuzzing. The port is bit-exact rather than merely
/// statistically equivalent: a card fuzzed by ts-fsrs and the same card fuzzed
/// here must land on the same day, so `>>> 0`, `| 0`, and `String(number)` are
/// all reproduced through [js_compat].
///
/// A port of an algorithm by Johannes Baagoe, 2010. Original work is under the
/// MIT license (see THIRD_PARTY_NOTICES).
library;

import 'js_compat.dart';

/// The internal state of an [Alea] generator.
class AleaState {
  /// Creates a state snapshot.
  const AleaState({
    required this.c,
    required this.s0,
    required this.s1,
    required this.s2,
  });

  /// Carry.
  final double c;

  /// First state word.
  final double s0;

  /// Second state word.
  final double s1;

  /// Third state word.
  final double s2;

  @override
  bool operator ==(Object other) =>
      other is AleaState &&
      c == other.c &&
      s0 == other.s0 &&
      s1 == other.s1 &&
      s2 == other.s2;

  @override
  int get hashCode => Object.hash(c, s0, s1, s2);

  @override
  String toString() => 'AleaState(c: $c, s0: $s0, s1: $s1, s2: $s2)';
}

/// The Alea generator itself.
class Alea {
  /// Seeds the generator. A null seed falls back to the current time, exactly
  /// as `Date.now()` does upstream.
  Alea([Object? seed]) {
    final mash = _mash();
    _c = 1;
    _s0 = mash(' ');
    _s1 = mash(' ');
    _s2 = mash(' ');
    final effectiveSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    _s0 -= mash(effectiveSeed);
    if (_s0 < 0) _s0 += 1;
    _s1 -= mash(effectiveSeed);
    if (_s1 < 0) _s1 += 1;
    _s2 -= mash(effectiveSeed);
    if (_s2 < 0) _s2 += 1;
  }

  late double _c;
  late double _s0;
  late double _s1;
  late double _s2;

  /// Produces the next value in `[0, 1)`.
  double next() {
    final t = 2091639 * _s0 + _c * 2.3283064365386963e-10; // 2^-32
    _s0 = _s1;
    _s1 = _s2;
    _c = toInt32(t).toDouble();
    _s2 = t - _c;
    return _s2;
  }

  /// The current state, for snapshot and restore.
  AleaState get state => AleaState(c: _c, s0: _s0, s1: _s1, s2: _s2);

  set state(AleaState state) {
    _c = state.c;
    _s0 = state.s0;
    _s1 = state.s1;
    _s2 = state.s2;
  }

  static double Function(Object) _mash() {
    var n = 0xefc8249d.toDouble();
    return (Object data) {
      final text = data is String ? data : jsNumberToString(data as num);
      for (var i = 0; i < text.length; i++) {
        n += text.codeUnitAt(i);
        var h = 0.02519603282416938 * n;
        n = toUint32(h).toDouble();
        h -= n;
        h *= n;
        n = toUint32(h).toDouble();
        h -= n;
        n += h * 0x100000000; // 2^32
      }
      return toUint32(n) * 2.3283064365386963e-10; // 2^-32
    };
  }
}

/// A seeded Alea generator with the helper projections ts-fsrs exposes.
class AleaPRNG {
  /// Seeds a generator; a null seed uses the current time.
  AleaPRNG([Object? seed]) : _xg = Alea(seed);

  final Alea _xg;

  /// The next double in `[0, 1)`.
  double call() => _xg.next();

  /// The next value as a signed 32-bit integer.
  int int32() => toInt32(_xg.next() * 0x100000000);

  /// The next value with 53 bits of entropy.
  double double53() =>
      call() + toInt32(call() * 0x200000) * 1.1102230246251565e-16; // 2^-53

  /// A snapshot of the internal state.
  AleaState get state => _xg.state;

  /// Restores a previously captured state.
  AleaPRNG importState(AleaState state) {
    _xg.state = state;
    return this;
  }
}

/// Creates a seeded generator, mirroring `alea(seed)` in ts-fsrs.
AleaPRNG alea([Object? seed]) => AleaPRNG(seed);
