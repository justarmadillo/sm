/// Time access. Domain and application code never calls [DateTime.now].
library;

import 'package:meta/meta.dart';

/// Supplies the current instant, always in UTC.
abstract interface class Clock {
  /// The current instant in UTC.
  DateTime nowUtc();
}

/// Production clock backed by the system time.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Deterministic clock for tests. Time only moves when told to.
@visibleForTesting
final class FakeClock implements Clock {
  FakeClock(DateTime initial) : _now = initial.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Moves the clock forward by [duration].
  void advance(Duration duration) => _now = _now.add(duration);

  /// Moves the clock to an absolute instant.
  void setTo(DateTime instant) => _now = instant.toUtc();
}
