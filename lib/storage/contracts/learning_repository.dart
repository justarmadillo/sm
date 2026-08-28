/// What the app promises about saving and loading when things come back.
///
/// Schedules, priority order, the repetition log, and the day's activity.
/// Nothing here mentions Drift, SQL, or Flutter.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:meta/meta.dart';

/// One appended entry in the activity log.
///
/// The log exists for diagnosis and audit, not as an event-sourced database:
/// SQLite rows remain canonical. It records *that* something happened and how
/// long it took, never the content it happened to.
@immutable
final class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.operationId,
    required this.kind,
    required this.atUtc,
    this.ref,
    this.durationMs,
    this.metadata,
  });

  final String id;

  /// Correlates every row written by one user-initiated operation.
  final String operationId;

  /// Stable dotted name, for example `topic.encounter_completed`.
  final String kind;

  final DateTime atUtc;
  final ElementRef? ref;

  /// Foreground duration, logged from day one so time-based features stay
  /// possible even though v1 schedules by count.
  final int? durationMs;

  final Map<String, Object?>? metadata;
}

/// Schedules, priority, topic pacing, and the activity log.
abstract interface class LearningRepository {
  /// Creates the schedule and pacing rows for a new topic.
  Future<void> insertTopic(TopicState topic);

  /// Topic state for [ref], or null.
  Future<TopicState?> findTopic(ElementRef ref);

  /// Replaces a topic's schedule and pacing rows.
  Future<void> saveTopic(TopicState topic);

  /// Replaces one canonical topic only if the stored snapshot is still
  /// current. Both the common-element and topic revisions must advance once.
  ///
  /// The name has an "and" in it because the comparing and the swapping are
  /// one indivisible step. Splitting them into `checkTopicIsUnchanged` and
  /// `saveTopic` would open a gap in which another write could land between
  /// the two, and the second grade of a double-tap would overwrite the first.
  /// Returns false instead of throwing when the snapshot is stale, so the
  /// caller can retry or report a conflict.
  Future<bool> compareAndSwapTopic({
    required TopicState expected,
    required TopicState replacement,
  });

  /// Creates the common schedule and FSRS memory rows for a formulated card.
  Future<void> insertCardState(CardState card);

  /// Common schedule plus FSRS memory for [cardId], or null.
  Future<CardState?> findCardState(String cardId);

  /// Replaces a card's common schedule and FSRS memory atomically inside the
  /// caller's transaction.
  Future<void> saveCardState(CardState card);

  /// Replaces one card only if the stored snapshot is still current.
  ///
  /// One indivisible step, for the same reason as [compareAndSwapTopic]: this
  /// is what makes grading a card exactly-once when the button is tapped twice.
  Future<bool> compareAndSwapCardState({
    required CardState expected,
    required CardState replacement,
  });

  /// Active cards whose exact UTC due instant has arrived.
  ///
  /// Unlike topics, cards can be due again within the same study day, so this
  /// must use the memory row's instant and not only the common due-day field.
  Future<List<CardState>> listDueCards(DateTime nowUtc);

  /// Card candidates irrespective of due. Effective-due evaluation needs
  /// this because an exact override may legitimately move a future card
  /// earlier than its canonical FSRS due.
  Future<List<CardState>> listCardStates({Set<ElementLifecycle>? lifecycles});

  /// Appends one lossless FSRS review event.
  Future<void> appendReview(ReviewRecord record);

  /// Review written by one operation, used for exactly-once retries.
  Future<ReviewRecord?> findReviewByOperationId(String operationId);

  /// Review history for one card, oldest first.
  Future<List<ReviewRecord>> listReviewsForCard(String cardId);

  /// Optimizer input: genuine card reviews which have not been undone.
  Future<List<ReviewRecord>> listOptimizerReviews();

  /// Topic state for many refs at once, keyed by ref.
  Future<Map<ElementRef, TopicState>> findTopics(List<ElementRef> refs);

  /// Removes an element's scheduling rows entirely.
  Future<void> deleteSchedule(ElementRef ref);

  /// The schedule for [ref], or null.
  Future<ElementSchedule?> findSchedule(ElementRef ref);

  /// Replaces a schedule wholesale.
  Future<void> saveSchedule(ElementSchedule schedule);

  /// Every schedule, ordered by priority, for the priority browser.
  Future<List<ElementSchedule>> listSchedulesByPriority({
    int? limit,
    int? offset,
  });

  /// Appends one activity record.
  Future<void> appendActivity(ActivityRecord record);

  /// Whether an activity row already exists for [operationId] and [kind].
  ///
  /// This is how terminal commands stay exactly-once: the log is the record
  /// of what has been applied, so a retried Done finds its own footprint and
  /// declines to advance the schedule a second time.
  Future<bool> hasActivity(String operationId, String kind);

  /// Recent activity, newest first. For the diagnostics panel.
  Future<List<ActivityRecord>> listRecentActivity({int limit = 50});

  /// Appends one repetition-log entry.
  ///
  /// Called by every command that changes a schedule, in the same transaction
  /// as the change. The log is the only record that cannot be rebuilt from
  /// current state, so a write that skips it loses information permanently.
  Future<void> appendReviewLog(ReviewLogEntry entry);

  /// Appends many entries at once, for the daily valve and Mercy.
  Future<void> appendReviewLogBatch(List<ReviewLogEntry> entries);

  /// Everything that happened to [ref], oldest first.
  Future<List<ReviewLogEntry>> listReviewLogForElement(
    ElementRef ref, {
    int? limit,
  });

  /// The most recent entries across the whole collection, newest first.
  Future<List<ReviewLogEntry>> listRecentReviewLog({int limit = 100});

  /// Appends the authoritative scheduler event. Events are never updated or
  /// deleted; an undo is another event referencing its target.
  Future<void> appendSchedulerEvent(SchedulerEvent event);

  Future<void> appendSchedulerEvents(List<SchedulerEvent> events);

  /// Event originally written for [operationId], used for idempotent replay.
  Future<SchedulerEvent?> findSchedulerEventByOperationId(
    String operationId, {
    SchedulerEventType? eventType,
  });

  Future<List<SchedulerEvent>> listSchedulerEventsFor(
    ElementRef ref, {
    int? limit,
  });

  /// Durable Mercy batches. Preview, apply, and undo are three separate
  /// transactions that may be separated by minutes or by a restart, so the
  /// proposal and its exact prior adjustment set have to survive in storage
  /// rather than in a view model.
  Future<void> saveMercyBatch(StoredMercyBatch batch);

  Future<StoredMercyBatch?> findMercyBatch(String batchId);

  /// Makes a repeated preview command idempotent.
  Future<StoredMercyBatch?> findMercyBatchByPreviewOperation(
    String operationId,
  );

  /// Applied, not-yet-undone batches on or after [day], newest first.
  Future<List<StoredMercyBatch>> listAppliedMercyBatchesSince(StudyDay day);

  /// The most recent applied, not-yet-undone batch.
  Future<StoredMercyBatch?> findLastAppliedMercyBatch();

  /// How many entries of each event type were written on [day].
  Future<Map<ReviewLogEventType, int>> countReviewLogEventsOn(StudyDay day);

  /// The most recent non-practice review of [cardId], or null.
  Future<ReviewRecord?> findLastReview(String cardId);

  /// The most recent non-practice review in the collection, or null.
  ///
  /// Undo-last-grade is a session affordance, so it works on whatever was
  /// graded last rather than only on the card currently open.
  Future<ReviewRecord?> findLastReviewInCollection();

  /// Priority keys of every non-deleted learning element, ascending.
  ///
  /// This is the input to [PriorityScale]: percentiles are derived from the
  /// live order rather than stored, so promoting one element necessarily
  /// demotes another and the field cannot inflate.
  Future<List<PriorityRank>> listActivePriorities();

  /// Card state for many ids at once.
  Future<Map<String, CardState>> findCardStates(List<String> cardIds);

  /// Replaces many schedules in one statement batch.
  Future<void> saveSchedules(List<ElementSchedule> schedules);

  /// Every schedule of the given [types], whatever its lifecycle.
  Future<List<ElementSchedule>> listSchedules({
    required Set<ElementType> types,
    Set<ElementLifecycle>? lifecycles,
    int? limit,
    int? offset,
  });

  /// How many elements sit in each lifecycle, by type. For diagnostics.
  Future<Map<ElementType, Map<ElementLifecycle, int>>> countByLifecycle();
}
