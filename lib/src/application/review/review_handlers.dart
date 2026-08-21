/// Exactly-once FSRS review application boundary.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import 'review_commands.dart';

const String kCardReviewedKind = 'card.reviewed';

final class ReviewHandlers {
  ReviewHandlers({
    required ContentRepository content,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    required CardScheduler scheduler,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _scheduler = scheduler,
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final CardScheduler _scheduler;
  final DiagnosticSink _diagnostics;

  Future<Result<CardState>> review(ReviewCard command) async {
    try {
      return await _transactions.run<Result<CardState>>(() async {
        if (command.elapsedMs case final elapsed? when elapsed < 0) {
          return const Err<CardState>(
            ValidationFailure('review duration cannot be negative'),
          );
        }
        if (await _learning.findReviewByOperationId(
              command.operationId.value,
            ) !=
            null) {
          return Err<CardState>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        if (await _content.findCard(command.cardId) == null) {
          return Err<CardState>(
            NotFoundFailure('no such card', entity: 'card', id: command.cardId),
          );
        }
        final before = await _learning.findCardState(command.cardId);
        if (before == null) {
          return Err<CardState>(
            NotFoundFailure(
              'no memory state for that card',
              entity: 'card_memory',
              id: command.cardId,
            ),
          );
        }
        final reviewedAt = command.timestampUtc;
        if (!before.schedule.lifecycle.isSchedulable) {
          return const Err<CardState>(
            ConflictFailure('that card is not active'),
          );
        }
        if (!before.memory.isDueAt(reviewedAt)) {
          return const Err<CardState>(
            ConflictFailure('that card is not due yet'),
          );
        }

        final transition = _scheduler.review(
          before,
          rating: command.rating,
          reviewedAtUtc: reviewedAt,
          operationId: command.operationId.value,
          elapsedMs: command.elapsedMs,
        );
        await _learning.saveCardState(transition.state);
        await _learning.appendReview(transition.record);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kCardReviewedKind,
            atUtc: reviewedAt,
            ref: ElementRef(id: command.cardId, type: ElementType.card),
            durationMs: command.elapsedMs,
            metadata: <String, Object?>{'rating': command.rating.value},
          ),
        );
        await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kCardReviewedKind,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: <String, Object?>{
              'rating': command.rating.value,
              'state': transition.state.memory.state.value,
            },
          ),
        );
        return Ok<CardState>(transition.state);
      });
    } on ArgumentError catch (error) {
      return Err<CardState>(
        ValidationFailure(error.message?.toString() ?? 'invalid review'),
      );
    } on StateError catch (error) {
      return Err<CardState>(ConflictFailure(error.message));
    } on Object catch (error, stackTrace) {
      final failure = UnexpectedFailure(
        'command $kCardReviewedKind failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: kCardReviewedKind,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<CardState>(failure);
    }
  }
}
