/// Transactional creation of scheduled image-occlusion cards.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/occlusion/occlusion_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/occlusion_repository.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';
import 'package:incremental_reader/storage/files/source_asset_file_store.dart';

const String kOcclusionCardsCreatedType = 'occlusion.cards_created';
const String kOcclusionCardEditedType = 'occlusion.card_edited';

/// Saves image bytes and creates every card inside one database transaction.
final class OcclusionCommandRunner {
  OcclusionCommandRunner({
    required ContentRepository content,
    required LearningRepository learning,
    required OcclusionRepository occlusions,
    required SearchRepository search,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required SourceAssetFileStore files,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _occlusions = occlusions,
       _search = search,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _files = files,
       _clock = clock,
       _ids = ids,
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final OcclusionRepository _occlusions;
  final SearchRepository _search;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final SourceAssetFileStore _files;
  final Clock _clock;
  final IdGenerator _ids;
  final DiagnosticSink _diagnostics;

  Future<Result<List<Card>>> create(CreateOcclusionCards command) async {
    if (command.regions.isEmpty) {
      return const Err<List<Card>>(ValidationFailure('draw at least one mask'));
    }
    try {
      final stored = await _files.saveBytes(command.image.bytes);
      if (stored.sha256 != command.image.sha256) {
        return const Err<List<Card>>(
          ValidationFailure('the image changed while it was imported'),
        );
      }
      return await _transactions.run<Result<List<Card>>>(
        () => _createInsideTransaction(command),
      );
    } on Object catch (error, stackTrace) {
      final failure = UnexpectedFailure(
        'command $kOcclusionCardsCreatedType failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kOcclusionCardsCreatedType,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<List<Card>>(failure);
    }
  }

  /// Saves a mask edit without touching the card's schedule or memory.
  Future<Result<Card>> edit(EditOcclusionCard command) async {
    if (command.regions.isEmpty) {
      return const Err<Card>(ValidationFailure('draw at least one mask'));
    }
    try {
      return await _transactions.run<Result<Card>>(
        () => _editInsideTransaction(command),
      );
    } on Object catch (error, stackTrace) {
      final failure = UnexpectedFailure(
        'command $kOcclusionCardEditedType failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kOcclusionCardEditedType,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<Card>(failure);
    }
  }

  Future<Result<Card>> _editInsideTransaction(EditOcclusionCard command) async {
    if (await _learning.hasActivity(
      command.operationId.value,
      kOcclusionCardEditedType,
    )) {
      return Err<Card>(
        ConflictFailure('operation ${command.operationId} already applied'),
      );
    }
    final Card? card = await _content.findCard(command.cardId);
    final CardOcclusion? occlusion = await _occlusions.findCardOcclusion(
      command.cardId,
    );
    if (card == null || occlusion == null) {
      return Err<Card>(
        NotFoundFailure(
          'no such image occlusion',
          entity: 'card',
          id: command.cardId,
        ),
      );
    }
    if (card.type != CardType.imageOcclusion) {
      return const Err<Card>(
        ValidationFailure('this card is not an image occlusion'),
      );
    }
    final Card updated = card.copyWith(
      front: command.header.trim(),
      back: command.remarks.trim(),
      editedAtUtc: command.timestampUtc,
    );
    await _content.updateCard(updated);
    await _occlusions.updateCardOcclusion(_editedOcclusion(command, occlusion));
    await _recordOcclusionEdit(command, card.id);
    await _transfer.advanceGeneration();
    return Ok<Card>(updated);
  }

  CardOcclusion _editedOcclusion(
    EditOcclusionCard command,
    CardOcclusion current,
  ) {
    final bool stillHasActiveRegion = command.regions.any(
      (OcclusionRegion region) => region.id == current.activeRegionId,
    );
    final String? activeRegionId = command.mode == OcclusionMode.hideAllGuessAll
        ? null
        : stillHasActiveRegion
        ? current.activeRegionId
        : command.regions.first.id;
    return CardOcclusion(
      cardId: current.cardId,
      imageSha256: current.imageSha256,
      imageMime: current.imageMime,
      imageWidthPx: current.imageWidthPx,
      imageHeightPx: current.imageHeightPx,
      regions: List<OcclusionRegion>.unmodifiable(command.regions),
      activeRegionId: activeRegionId,
      mode: command.mode,
    );
  }

  Future<void> _recordOcclusionEdit(EditOcclusionCard command, String cardId) =>
      _learning.appendActivity(
        ActivityRecord(
          id: _ids.newId(),
          operationId: command.operationId.value,
          type: kOcclusionCardEditedType,
          atUtc: command.timestampUtc,
          ref: ElementRef(id: cardId, type: ElementType.card),
          metadata: <String, Object?>{'masks': command.regions.length},
        ),
      );

  Future<Result<List<Card>>> _createInsideTransaction(
    CreateOcclusionCards command,
  ) async {
    if (await _learning.hasActivity(
      command.operationId.value,
      kOcclusionCardsCreatedType,
    )) {
      return Err<List<Card>>(
        ConflictFailure('operation ${command.operationId} already applied'),
      );
    }
    final now = _clock.nowUtc();
    final activeRegions = command.mode == OcclusionMode.hideAllGuessAll
        ? const <OcclusionRegion?>[null]
        : <OcclusionRegion?>[...command.regions];
    final cards = <Card>[
      for (var index = 0; index < activeRegions.length; index++)
        Card.imageOcclusion(
          id: _ids.newId(),
          parent: command.parent,
          header: command.header.trim(),
          remarks: command.remarks.trim(),
          createdAtUtc: now,
        ),
    ];
    final parentSchedule = await _parentSchedule(command.parent);
    if (command.parent != null && parentSchedule == null) {
      return const Err<List<Card>>(
        NotFoundFailure(
          'the card parent has no schedule',
          entity: 'schedule',
          id: 'parent',
        ),
      );
    }
    final scale = await _context.priorityScale();
    final ranks = parentSchedule == null
        ? _standaloneRanks(cards.length, scale)
        : PriorityRank.spread(
            count: cards.length,
            before: parentSchedule.priority,
            after: scale.neighbourBelow(parentSchedule.priority),
          );
    final today = await _context.today();
    await _content.insertCards(cards);
    await _occlusions.insertCardOcclusions(<CardOcclusion>[
      for (var index = 0; index < cards.length; index++)
        CardOcclusion(
          cardId: cards[index].id,
          imageSha256: command.image.sha256,
          imageMime: command.image.mime,
          imageWidthPx: command.image.widthPx,
          imageHeightPx: command.image.heightPx,
          regions: List<OcclusionRegion>.unmodifiable(command.regions),
          activeRegionId: activeRegions[index]?.id,
          mode: command.mode,
        ),
    ]);
    final refs = <ElementRef>[];
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      final ref = ElementRef(id: card.id, type: ElementType.card);
      refs.add(ref);
      await _learning.insertCardState(
        CardState(
          schedule: ElementSchedule(
            ref: ref,
            priority: ranks[index],
            lifecycle: ElementLifecycle.active,
            dueDay: today,
            originalDueDay: today,
            rootId: parentSchedule?.rootId ?? command.parent?.id,
            parentElementId: command.parent?.id,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
          memory: CardMemory.newCard(cardId: card.id, dueAtUtc: now),
        ),
      );
      await _search.saveDocument(
        SearchDocument(
          ref: ref,
          title: 'Image occlusion',
          body: '${card.front}\n${card.back}',
          sourceId: parentSchedule?.rootId ?? command.parent?.id,
          updatedAtUtc: now,
        ),
      );
    }
    final runtime = await _context.runtimeState();
    await _context.saveRuntimeState(
      runtime.copyWith(pending: <ElementRef>[...runtime.pending, ...refs]),
    );
    await _learning.appendActivity(
      ActivityRecord(
        id: _ids.newId(),
        operationId: command.operationId.value,
        type: kOcclusionCardsCreatedType,
        atUtc: command.timestampUtc,
        ref: command.parent == null
            ? null
            : ElementRef(
                id: command.parent!.id,
                type: _elementType(command.parent!.type),
              ),
        metadata: <String, Object?>{'cards': cards.length},
      ),
    );
    await _transfer.advanceGeneration();
    _diagnostics.record(
      DiagnosticEvent(
        level: DiagnosticLevel.info,
        name: kOcclusionCardsCreatedType,
        timestampUtc: now,
        operationId: command.operationId,
        fields: <String, Object?>{'cards': cards.length},
      ),
    );
    return Ok<List<Card>>(List<Card>.unmodifiable(cards));
  }

  Future<ElementSchedule?> _parentSchedule(CardParent? parent) => parent == null
      ? Future<ElementSchedule?>.value()
      : _learning.findSchedule(
          ElementRef(id: parent.id, type: _elementType(parent.type)),
        );

  ElementType _elementType(CardParentType type) => switch (type) {
    CardParentType.source => ElementType.source,
    CardParentType.extract => ElementType.extract,
    CardParentType.video => ElementType.video,
  };

  List<PriorityRank> _standaloneRanks(int count, PriorityScale scale) {
    final first = scale.rankAtPercent(50);
    final after = scale.neighbourBelow(first);
    final ranks = <PriorityRank>[first];
    while (ranks.length < count) {
      ranks.add(PriorityRank.between(ranks.last, after));
    }
    return ranks;
  }
}
