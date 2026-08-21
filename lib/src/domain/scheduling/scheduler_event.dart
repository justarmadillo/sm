/// Append-only scheduler audit events.
///
/// These events are deliberately richer than the legacy repetition log. They
/// retain the calendar coordinate used when an operation occurred, canonical
/// before/after state, algorithmic due values, and the complete presentation
/// adjustment snapshots needed for exact undo.
library;

import 'package:meta/meta.dart';

import 'element.dart';
import 'study_day.dart';

/// Stable wire names persisted in the scheduler event stream.
enum SchedulerEventType {
  cardReviewed('card_reviewed'),
  cardReviewUndone('card_review_undone'),
  practiceReviewed('practice_reviewed'),
  topicEncountered('topic_encountered'),
  topicEncounterUndone('topic_encounter_undone'),
  priorityChanged('priority_changed'),
  manualLaterSet('manual_later_set'),
  manualLaterCleared('manual_later_cleared'),
  autoOverflowSet('auto_overflow_set'),
  autoOverflowCleared('auto_overflow_cleared'),
  siblingBuried('sibling_buried'),
  siblingBuryCleared('sibling_bury_cleared'),
  mercyPreviewed('mercy_previewed'),
  mercyApplied('mercy_applied'),
  mercyUndone('mercy_undone'),
  manualRescheduleSet('manual_reschedule_set'),
  manualRescheduleCleared('manual_reschedule_cleared'),
  suspended('suspended'),
  resumed('resumed'),
  dismissed('dismissed'),
  restored('restored'),
  finished('finished');

  const SchedulerEventType(this.wireName);

  final String wireName;

  static SchedulerEventType parse(String value) => values.firstWhere(
    (SchedulerEventType type) => type.wireName == value,
    orElse: () => throw FormatException('unknown scheduler event type', value),
  );
}

/// One immutable event in the authoritative scheduler history.
@immutable
final class SchedulerEvent {
  SchedulerEvent({
    required this.id,
    required this.operationId,
    required this.eventType,
    required this.occurredAtUtc,
    required this.studyDay,
    required this.policyVersion,
    this.element,
    this.schedulerName,
    this.schedulerVersion,
    this.stateBefore,
    this.stateAfter,
    this.algorithmicDueBefore,
    this.algorithmicDueAfter,
    this.adjustmentsBefore,
    this.adjustmentsAfter,
    this.undoesEventId,
    this.batchId,
    this.metadata,
  }) {
    if (id.trim().isEmpty || operationId.trim().isEmpty) {
      throw ArgumentError('event and operation ids must not be empty');
    }
    if (!occurredAtUtc.isUtc) {
      throw ArgumentError.value(occurredAtUtc, 'occurredAtUtc', 'must be UTC');
    }
    if (policyVersion.trim().isEmpty) {
      throw ArgumentError.value(
        policyVersion,
        'policyVersion',
        'must not be empty',
      );
    }
    if (element == null &&
        eventType != SchedulerEventType.mercyPreviewed &&
        eventType != SchedulerEventType.mercyApplied &&
        eventType != SchedulerEventType.mercyUndone) {
      throw ArgumentError(
        'only Mercy batch events may omit an element coordinate',
      );
    }
    if (eventType == SchedulerEventType.cardReviewUndone ||
        eventType == SchedulerEventType.topicEncounterUndone) {
      if (undoesEventId == null || undoesEventId!.trim().isEmpty) {
        throw ArgumentError('undo events must reference the original event');
      }
    }
  }

  final String id;
  final String operationId;
  final ElementRef? element;
  final SchedulerEventType eventType;
  final DateTime occurredAtUtc;

  /// Stored rather than recomputed, so changing home zone never rebuckets
  /// historical work.
  final StudyDay studyDay;
  final String? schedulerName;
  final String? schedulerVersion;
  final String policyVersion;

  /// Canonical serialized scheduler state, not presentation state.
  final String? stateBefore;
  final String? stateAfter;

  /// Domain-tagged due encodings (`utc:<millis>` or `day:<zone>:<epoch>`).
  final String? algorithmicDueBefore;
  final String? algorithmicDueAfter;

  /// Deterministically serialized active adjustment sets.
  final String? adjustmentsBefore;
  final String? adjustmentsAfter;
  final String? undoesEventId;
  final String? batchId;
  final Map<String, Object?>? metadata;

  bool get isGenuineCardReview => eventType == SchedulerEventType.cardReviewed;

  static String encodeUtcDue(DateTime value) {
    if (!value.isUtc) {
      throw ArgumentError.value(value, 'value', 'must be UTC');
    }
    return 'utc:${value.millisecondsSinceEpoch}';
  }

  static String encodeStudyDayDue(StudyDay value) =>
      'day:${value.zoneId}:${value.epochDay}';
}
