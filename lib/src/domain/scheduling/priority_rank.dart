/// Relative priority as a sortable order key.
///
/// Priority is *relative*: what matters is whether one element outranks
/// another, not what number it holds. Storing an absolute score invites two
/// bugs — it implies a precision the user never expressed, and every
/// reordering rewrites unrelated rows. Instead each element holds a string
/// order key, and a new key can always be generated strictly between two
/// existing ones without touching anything else. Position and percentile are
/// derived at query time from the sorted order.
///
/// Lower keys mean higher priority, matching the SuperMemo presentation where
/// 0% is the most important element and 100% the least.
library;

import 'package:meta/meta.dart';

/// Digits of the order-key alphabet, in ascending ASCII order.
const String orderKeyDigits =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// A sortable relative priority.
@immutable
final class PriorityRank implements Comparable<PriorityRank> {
  /// Wraps an existing [orderKey]. Use [between] to make new ones.
  const PriorityRank(this.orderKey);

  /// The rank new root elements start at.
  static const PriorityRank middle = PriorityRank('V');

  /// Lexicographically sortable key. Never empty, never ends with `0`.
  final String orderKey;

  /// A rank strictly between [before] and [after].
  ///
  /// A null [before] means "above everything"; a null [after] means "below
  /// everything". Throws [ArgumentError] when the bounds are not ordered.
  static PriorityRank between(PriorityRank? before, PriorityRank? after) {
    final a = before?.orderKey ?? '';
    final b = after?.orderKey;
    if (b != null && a.compareTo(b) >= 0) {
      throw ArgumentError('order keys must be ascending: "$a" >= "$b"');
    }
    return PriorityRank(_midpoint(a, b));
  }

  /// A rank immediately more important than [rank].
  static PriorityRank above(PriorityRank rank) => between(null, rank);

  /// A rank immediately less important than [rank].
  static PriorityRank below(PriorityRank rank) => between(rank, null);

  /// Evenly spaced ranks strictly between [before] and [after].
  ///
  /// Used by bulk reprioritization, which spreads one range across every
  /// element under a branch in a single transaction.
  static List<PriorityRank> spread({
    required int count,
    PriorityRank? before,
    PriorityRank? after,
  }) {
    if (count <= 0) return const <PriorityRank>[];
    final result = <PriorityRank>[];
    var low = before;
    for (var i = 0; i < count; i++) {
      final next = between(low, after);
      result.add(next);
      low = next;
    }
    return result;
  }

  @override
  int compareTo(PriorityRank other) => orderKey.compareTo(other.orderKey);

  bool operator <(PriorityRank other) => compareTo(other) < 0;

  bool operator >(PriorityRank other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is PriorityRank && other.orderKey == orderKey;

  @override
  int get hashCode => orderKey.hashCode;

  @override
  String toString() => 'PriorityRank($orderKey)';
}

/// Where a rank sits in the current collection, derived not stored.
@immutable
final class PriorityPosition {
  const PriorityPosition({required this.index, required this.total});

  /// Zero-based position in ascending order-key order.
  final int index;

  /// Number of ranked elements the position was computed against.
  final int total;

  /// SuperMemo-style percent: 0 is the most important, 100 the least.
  double get percent => total <= 1 ? 0 : (index / (total - 1)) * 100;

  @override
  String toString() => '${percent.toStringAsFixed(0)}%';
}

/// The order key strictly between [a] and [b].
///
/// This is the fractional-indexing midpoint: treat the keys as fractions in
/// base 62 and find a shortest string between them. Keys never end in `0`, so
/// there is always room to insert again on either side.
String _midpoint(String a, String? b) {
  assert(b == null || a.compareTo(b) < 0, 'bounds must be ascending');
  assert(!a.endsWith('0'), 'order key must not end with a zero digit');
  assert(b == null || !b.endsWith('0'), 'order key must not end with a zero');

  if (b != null) {
    // Keep any shared prefix and recurse on the remainder.
    var n = 0;
    while (n < b.length && (n < a.length ? a[n] : '0') == b[n]) {
      n++;
    }
    if (n > 0) {
      return b.substring(0, n) +
          _midpoint(n < a.length ? a.substring(n) : '', b.substring(n));
    }
  }

  final digitA = a.isEmpty ? 0 : orderKeyDigits.indexOf(a[0]);
  final digitB = b == null
      ? orderKeyDigits.length
      : orderKeyDigits.indexOf(b[0]);
  if (digitB - digitA > 1) {
    final mid = (0.5 * (digitA + digitB)).round();
    return orderKeyDigits[mid];
  }
  // The leading digits are adjacent: descend into whichever side has room.
  if (b != null && b.length > 1) {
    return b.substring(0, 1);
  }
  return orderKeyDigits[digitA] +
      _midpoint(a.isEmpty ? '' : a.substring(1), null);
}
