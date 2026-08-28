/// Writes the repetition log.
///
/// Every command runner that changes a schedule appends here, inside the same
/// transaction as the change. Centralizing it is not tidiness: it is the only
/// way to guarantee that the snapshots are taken the same way everywhere, so
/// that "what happened to this element" is answerable months later without
/// having to know which command wrote which row.
///
/// The one rule this file enforces on behalf of its callers: a grade is
/// attached only to a review or a practice event. Anything else — a
/// postponement, a lifecycle change, a priority edit — is logged without one,
/// because it was never a retention test and must never reach an optimizer's
/// training set.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';

/// Builds and appends [ReviewLogEntry] rows.
final class SchedulingJournal {
  const SchedulingJournal({
    required LearningRepository learning,
    required IdGenerator ids,
  }) : _learning = learning,
       _ids = ids;

  final LearningRepository _learning;
  final IdGenerator _ids;

  /// Snapshot of a topic as it stands now.
  ReviewLogSnapshot topicSnapshot(
    TopicState state, {
    required StudyDayCalendar calendar,
    double? pressure,
    double? readFraction,
  }) => ReviewLogSnapshot(
    dueAtUtc: calendar.startOfDayUtc(state.schedule.algorithmicDueDay),
    intervalDays: state.intervalDays,
    aFactor: state.aFactor,
    priorityKey: state.schedule.priority.orderKey,
    pressure: pressure,
    readFraction: readFraction,
    lifecycle: state.schedule.lifecycle.index,
  );

  /// Snapshot of a card as it stands now.
  ReviewLogSnapshot cardSnapshot(CardState state, {double? pressure}) =>
      ReviewLogSnapshot(
        dueAtUtc: state.memory.dueAtUtc,
        stability: state.memory.stability,
        difficulty: state.memory.difficulty,
        learningState: state.memory.state.value,
        repetitionCount: state.memory.repetitionCount,
        lapses: state.memory.lapses,
        priorityKey: state.schedule.priority.orderKey,
        pressure: pressure,
        lifecycle: state.schedule.lifecycle.index,
      );

  /// Appends one entry.
  Future<ReviewLogEntry> append({
    required String operationId,
    required ElementRef ref,
    required ReviewLogEventType eventType,
    required DateTime atUtc,
    ReviewLogSnapshot before = ReviewLogSnapshot.none,
    ReviewLogSnapshot after = ReviewLogSnapshot.none,
    int? grade,
    double? elapsedDays,
    double? scheduledDays,
    int? durationMs,
    int? postponeCount,
    String? schedulerVersion,
    String? parametersVersion,
    Map<String, Object?>? metadata,
  }) async {
    final ReviewLogEntry entry = ReviewLogEntry(
      id: _ids.newId(),
      operationId: operationId,
      ref: ref,
      eventType: eventType,
      atUtc: atUtc,
      before: before,
      after: after,
      grade: grade,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      durationMs: durationMs,
      postponeCount: postponeCount,
      schedulerVersion: schedulerVersion,
      parametersVersion: parametersVersion,
      metadata: metadata,
    );
    await _learning.appendReviewLog(entry);
    return entry;
  }

  /// Appends many entries, for the daily valve and Mercy.
  Future<void> appendAll(List<ReviewLogEntry> entries) =>
      _learning.appendReviewLogBatch(entries);

  /// Appends the full scheduler audit envelope. The caller supplies the
  /// calendar-derived [studyDay] at operation time; it is persisted and never
  /// recalculated after a home-zone change.
  Future<SchedulerEvent> appendScheduler({
    required String operationId,
    required SchedulerEventType eventType,
    required DateTime atUtc,
    required StudyDay studyDay,
    required String policyVersion,
    ElementRef? ref,
    String? schedulerName,
    String? schedulerVersion,
    String? stateBefore,
    String? stateAfter,
    String? algorithmicDueBefore,
    String? algorithmicDueAfter,
    String? undoesEventId,
    String? batchId,
    Map<String, Object?>? metadata,
  }) async {
    final SchedulerEvent event = SchedulerEvent(
      id: _ids.newId(),
      operationId: operationId,
      element: ref,
      eventType: eventType,
      occurredAtUtc: atUtc,
      studyDay: studyDay,
      schedulerName: schedulerName,
      schedulerVersion: schedulerVersion,
      policyVersion: policyVersion,
      stateBefore: stateBefore,
      stateAfter: stateAfter,
      algorithmicDueBefore: algorithmicDueBefore,
      algorithmicDueAfter: algorithmicDueAfter,
      undoesEventId: undoesEventId,
      batchId: batchId,
      metadata: metadata,
    );
    await _learning.appendSchedulerEvent(event);
    return event;
  }

  /// Builds an entry without appending it, for batched callers.
  ReviewLogEntry build({
    required String operationId,
    required ElementRef ref,
    required ReviewLogEventType eventType,
    required DateTime atUtc,
    ReviewLogSnapshot before = ReviewLogSnapshot.none,
    ReviewLogSnapshot after = ReviewLogSnapshot.none,
    int? grade,
    double? elapsedDays,
    double? scheduledDays,
    int? durationMs,
    int? postponeCount,
    String? schedulerVersion,
    String? parametersVersion,
    Map<String, Object?>? metadata,
  }) => ReviewLogEntry(
    id: _ids.newId(),
    operationId: operationId,
    ref: ref,
    eventType: eventType,
    atUtc: atUtc,
    before: before,
    after: after,
    grade: grade,
    elapsedDays: elapsedDays,
    scheduledDays: scheduledDays,
    durationMs: durationMs,
    postponeCount: postponeCount,
    schedulerVersion: schedulerVersion,
    parametersVersion: parametersVersion,
    metadata: metadata,
  );

  /// Days between two instants, as the log records elapsed time.
  static double? daysBetween(DateTime? from, DateTime to) =>
      from == null ? null : to.difference(from).inMinutes / 1440;
}
