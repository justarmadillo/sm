/// The study day: the unit scheduling is expressed in.
///
/// A study day is a local calendar date whose boundary is a configurable
/// rollover (04:00 by default), not midnight — a session that runs past
/// midnight is still the same study day. The domain never reads the system
/// zone; it asks an injected [TimeZoneRules] for the offset at an instant, so
/// DST transitions are testable without a real timezone database.
library;

import 'package:meta/meta.dart';

/// Offset rules for the user's configured home timezone.
abstract interface class TimeZoneRules {
  /// IANA identifier, for example `Europe/Berlin`.
  String get zoneId;

  /// Offset from UTC in minutes that applies at [instantUtc].
  int offsetMinutesAt(DateTime instantUtc);
}

/// A configured rollover landed in a repeated or nonexistent local wall time.
///
/// The default 04:00 boundary is unique in normal civil-time transitions. If
/// a user configures a boundary inside a DST fold or gap, silently selecting
/// either possible instant would make scheduling policy implicit, so the time
/// service fails explicitly.
final class StudyDayBoundaryException implements Exception {
  const StudyDayBoundaryException({
    required this.zoneId,
    required this.localBoundary,
    required this.kind,
  });

  final String zoneId;
  final DateTime localBoundary;
  final String kind;

  @override
  String toString() =>
      '$kind StudyDay boundary $localBoundary in home timezone $zoneId';
}

/// A zone with one fixed offset. Useful for UTC and for deterministic tests.
@immutable
final class FixedOffsetZone implements TimeZoneRules {
  const FixedOffsetZone({required this.zoneId, required this.offsetMinutes});

  /// UTC.
  static const FixedOffsetZone utc = FixedOffsetZone(
    zoneId: 'UTC',
    offsetMinutes: 0,
  );

  @override
  final String zoneId;

  /// Constant offset from UTC in minutes.
  final int offsetMinutes;

  @override
  int offsetMinutesAt(DateTime instantUtc) => offsetMinutes;
}

/// One local calendar date in one zone.
@immutable
final class StudyDay implements Comparable<StudyDay> {
  const StudyDay({
    required this.year,
    required this.month,
    required this.day,
    required this.zoneId,
  });

  /// Parses the `YYYY-MM-DD` form produced by [toString].
  factory StudyDay.parse(String value, {required String zoneId}) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('not a study day', value);
    }
    return StudyDay(
      year: int.parse(parts[0]),
      month: int.parse(parts[1]),
      day: int.parse(parts[2]),
      zoneId: zoneId,
    );
  }

  final int year;
  final int month;
  final int day;

  /// Zone the date is expressed in. Comparing across zones is meaningless.
  final String zoneId;

  /// Days since the Unix epoch, used for ordering and arithmetic.
  int get epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/ 86400000;

  /// This day shifted by [days].
  StudyDay addDays(int days) {
    final shifted = DateTime.utc(year, month, day).add(Duration(days: days));
    return StudyDay(
      year: shifted.year,
      month: shifted.month,
      day: shifted.day,
      zoneId: zoneId,
    );
  }

  /// Number of days from this day to [other]; negative when [other] is before.
  int daysUntil(StudyDay other) => other.epochDay - epochDay;

  @override
  int compareTo(StudyDay other) => epochDay.compareTo(other.epochDay);

  bool operator <(StudyDay other) => epochDay < other.epochDay;

  bool operator <=(StudyDay other) => epochDay <= other.epochDay;

  bool operator >(StudyDay other) => epochDay > other.epochDay;

  bool operator >=(StudyDay other) => epochDay >= other.epochDay;

  @override
  bool operator ==(Object other) =>
      other is StudyDay &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.zoneId == zoneId;

  @override
  int get hashCode => Object.hash(year, month, day, zoneId);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Maps instants to study days for one zone and rollover.
@immutable
final class StudyDayCalendar {
  const StudyDayCalendar({
    required this.zone,
    this.rollover = const Duration(hours: 4),
  });

  /// Zone the user studies in.
  final TimeZoneRules zone;

  /// Time of day at which a new study day begins.
  final Duration rollover;

  /// Study day that [instantUtc] falls in.
  StudyDay dayOf(DateTime instantUtc) {
    _validateRollover();
    final utc = instantUtc.toUtc();
    final local = utc.add(Duration(minutes: zone.offsetMinutesAt(utc)));
    final shifted = local.subtract(rollover);
    return StudyDay(
      year: shifted.year,
      month: shifted.month,
      day: shifted.day,
      zoneId: zone.zoneId,
    );
  }

  /// Instant at which [day] begins.
  ///
  /// Resolved against the offset in effect around the boundary, so a DST
  /// change on the boundary day does not shift the day by an hour.
  DateTime startOfDayUtc(StudyDay day) {
    _validateRollover();
    if (day.zoneId != zone.zoneId) {
      throw ArgumentError.value(
        day.zoneId,
        'day.zoneId',
        'StudyDay belongs to ${day.zoneId}, not ${zone.zoneId}',
      );
    }
    final naiveLocal = DateTime.utc(day.year, day.month, day.day).add(rollover);

    if (zone case final FixedOffsetZone fixed) {
      return naiveLocal.subtract(Duration(minutes: fixed.offsetMinutes));
    }

    // A local timestamp is not itself an instant. Discover every offset near
    // the date, project the local boundary through each one, and retain only
    // candidates whose actual offset maps exactly back to that wall time.
    // Sampling three days either side also covers unusual political jumps,
    // while the candidate validation prevents a neighboring offset from being
    // accepted accidentally.
    final Set<int> nearbyOffsets = <int>{};
    for (final int hours in _offsetProbeHours) {
      nearbyOffsets.add(
        zone.offsetMinutesAt(naiveLocal.add(Duration(hours: hours))),
      );
    }

    final Set<DateTime> candidates = <DateTime>{};
    for (final int offset in nearbyOffsets) {
      final DateTime candidate = naiveLocal.subtract(Duration(minutes: offset));
      final DateTime projected = candidate.add(
        Duration(minutes: zone.offsetMinutesAt(candidate)),
      );
      if (projected == naiveLocal) candidates.add(candidate);
    }

    if (candidates.length == 1) return candidates.single;
    throw StudyDayBoundaryException(
      zoneId: zone.zoneId,
      localBoundary: naiveLocal,
      kind: candidates.isEmpty ? 'Nonexistent' : 'Ambiguous',
    );
  }

  /// Instant at which [day] ends, exclusive.
  DateTime endOfDayUtc(StudyDay day) => startOfDayUtc(day.addDays(1));

  /// Whether [instantUtc] falls inside [day].
  bool contains(StudyDay day, DateTime instantUtc) {
    final utc = instantUtc.toUtc();
    return !utc.isBefore(startOfDayUtc(day)) && utc.isBefore(endOfDayUtc(day));
  }

  void _validateRollover() {
    if (rollover.isNegative || rollover >= const Duration(days: 1)) {
      throw ArgumentError.value(
        rollover,
        'rollover',
        'must be within one local calendar day',
      );
    }
  }
}

const List<int> _offsetProbeHours = <int>[
  -72,
  -66,
  -60,
  -54,
  -48,
  -42,
  -36,
  -30,
  -24,
  -18,
  -12,
  -6,
  0,
  6,
  12,
  18,
  24,
  30,
  36,
  42,
  48,
  54,
  60,
  66,
  72,
];
