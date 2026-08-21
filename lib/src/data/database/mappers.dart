/// Conversion between Drift rows and domain values.
///
/// The only place row shapes and domain shapes meet. Enums are persisted by
/// index, so their declaration order is now part of the on-disk format:
/// reorder an enum and every stored row changes meaning. Append, never insert.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/content/block.dart';
import '../../domain/content/block_content.dart';
import '../../domain/content/card.dart';
import '../../domain/content/document.dart';
import '../../domain/content/extract.dart';
import '../../domain/content/reader_anchor.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/schedule_adjustment.dart';
import '../../domain/scheduling/scheduler_event.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import 'app_database.dart';

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

/// Domain presentation adjustment from its audit-preserving row.
ScheduleAdjustment scheduleAdjustmentFromRow(ScheduleAdjustmentRow row) =>
    ScheduleAdjustment(
      id: row.id,
      element: ElementRef(
        id: row.elementId,
        type: ElementType.values[row.elementType],
      ),
      mode: ScheduleAdjustmentMode.values[row.mode],
      reason: ScheduleAdjustmentReason.values[row.reason],
      notBeforeAtUtc: row.notBeforeAtUtc == null
          ? null
          : fromEpochMs(row.notBeforeAtUtc!),
      notBeforeStudyDay: row.notBeforeStudyDay == null
          ? null
          : studyDayFromEpochDay(
              row.notBeforeStudyDay!,
              row.zoneId ?? row.createdZoneId,
            ),
      scheduledForAtUtc: row.scheduledForAtUtc == null
          ? null
          : fromEpochMs(row.scheduledForAtUtc!),
      scheduledForStudyDay: row.scheduledForStudyDay == null
          ? null
          : studyDayFromEpochDay(
              row.scheduledForStudyDay!,
              row.zoneId ?? row.createdZoneId,
            ),
      operationId: row.operationId,
      batchId: row.batchId,
      policyVersion: row.policyVersion,
      createdAtUtc: fromEpochMs(row.createdAtUtc),
      createdStudyDay: studyDayFromEpochDay(
        row.createdStudyDay,
        row.createdZoneId,
      ),
      clearedAtUtc: row.clearedAtUtc == null
          ? null
          : fromEpochMs(row.clearedAtUtc!),
      clearedByOperationId: row.clearedByOperationId,
    );

ScheduleAdjustmentsCompanion scheduleAdjustmentToCompanion(
  ScheduleAdjustment adjustment,
) => ScheduleAdjustmentsCompanion.insert(
  id: adjustment.id,
  elementId: adjustment.element.id,
  elementType: adjustment.element.type.index,
  mode: adjustment.mode.index,
  reason: adjustment.reason.index,
  notBeforeAtUtc: Value<int?>(
    adjustment.notBeforeAtUtc == null
        ? null
        : toEpochMs(adjustment.notBeforeAtUtc!),
  ),
  notBeforeStudyDay: Value<int?>(adjustment.notBeforeStudyDay?.epochDay),
  scheduledForAtUtc: Value<int?>(
    adjustment.scheduledForAtUtc == null
        ? null
        : toEpochMs(adjustment.scheduledForAtUtc!),
  ),
  scheduledForStudyDay: Value<int?>(adjustment.scheduledForStudyDay?.epochDay),
  zoneId: Value<String?>(
    adjustment.notBeforeStudyDay?.zoneId ??
        adjustment.scheduledForStudyDay?.zoneId,
  ),
  operationId: adjustment.operationId,
  batchId: Value<String?>(adjustment.batchId),
  policyVersion: adjustment.policyVersion,
  createdAtUtc: toEpochMs(adjustment.createdAtUtc),
  createdStudyDay: adjustment.createdStudyDay.epochDay,
  createdZoneId: adjustment.createdStudyDay.zoneId,
  clearedAtUtc: Value<int?>(
    adjustment.clearedAtUtc == null
        ? null
        : toEpochMs(adjustment.clearedAtUtc!),
  ),
  clearedByOperationId: Value<String?>(adjustment.clearedByOperationId),
);

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
  adjustmentsBefore: row.adjustmentsBefore,
  adjustmentsAfter: row.adjustmentsAfter,
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
      adjustmentsBefore: Value<String?>(event.adjustmentsBefore),
      adjustmentsAfter: Value<String?>(event.adjustmentsAfter),
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
  pace: ReadingPace.values[row.pace],
  resume: ResumePosition(
    marker: _anchorOrNull(row.markerBlockId, row.markerOffset),
    softPosition: _anchorOrNull(row.softBlockId, row.softOffset),
  ),
  folderId: row.folderId,
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
      pace: Value<int>(source.pace.index),
      markerBlockId: Value<String?>(source.resume.marker?.blockId),
      markerOffset: Value<int?>(source.resume.marker?.utf8Offset),
      softBlockId: Value<String?>(source.resume.softPosition?.blockId),
      softOffset: Value<int?>(source.resume.softPosition?.utf8Offset),
      folderId: Value<String?>(source.folderId),
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
  ordered: row.ordered,
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
      ordered: Value<bool>(block.ordered),
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
);

/// Domain [Extract] from its row.
Extract extractFromRow(ExtractRow row) => Extract(
  id: row.id,
  markdown: row.markdown,
  provenance: Provenance(
    sourceId: row.sourceId,
    parentId: row.parentId,
    parentIsSource: row.parentIsSource,
    startAnchor: ReaderAnchor(
      blockId: row.startBlockId,
      utf8Offset: row.startOffset,
    ),
    endAnchor: ReaderAnchor(blockId: row.endBlockId, utf8Offset: row.endOffset),
    selectedTextHash: row.selectedTextHash,
  ),
  createdAtUtc: fromEpochMs(row.createdAtUtc),
  editedAtUtc: row.editedAtUtc == null ? null : fromEpochMs(row.editedAtUtc!),
);

/// Row companion for an [Extract].
ExtractsCompanion extractToCompanion(Extract extract) {
  final provenance = extract.provenance;
  return ExtractsCompanion.insert(
    id: extract.id,
    markdown: extract.markdown,
    sourceId: provenance.sourceId,
    parentId: provenance.parentId,
    parentIsSource: provenance.parentIsSource,
    startBlockId: provenance.startAnchor.blockId,
    startOffset: provenance.startAnchor.utf8Offset,
    endBlockId: provenance.endAnchor.blockId,
    endOffset: provenance.endAnchor.utf8Offset,
    selectedTextHash: provenance.selectedTextHash,
    createdAtUtc: toEpochMs(extract.createdAtUtc),
    editedAtUtc: Value<int?>(
      extract.editedAtUtc == null ? null : toEpochMs(extract.editedAtUtc!),
    ),
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
  deferredUntil: row.deferredUntil == null
      ? null
      : studyDayFromEpochDay(row.deferredUntil!, row.zoneId),
  deferralKind: DeferralKind.values[row.deferralKind],
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
      deferredUntil: Value<int?>(schedule.deferredUntil?.epochDay),
      deferralKind: Value<int>(schedule.deferralKind.index),
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
      profileId: row.profileId,
      stepIndex: row.stepIndex,
      schedulerKind: TopicSchedulerKind.parse(row.schedulerKind),
      schedulerVersion: row.schedulerVersion,
      intervalDays: row.intervalDays,
      aFactor: row.aFactor,
      yieldEwma: row.yieldEwma,
      encounters: row.encounters,
      postponeCount: row.postponeCount,
      encountersSinceLastCard: row.encountersSinceLastCard,
      lastEncounterDay: row.lastEncounterDay == null
          ? null
          : studyDayFromEpochDay(row.lastEncounterDay!, schedule.dueDay.zoneId),
      policyInputSnapshot: row.policyInputSnapshot == null
          ? null
          : (jsonDecode(row.policyInputSnapshot!) as Map<String, Object?>),
      revision: row.revision,
    );

/// Row companion for a topic's pacing state.
TopicStatesCompanion topicStateToCompanion(TopicState topic) =>
    TopicStatesCompanion.insert(
      elementId: topic.ref.id,
      elementType: topic.ref.type.index,
      profileId: topic.profileId,
      stepIndex: topic.stepIndex,
      intervalDays: Value<double>(topic.intervalDays),
      aFactor: Value<double>(topic.aFactor),
      yieldEwma: Value<double>(topic.yieldEwma),
      encounters: Value<int>(topic.encounters),
      postponeCount: Value<int>(topic.postponeCount),
      encountersSinceLastCard: Value<int>(topic.encountersSinceLastCard),
      lastEncounterDay: Value<int?>(topic.lastEncounterDay?.epochDay),
      algorithmDueDay: Value<int>(topic.schedule.algorithmicDueDay.epochDay),
      schedulerKind: Value<String>(topic.schedulerKind.storageName),
      schedulerVersion: Value<String>(topic.schedulerVersion),
      policyInputSnapshot: Value<String?>(
        topic.policyInputSnapshot == null
            ? null
            : jsonEncode(topic.policyInputSnapshot),
      ),
      revision: Value<int>(topic.revision),
    );

/// Domain [RevlogEntry] from its append-only row.
RevlogEntry revlogFromRow(RevlogRow row) => RevlogEntry(
  id: row.id,
  operationId: row.operationId,
  ref: ElementRef(id: row.elementId, type: ElementType.values[row.elementType]),
  eventType: RevlogEventType.fromValue(row.eventType),
  atUtc: fromEpochMs(row.atUtc),
  grade: row.grade,
  elapsedDays: row.elapsedDays,
  scheduledDays: row.scheduledDays,
  durationMs: row.durationMs,
  postponeCount: row.postponeCount,
  schedulerVersion: row.schedulerVersion,
  parametersVersion: row.parametersVersion,
  before: RevlogSnapshot(
    dueAtUtc: row.dueBeforeUtc == null ? null : fromEpochMs(row.dueBeforeUtc!),
    intervalDays: row.intervalBefore,
    aFactor: row.aFactorBefore,
    stability: row.stabilityBefore,
    difficulty: row.difficultyBefore,
    learningState: row.stateBefore,
    reps: row.repsBefore,
    lapses: row.lapsesBefore,
    priorityKey: row.priorityBefore,
    pressure: row.pressureBefore,
    readFraction: row.readFractionBefore,
    lifecycle: row.lifecycleBefore,
  ),
  after: RevlogSnapshot(
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
RevlogEntriesCompanion revlogToCompanion(RevlogEntry entry) =>
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
      repsBefore: Value<int?>(entry.before.reps),
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
  reps: row.reps,
  lapses: row.lapses,
  lastReviewAtUtc: row.lastReviewUtc == null
      ? null
      : fromEpochMs(row.lastReviewUtc!),
  dueAtUtc: fromEpochMs(row.dueAtUtc),
  originalDueAtUtc: fromEpochMs(row.originalDueAtUtc),
  deferredUntilUtc: row.deferredUntilUtc == null
      ? null
      : fromEpochMs(row.deferredUntilUtc!),
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
      reps: Value<int>(memory.reps),
      lapses: Value<int>(memory.lapses),
      lastReviewUtc: Value<int?>(
        memory.lastReviewAtUtc == null
            ? null
            : toEpochMs(memory.lastReviewAtUtc!),
      ),
      dueAtUtc: toEpochMs(memory.dueAtUtc),
      originalDueAtUtc: toEpochMs(memory.originalDueAtUtc),
      deferredUntilUtc: Value<int?>(
        memory.deferredUntilUtc == null
            ? null
            : toEpochMs(memory.deferredUntilUtc!),
      ),
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

ReaderAnchor? _anchorOrNull(String? blockId, int? offset) =>
    blockId == null || offset == null
    ? null
    : ReaderAnchor(blockId: blockId, utf8Offset: offset);
