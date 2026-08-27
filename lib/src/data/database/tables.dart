/// Drift table definitions for the whole v1 schema.
///
/// Invariants live in SQL, not only in Dart: check constraints on enums and
/// ranges, foreign keys with explicit delete behaviour, and unique indexes on
/// the one-to-one subtype rows. A bug in a handler should hit a constraint,
/// not quietly write a collection that no longer makes sense.
library;

// Drift's check() idiom names the column inside its own definition. The
// analyzer reads that as a recursive getter; it is not, because the builder
// evaluates it once at schema-construction time.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Imported documents. The markdown is an immutable snapshot.
@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  /// Normalized original markdown. Every anchor addresses this exact text.
  TextColumn get markdown => text()();

  TextColumn get contentHash => text().withLength(min: 64, max: 64)();

  IntColumn get wordCount =>
      integer().check(wordCount.isBiggerOrEqualValue(0))();

  IntColumn get importedAtUtc => integer()();

  /// Explicit resume marker. Both columns are set or both are null.
  TextColumn get markerBlockId => text().nullable()();

  IntColumn get markerOffset => integer().nullable()();

  /// Soft position. Never drives scheduling.
  TextColumn get softBlockId => text().nullable()();

  IntColumn get softOffset => integer().nullable()();

  /// Bumped on every write, for change detection and diagnostics.
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK ((marker_block_id IS NULL) = (marker_offset IS NULL))',
    'CHECK ((soft_block_id IS NULL) = (soft_offset IS NULL))',
  ];
}

/// Immutable blocks derived from a source at import.
@DataClassName('BlockRow')
class Blocks extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  IntColumn get idx => integer().check(idx.isBiggerOrEqualValue(0))();

  /// Index into the block-type enum.
  IntColumn get type => integer().check(type.isBetweenValues(0, 7))();

  TextColumn get raw => text()();

  IntColumn get startUtf8 => integer()();

  IntColumn get endUtf8 => integer()();

  IntColumn get startUtf16 => integer()();

  /// JSON array of `[start, end]` UTF-16 pairs, relative to [raw].
  TextColumn get contentSpans => text()();

  IntColumn get headingLevel => integer().nullable()();

  TextColumn get codeLanguage => text().nullable()();

  BoolColumn get ordered => boolean().withDefault(const Constant(false))();

  TextColumn get listMarker => text().nullable()();

  IntColumn get listDepth => integer().withDefault(const Constant(0))();

  IntColumn get quoteDepth => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (source_id, idx)',
    'CHECK (end_utf8 >= start_utf8)',
  ];
}

/// Passages promoted into independent learning objects.
@DataClassName('ExtractRow')
class Extracts extends Table {
  TextColumn get id => text()();

  TextColumn get markdown => text()();

  /// Root source, denormalized so opening context never walks the chain.
  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.restrict)();

  /// Immediate parent: a source or another extract.
  TextColumn get parentId => text()();

  BoolColumn get parentIsSource => boolean()();

  TextColumn get startBlockId => text()();

  IntColumn get startOffset => integer()();

  TextColumn get endBlockId => text()();

  IntColumn get endOffset => integer()();

  TextColumn get selectedTextHash => text().withLength(min: 64, max: 64)();

  IntColumn get createdAtUtc => integer()();

  IntColumn get editedAtUtc => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (start_offset >= 0)',
    'CHECK (end_offset >= 0)',
    'CHECK ((start_block_id != end_block_id) OR (end_offset > start_offset))',
  ];
}

/// Formulated items.
@DataClassName('CardRow')
class Cards extends Table {
  TextColumn get id => text()();

  /// Sole canonical learning-element parent. [parentElementType] is null iff
  /// this is a standalone card. Referential validation is performed against
  /// the common schedule table inside the insertion transaction because
  /// SQLite cannot express a polymorphic foreign key.
  TextColumn get parentElementId => text().nullable()();

  IntColumn get parentElementType =>
      integer().nullable().check(parentElementType.isBetweenValues(0, 1))();

  /// Index into the card-kind enum.
  IntColumn get kind => integer().check(kind.isBetweenValues(0, 1))();

  TextColumn get front => text()();

  TextColumn get back => text()();

  IntColumn get clozeOrdinal => integer().nullable()();

  IntColumn get createdAtUtc => integer()();

  IntColumn get editedAtUtc => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // A cloze card names the deletion it tests; a Q&A card never does.
    'CHECK ((kind = 1) = (cloze_ordinal IS NOT NULL))',
    'CHECK ((parent_element_id IS NULL) = (parent_element_type IS NULL))',
  ];
}

/// The scheduling row every element has, whatever its type.
@DataClassName('ScheduleRow')
class ElementSchedules extends Table {
  TextColumn get elementId => text()();

  /// Index into the element-type enum.
  IntColumn get elementType =>
      integer().check(elementType.isBetweenValues(0, 2))();

  /// Sortable relative priority. Lower sorts as more important.
  TextColumn get priorityKey => text().withLength(min: 1, max: 128)();

  /// Index into the lifecycle enum: active (0), dismissed (1), deleted (2).
  ///
  /// The retired suspended and finished states are gone: SM20 knows only
  /// pending, memorized, dismissed, and deleted, and both of those states
  /// meant nothing more than "not scheduled, content kept".
  IntColumn get lifecycle => integer().check(lifecycle.isBetweenValues(0, 2))();

  /// Days since the Unix epoch.
  IntColumn get dueDay => integer()();

  /// What the scheduler chose, preserved across postponement.
  IntColumn get originalDueDay => integer()();

  /// Source at the root of this element's provenance, denormalized.
  ///
  /// Walking up the tree on every queue build would be a needless join, and
  /// the queue needs it on every element to stop one article's subtree from
  /// taking over a session. Denormalizing also means a card keeps its
  /// citation if its source is ever removed.
  TextColumn get rootId => text().nullable()();

  /// Immediate learning-element parent; one coordinate for every kind.
  TextColumn get parentElementId => text().nullable()();

  /// Pending/user-visible order metadata, independent of priority and due.
  IntColumn get ordinal => integer().nullable()();

  IntColumn get createdAtUtc => integer().nullable()();

  IntColumn get updatedAtUtc => integer().nullable()();

  IntColumn get revision => integer()
      .check(revision.isBiggerOrEqualValue(1))
      .withDefault(const Constant(1))();

  /// canonical (0) or legacy_due_unknown (1).
  IntColumn get legacyDueProvenance => integer()
      .check(legacyDueProvenance.isBetweenValues(0, 1))
      .withDefault(const Constant(0))();

  TextColumn get zoneId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    elementId,
    elementType,
  };
}

/// Exact SM20 scheduling state for sources and extracts.
@DataClassName('TopicStateRow')
class TopicStates extends Table {
  TextColumn get elementId => text()();

  IntColumn get elementType =>
      integer().check(elementType.isBetweenValues(0, 1))();

  /// SM20 record status: pending, memorized, dismissed, or deleted.
  IntColumn get status => integer().check(status.isBetweenValues(0, 3))();

  IntColumn get repetitionCount => integer()
      .check(repetitionCount.isBetweenValues(0, 65535))
      .withDefault(const Constant(0))();

  IntColumn get lapseCount => integer()
      .check(lapseCount.isBetweenValues(0, 65535))
      .withDefault(const Constant(0))();

  IntColumn get storedInterval => integer()
      .check(storedInterval.isBetweenValues(0, 44530))
      .withDefault(const Constant(0))();

  /// Signed collection day. Null before the first review.
  IntColumn get lastReviewDay => integer().nullable()();

  /// Raw little-endian Delphi Real48 bytes, encoded as twelve hex characters.
  TextColumn get aFactorRaw =>
      text().withDefault(const Constant('819a99999919'))();

  /// Raw little-endian Delphi Real48 interval-ratio bytes.
  TextColumn get lastIntervalRatioRaw =>
      text().withDefault(const Constant('000000000000'))();

  IntColumn get historyBlockId => integer()
      .check(historyBlockId.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  IntColumn get recentPostponementCount => integer()
      .check(recentPostponementCount.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  IntColumn get totalPostponementCount => integer()
      .check(totalPostponementCount.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  IntColumn get learningControl => integer()
      .check(learningControl.isBetweenValues(0, 255))
      .withDefault(const Constant(0))();

  /// Encounters since the last card was formulated from this element.
  IntColumn get encountersSinceLastCard => integer()
      .check(encountersSinceLastCard.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  IntColumn get revision => integer()
      .check(revision.isBiggerOrEqualValue(1))
      .withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    elementId,
    elementType,
  };

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(a_factor_raw) = 12 AND '
        "a_factor_raw NOT GLOB '*[^0-9a-fA-F]*')",
    'CHECK (length(last_interval_ratio_raw) = 12 AND '
        "last_interval_ratio_raw NOT GLOB '*[^0-9a-fA-F]*')",
  ];
}

/// FSRS memory state for cards, one row per card.
@DataClassName('CardMemoryRow')
class CardMemories extends Table {
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.restrict)();

  /// Null until the first review, matching dart-fsrs' new-card shape.
  RealColumn get stability => real().nullable()();

  /// Null until the first review, matching dart-fsrs' new-card shape.
  RealColumn get difficulty => real().nullable()();

  /// dart-fsrs state: learning (1), review (2), relearning (3).
  IntColumn get state => integer().check(state.isBetweenValues(1, 3))();

  /// Position in the active learning or relearning steps. Null in review.
  IntColumn get step =>
      integer().nullable().check(step.isBiggerOrEqualValue(0))();

  IntColumn get reps => integer()
      .check(reps.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  IntColumn get lapses => integer()
      .check(lapses.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  IntColumn get lastReviewUtc => integer().nullable()();

  IntColumn get dueAtUtc => integer()();

  IntColumn get originalDueAtUtc => integer()();

  /// Deferrals so far. Never a review, so it lives apart from [reps].
  IntColumn get postponeCount => integer()
      .check(postponeCount.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();

  /// Pinned scheduler build and parameter set, recorded so history stays
  /// interpretable after either changes.
  TextColumn get schedulerVersion => text()();

  TextColumn get parametersVersion => text()();

  TextColumn get schedulerName =>
      text().withDefault(const Constant('dart-fsrs'))();

  RealColumn get scheduledDays => real().nullable()();

  /// Exact serialized state consumed by the pinned adapter. Nullable only for
  /// legacy rows while a migration is validating/backfilling them.
  TextColumn get fsrsStateJson => text().nullable()();

  IntColumn get revision => integer()
      .check(revision.isBiggerOrEqualValue(1))
      .withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{cardId};

  @override
  List<String> get customConstraints => <String>[
    'CHECK ((state = 2 AND step IS NULL) OR '
        '(state IN (1, 3) AND step IS NOT NULL))',
    'CHECK ((stability IS NULL) = (difficulty IS NULL))',
    'CHECK (lapses <= reps)',
    'CHECK ((reps = 0 AND stability IS NULL AND difficulty IS NULL '
        'AND last_review_utc IS NULL) OR '
        '(reps > 0 AND stability IS NOT NULL AND difficulty IS NOT NULL '
        'AND last_review_utc IS NOT NULL))',
  ];
}

/// Complete append-only scheduler audit envelope.
@DataClassName('SchedulerEventRow')
class SchedulerEvents extends Table {
  TextColumn get id => text()();
  TextColumn get operationId => text()();
  TextColumn get elementId => text().nullable()();
  IntColumn get elementType => integer().nullable()();
  TextColumn get eventType => text()();
  IntColumn get occurredAtUtc => integer()();
  IntColumn get studyDay => integer()();
  TextColumn get studyDayZoneId => text()();
  TextColumn get schedulerName => text().nullable()();
  TextColumn get schedulerVersion => text().nullable()();
  TextColumn get policyVersion => text()();
  TextColumn get stateBefore => text().nullable()();
  TextColumn get stateAfter => text().nullable()();
  TextColumn get algorithmicDueBefore => text().nullable()();
  TextColumn get algorithmicDueAfter => text().nullable()();
  TextColumn get undoesEventId => text().nullable()();
  TextColumn get batchId => text().nullable()();
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Durable Mercy preview/apply data needed for stale detection and exact undo.
@DataClassName('MercyBatchRow')
class MercyBatches extends Table {
  TextColumn get batchId => text()();
  TextColumn get previewOperationId => text()();
  TextColumn get applyOperationId => text().nullable()();
  TextColumn get undoOperationId => text().nullable()();
  TextColumn get policyVersion => text()();
  TextColumn get previewJson => text()();

  /// Exact per-element canonical states needed to validate and undo an apply.
  TextColumn get appliedSnapshotJson => text().nullable()();
  IntColumn get createdAtUtc => integer()();
  IntColumn get appliedAtUtc => integer().nullable()();
  IntColumn get undoneAtUtc => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{batchId};
}

/// Append-only review log. Never updated or deleted; undo appends an inverse.
@DataClassName('ReviewEventRow')
class ReviewEvents extends Table {
  TextColumn get id => text()();

  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.restrict)();

  IntColumn get reviewedAtUtc => integer()();

  /// Again, Hard, Good, Easy.
  IntColumn get rating => integer().check(rating.isBetweenValues(1, 4))();

  /// FSRS state before the review, as JSON. Undo restores from this, and a
  /// future parameter optimizer replays from it.
  TextColumn get preStateJson => text()();

  TextColumn get postStateJson => text()();

  IntColumn get elapsedMs => integer().nullable()();

  TextColumn get schedulerVersion => text()();

  TextColumn get parametersVersion => text()();

  /// Practice-session grades are logged but never touch memory state, due
  /// dates, admission, or future optimization.
  BoolColumn get isPractice => boolean().withDefault(const Constant(false))();

  TextColumn get operationId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The universal repetition log: one row per scheduling event, any element.
///
/// The highest-value table in the collection, because it is the only one that
/// cannot be reconstructed. Every other table holds *current* state, which a
/// bug can overwrite; this one records the inputs and the outputs of each
/// decision so the scheduler's constants can be retuned against what really
/// happened. Append-only: nothing here is ever updated, and only undo deletes.
///
/// [ReviewEvents] is not made redundant by this table. That one is the
/// lossless FSRS record — full pre- and post-state JSON, one row per
/// operation id — and is what undo and a future optimizer replay from. This
/// one is the flat, queryable, all-element-types view that makes "what
/// happened to this element, in order" a single indexed query.
@DataClassName('RevlogRow')
class RevlogEntries extends Table {
  TextColumn get id => text()();

  TextColumn get operationId => text()();

  TextColumn get elementId => text()();

  IntColumn get elementType =>
      integer().check(elementType.isBetweenValues(0, 2))();

  /// Stable `RevlogEventType` value. Never the enum index.
  IntColumn get eventType =>
      integer().check(eventType.isBetweenValues(1, 15))();

  IntColumn get atUtc => integer()();

  /// 1–4 on review and practice rows, null everywhere else. A postpone has no
  /// grade because it was never a retention test.
  IntColumn get grade =>
      integer().nullable().check(grade.isBetweenValues(1, 4))();

  /// Days that actually passed since the previous repetition.
  RealColumn get elapsedDays => real().nullable()();

  /// Days the interval had been set to. The gap between this and
  /// [elapsedDays] is the signal an optimizer needs.
  RealColumn get scheduledDays => real().nullable()();

  IntColumn get durationMs => integer().nullable()();

  IntColumn get postponeCount => integer().nullable()();

  IntColumn get dueBeforeUtc => integer().nullable()();

  IntColumn get dueAfterUtc => integer().nullable()();

  RealColumn get intervalBefore => real().nullable()();

  RealColumn get intervalAfter => real().nullable()();

  RealColumn get aFactorBefore => real().nullable()();

  RealColumn get aFactorAfter => real().nullable()();

  RealColumn get stabilityBefore => real().nullable()();

  RealColumn get stabilityAfter => real().nullable()();

  RealColumn get difficultyBefore => real().nullable()();

  RealColumn get difficultyAfter => real().nullable()();

  IntColumn get stateBefore => integer().nullable()();

  IntColumn get stateAfter => integer().nullable()();

  IntColumn get repsBefore => integer().nullable()();

  IntColumn get lapsesBefore => integer().nullable()();

  TextColumn get priorityBefore => text().nullable()();

  TextColumn get priorityAfter => text().nullable()();

  /// Priority pressure at the moment of the event, stored rather than
  /// recomputed: the collection's order moves, and what mattered to the
  /// decision is where the element stood then.
  RealColumn get pressureBefore => real().nullable()();

  RealColumn get pressureAfter => real().nullable()();

  RealColumn get readFractionBefore => real().nullable()();

  RealColumn get readFractionAfter => real().nullable()();

  IntColumn get lifecycleBefore => integer().nullable()();

  IntColumn get lifecycleAfter => integer().nullable()();

  TextColumn get schedulerVersion => text().nullable()();

  TextColumn get parametersVersion => text().nullable()();

  /// Free-form detail: the A-factor's terms, a delay formula's inputs, the
  /// cap that triggered a deferral. Never element content.
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    // Only a graded event may carry a grade. Enforced in SQL as well as in
    // Dart because a stray grade on a postpone row would poison any future
    // optimizer's training set.
    'CHECK (grade IS NULL OR event_type IN (1, 14))',
  ];
}

/// Materialized search rows, kept in step with content inside the same
/// transaction that writes the content.
///
/// The FTS5 index is external-content over this table and is rebuildable from
/// it, so a corrupted index is a one-statement repair rather than data loss.
@DataClassName('SearchDocumentRow')
class SearchDocuments extends Table {
  TextColumn get elementId => text()();

  IntColumn get elementType =>
      integer().check(elementType.isBetweenValues(0, 2))();

  TextColumn get title => text()();

  TextColumn get body => text()();

  /// Root source, so results can be grouped by article without a join.
  TextColumn get sourceId => text().nullable()();

  IntColumn get updatedAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    elementId,
    elementType,
  };
}

/// Append-only activity log for diagnosis and audit.
@DataClassName('ActivityEventRow')
class ActivityEvents extends Table {
  TextColumn get id => text()();

  TextColumn get operationId => text()();

  TextColumn get elementId => text().nullable()();

  IntColumn get elementType => integer().nullable()();

  /// Stable dotted event name, for example `reader.done`.
  TextColumn get kind => text()();

  IntColumn get atUtc => integer()();

  /// Foreground duration, logged from day one so time-based features remain
  /// possible later even though v1 is count-based.
  IntColumn get durationMs => integer().nullable()();

  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Key/value settings.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// Single-row dataset identity and lineage.
///
/// Present from the first migration so the v1.1 handoff protocol needs no
/// migration of accumulated history.
@DataClassName('DatasetMetaRow')
class DatasetMeta extends Table {
  /// Always 1: the table holds exactly one row.
  IntColumn get id => integer().check(id.equals(1))();

  TextColumn get datasetId => text()();

  IntColumn get generation => integer()();

  IntColumn get writerEpoch => integer()();

  TextColumn get ownerDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
