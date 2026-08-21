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
import '../../domain/scheduling/study_day.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import 'formulation_commands.dart';

const String kCardsFormulatedKind = 'formulation.cards_created';

final class FormulationHandlers {
  FormulationHandlers({
    required ContentRepository content,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    required StudyDayCalendar calendar,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _calendar = calendar,
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final StudyDayCalendar _calendar;
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

        final today = _calendar.dayOf(now);
        await _content.insertCards(cards);
        for (final card in cards) {
          final ref = ElementRef(id: card.id, type: ElementType.card);
          await _learning.insertCardState(
            CardState(
              schedule: ElementSchedule(
                ref: ref,
                // Priority is inherited once, from whatever element the card
                // was made from. Later changes to that parent do not
                // silently reorder cards already formulated from it.
                priority: parentSchedule?.priority ?? PriorityRank.middle,
                lifecycle: ElementLifecycle.active,
                dueDay: today,
                originalDueDay: today,
              ),
              memory: CardMemory.newCard(cardId: card.id, dueAtUtc: now),
            ),
          );
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
            fields: <String, Object?>{'cards': cards.length},
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
