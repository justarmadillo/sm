/// Drift table definitions for the whole v1 schema.
///
/// Invariants live in SQL, not only in Dart: check constraints on enums and
/// ranges, foreign keys with explicit delete behaviour, and unique indexes on
/// the one-to-one subtype rows. A bug in a command runner should hit a
/// constraint, not quietly write a collection that no longer makes sense.
///
/// **Renaming a getter here renames a database column.** Drift derives the SQL
/// name from the Dart name (`parentIsSource` becomes `parent_is_source`), so a
/// rename that looks cosmetic will make every existing collection unreadable.
/// If a name really has to change, add `.named('old_column')` to keep the SQL
/// side fixed, and regenerate `app_database.g.dart`.
library;

// Drift's check() idiom names the column inside its own definition. The
// analyzer reads that as a recursive getter; it is not, because the builder
// evaluates it once at schema-construction time.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Imported documents.
///
/// The markdown is editable, and every edit is a splice recorded in
/// [SourceEdits]. Positions are byte offsets into this exact text, stamped
/// with the [contentRevision] they were written against.
@DataClassName('SourceRow')
class Sources extends Table {
  TextColumn get id => text()();

  TextColumn get title => text().withLength(min: 1, max: 500)();

  /// Normalized markdown at [contentRevision]. Every anchor addresses it.
  TextColumn get markdown => text()();

  TextColumn get contentHash => text().withLength(min: 64, max: 64)();

  IntColumn get wordCount =>
      integer().check(wordCount.isBiggerOrEqualValue(0))();

  IntColumn get importedAtUtc => integer()();

  /// Version of [markdown] itself, bumped only by a content splice.
  ///
  /// Deliberately not [revision]: that counts row writes of any kind, and
  /// replaying the edit journal needs a counter that advances once per splice
  /// and never otherwise.
  IntColumn get contentRevision => integer().withDefault(const Constant(1))();

  /// Explicit resume marker, as a document byte offset. Both columns are set
  /// or both are null.
  IntColumn get markerUtf8 => integer().nullable()();

  IntColumn get markerRevision => integer().nullable()();

  /// Soft position. Never drives scheduling.
  IntColumn get softUtf8 => integer().nullable()();

  IntColumn get softRevision => integer().nullable()();

  /// Bumped on every write, for change detection and diagnostics.
  IntColumn get revision => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK ((marker_utf8 IS NULL) = (marker_revision IS NULL))',
    'CHECK ((soft_utf8 IS NULL) = (soft_revision IS NULL))',
    'CHECK (marker_utf8 IS NULL OR marker_utf8 >= 0)',
    'CHECK (soft_utf8 IS NULL OR soft_utf8 >= 0)',
    'CHECK (content_revision >= 1)',
  ];
}

/// Source-owned references to immutable image blobs in app storage.
@DataClassName('SourceAssetRow')
class SourceAssets extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// Portable reference kept verbatim in the source markdown.
  TextColumn get srcRef => text().withLength(min: 1)();

  /// Lowercase hexadecimal SHA-256, also used as the safe blob filename.
  TextColumn get sha256 => text().withLength(min: 64, max: 64)();

  TextColumn get mime => text().withLength(min: 7)();

  IntColumn get widthPx => integer().check(widthPx.isBiggerThanValue(0))();

  IntColumn get heightPx => integer().check(heightPx.isBiggerThanValue(0))();

  IntColumn get byteSize => integer().check(byteSize.isBiggerThanValue(0))();

  /// ok (0), missing (1), or failed validation (2).
  IntColumn get state => integer().check(state.isBetweenValues(0, 2))();

  IntColumn get importedAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (source_id, src_ref)',
    "CHECK (sha256 NOT GLOB '*[^0-9a-f]*')",
    "CHECK (mime LIKE 'image/%' AND length(mime) > 6)",
  ];
}

/// Every edit ever applied to a source's text, one row per splice.
///
/// Append-only. Undo appends the inverse splice at a new revision rather than
/// deleting a row, so the journal is always a complete forward history and a
/// position written against any past revision can be replayed to the present.
@DataClassName('SourceEditRow')
class SourceEdits extends Table {
  TextColumn get id => text()();

  TextColumn get sourceId =>
      text().references(Sources, #id, onDelete: KeyAction.cascade)();

  /// The revision this splice produced.
  IntColumn get contentRevision => integer()();

  /// First byte replaced.
  IntColumn get startUtf8 => integer()();

  /// One past the last byte replaced; equal to [startUtf8] for an insertion.
  IntColumn get endUtf8 => integer()();

  /// Exactly what was removed, so the inverse splice is exact.
  TextColumn get removedText => text()();

  /// Exactly what was inserted, already normalized.
  TextColumn get insertedText => text()();

  /// Whether this edit was itself the undo of an earlier one.
  BoolColumn get isUndo => boolean().withDefault(const Constant(false))();

  /// JSON of everything this edit displaced, so undo restores it exactly.
  ///
  /// Collapsing a position onto the start of an edit destroys where it was;
  /// no rule can invert that, so the pre-edit values are carried here.
  TextColumn get restoreJson => text().withDefault(const Constant(''))();

  IntColumn get appliedAtUtc => integer()();

  TextColumn get operationId => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'UNIQUE (source_id, content_revision)',
    'UNIQUE (operation_id)',
    'CHECK (end_utf8 >= start_utf8)',
    'CHECK (start_utf8 >= 0)',
    'CHECK (content_revision >= 2)',
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

  /// Whether [parentId] names a source rather than another extract.
  ///
  /// The column stays `parent_is_source`, which is what every collection on
  /// disk and every migration's raw SQL already calls it. Letting Drift derive
  /// `has_source_as_parent` from the Dart name would rename the column and
  /// every existing collection would stop loading its extracts.
  BoolColumn get hasSourceAsParent => boolean().named('parent_is_source')();

  /// Byte range of the parent's markdown this passage was taken from.
  IntColumn get startUtf8 => integer()();

  IntColumn get endUtf8 => integer()();

  /// Parent revision the range was recorded against.
  IntColumn get anchorRevision => integer().withDefault(const Constant(1))();

  /// How much of the link back still holds: 0 verbatim, 1 stale, 2 orphaned.
  ///
  /// Never cleared by a migration. A range whose text was edited away is
  /// reported, not re-found: searching for the passage again picks the wrong
  /// occurrence whenever a phrase repeats, and does it silently.
  IntColumn get provenanceState => integer()
      .check(provenanceState.isBetweenValues(0, 2))
      .withDefault(const Constant(0))();

  TextColumn get selectedTextHash => text().withLength(min: 64, max: 64)();

  IntColumn get createdAtUtc => integer()();

  IntColumn get editedAtUtc => integer().nullable()();

  /// Version of this extract's own [markdown], for extracts with children.
  IntColumn get contentRevision => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (start_utf8 >= 0)',
    'CHECK (end_utf8 >= start_utf8)',
    'CHECK (anchor_revision >= 1)',
    'CHECK (content_revision >= 1)',
  ];
}

/// A video that exists somewhere on the internet. One row per URL.
///
/// Deliberately separate from [VideoElements]: the thing on the internet and
/// the ranges the user has chosen to study over it are different objects, and
/// correcting a mistyped URL must be one write rather than one per clip.
@DataClassName('VideoRow')
class Videos extends Table {
  TextColumn get id => text()();

  /// The page the video is watched on, carrying no timestamp of ours.
  TextColumn get url => text().withLength(min: 1)();

  /// Index into the VideoPlatform enum: youtube (0), vumedi (1), other (2).
  IntColumn get platform => integer().check(platform.isBetweenValues(0, 2))();

  /// Whole-video length, when the user typed it. Never fetched: asking the
  /// site for it would put the feature back under the API terms it exists to
  /// avoid.
  IntColumn get durationSeconds =>
      integer().nullable().check(durationSeconds.isBiggerThanValue(0))();

  IntColumn get addedAtUtc => integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// One scheduled range over a video: the whole thing, or a clip cut from it.
///
/// A clip is not a different kind of thing from a whole video — it is a
/// narrower range with a parent — which is why one table serves both and why
/// cutting a clip out of a clip needs no rule of its own.
@DataClassName('VideoElementRow')
class VideoElements extends Table {
  TextColumn get id => text()();

  TextColumn get videoId =>
      text().references(Videos, #id, onDelete: KeyAction.restrict)();

  /// The element this clip was cut from, or null on the whole video.
  ///
  /// RESTRICT, not CASCADE, for the same reason extracts use it: the app soft
  /// deletes through lifecycle, and a physical parent delete must never take
  /// independently scheduled children with it.
  TextColumn get parentVideoElementId => text().nullable().references(
    VideoElements,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// The user's own name for this range. Required on a whole video, which is
  /// otherwise unfindable in the tree; optional on a clip, which falls back
  /// to its own times.
  TextColumn get title => text().nullable().withLength(min: 1, max: 500)();

  /// What the user wrote about this range, and what cards formulate from.
  TextColumn get note => text().withDefault(const Constant(''))();

  IntColumn get startSeconds => integer()();

  /// One past the last second of the range, so the difference is a length.
  IntColumn get endSeconds => integer()();

  /// How far into the video the user says they got.
  ///
  /// Typed, never observed. Playback happens outside the app, so there is no
  /// honest way to know where the viewer is, and a value nobody entered would
  /// be indistinguishable from one they did.
  IntColumn get resumeSeconds => integer().nullable()();

  IntColumn get createdAtUtc => integer()();

  IntColumn get editedAtUtc => integer().nullable()();

  IntColumn get revision => integer()
      .check(revision.isBiggerOrEqualValue(1))
      .withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (start_seconds >= 0)',
    'CHECK (end_seconds > start_seconds)',
    'CHECK (resume_seconds IS NULL OR '
        '(resume_seconds >= start_seconds AND resume_seconds <= end_seconds))',
    'CHECK (parent_video_element_id IS NULL OR parent_video_element_id <> id)',
    'CHECK (parent_video_element_id IS NOT NULL OR title IS NOT NULL)',
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

  /// Enumerated rather than ranged because 2 is a card, and a card is never
  /// the parent of another card.
  IntColumn get parentElementType =>
      integer().nullable().check(parentElementType.isIn(<int>[0, 1, 3]))();

  /// Index into the CardType enum.
  IntColumn get type => integer().check(type.isBetweenValues(0, 1))();

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
    'CHECK ((type = 1) = (cloze_ordinal IS NOT NULL))',
    'CHECK ((parent_element_id IS NULL) = (parent_element_type IS NULL))',
  ];
}

/// The scheduling row every element has, whatever its type.
@DataClassName('ScheduleRow')
class ElementSchedules extends Table {
  TextColumn get elementId => text()();

  /// Index into the element-type enum.
  IntColumn get elementType =>
      integer().check(elementType.isBetweenValues(0, 3))();

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

  /// Where the element is filed in the Browser: one parent coordinate for
  /// every kind of element, null at the top of the tree.
  ///
  /// Set to the element's origin when it is created and to wherever the user
  /// drags it afterwards. Provenance is not this column: an extract's real
  /// parent and byte range live on `extracts`, and no move touches them.
  TextColumn get parentElementId => text().nullable()();

  /// Order among the rows filed under the same parent, ascending. Null until
  /// something is moved, and independent of priority and due.
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

  /// Enumerated rather than ranged because 2 is a card, and a card is
  /// scheduled by FSRS in [CardMemories] rather than by SM20 here.
  IntColumn get elementType =>
      integer().check(elementType.isIn(<int>[0, 1, 3]))();

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
/// The class name spells "revlog" — the SuperMemo/Anki word for a review
/// log — because Drift derives the SQL table name `revlog_entries` from it,
/// and every shipped collection already has that table. The Dart side of
/// this data is spelled out: see `ReviewLogEntry` in
/// `scheduling/history/review_log.dart`, and `reviewLogFromRow` in
/// `row_converters.dart` for the bridge between the two.
@DataClassName('RevlogRow')
class RevlogEntries extends Table {
  TextColumn get id => text()();

  TextColumn get operationId => text()();

  TextColumn get elementId => text()();

  IntColumn get elementType =>
      integer().check(elementType.isBetweenValues(0, 3))();

  /// Stable `ReviewLogEventType` value. Never the enum index.
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
      integer().check(elementType.isBetweenValues(0, 3))();

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
  TextColumn get type => text()();

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
