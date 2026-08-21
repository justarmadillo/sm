/// Application boundary for batch Q&A and cloze formulation.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/content/card.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'formulation_commands.dart';

const String kCardsFormulatedKind = 'formulation.cards_created';

final class FormulationHandlers {
  FormulationHandlers({
    required ContentRepository content,
    required LearningRepository learning,
    required SearchRepository search,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _search = search,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final SearchRepository _search;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  Future<Result<List<Card>>> formulate(FormulateCards command) async {
    try {
      return await _transactions.run<Result<List<Card>>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kCardsFormulatedKind,
        )) {
          return Err<List<Card>>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }

        final parent = command.parent;
        ElementRef? parentRef;
        ElementSchedule? parentSchedule;
        if (parent != null) {
          final exists = parent.isExtract
              ? await _content.findExtract(parent.id) != null
              : await _content.findSource(parent.id) != null;
          final String entity = parent.isExtract ? 'extract' : 'source';
          if (!exists) {
            return Err<List<Card>>(
              NotFoundFailure('no such $entity', entity: entity, id: parent.id),
            );
          }
          parentRef = ElementRef(
            id: parent.id,
            type: parent.isExtract ? ElementType.extract : ElementType.source,
          );
          parentSchedule = await _learning.findSchedule(parentRef);
          if (parentSchedule == null) {
            return Err<List<Card>>(
              NotFoundFailure(
                'no schedule for that $entity',
                entity: 'schedule',
                id: parent.id,
              ),
            );
          }
        }
        if (command.drafts.isEmpty) {
          return const Err<List<Card>>(
            ValidationFailure('add at least one card'),
          );
        }

        final now = _clock.nowUtc();
        final cards = <Card>[];
        for (
          var draftIndex = 0;
          draftIndex < command.drafts.length;
          draftIndex++
        ) {
          final draft = command.drafts[draftIndex];
          switch (draft) {
            case QaCardDraft(:final question, :final answer):
              final cleanQuestion = question.trim();
              final cleanAnswer = answer.trim();
              if (cleanQuestion.isEmpty || cleanAnswer.isEmpty) {
                return Err<List<Card>>(
                  ValidationFailure(
                    'question and answer are both required',
                    field: 'drafts[$draftIndex]',
                  ),
                );
              }
              cards.add(
                Card.qa(
                  id: _ids.newId(),
                  parent: parent,
                  question: cleanQuestion,
                  answer: cleanAnswer,
                  createdAtUtc: now,
                ),
              );
            case ClozeCardDraft(:final text):
              final cleanText = text.trim();
              final deletions = parseClozeDeletions(cleanText);
              if (deletions.isEmpty ||
                  deletions.any(
                    (deletion) =>
                        deletion.ordinal < 1 || deletion.answer.trim().isEmpty,
                  )) {
                return Err<List<Card>>(
                  ValidationFailure(
                    'use canonical cloze text such as {{c1::answer}}',
                    field: 'drafts[$draftIndex]',
                  ),
                );
              }
              for (final ordinal in clozeOrdinals(cleanText)) {
                cards.add(
                  Card.cloze(
                    id: _ids.newId(),
                    parent: parent,
                    text: cleanText,
                    ordinal: ordinal,
                    createdAtUtc: now,
                  ),
                );
              }
          }
        }

        final StudyDay today = await _context.today();
        final StudyDayCalendar calendar = await _context.calendar();
        final String? rootId = parentSchedule?.rootId ?? parent?.id;
        final PriorityScale scale = await _context.priorityScale();
        final List<PriorityRank> childRanks;
        if (parentSchedule case final ElementSchedule parentState) {
          childRanks = PriorityRank.spread(
            count: cards.length,
            before: parentState.priority,
            after: scale.neighbourBelow(parentState.priority),
          );
        } else {
          final PriorityRank first = scale.rankAtPercent(50);
          final PriorityRank? after = scale.neighbourBelow(first);
          childRanks = <PriorityRank>[first];
          while (childRanks.length < cards.length) {
            childRanks.add(PriorityRank.between(childRanks.last, after));
          }
        }
        await _content.insertCards(cards);
        for (var cardIndex = 0; cardIndex < cards.length; cardIndex++) {
          final Card card = cards[cardIndex];
          final ref = ElementRef(id: card.id, type: ElementType.card);
          final CardState state = CardState(
            schedule: ElementSchedule(
              ref: ref,
              priority: childRanks[cardIndex],
              lifecycle: ElementLifecycle.active,
              dueDay: today,
              originalDueDay: today,
              // Denormalized so the queue can cap one article's share of a
              // session, and so the card keeps its citation if the source is
              // ever removed.
              rootId: rootId,
              parentElementId: card.parent?.id,
              createdAtUtc: card.createdAtUtc,
              updatedAtUtc: card.createdAtUtc,
            ),
            memory: CardMemory.newCard(cardId: card.id, dueAtUtc: now),
          );
          await _learning.insertCardState(state);
          await _search.upsertDocument(
            SearchDocument(
              ref: ref,
              title: 'Card',
              // The cloze text carries its own answer, so indexing the front
              // alone would make half the collection unsearchable.
              body: '${card.front}\n${card.back}',
              sourceId: rootId,
              updatedAtUtc: now,
            ),
          );
          await _journal.append(
            operationId: command.operationId.value,
            ref: ref,
            eventType: RevlogEventType.created,
            atUtc: command.timestampUtc,
            after: _journal.cardSnapshot(state),
            metadata: <String, Object?>{
              'kind': card.kind.name,
              if (parent != null) 'parent': parent.id,
            },
          );
        }

        // The parent is not rescheduled, converted, or removed — formulating
        // is capture, not completion. The one thing it does change is the
        // nudge counter: an extract that has just produced a card is not the
        // extract that has sat unconverted for months.
        if (parentRef != null && parentRef.type.isTopic) {
          final TopicState? parentTopic = await _learning.findTopic(parentRef);
          if (parentTopic != null) {
            final TopicScheduler scheduler = await _context.topicScheduler();
            await _learning.saveTopic(scheduler.notifyCardCreated(parentTopic));
          }
        }
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kCardsFormulatedKind,
            atUtc: command.timestampUtc,
            ref: parentRef,
            metadata: <String, Object?>{'cards': cards.length},
          ),
        );
        await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kCardsFormulatedKind,
            timestampUtc: now,
            operationId: command.operationId,
            fields: <String, Object?>{
              'cards': cards.length,
              'day': calendar.dayOf(now).toString(),
            },
          ),
        );
        return Ok<List<Card>>(List<Card>.unmodifiable(cards));
      });
    } on Object catch (error, stackTrace) {
      final failure = UnexpectedFailure(
        'command $kCardsFormulatedKind failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kCardsFormulatedKind,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<List<Card>>(failure);
    }
  }
}
