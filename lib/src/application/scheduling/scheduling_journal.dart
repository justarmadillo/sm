/// Writes the repetition log.
///
/// Every handler that changes a schedule appends here, inside the same
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

import '../../core/ids.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../ports/repositories.dart';

/// Builds and appends [RevlogEntry] rows.
final class SchedulingJournal {
  const SchedulingJournal({
    required LearningRepository learning,
    required IdGenerator ids,
  }) : _learning = learning,
       _ids = ids;

  final LearningRepository _learning;
  final IdGenerator _ids;

  /// Snapshot of a topic as it stands now.
  RevlogSnapshot topicSnapshot(
    TopicState state, {
    required StudyDayCalendar calendar,
    double? pressure,
    double? readFraction,
  }) => RevlogSnapshot(
    dueAtUtc: calendar.startOfDayUtc(state.schedule.effectiveDueDay),
    intervalDays: state.intervalDays,
    aFactor: state.aFactor,
    priorityKey: state.schedule.priority.orderKey,
    pressure: pressure,
    readFraction: readFraction,
    lifecycle: state.schedule.lifecycle.index,
  );

  /// Snapshot of a card as it stands now.
  RevlogSnapshot cardSnapshot(CardState state, {double? pressure}) =>
      RevlogSnapshot(
        dueAtUtc: state.memory.effectiveDueAtUtc,
        stability: state.memory.stability,
        difficulty: state.memory.difficulty,
        learningState: state.memory.state.value,
        reps: state.memory.reps,
        lapses: state.memory.lapses,
        priorityKey: state.schedule.priority.orderKey,
        pressure: pressure,
        lifecycle: state.schedule.lifecycle.index,
      );

  /// Appends one entry.
  Future<RevlogEntry> append({
    required String operationId,
    required ElementRef ref,
    required RevlogEventType eventType,
    required DateTime atUtc,
    RevlogSnapshot before = RevlogSnapshot.none,
    RevlogSnapshot after = RevlogSnapshot.none,
    int? grade,
    double? elapsedDays,
    double? scheduledDays,
    int? durationMs,
    int? postponeCount,
    String? schedulerVersion,
    String? parametersVersion,
    Map<String, Object?>? metadata,
  }) async {
    final RevlogEntry entry = RevlogEntry(
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
    await _learning.appendRevlog(entry);
    return entry;
  }

  /// Appends many entries, for the daily valve and Mercy.
  Future<void> appendAll(List<RevlogEntry> entries) =>
      _learning.appendRevlogBatch(entries);

  /// Builds an entry without appending it, for batched callers.
  RevlogEntry build({
    required String operationId,
    required ElementRef ref,
    required RevlogEventType eventType,
    required DateTime atUtc,
    RevlogSnapshot before = RevlogSnapshot.none,
    RevlogSnapshot after = RevlogSnapshot.none,
    int? grade,
    double? elapsedDays,
    double? scheduledDays,
    int? durationMs,
    int? postponeCount,
    String? schedulerVersion,
    String? parametersVersion,
    Map<String, Object?>? metadata,
  }) => RevlogEntry(
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
