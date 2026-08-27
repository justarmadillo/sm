/// Repository contracts, organized by aggregate rather than by table.
///
/// Four aggregates, four repositories: what the user reads, when they see it,
/// how the app is configured, and what has been exported. A handler that needs
/// content and schedules composes two repositories inside one
/// transaction-runner scope rather than reaching into a shared god-object.
///
/// Implementations live in `data/repositories`. Nothing here mentions Drift,
/// SQL, or Flutter.
library;

import 'package:meta/meta.dart';

import '../../domain/content/card.dart';
import '../../domain/content/document.dart';
import '../../domain/content/extract.dart';
import '../../domain/content/reader_anchor.dart';
import '../../domain/content/source.dart';
import '../../domain/content/source_edit.dart';
import '../../domain/content/source_editing.dart';
import '../../domain/content/text_splice.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/scheduler_event.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/transfer/dataset_lineage.dart';
import '../scheduling/mercy_workflow.dart';

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

/// Sources, their parsed documents, extracts, and cards.
abstract interface class ContentRepository {
  /// Stores a newly imported source together with its derived blocks.
  Future<void> insertSource(Source source, Document document);

  /// The source with [id], or null.
  Future<Source?> findSource(String id);

  /// The parsed document for [sourceId], or null.
  Future<Document?> findDocument(String sourceId);

  /// Every source, newest import first.
  Future<List<Source>> listSources();

  /// Replaces mutable source fields: title, pace, resume position, folder.
  Future<void> updateSource(Source source);

  /// Updates only the authoritative marker and returns the stored source.
  Future<Source?> setResumeMarker(String sourceId, ReaderAnchor anchor);

  /// Updates only the scratch scroll position and returns the stored source.
  Future<Source?> setSoftPosition(String sourceId, ReaderAnchor anchor);

  /// Atomically promotes the stored soft position to the marker.
  Future<Source?> confirmSoftPosition(String sourceId);

  /// Applies one splice to a source's text, in a single transaction.
  ///
  /// Everything that points into the text moves with it: both reading
  /// positions, and every direct child's recorded range. Nothing
  /// scheduling-related is read or written — editing text is not a repetition
  /// and must never disturb a due date.
  ///
  /// [baseContentRevision] is the revision the caller believed it was editing.
  /// A mismatch yields [SourceEditConflict] and writes nothing, so two windows
  /// editing the same source cannot silently overwrite one another.
  Future<SourceEditResult> applySourceEdit({
    required String sourceId,
    required TextSplice splice,
    required int baseContentRevision,
    required String operationId,
    required DateTime nowUtc,
    bool isUndo = false,
    SourceEditRestore? restore,
  });

  /// The edit journal for [sourceId], oldest first.
  Future<List<SourceEdit>> listSourceEdits(String sourceId);

  /// The most recent edit applied to [sourceId], or null.
  Future<SourceEdit?> latestSourceEdit(String sourceId);

  /// Stores a new extract.
  Future<void> insertExtract(Extract extract);

  /// The extract with [id], or null.
  Future<Extract?> findExtract(String id);

  /// Extracts whose provenance names [parentId], in creation order.
  Future<List<Extract>> listExtractsOfParent(String parentId);

  /// Every extract taken from [sourceId], including nested ones.
  Future<List<Extract>> listExtractsOfSource(String sourceId);

  /// How many extracts each of [sourceIds] has produced.
  Future<Map<String, int>> countExtractsBySource(List<String> sourceIds);

  /// Replaces an extract's editable text.
  Future<void> updateExtract(Extract extract);

  /// Removes an extract outright. Used by Undo, which must leave no trace.
  Future<void> deleteExtract(String id);

  /// Stores newly formulated cards.
  Future<void> insertCards(List<Card> cards);

  /// The card with [id], or null.
  Future<Card?> findCard(String id);

  /// Cards formulated from [extractId].
  Future<List<Card>> listCardsOfExtract(String extractId);

  /// Cards formulated directly from [sourceId], without an extract between.
  Future<List<Card>> listCardsOfSource(String sourceId);

  /// Replaces a card's text, including edits made during review.
  Future<void> updateCard(Card card);

  /// Cards formulated from the same parent as [cardId], excluding it.
  ///
  /// Sibling burying needs exactly this: three clozes cut from one sentence
  /// give each other away, so answering one pushes the rest off today.
  Future<List<Card>> listSiblingCards(String cardId);
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
  Future<List<ElementSchedule>> listByPriority({int? limit, int? offset});

  /// Appends one activity record.
  Future<void> appendActivity(ActivityRecord record);

  /// Whether an activity row already exists for [operationId] and [kind].
  ///
  /// This is how terminal commands stay exactly-once: the log is the record
  /// of what has been applied, so a retried Done finds its own footprint and
  /// declines to advance the schedule a second time.
  Future<bool> hasActivity(String operationId, String kind);

  /// Recent activity, newest first. For the diagnostics panel.
  Future<List<ActivityRecord>> recentActivity({int limit = 50});

  /// Appends one repetition-log entry.
  ///
  /// Called by every command that changes a schedule, in the same transaction
  /// as the change. The log is the only record that cannot be rebuilt from
  /// current state, so a write that skips it loses information permanently.
  Future<void> appendRevlog(RevlogEntry entry);

  /// Appends many entries at once, for the daily valve and Mercy.
  Future<void> appendRevlogBatch(List<RevlogEntry> entries);

  /// Everything that happened to [ref], oldest first.
  Future<List<RevlogEntry>> listRevlogFor(ElementRef ref, {int? limit});

  /// The most recent entries across the whole collection, newest first.
  Future<List<RevlogEntry>> recentRevlog({int limit = 100});

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
  Future<Map<RevlogEventType, int>> countRevlogOn(StudyDay day);

  /// The most recent non-practice review of [cardId], or null.
  Future<ReviewRecord?> findLastReview(String cardId);

  /// The most recent non-practice review in the collection, or null.
  ///
  /// Undo-last-grade is a session affordance, so it works on whatever was
  /// graded last rather than only on the card currently open.
  Future<ReviewRecord?> findLastReviewOverall();

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

/// One row of the materialized search table.
@immutable
final class SearchDocument {
  const SearchDocument({
    required this.ref,
    required this.title,
    required this.body,
    required this.updatedAtUtc,
    this.sourceId,
  });

  final ElementRef ref;
  final String title;

  /// Indexed text. For a source this is the whole markdown, so a passage can
  /// be found before it has ever been extracted.
  final String body;

  final DateTime updatedAtUtc;

  /// Root source, so results group by article without a join.
  final String? sourceId;
}

/// One search hit, with the snippet that matched.
@immutable
final class SearchHit {
  const SearchHit({
    required this.ref,
    required this.title,
    required this.snippet,
    required this.rank,
    this.sourceId,
  });

  final ElementRef ref;
  final String title;

  /// Highlighted excerpt around the match, produced by FTS5.
  final String snippet;

  /// FTS5 relevance; lower is better.
  final double rank;

  final String? sourceId;
}

/// Full-text search over sources, extracts, and cards.
abstract interface class SearchRepository {
  /// Inserts or replaces one document, inside the caller's transaction.
  Future<void> upsertDocument(SearchDocument document);

  /// Removes one document and its index entry.
  Future<void> deleteDocument(ElementRef ref);

  /// Matches against the FTS5 index, best first.
  Future<List<SearchHit>> search(
    String query, {
    int limit = 50,
    Set<ElementType>? types,
  });

  /// Rebuilds the index from the materialized rows.
  Future<void> rebuildIndex();

  /// Whether the index reports itself consistent with its content table.
  Future<bool> indexIsValid();

  /// How many documents are materialized.
  Future<int> documentCount();
}

/// User settings and the values the schedulers read.
abstract interface class SettingsRepository {
  /// Reads the setting [key], or null when unset.
  Future<String?> read(String key);

  /// Writes the setting [key].
  Future<void> write(String key, String value);

  /// Every stored setting.
  Future<Map<String, String>> readAll();

  /// Writes many settings in one batch, replacing what was there.
  Future<void> writeAll(Map<String, String> values);

  /// Removes the setting [key], returning it to its shipped default.
  Future<void> remove(String key);
}

/// Dataset lineage, backups, and export snapshots.
abstract interface class TransferRepository {
  /// Current dataset identity, creating it on first use.
  Future<DatasetIdentity> currentIdentity();

  /// Records an advanced generation after a domain transaction.
  Future<void> saveIdentity(DatasetIdentity identity);

  /// Increments the generation counter and returns the new identity.
  Future<DatasetIdentity> advanceGeneration();
}
