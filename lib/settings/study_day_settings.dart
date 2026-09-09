/// The rollover rule plus the compatibility label of stored study days.
library;

import 'package:meta/meta.dart';

/// Which study day an instant belongs to.
@immutable
final class StudyDaySettings {
  const StudyDaySettings({this.zoneId = 'UTC', this.rolloverMinutes = 240});

  /// Legacy identifier retained so existing schedules keep one day identity.
  ///
  /// The running app takes actual offsets from the operating system, not from
  /// this field. Removing its persisted key would strand existing StudyDays.
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
