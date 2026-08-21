/// Resolves the configured home timezone into offset rules the domain reads.
///
/// The domain never asks the system what time it is or where it is; it asks an
/// injected `TimeZoneRules` for the offset at an instant. This file is the one
/// place that answer comes from, which is what makes DST transitions testable
/// with a fake zone instead of a real clock.
///
/// v1 supports three kinds of zone:
///
/// * `system` — the machine's own zone, with correct DST because Dart's
///   `toLocal()` reads the operating system's timezone database.
/// * `UTC` — no offset, the deterministic default.
/// * `UTC+HH:MM` / `UTC-HH:MM` — a fixed offset, for a user who studies in a
///   zone other than the machine's.
///
/// Choosing an arbitrary IANA zone that differs from the machine's *and*
/// follows its DST rules needs a bundled timezone database, which v1 does not
/// carry; naming an unknown zone therefore falls back to the system zone
/// rather than silently pretending an offset.
library;

import 'package:meta/meta.dart';

import '../../domain/scheduling/study_day.dart';

/// Zone identifier meaning "whatever this machine is set to".
const String kSystemZoneId = 'system';

/// The machine's own zone, DST included.
///
/// [DateTime.toLocal] consults the operating system's timezone database, so
/// the offset returned here changes across a DST boundary exactly as the
/// user's wall clock does.
@immutable
final class SystemLocalZone implements TimeZoneRules {
  const SystemLocalZone();

  @override
  String get zoneId => kSystemZoneId;

  @override
  int offsetMinutesAt(DateTime instantUtc) =>
      instantUtc.toUtc().toLocal().timeZoneOffset.inMinutes;
}

/// Builds the zone rules named by [zoneId].
///
/// Unknown identifiers resolve to the system zone: a collection whose zone
/// setting was written by a build that knew more zones than this one must
/// still open, and the machine's own zone is the least surprising answer.
TimeZoneRules resolveTimeZone(String zoneId) {
  final String id = zoneId.trim();
  if (id.isEmpty || id == kSystemZoneId) return const SystemLocalZone();
  if (id.toUpperCase() == 'UTC') return FixedOffsetZone.utc;

  final RegExpMatch? match = _fixedOffset.firstMatch(id.toUpperCase());
  if (match != null) {
    final int hours = int.parse(match.group(2)!);
    final int minutes = int.parse(match.group(3) ?? '0');
    final int magnitude = hours * 60 + minutes;
    return FixedOffsetZone(
      zoneId: id,
      offsetMinutes: match.group(1) == '-' ? -magnitude : magnitude,
    );
  }
  return const SystemLocalZone();
}

/// Zone identifiers the Settings screen offers.
///
/// Fixed offsets rather than city names, because without a bundled database a
/// city name would be a promise about DST that cannot be kept.
List<String> get selectableZoneIds => <String>[
  kSystemZoneId,
  'UTC',
  for (var hour = -12; hour <= 14; hour++)
    'UTC${hour < 0 ? '-' : '+'}${hour.abs().toString().padLeft(2, '0')}:00',
];

final RegExp _fixedOffset = RegExp(r'^UTC([+-])(\d{1,2})(?::(\d{2}))?$');
