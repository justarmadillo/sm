/// Conversion between Drift rows and domain values.
///
/// The only place row shapes and domain shapes meet. Enums are persisted by
/// index, so their declaration order is now part of the on-disk format:
/// reorder an enum and every stored row changes meaning. Append, never insert.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/block_content.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/source_edit.dart';
import 'package:incremental_reader/documents/text_splice.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Milliseconds since the Unix epoch, the storage form for every instant.
int toEpochMs(DateTime instant) => instant.toUtc().millisecondsSinceEpoch;

/// A UTC instant from stored milliseconds.
DateTime fromEpochMs(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

/// A study day from its stored epoch-day number.
StudyDay studyDayFromEpochDay(int epochDay, String zoneId) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    epochDay * 86400000,
    isUtc: true,
  );
  return StudyDay(
    year: date.year,
    month: date.month,
    day: date.day,
    zoneId: zoneId,
  );
}

/// Restores the six Real48 bytes stored as a compact hexadecimal string.
DelphiReal48 real48FromHex(String value) => DelphiReal48.fromBytes(<int>[
  for (var offset = 0; offset < value.length; offset += 2)
    int.parse(value.substring(offset, offset + 2), radix: 16),
]);

SchedulerEvent schedulerEventFromRow(SchedulerEventRow row) => SchedulerEvent(
  id: row.id,
  operationId: row.operationId,
  element: row.elementId == null
      ? null
      : ElementRef(
          id: row.elementId!,
          type: ElementType.values[row.elementType!],
        ),
  eventType: SchedulerEventType.parse(row.eventType),
  occurredAtUtc: fromEpochMs(row.occurredAtUtc),
  studyDay: studyDayFromEpochDay(row.studyDay, row.studyDayZoneId),
  schedulerName: row.schedulerName,
  schedulerVersion: row.schedulerVersion,
  policyVersion: row.policyVersion,
  stateBefore: row.stateBefore,
  stateAfter: row.stateAfter,
  algorithmicDueBefore: row.algorithmicDueBefore,
  algorithmicDueAfter: row.algorithmicDueAfter,
  undoesEventId: row.undoesEventId,
  batchId: row.batchId,
  metadata: row.metadataJson == null
      ? null
      : jsonDecode(row.metadataJson!) as Map<String, Object?>,
);

SchedulerEventsCompanion schedulerEventToCompanion(SchedulerEvent event) =>
    SchedulerEventsCompanion.insert(
      id: event.id,
      operationId: event.operationId,
      elementId: Value<String?>(event.element?.id),
      elementType: Value<int?>(event.element?.type.index),
      eventType: event.eventType.wireName,
      occurredAtUtc: toEpochMs(event.occurredAtUtc),
      studyDay: event.studyDay.epochDay,
      studyDayZoneId: event.studyDay.zoneId,
      schedulerName: Value<String?>(event.schedulerName),
      schedulerVersion: Value<String?>(event.schedulerVersion),
      policyVersion: event.policyVersion,
      stateBefore: Value<String?>(event.stateBefore),
      stateAfter: Value<String?>(event.stateAfter),
      algorithmicDueBefore: Value<String?>(event.algorithmicDueBefore),
      algorithmicDueAfter: Value<String?>(event.algorithmicDueAfter),
      undoesEventId: Value<String?>(event.undoesEventId),
      batchId: Value<String?>(event.batchId),
      metadataJson: Value<String?>(
        event.metadata == null ? null : jsonEncode(event.metadata),
      ),
    );

/// Encodes a block's content spans as JSON pairs.
String encodeContentSpans(List<Utf16Span> spans) => jsonEncode(<List<int>>[
  for (final span in spans) <int>[span.start, span.end],
]);

/// Decodes content spans written by [encodeContentSpans].
List<Utf16Span> decodeContentSpans(String json) {
  final decoded = jsonDecode(json) as List<Object?>;
  return <Utf16Span>[
    for (final entry in decoded)
      Utf16Span(
        (entry! as List<Object?>)[0]! as int,
        (entry as List<Object?>)[1]! as int,
      ),
  ];
}

/// Domain [Source] from its row.
Source sourceFromRow(SourceRow row) => Source(
  id: row.id,
  title: row.title,
  markdown: row.markdown,
  contentHash: row.contentHash,
  wordCount: row.wordCount,
  importedAtUtc: fromEpochMs(row.importedAtUtc),
  resume: ResumePosition(
    marker: _anchorOrNull(row.markerUtf8, row.markerRevision),
    softPosition: _anchorOrNull(row.softUtf8, row.softRevision),
  ),
  contentRevision: row.contentRevision,
);

/// Row companion for inserting or replacing a [Source].
SourcesCompanion sourceToCompanion(Source source, {int revision = 1}) =>
    SourcesCompanion.insert(
      id: source.id,
      title: source.title,
      markdown: source.markdown,
      contentHash: source.contentHash,
      wordCount: source.wordCount,
      importedAtUtc: toEpochMs(source.importedAtUtc),
      markerUtf8: Value<int?>(source.resume.marker?.utf8Offset),
      markerRevision: Value<int?>(source.resume.marker?.contentRevision),
      softUtf8: Value<int?>(source.resume.softPosition?.utf8Offset),
      softRevision: Value<int?>(source.resume.softPosition?.contentRevision),
      contentRevision: Value<int>(source.contentRevision),
      revision: Value<int>(revision),
    );

/// Domain [Block] from its row.
Block blockFromRow(BlockRow row) => Block(
  id: row.id,
  index: row.idx,
  type: BlockType.values[row.type],
  raw: row.raw,
  sourceStartUtf8: row.startUtf8,
  sourceEndUtf8: row.endUtf8,
  sourceStartUtf16: row.startUtf16,
  contentSpans: decodeContentSpans(row.contentSpans),
  headingLevel: row.headingLevel,
  codeLanguage: row.codeLanguage,
  isOrderedListItem: row.ordered,
  listMarker: row.listMarker,
  listDepth: row.listDepth,
  quoteDepth: row.quoteDepth,
);

/// Row companion for a derived [Block].
BlocksCompanion blockToCompanion(Block block, String sourceId) =>
    BlocksCompanion.insert(
      id: block.id,
      sourceId: sourceId,
      idx: block.index,
      type: block.type.index,
      raw: block.raw,
      startUtf8: block.sourceStartUtf8,
      endUtf8: block.sourceEndUtf8,
      startUtf16: block.sourceStartUtf16,
      contentSpans: encodeContentSpans(block.contentSpans),
      headingLevel: Value<int?>(block.headingLevel),
      codeLanguage: Value<String?>(block.codeLanguage),
      ordered: Value<bool>(block.isOrderedListItem),
      listMarker: Value<String?>(block.listMarker),
      listDepth: Value<int>(block.listDepth),
      quoteDepth: Value<int>(block.quoteDepth),
    );

/// Rebuilds a [Document] from stored rows rather than re-parsing.
///
/// Blocks are immutable derivations, so reading them back is both faster and
/// safer than parsing again: a future parser change can never silently move
/// the offsets that existing extracts point at.
Document documentFromRows(SourceRow source, List<BlockRow> blocks) => Document(
  sourceId: source.id,
  markdown: source.markdown,
  blocks: <Block>[for (final row in blocks) blockFromRow(row)],
  contentRevision: source.contentRevision,
);

/// Domain [Extract] from its row.
Extract extractFromRow(ExtractRow row) => Extract(
  id: row.id,
  markdown: row.markdown,
  provenance: Provenance(
    sourceId: row.sourceId,
    parentId: row.parentId,
    hasSourceAsParent: row.parentIsSource,
    startAnchor: ReaderAnchor(
      utf8Offset: row.startUtf8,
      contentRevision: row.anchorRevision,
    ),
    endAnchor: ReaderAnchor(
      utf8Offset: row.endUtf8,
      contentRevision: row.anchorRevision,
    ),
    selectedTextHash: row.selectedTextHash,
    state: ProvenanceState.values[row.provenanceState],
  ),
  createdAtUtc: fromEpochMs(row.createdAtUtc),
  editedAtUtc: row.editedAtUtc == null ? null : fromEpochMs(row.editedAtUtc!),
  contentRevision: row.contentRevision,
);

/// Row companion for an [Extract].
ExtractsCompanion extractToCompanion(Extract extract) {
  final provenance = extract.provenance;
  return ExtractsCompanion.insert(
    id: extract.id,
    markdown: extract.markdown,
    sourceId: provenance.sourceId,
    parentId: provenance.parentId,
    parentIsSource: provenance.hasSourceAsParent,
    startUtf8: provenance.startUtf8,
    endUtf8: provenance.endUtf8,
    anchorRevision: Value<int>(provenance.contentRevision),
    provenanceState: Value<int>(provenance.state.index),
    selectedTextHash: provenance.selectedTextHash,
    createdAtUtc: toEpochMs(extract.createdAtUtc),
    editedAtUtc: Value<int?>(
      extract.editedAtUtc == null ? null : toEpochMs(extract.editedAtUtc!),
    ),
    contentRevision: Value<int>(extract.contentRevision),
  );
}

/// Domain [Card] from its row.
Card cardFromRow(CardRow row) => Card(
  id: row.id,
  parent: cardParentFromRow(row),
  kind: CardKind.values[row.kind],
  front: row.front,
  back: row.back,
  clozeOrdinal: row.clozeOrdinal,
  createdAtUtc: fromEpochMs(row.createdAtUtc),
  editedAtUtc: row.editedAtUtc == null ? null : fromEpochMs(row.editedAtUtc!),
);

/// The sole parent a card row points at, or null for a standalone card.
CardParent? cardParentFromRow(CardRow row) {
  final String? id = row.parentElementId;
  if (id == null) return null;
  return row.parentElementType == ElementType.extract.index
      ? CardParent.extract(id)
      : CardParent.source(id);
}

/// Row companion for a [Card].
CardsCompanion cardToCompanion(Card card) => CardsCompanion.insert(
  id: card.id,
  parentElementId: Value<String?>(card.parent?.id),
  parentElementType: Value<int?>(
    card.parent == null
        ? null
        : (card.parent!.isSource
              ? ElementType.source.index
              : ElementType.extract.index),
  ),
  kind: card.kind.index,
  front: card.front,
  back: card.back,
  clozeOrdinal: Value<int?>(card.clozeOrdinal),
  createdAtUtc: toEpochMs(card.createdAtUtc),
  editedAtUtc: Value<int?>(
    card.editedAtUtc == null ? null : toEpochMs(card.editedAtUtc!),
  ),
);

/// Domain [ElementSchedule] from its row.
ElementSchedule scheduleFromRow(ScheduleRow row) => ElementSchedule(
  ref: ElementRef(id: row.elementId, type: ElementType.values[row.elementType]),
  priority: PriorityRank(row.priorityKey),
  lifecycle: ElementLifecycle.values[row.lifecycle],
  dueDay: studyDayFromEpochDay(row.dueDay, row.zoneId),
  originalDueDay: studyDayFromEpochDay(row.originalDueDay, row.zoneId),
  rootId: row.rootId,
  parentElementId: row.parentElementId,
  ordinal: row.ordinal,
  createdAtUtc: row.createdAtUtc == null
      ? null
      : fromEpochMs(row.createdAtUtc!),
  updatedAtUtc: row.updatedAtUtc == null
      ? null
      : fromEpochMs(row.updatedAtUtc!),
  revision: row.revision,
  legacyDueProvenance: LegacyDueProvenance.values[row.legacyDueProvenance],
);

/// Row companion for an [ElementSchedule].
ElementSchedulesCompanion scheduleToCompanion(ElementSchedule schedule) =>
    ElementSchedulesCompanion.insert(
      elementId: schedule.ref.id,
      elementType: schedule.ref.type.index,
      priorityKey: schedule.priority.orderKey,
      lifecycle: schedule.lifecycle.index,
      dueDay: schedule.dueDay.epochDay,
      originalDueDay: schedule.originalDueDay.epochDay,
      rootId: Value<String?>(schedule.rootId),
      parentElementId: Value<String?>(schedule.parentElementId),
      ordinal: Value<int?>(schedule.ordinal),
      createdAtUtc: Value<int?>(schedule.createdAtUtc?.millisecondsSinceEpoch),
      updatedAtUtc: Value<int?>(schedule.updatedAtUtc?.millisecondsSinceEpoch),
      revision: Value<int>(schedule.revision),
      legacyDueProvenance: Value<int>(schedule.legacyDueProvenance.index),
      zoneId: schedule.dueDay.zoneId,
    );

/// Domain [TopicState] from its two rows.
TopicState topicStateFromRows(TopicStateRow row, ElementSchedule schedule) =>
    TopicState(
      schedule: schedule,
      status: Sm20ElementStatus.values[row.status],
      repetitionCount: row.repetitionCount,
      lapseCount: row.lapseCount,
      storedInterval: row.storedInterval,
      lastReviewDay: row.lastReviewDay == null
          ? null
          : studyDayFromEpochDay(row.lastReviewDay!, schedule.dueDay.zoneId),
      aFactorRaw: real48FromHex(row.aFactorRaw),
      lastIntervalRatioRaw: real48FromHex(row.lastIntervalRatioRaw),
      historyBlockId: row.historyBlockId,
      recentPostponementCount: row.recentPostponementCount,
      totalPostponementCount: row.totalPostponementCount,
      learningControl: row.learningControl,
      encountersSinceLastCard: row.encountersSinceLastCard,
      revision: row.revision,
    );

/// Row companion for a topic's pacing state.
TopicStatesCompanion topicStateToCompanion(TopicState topic) =>
    TopicStatesCompanion.insert(
      elementId: topic.ref.id,
      elementType: topic.ref.type.index,
      status: topic.status.index,
      repetitionCount: Value<int>(topic.repetitionCount),
      lapseCount: Value<int>(topic.lapseCount),
      storedInterval: Value<int>(topic.storedInterval),
      lastReviewDay: Value<int?>(topic.lastReviewDay?.epochDay),
      aFactorRaw: Value<String>(topic.aFactorRaw.toString()),
      lastIntervalRatioRaw: Value<String>(
        topic.lastIntervalRatioRaw.toString(),
      ),
      historyBlockId: Value<int>(topic.historyBlockId),
      recentPostponementCount: Value<int>(topic.recentPostponementCount),
      totalPostponementCount: Value<int>(topic.totalPostponementCount),
      learningControl: Value<int>(topic.learningControl),
      encountersSinceLastCard: Value<int>(topic.encountersSinceLastCard),
      revision: Value<int>(topic.revision),
    );

/// Domain [ReviewLogEntry] from its append-only row.
ReviewLogEntry reviewLogFromRow(RevlogRow row) => ReviewLogEntry(
  id: row.id,
  operationId: row.operationId,
  ref: ElementRef(id: row.elementId, type: ElementType.values[row.elementType]),
  eventType: ReviewLogEventType.fromValue(row.eventType),
  atUtc: fromEpochMs(row.atUtc),
  grade: row.grade,
  elapsedDays: row.elapsedDays,
  scheduledDays: row.scheduledDays,
  durationMs: row.durationMs,
  postponeCount: row.postponeCount,
  schedulerVersion: row.schedulerVersion,
  parametersVersion: row.parametersVersion,
  before: ReviewLogSnapshot(
    dueAtUtc: row.dueBeforeUtc == null ? null : fromEpochMs(row.dueBeforeUtc!),
    intervalDays: row.intervalBefore,
    aFactor: row.aFactorBefore,
    stability: row.stabilityBefore,
    difficulty: row.difficultyBefore,
    learningState: row.stateBefore,
    repetitionCount: row.repsBefore,
    lapses: row.lapsesBefore,
    priorityKey: row.priorityBefore,
    pressure: row.pressureBefore,
    readFraction: row.readFractionBefore,
    lifecycle: row.lifecycleBefore,
  ),
  after: ReviewLogSnapshot(
    dueAtUtc: row.dueAfterUtc == null ? null : fromEpochMs(row.dueAfterUtc!),
    intervalDays: row.intervalAfter,
    aFactor: row.aFactorAfter,
    stability: row.stabilityAfter,
    difficulty: row.difficultyAfter,
    learningState: row.stateAfter,
    priorityKey: row.priorityAfter,
    pressure: row.pressureAfter,
    readFraction: row.readFractionAfter,
    lifecycle: row.lifecycleAfter,
  ),
  metadata: row.metadataJson == null
      ? null
      : jsonDecode(row.metadataJson!) as Map<String, Object?>,
);

/// Row companion for one repetition-log entry.
RevlogEntriesCompanion reviewLogToCompanion(ReviewLogEntry entry) =>
    RevlogEntriesCompanion.insert(
      id: entry.id,
      operationId: entry.operationId,
      elementId: entry.ref.id,
      elementType: entry.ref.type.index,
      eventType: entry.eventType.value,
      atUtc: toEpochMs(entry.atUtc),
      grade: Value<int?>(entry.grade),
      elapsedDays: Value<double?>(entry.elapsedDays),
      scheduledDays: Value<double?>(entry.scheduledDays),
      durationMs: Value<int?>(entry.durationMs),
      postponeCount: Value<int?>(entry.postponeCount),
      dueBeforeUtc: Value<int?>(
        entry.before.dueAtUtc == null
            ? null
            : toEpochMs(entry.before.dueAtUtc!),
      ),
      dueAfterUtc: Value<int?>(
        entry.after.dueAtUtc == null ? null : toEpochMs(entry.after.dueAtUtc!),
      ),
      intervalBefore: Value<double?>(entry.before.intervalDays),
      intervalAfter: Value<double?>(entry.after.intervalDays),
      aFactorBefore: Value<double?>(entry.before.aFactor),
      aFactorAfter: Value<double?>(entry.after.aFactor),
      stabilityBefore: Value<double?>(entry.before.stability),
      stabilityAfter: Value<double?>(entry.after.stability),
      difficultyBefore: Value<double?>(entry.before.difficulty),
      difficultyAfter: Value<double?>(entry.after.difficulty),
      stateBefore: Value<int?>(entry.before.learningState),
      stateAfter: Value<int?>(entry.after.learningState),
      repsBefore: Value<int?>(entry.before.repetitionCount),
      lapsesBefore: Value<int?>(entry.before.lapses),
      priorityBefore: Value<String?>(entry.before.priorityKey),
      priorityAfter: Value<String?>(entry.after.priorityKey),
      pressureBefore: Value<double?>(entry.before.pressure),
      pressureAfter: Value<double?>(entry.after.pressure),
      readFractionBefore: Value<double?>(entry.before.readFraction),
      readFractionAfter: Value<double?>(entry.after.readFraction),
      lifecycleBefore: Value<int?>(entry.before.lifecycle),
      lifecycleAfter: Value<int?>(entry.after.lifecycle),
      schedulerVersion: Value<String?>(entry.schedulerVersion),
      parametersVersion: Value<String?>(entry.parametersVersion),
      metadataJson: Value<String?>(
        entry.metadata == null ? null : jsonEncode(entry.metadata),
      ),
    );

/// Domain FSRS memory from its row.
CardMemory cardMemoryFromRow(CardMemoryRow row) => CardMemory(
  cardId: row.cardId,
  state: CardLearningState.fromValue(row.state),
  step: row.step,
  stability: row.stability,
  difficulty: row.difficulty,
  repetitionCount: row.reps,
  lapses: row.lapses,
  lastReviewAtUtc: row.lastReviewUtc == null
      ? null
      : fromEpochMs(row.lastReviewUtc!),
  dueAtUtc: fromEpochMs(row.dueAtUtc),
  originalDueAtUtc: fromEpochMs(row.originalDueAtUtc),
  schedulerVersion: row.schedulerVersion,
  parametersVersion: row.parametersVersion,
  postponeCount: row.postponeCount,
  scheduledDays: row.scheduledDays,
  schedulerName: row.schedulerName,
  revision: row.revision,
);

/// Row companion for inserting or replacing a card's FSRS memory.
CardMemoriesCompanion cardMemoryToCompanion(CardMemory memory) =>
    CardMemoriesCompanion.insert(
      cardId: memory.cardId,
      stability: Value<double?>(memory.stability),
      difficulty: Value<double?>(memory.difficulty),
      state: memory.state.value,
      step: Value<int?>(memory.step),
      reps: Value<int>(memory.repetitionCount),
      lapses: Value<int>(memory.lapses),
      lastReviewUtc: Value<int?>(
        memory.lastReviewAtUtc == null
            ? null
            : toEpochMs(memory.lastReviewAtUtc!),
      ),
      dueAtUtc: toEpochMs(memory.dueAtUtc),
      originalDueAtUtc: toEpochMs(memory.originalDueAtUtc),
      postponeCount: Value<int>(memory.postponeCount),
      schedulerVersion: memory.schedulerVersion,
      parametersVersion: memory.parametersVersion,
      schedulerName: Value<String>(memory.schedulerName),
      scheduledDays: Value<double?>(memory.scheduledDays),
      fsrsStateJson: Value<String>(memory.canonicalFsrsJson()),
      revision: Value<int>(memory.revision),
    );

/// Domain review event from its append-only row.
ReviewRecord reviewRecordFromRow(ReviewEventRow row) => ReviewRecord(
  operationId: row.operationId,
  cardId: row.cardId,
  rating: CardRating.fromValue(row.rating),
  reviewedAtUtc: fromEpochMs(row.reviewedAtUtc),
  elapsedMs: row.elapsedMs,
  preStateJson: row.preStateJson,
  postStateJson: row.postStateJson,
  schedulerVersion: row.schedulerVersion,
  parametersVersion: row.parametersVersion,
  isPractice: row.isPractice,
);

/// Row companion for a lossless review event. The operation id is also the
/// event id: one user operation can commit at most one card grade.
ReviewEventsCompanion reviewRecordToCompanion(ReviewRecord record) =>
    ReviewEventsCompanion.insert(
      id: record.operationId,
      cardId: record.cardId,
      reviewedAtUtc: toEpochMs(record.reviewedAtUtc),
      rating: record.rating.value,
      preStateJson: record.preStateJson,
      postStateJson: record.postStateJson,
      elapsedMs: Value<int?>(record.elapsedMs),
      schedulerVersion: record.schedulerVersion,
      parametersVersion: record.parametersVersion,
      isPractice: Value<bool>(record.isPractice),
      operationId: record.operationId,
    );

/// Domain [SourceEdit] from its row.
SourceEdit sourceEditFromRow(SourceEditRow row) => SourceEdit(
  id: row.id,
  sourceId: row.sourceId,
  contentRevision: row.contentRevision,
  splice: TextSplice.normalized(
    startUtf8: row.startUtf8,
    endUtf8: row.endUtf8,
    inserted: row.insertedText,
  ),
  removedText: row.removedText,
  appliedAtUtc: fromEpochMs(row.appliedAtUtc),
  operationId: row.operationId,
  isUndo: row.isUndo,
  restore: SourceEditRestore.decode(row.restoreJson),
);

/// Row companion for a [SourceEdit].
SourceEditsCompanion sourceEditToCompanion(SourceEdit edit) =>
    SourceEditsCompanion.insert(
      id: edit.id,
      sourceId: edit.sourceId,
      contentRevision: edit.contentRevision,
      startUtf8: edit.splice.startUtf8,
      endUtf8: edit.splice.endUtf8,
      removedText: edit.removedText,
      insertedText: edit.splice.inserted,
      isUndo: Value<bool>(edit.isUndo),
      restoreJson: Value<String>(edit.restore.encode()),
      appliedAtUtc: toEpochMs(edit.appliedAtUtc),
      operationId: edit.operationId,
    );

ReaderAnchor? _anchorOrNull(int? offset, int? contentRevision) =>
    offset == null || contentRevision == null
    ? null
    : ReaderAnchor(utf8Offset: offset, contentRevision: contentRevision);
