/// Stable JSON codec for adjustment event and Mercy snapshots.
library;

import 'dart:convert';

import 'element.dart';
import 'schedule_adjustment.dart';
import 'study_day.dart';

String encodeAdjustmentSnapshot(ScheduleAdjustmentSnapshot snapshot) =>
    jsonEncode(<String, Object?>{
      'elements': <Map<String, Object?>>[
        for (final element in snapshot.elements)
          <String, Object?>{'id': element.id, 'type': element.type.index},
      ],
      'active': <Map<String, Object?>>[
        for (final adjustment in snapshot.activeAdjustments)
          scheduleAdjustmentToJsonMap(adjustment),
      ],
    });

ScheduleAdjustmentSnapshot decodeAdjustmentSnapshot(String source) {
  final map = jsonDecode(source) as Map<String, Object?>;
  final elements = (map['elements']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map(
        (Map<String, Object?> value) => ElementRef(
          id: value['id']! as String,
          type: ElementType.values[value['type']! as int],
        ),
      );
  final active = (map['active']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .map(scheduleAdjustmentFromJsonMap);
  return ScheduleAdjustmentSnapshot(
    elements: elements,
    activeAdjustments: active,
  );
}

Map<String, Object?> scheduleAdjustmentToJsonMap(
  ScheduleAdjustment adjustment,
) => <String, Object?>{
  'id': adjustment.id,
  'element_id': adjustment.element.id,
  'element_type': adjustment.element.type.index,
  'mode': adjustment.mode.wireName,
  'reason': adjustment.reason.wireName,
  'not_before_at_utc': adjustment.notBeforeAtUtc?.millisecondsSinceEpoch,
  'not_before_study_day': adjustment.notBeforeStudyDay?.epochDay,
  'scheduled_for_at_utc': adjustment.scheduledForAtUtc?.millisecondsSinceEpoch,
  'scheduled_for_study_day': adjustment.scheduledForStudyDay?.epochDay,
  'zone_id':
      adjustment.notBeforeStudyDay?.zoneId ??
      adjustment.scheduledForStudyDay?.zoneId,
  'operation_id': adjustment.operationId,
  'batch_id': adjustment.batchId,
  'policy_version': adjustment.policyVersion,
  'created_at_utc': adjustment.createdAtUtc.millisecondsSinceEpoch,
  'created_study_day': adjustment.createdStudyDay.epochDay,
  'created_zone_id': adjustment.createdStudyDay.zoneId,
  'cleared_at_utc': adjustment.clearedAtUtc?.millisecondsSinceEpoch,
  'cleared_by_operation_id': adjustment.clearedByOperationId,
};

ScheduleAdjustment scheduleAdjustmentFromJsonMap(Map<String, Object?> map) {
  final ElementRef element = ElementRef(
    id: map['element_id']! as String,
    type: ElementType.values[map['element_type']! as int],
  );
  final String createdZone = map['created_zone_id']! as String;
  final String? destinationZone = map['zone_id'] as String?;
  DateTime? instant(String key) {
    final Object? stored = map[key];
    return stored is int
        ? DateTime.fromMillisecondsSinceEpoch(stored, isUtc: true)
        : null;
  }

  StudyDay? day(String key, String? zone) {
    final Object? stored = map[key];
    return stored is int ? _dayFromEpoch(stored, zone ?? createdZone) : null;
  }

  return ScheduleAdjustment(
    id: map['id']! as String,
    element: element,
    mode: ScheduleAdjustmentMode.values.firstWhere(
      (ScheduleAdjustmentMode value) => value.wireName == map['mode'],
    ),
    reason: ScheduleAdjustmentReason.values.firstWhere(
      (ScheduleAdjustmentReason value) => value.wireName == map['reason'],
    ),
    notBeforeAtUtc: instant('not_before_at_utc'),
    notBeforeStudyDay: day('not_before_study_day', destinationZone),
    scheduledForAtUtc: instant('scheduled_for_at_utc'),
    scheduledForStudyDay: day('scheduled_for_study_day', destinationZone),
    operationId: map['operation_id']! as String,
    batchId: map['batch_id'] as String?,
    policyVersion: map['policy_version']! as String,
    createdAtUtc: instant('created_at_utc')!,
    createdStudyDay: _dayFromEpoch(
      map['created_study_day']! as int,
      createdZone,
    ),
    clearedAtUtc: instant('cleared_at_utc'),
    clearedByOperationId: map['cleared_by_operation_id'] as String?,
  );
}

StudyDay _dayFromEpoch(int epochDay, String zoneId) {
  final DateTime date = DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return StudyDay(
    year: date.year,
    month: date.month,
    day: date.day,
    zoneId: zoneId,
  );
}
