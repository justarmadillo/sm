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

/// The parent a card row points at, or null for a standalone card.
///
/// The table's CHECK guarantees at most one of the two columns is set, so the
/// order of these tests is a formality rather than a precedence rule.
CardParent? cardParentFromRow(CardRow row) {
  final extractId = row.extractId;
  if (extractId != null) return CardParent.extract(extractId);
  final sourceId = row.sourceId;
  if (sourceId != null) return CardParent.source(sourceId);
  return null;
}

/// Row companion for a [Card].
CardsCompanion cardToCompanion(Card card) => CardsCompanion.insert(
  id: card.id,
  extractId: Value<String?>(card.extractId),
  sourceId: Value<String?>(card.sourceId),
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
      zoneId: schedule.dueDay.zoneId,
    );

/// Row companion for a topic's pacing state.
TopicStatesCompanion topicStateToCompanion(TopicState topic) =>
    TopicStatesCompanion.insert(
      elementId: topic.ref.id,
      elementType: topic.ref.type.index,
      profileId: topic.profileId,
      stepIndex: topic.stepIndex,
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
      schedulerVersion: memory.schedulerVersion,
      parametersVersion: memory.parametersVersion,
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
