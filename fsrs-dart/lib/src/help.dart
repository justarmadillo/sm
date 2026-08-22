/// Date arithmetic, clamping, rounding, and the fuzz range — the small shared
/// helpers the scheduler and the algorithm both depend on.
library;

import 'convert.dart';
import 'error.dart';
import 'js_compat.dart';

/// The unit a date difference is measured in.
enum DateDiffUnit {
  /// Whole days.
  days,

  /// Whole minutes.
  minutes,
}

/// Offsets [now] by [t] days (when [isDay]) or minutes.
DateTime dateScheduler(Object now, num t, {bool isDay = false}) {
  final base = TypeConvert.time(now).millisecondsSinceEpoch;
  final offset = isDay ? t * 24 * 60 * 60 * 1000 : t * 60 * 1000;
  // `new Date(x)` applies ToInteger, i.e. truncation toward zero.
  final ms = (base + offset).toDouble().truncate();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}

/// Whole [unit]s between [pre] and [now], floored (so it can be negative).
int dateDiff(Object? now, Object? pre, DateDiffUnit unit) {
  if (now == null || pre == null) {
    throw FSRSValidationError('Invalid date');
  }
  final diff = TypeConvert.time(now).millisecondsSinceEpoch -
      TypeConvert.time(pre).millisecondsSinceEpoch;
  switch (unit) {
    case DateDiffUnit.days:
      return (diff / (24 * 60 * 60 * 1000)).floor();
    case DateDiffUnit.minutes:
      return (diff / (60 * 1000)).floor();
  }
}

/// Formats a date as `YYYY-MM-DD HH:mm:ss` in local time, like ts-fsrs.
String formatDate(Object dateInput) {
  final date = TypeConvert.time(dateInput).toLocal();
  return '${date.year}-${_padZero(date.month)}-${_padZero(date.day)} '
      '${_padZero(date.hour)}:${_padZero(date.minute)}:'
      '${_padZero(date.second)}';
}

String _padZero(int num) => num < 10 ? '0$num' : '$num';

const List<int> _timeUnit = <int>[60, 60, 24, 31, 12];
const List<String> _timeUnitFormat = <String>[
  'second',
  'min',
  'hour',
  'day',
  'month',
  'year',
];

/// Renders the gap between [lastReview] and [due] in the largest unit that
/// fits, optionally suffixed with the unit name.
String showDiffMessage(
  Object due,
  Object lastReview, {
  bool unit = false,
  List<String> timeUnit = _timeUnitFormat,
}) {
  final dueDate = TypeConvert.time(due);
  final lastReviewDate = TypeConvert.time(lastReview);
  var names = timeUnit;
  if (names.length != _timeUnitFormat.length) {
    names = _timeUnitFormat;
  }
  var diff =
      (dueDate.millisecondsSinceEpoch - lastReviewDate.millisecondsSinceEpoch)
          .toDouble();
  diff /= 1000;
  var i = 0;
  for (i = 0; i < _timeUnit.length; i++) {
    if (diff < _timeUnit[i]) {
      break;
    } else {
      diff /= _timeUnit[i];
    }
  }
  return '${diff.floor()}${unit ? names[i] : ''}';
}

class _FuzzRange {
  const _FuzzRange(this.start, this.end, this.factor);

  final double start;
  final double end;
  final double factor;
}

const List<_FuzzRange> _fuzzRanges = <_FuzzRange>[
  _FuzzRange(2.5, 7.0, 0.15),
  _FuzzRange(7.0, 20.0, 0.1),
  _FuzzRange(20.0, double.infinity, 0.05),
];

/// The inclusive `[min, max]` day range fuzz may pick from.
class FuzzRange {
  /// Creates a fuzz range.
  const FuzzRange(this.minIvl, this.maxIvl);

  /// Smallest permitted interval.
  final int minIvl;

  /// Largest permitted interval.
  final int maxIvl;

  @override
  String toString() => 'FuzzRange(minIvl: $minIvl, maxIvl: $maxIvl)';
}

/// Computes the fuzz window around [interval].
///
/// The window never dips to or below [elapsedDays] when the new interval is
/// longer than the elapsed time, so fuzz can never schedule a card earlier than
/// the review that just happened.
FuzzRange getFuzzRange(
  double interval,
  num elapsedDays,
  num maximumInterval,
) {
  var delta = 1.0;
  for (final range in _fuzzRanges) {
    final capped = interval < range.end ? interval : range.end;
    final contribution = capped - range.start;
    delta += range.factor * (contribution > 0.0 ? contribution : 0.0);
  }
  final ivl =
      interval < maximumInterval ? interval : maximumInterval.toDouble();
  var minIvl = _max(2, jsRound(ivl - delta));
  final maxIvl = _min(jsRound(ivl + delta), maximumInterval.toInt());
  if (ivl > elapsedDays) {
    minIvl = _max(minIvl, elapsedDays.toInt() + 1);
  }
  minIvl = _min(minIvl, maxIvl);
  return FuzzRange(minIvl, maxIvl);
}

int _max(int a, int b) => a > b ? a : b;

int _min(int a, int b) => a < b ? a : b;

/// Clamps [value] into `[min, max]`.
double clamp(double value, double min, double max) {
  final lower = value > min ? value : min;
  return lower < max ? lower : max;
}

/// Rounds [num] to [decimals] places using JavaScript's half-up rounding.
double roundTo(double num, int decimals) {
  final factor = _pow10(decimals);
  return jsRoundDouble(num * factor) / factor;
}

double _pow10(int decimals) {
  var factor = 1.0;
  for (var i = 0; i < decimals; i++) {
    factor *= 10;
  }
  return factor;
}

/// Whole days between the UTC calendar dates of [last] and [cur].
///
/// Deliberately date-based rather than duration-based: two reviews 23 hours
/// apart across midnight are one day apart to FSRS.
int dateDiffInDays(DateTime last, DateTime cur) {
  final lastUtc = last.toUtc();
  final curUtc = cur.toUtc();
  final utc1 = DateTime.utc(lastUtc.year, lastUtc.month, lastUtc.day)
      .millisecondsSinceEpoch;
  final utc2 =
      DateTime.utc(curUtc.year, curUtc.month, curUtc.day).millisecondsSinceEpoch;
  return ((utc2 - utc1) / 86400000).floor();
}
