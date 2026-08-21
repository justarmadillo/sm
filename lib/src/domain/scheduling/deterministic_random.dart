/// Reproducible randomness for scheduling decisions.
///
/// Three places in the design want randomness — queue jitter, the manual
/// Later delay, and auto-postpone dispersal — and in all three a fresh
/// `Random()` would be a bug rather than a nicety:
///
/// * the queue must produce the same order every time it is rebuilt within a
///   study day, or the user's place in the session moves under them;
/// * a retried command must land on the same date as its first attempt, or
///   exactly-once retry stops being exactly-once.
///
/// So every draw is a pure function of a caller-supplied seed string. The hash
/// is specified here rather than borrowed from [Object.hashCode], which Dart
/// does not guarantee across processes or versions.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// Deterministic 32-bit FNV-1a of [value], as a non-negative int.
///
/// Stable across processes, platforms, and Dart versions — that stability is
/// the whole point, so this must not be replaced with [Object.hashCode], whose
/// value Dart explicitly does not guarantee between runs.
int stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final int byte in utf8.encode(value)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// A stream of reproducible values derived from one seed string.
///
/// Not a general-purpose RNG: it is a small xorshift whose only requirements
/// are determinism, cheapness, and a reasonably even spread. Statistical
/// quality beyond that would buy nothing here.
@immutable
final class DeterministicRandom {
  /// A stream seeded by [seed].
  factory DeterministicRandom(String seed) =>
      DeterministicRandom._(stableHash(seed));

  const DeterministicRandom._(this._seed);

  final int _seed;

  /// A value in `[0, 1)` for [key], stable for the same seed and key.
  ///
  /// Keyed rather than sequential so a caller can draw for one element
  /// without the result depending on how many elements came before it.
  double unit(String key) {
    var x = (_seed ^ stableHash(key)) & 0xffffffff;
    if (x == 0) x = 0x2545f491;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >>> 17;
    x ^= (x << 5) & 0xffffffff;
    return (x & 0xffffffff) / 0x100000000;
  }

  /// A value in `[-magnitude, magnitude]` for [key].
  double symmetric(String key, double magnitude) =>
      (unit(key) * 2 - 1) * magnitude;

  /// A value in `[min, max]` for [key].
  double between(String key, double min, double max) =>
      min + unit(key) * (max - min);
}
