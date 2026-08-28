/// Which study day an instant belongs to: home timezone and rollover hour.
library;

import 'package:meta/meta.dart';

/// Which study day an instant belongs to.
@immutable
final class StudyDaySettings {
  const StudyDaySettings({this.zoneId = 'UTC', this.rolloverMinutes = 240});

  /// IANA identifier of the user's home timezone.
  final String zoneId;

  /// Minutes after local midnight at which the study day rolls over.
  final int rolloverMinutes;

  StudyDaySettings copyWith({String? zoneId, int? rolloverMinutes}) =>
      StudyDaySettings(
        zoneId: zoneId ?? this.zoneId,
        rolloverMinutes: rolloverMinutes ?? this.rolloverMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is StudyDaySettings &&
      other.zoneId == zoneId &&
      other.rolloverMinutes == rolloverMinutes;

  @override
  int get hashCode => Object.hash(zoneId, rolloverMinutes);
}
