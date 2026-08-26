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

import 'sm20_numeric.dart';

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

  bool operator <=(PriorityRank other) => compareTo(other) <= 0;

  bool operator >(PriorityRank other) => compareTo(other) > 0;

  bool operator >=(PriorityRank other) => compareTo(other) >= 0;

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

  /// [percent] as a fraction in `[0, 1]`.
  double get fraction => percent / 100;

  /// How far down the collection this rank sits: `0` at the top, `1` at the
  /// bottom.
  ///
  /// The schedulers speak in pressure rather than percent because every
  /// formula that uses it — first interval, A-factor modulation,
  /// auto-postpone delay — grows with distance from the top. The two design
  /// documents describe this quantity with opposite words in one place and
  /// the same worked numbers everywhere else; the numbers win, so top of
  /// collection is zero pressure.
  double get pressure => fraction;

  /// The complement of [pressure]: `1` at the top, `0` at the bottom. This is
  /// the queue's `p_norm` sort term.
  double get normalized => 1 - fraction;

  /// SuperMemo's one-based position display.
  int get displayPosition => index + 1;

  @override
  bool operator ==(Object other) =>
      other is PriorityPosition && other.index == index && other.total == total;

  @override
  int get hashCode => Object.hash(index, total);

  @override
  String toString() => '${percent.toStringAsFixed(0)}%';
}

/// The collection's priority order, as a snapshot.
///
/// Percentiles are derived, never stored: an absolute 0–100 score inflates
/// (every new import feels like an 80) until the field carries no information
/// and the overload valve has nothing left to discriminate on. A relative
/// order enforces scarcity structurally — promoting one element necessarily
/// demotes another — which is exactly the property the priority queue needs.
@immutable
final class PriorityScale {
  /// Builds a scale from [keys], which must already be sorted ascending.
  const PriorityScale.sorted(List<PriorityRank> keys) : _keys = keys;

  /// Builds a scale from unsorted [keys].
  factory PriorityScale(Iterable<PriorityRank> keys) {
    final sorted = keys.toList()..sort();
    return PriorityScale.sorted(sorted);
  }

  /// An empty collection.
  static const PriorityScale empty = PriorityScale.sorted(<PriorityRank>[]);

  final List<PriorityRank> _keys;

  /// How many ranked elements the scale covers.
  int get total => _keys.length;

  /// Whether the collection has no ranked elements.
  bool get isEmpty => _keys.isEmpty;

  /// Where [rank] sits, or null when the scale is empty.
  ///
  /// A rank that is not itself in the scale still resolves: it is placed at
  /// the position it *would* occupy, so a freshly created element can be
  /// scheduled before its row has been written.
  PriorityPosition? positionOf(PriorityRank rank) {
    if (_keys.isEmpty) return null;
    return PriorityPosition(index: _lowerBound(rank), total: _keys.length);
  }

  /// The rank at [index] in the current order, or null when out of range.
  PriorityRank? at(int index) =>
      index < 0 || index >= _keys.length ? null : _keys[index];

  /// [PriorityPosition.pressure] for [rank], or the midpoint for an empty
  /// collection — the only honest answer when nothing has been ranked yet.
  double pressureOf(PriorityRank rank) => positionOf(rank)?.pressure ?? 0.5;

  /// SM20 rank-derived percentage for [rank].
  double percentageOf(PriorityRank rank) => positionOf(rank)?.percent ?? 100;

  /// SM20 one-based position for a percentage in the current population.
  int positionForPercentage(double percent) {
    if (_keys.isEmpty) return 1;
    final double value = percent.isFinite ? percent.clamp(0, 100) : 100;
    return sm20RoundEven((value / 100) * (_keys.length - 1)) + 1;
  }

  /// SM20 percentage for a one-based position in the current population.
  double percentageForPosition(int position) {
    if (_keys.length <= 1 || position < 2) return 0;
    final int pos = position.clamp(1, _keys.length);
    return 100 * (pos - 1) / (_keys.length - 1);
  }

  /// The same order with [rank] inserted.
  ///
  /// Used when creating an element: its priority pressure is a question about
  /// where it will sit once it exists, and asking the order it is not yet part
  /// of would place every new element at the edge of the collection.
  PriorityScale including(PriorityRank rank) {
    final List<PriorityRank> keys = <PriorityRank>[..._keys];
    final int index = _lowerBound(rank);
    keys.insert(index, rank);
    return PriorityScale.sorted(keys);
  }

  /// Returns the order after replacing one exact rank and re-sorting it.
  PriorityScale replacing(PriorityRank before, PriorityRank after) {
    final List<PriorityRank> keys = <PriorityRank>[..._keys];
    final int index = keys.indexOf(before);
    if (index >= 0) keys.removeAt(index);
    keys.add(after);
    keys.sort();
    return PriorityScale.sorted(List<PriorityRank>.unmodifiable(keys));
  }

  /// The rank [places] positions above or below [rank].
  ///
  /// The neighbours are read excluding [rank] itself, which is what "move past
  /// your neighbour" means — computing a target percent against an order that
  /// still contains the element would land it back where it started.
  PriorityRank stepped(
    PriorityRank rank, {
    required bool increase,
    int places = 1,
  }) {
    final PriorityPosition? position = positionOf(rank);
    if (position == null || _keys.length < 2) return rank;
    final int steps = places < 1 ? 1 : places;
    final int target = increase
        ? position.index - steps
        : position.index + steps;

    if (target <= 0) return PriorityRank.between(null, _keys.first);
    if (target >= _keys.length - 1) {
      return PriorityRank.between(_keys.last, null);
    }
    return increase
        ? PriorityRank.between(at(target - 1), at(target))
        : PriorityRank.between(at(target), at(target + 1));
  }

  /// A rank that lands at [percent], where `0` is the most important.
  ///
  /// The new key is generated strictly between the two elements currently
  /// straddling that percent, so setting a priority rewrites one row rather
  /// than renumbering the collection.
  PriorityRank rankAtPercent(double percent) {
    final double clamped = percent.isNaN ? 50 : percent.clamp(0, 100);
    if (_keys.isEmpty) return PriorityRank.middle;
    final int insertionPosition = clamped == 100
        ? _keys.length + 1
        : sm20RoundEven((clamped / 100) * _keys.length) + 1;
    final int index = (insertionPosition - 1).clamp(0, _keys.length);
    final PriorityRank? before = index == 0 ? null : _keys[index - 1];
    final PriorityRank? after = index == _keys.length ? null : _keys[index];
    return PriorityRank.between(before, after);
  }

  /// Exact Set Priority insertion after removing [current] first.
  PriorityRank rankForSetPriority(PriorityRank current, double percent) {
    final double target = percent.isFinite ? percent.clamp(0, 100) : 100;
    final List<PriorityRank> remaining = <PriorityRank>[..._keys];
    final int currentIndex = remaining.indexOf(current);
    if (currentIndex >= 0) remaining.removeAt(currentIndex);
    final int count = remaining.length;
    final int insertionPosition = target == 100
        ? count + 1
        : sm20RoundEven((target / 100) * count) + 1;
    final int index = (insertionPosition - 1).clamp(0, count);
    return PriorityRank.between(
      index == 0 ? null : remaining[index - 1],
      index == count ? null : remaining[index],
    );
  }

  /// Executable-derived interval relationship drift, including its forced
  /// one-rank movement when percentage quantization hides the calculated move.
  PriorityRank adjustedForInterval(
    PriorityRank current, {
    required int oldInterval,
    required int newInterval,
    required bool bulk,
  }) {
    if (_keys.isEmpty) return current;
    final int old = oldInterval < 1 ? 1 : oldInterval;
    final int next = newInterval;
    if (old == next) return current;

    var correction = 80 * (1 - mathMin(old, next) / mathMax(old, next));
    if (bulk) correction /= 3;
    final double scale = (100 - correction) / 100;
    final double currentPercent = percentageOf(current);
    double target = next < old
        ? currentPercent * scale
        : currentPercent / scale;
    final int oldPosition = positionOf(current)?.displayPosition ?? 1;
    var targetPosition = positionForPercentage(target);
    if (targetPosition == oldPosition) {
      targetPosition += next < old ? -1 : 1;
      targetPosition = targetPosition.clamp(1, _keys.length);
      target = percentageForPosition(targetPosition);
    }
    return rankForSetPriority(current, target);
  }

  /// The rank immediately more important than [rank], for the Alt+P dialog's
  /// "before" field.
  PriorityRank? neighbourAbove(PriorityRank rank) {
    final int index = _lowerBound(rank);
    return index == 0 ? null : _keys[index - 1];
  }

  /// The rank immediately less important than [rank].
  PriorityRank? neighbourBelow(PriorityRank rank) {
    final int index = _lowerBound(rank);
    for (var i = index; i < _keys.length; i++) {
      if (_keys[i] > rank) return _keys[i];
    }
    return null;
  }

  /// Whether [rank] sits inside the top [fraction] the overload valve must
  /// never touch.
  ///
  /// Without this floor, auto-postpone eventually pushes everything out and
  /// the collection schedules nothing — the postpone death spiral. Protected
  /// elements stay due and force a decision: do it, or demote it by hand.
  bool isProtected(PriorityRank rank, double fraction) {
    if (_keys.isEmpty || fraction <= 0) return false;
    final PriorityPosition? position = positionOf(rank);
    if (position == null) return false;
    return position.index < (_keys.length * fraction).ceil();
  }

  int _lowerBound(PriorityRank rank) {
    var low = 0;
    var high = _keys.length;
    while (low < high) {
      final int mid = (low + high) >> 1;
      if (_keys[mid] < rank) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }
}

double mathMin(num a, num b) => a < b ? a.toDouble() : b.toDouble();

double mathMax(num a, num b) => a > b ? a.toDouble() : b.toDouble();

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
