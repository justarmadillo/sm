/// Exactly-once FSRS review application boundary.
///
/// Four things happen around a grade, and keeping them straight is the point
/// of this file:
///
/// * The grade itself, applied by the pinned FSRS adapter, recorded losslessly
///   with a pre-review snapshot so it can be undone and later re-optimized.
/// * **Sibling burying.** Three clozes cut from one sentence give each other
///   away, so answering one pushes the rest off today. Logged as a deferral,
///   never as a review.
/// * **Leech flagging.** A card that keeps failing is usually a badly written
///   card rather than a hard fact. It is flagged, and its source passage
///   offered — never auto-suspended, which would hide the evidence.
/// * **Practice grades**, which are logged and then deliberately dropped:
///   they change no state, no due date, and no admission.
library;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../core/result.dart';
import '../../core/tracing.dart';
import '../../domain/content/card.dart';
import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/overload.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/revlog.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/settings/app_settings.dart';
import '../app_command.dart';
import '../ports/repositories.dart';
import '../ports/transaction_runner.dart';
import '../scheduling/scheduling_context.dart';
import '../scheduling/scheduling_journal.dart';
import 'review_commands.dart';

/// Activity kind recorded when a card is graded.
const String kCardReviewedKind = 'card.reviewed';

/// Activity kind recorded when a grade is taken back.
const String kReviewUndoneKind = 'card.review_undone';

/// Activity kind recorded when a card's text is edited.
const String kCardEditedKind = 'card.edited';

/// Activity kind recorded when a card's eligibility is moved.
const String kCardPostponedKind = 'card.postponed';

/// Activity kind recorded when siblings are pushed off the day.
const String kSiblingsBuriedKind = 'card.siblings_buried';

/// The outcome of one grade, including what it triggered.
final class ReviewOutcome {
  const ReviewOutcome({
    required this.state,
    required this.buriedSiblings,
    required this.isLeech,
  });

  /// The card as it now stands.
  final CardState state;

  /// How many same-parent cards were pushed to the next day.
  final int buriedSiblings;

  /// Whether this card has now failed often enough to deserve rewriting.
  final bool isLeech;
}

/// Handlers for grading, undoing, editing, and deferring cards.
final class ReviewHandlers {
  ReviewHandlers({
    required ContentRepository content,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _content = content,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final ContentRepository _content;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// Applies one grade.
  Future<Result<ReviewOutcome>> review(ReviewCard command) async {
    try {
      return await _transactions.run<Result<ReviewOutcome>>(() async {
        if (command.elapsedMs case final int elapsed when elapsed < 0) {
          return const Err<ReviewOutcome>(
            ValidationFailure('review duration cannot be negative'),
          );
        }
        if (await _learning.findReviewByOperationId(
              command.operationId.value,
            ) !=
            null) {
          return Err<ReviewOutcome>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        if (await _content.findCard(command.cardId) == null) {
          return Err<ReviewOutcome>(
            NotFoundFailure(
              'no such card',
              entity: 'card',
              id: command.cardId,
            ),
          );
        }
        final CardState? before = await _learning.findCardState(
          command.cardId,
        );
        if (before == null) {
          return Err<ReviewOutcome>(
            NotFoundFailure(
              'no memory state for that card',
              entity: 'card_memory',
              id: command.cardId,
            ),
          );
        }
        final DateTime reviewedAt = command.timestampUtc;
        if (!before.schedule.lifecycle.isSchedulable) {
          return const Err<ReviewOutcome>(
            ConflictFailure('that card is not active'),
          );
        }

        final CardScheduler scheduler = await _context.cardScheduler();
        final PriorityScale scale = await _context.priorityScale();
        final double pressure = scale.pressureOf(before.schedule.priority);

        if (command.isPractice) {
          return _logPractice(command, before, reviewedAt, pressure);
        }
        if (!before.memory.isDueAt(reviewedAt)) {
          return const Err<ReviewOutcome>(
            ConflictFailure('that card is not due yet'),
          );
        }

        final CardReviewTransition transition = scheduler.review(
          before,
          rating: command.rating,
          reviewedAtUtc: reviewedAt,
          operationId: command.operationId.value,
          elapsedMs: command.elapsedMs,
        );
        await _learning.saveCardState(transition.state);
        await _learning.appendReview(transition.record);
        await _journal.append(
          operationId: command.operationId.value,
          ref: ElementRef(id: command.cardId, type: ElementType.card),
          eventType: RevlogEventType.review,
          atUtc: reviewedAt,
          before: _journal.cardSnapshot(before, pressure: pressure),
          after: _journal.cardSnapshot(transition.state, pressure: pressure),
          grade: command.rating.value,
          elapsedDays: SchedulingJournal.daysBetween(
            before.memory.lastReviewAtUtc,
            reviewedAt,
          ),
          scheduledDays: SchedulingJournal.daysBetween(
            before.memory.lastReviewAtUtc,
            before.memory.originalDueAtUtc,
          ),
          durationMs: command.elapsedMs,
          postponeCount: before.memory.postponeCount,
          schedulerVersion: transition.record.schedulerVersion,
          parametersVersion: transition.record.parametersVersion,
        );

        final int buried = await _burySiblings(command, transition.state);
        final bool leech = scheduler.isLeech(transition.state.memory);

        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kCardReviewedKind,
            atUtc: reviewedAt,
            ref: ElementRef(id: command.cardId, type: ElementType.card),
            durationMs: command.elapsedMs,
            metadata: <String, Object?>{
              'rating': command.rating.value,
              'buried_siblings': buried,
              if (leech) 'leech': true,
            },
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
              'buried': buried,
            },
          ),
        );
        return Ok<ReviewOutcome>(
          ReviewOutcome(
            state: transition.state,
            buriedSiblings: buried,
            isLeech: leech,
          ),
        );
      });
    } on ArgumentError catch (error) {
      return Err<ReviewOutcome>(
        ValidationFailure(error.message?.toString() ?? 'invalid review'),
      );
    } on StateError catch (error) {
      return Err<ReviewOutcome>(ConflictFailure(error.message));
    } on Object catch (error, stackTrace) {
      return Err<ReviewOutcome>(
        _fail(command, kCardReviewedKind, error, stackTrace),
      );
    }
  }

  /// Restores the state the last grade was applied on top of.
  Future<Result<CardState>> undoLastReview(UndoLastReview command) async {
    try {
      return await _transactions.run<Result<CardState>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kReviewUndoneKind,
        )) {
          return Err<CardState>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        final ReviewRecord? record = command.cardId == null
            ? await _learning.findLastReviewOverall()
            : await _learning.findLastReview(command.cardId!);
        if (record == null) {
          return const Err<CardState>(
            ConflictFailure('there is no grade to take back'),
          );
        }
        final CardState? current = await _learning.findCardState(
          record.cardId,
        );
        if (current == null) {
          return Err<CardState>(
            NotFoundFailure(
              'no memory state for that card',
              entity: 'card_memory',
              id: record.cardId,
            ),
          );
        }

        final CardScheduler scheduler = await _context.cardScheduler();
        final CardState restored = scheduler.undo(current, record);
        await _learning.saveCardState(restored);
        // The one place the append-only log shrinks. Both records go: leaving
        // the review behind would make the card's history describe a grade
        // whose effect no longer exists.
        await _learning.deleteReview(record.operationId);
        await _learning.deleteRevlogByOperationId(record.operationId);

        await _journal.append(
          operationId: command.operationId.value,
          ref: ElementRef(id: record.cardId, type: ElementType.card),
          eventType: RevlogEventType.undo,
          atUtc: command.timestampUtc,
          before: _journal.cardSnapshot(current),
          after: _journal.cardSnapshot(restored),
          metadata: <String, Object?>{
            'undone_operation': record.operationId,
            'undone_grade': record.rating.value,
          },
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kReviewUndoneKind,
            atUtc: command.timestampUtc,
            ref: ElementRef(id: record.cardId, type: ElementType.card),
            metadata: <String, Object?>{'rating': record.rating.value},
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<CardState>(restored);
      });
    } on Object catch (error, stackTrace) {
      return Err<CardState>(
        _fail(command, kReviewUndoneKind, error, stackTrace),
      );
    }
  }

  /// Rewrites a card's text. Never reschedules.
  Future<Result<Card>> editCard(EditCard command) async {
    try {
      return await _transactions.run<Result<Card>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kCardEditedKind,
        )) {
          return Err<Card>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        final Card? card = await _content.findCard(command.cardId);
        if (card == null) {
          return Err<Card>(
            NotFoundFailure('no such card', entity: 'card', id: command.cardId),
          );
        }

        final String front = (command.front ?? card.front).trim();
        final String back = (command.back ?? card.back).trim();
        if (front.isEmpty) {
          return const Err<Card>(
            ValidationFailure('a card needs a question', field: 'front'),
          );
        }
        if (card.kind == CardKind.qa && back.isEmpty) {
          return const Err<Card>(
            ValidationFailure('a Q&A card needs an answer', field: 'back'),
          );
        }
        if (card.kind == CardKind.cloze) {
          final List<int> ordinals = clozeOrdinals(front);
          if (!ordinals.contains(card.clozeOrdinal)) {
            // The deletion this card tests has to survive the edit, or the
            // card would silently start testing something else while keeping
            // its memory state.
            return Err<Card>(
              ValidationFailure(
                'keep {{c${card.clozeOrdinal}::…}} in the text',
                field: 'front',
              ),
            );
          }
        }

        final Card updated = card.copyWith(
          front: front,
          back: card.kind == CardKind.cloze ? front : back,
          editedAtUtc: command.timestampUtc,
        );
        await _content.updateCard(updated);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kCardEditedKind,
            atUtc: command.timestampUtc,
            ref: ElementRef(id: card.id, type: ElementType.card),
            // Metadata records that an edit happened, never what it said.
            metadata: <String, Object?>{'kind': card.kind.name},
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<Card>(updated);
      });
    } on Object catch (error, stackTrace) {
      return Err<Card>(_fail(command, kCardEditedKind, error, stackTrace));
    }
  }

  /// Moves a card's eligibility without reviewing it.
  Future<Result<CardState>> postpone(PostponeCard command) async {
    try {
      return await _transactions.run<Result<CardState>>(() async {
        if (await _learning.hasActivity(
          command.operationId.value,
          kCardPostponedKind,
        )) {
          return Err<CardState>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        final CardState? state = await _learning.findCardState(command.cardId);
        if (state == null) {
          return Err<CardState>(
            NotFoundFailure(
              'no memory state for that card',
              entity: 'card_memory',
              id: command.cardId,
            ),
          );
        }

        final StudyDayCalendar calendar = await _context.calendar();
        final CardScheduler scheduler = await _context.cardScheduler();
        final StudyDay today = calendar.dayOf(command.timestampUtc);

        StudyDay until;
        PostponeDecision? decision;
        if (command.until != null) {
          until = command.until!;
        } else {
          final OverloadValve valve = await _context.overloadValve();
          decision = valve.later(
            intervalDays: _intervalOf(state),
            seed: '${command.operationId.value}:${command.cardId}',
          );
          until = today.addDays(decision.delayDays);
        }

        final CardState deferred = scheduler.postpone(
          state,
          untilUtc: calendar.startOfDayUtc(until),
          kind: command.kind,
        );
        await _learning.saveCardState(deferred);
        await _journal.append(
          operationId: command.operationId.value,
          ref: ElementRef(id: command.cardId, type: ElementType.card),
          eventType: command.kind == DeferralKind.automatic
              ? RevlogEventType.autoPostpone
              : RevlogEventType.postpone,
          atUtc: command.timestampUtc,
          before: _journal.cardSnapshot(state),
          after: _journal.cardSnapshot(deferred),
          scheduledDays: _intervalOf(state),
          postponeCount: deferred.memory.postponeCount,
          metadata: <String, Object?>{
            'until': until.toString(),
            if (decision != null) ...decision.toMetadata(),
          },
        );
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kCardPostponedKind,
            atUtc: command.timestampUtc,
            ref: ElementRef(id: command.cardId, type: ElementType.card),
            metadata: <String, Object?>{
              'until': until.toString(),
              'kind': command.kind.name,
            },
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<CardState>(deferred);
      });
    } on Object catch (error, stackTrace) {
      return Err<CardState>(
        _fail(command, kCardPostponedKind, error, stackTrace),
      );
    }
  }

  /// Logs a practice grade and changes nothing else.
  Future<Result<ReviewOutcome>> _logPractice(
    ReviewCard command,
    CardState state,
    DateTime reviewedAt,
    double pressure,
  ) async {
    final ReviewRecord record = ReviewRecord(
      operationId: command.operationId.value,
      cardId: command.cardId,
      rating: command.rating,
      reviewedAtUtc: reviewedAt,
      elapsedMs: command.elapsedMs,
      // Identical snapshots, because a practice grade is by definition a
      // measurement that moved nothing.
      preStateJson: state.memory.toJson(),
      postStateJson: state.memory.toJson(),
      schedulerVersion: state.memory.schedulerVersion,
      parametersVersion: state.memory.parametersVersion,
      isPractice: true,
    );
    await _learning.appendReview(record);
    await _journal.append(
      operationId: command.operationId.value,
      ref: ElementRef(id: command.cardId, type: ElementType.card),
      eventType: RevlogEventType.practice,
      atUtc: reviewedAt,
      before: _journal.cardSnapshot(state, pressure: pressure),
      after: _journal.cardSnapshot(state, pressure: pressure),
      grade: command.rating.value,
      durationMs: command.elapsedMs,
      schedulerVersion: state.memory.schedulerVersion,
      parametersVersion: state.memory.parametersVersion,
      metadata: const <String, Object?>{'practice': true},
    );
    await _learning.appendActivity(
      ActivityRecord(
        id: _ids.newId(),
        operationId: command.operationId.value,
        kind: kCardReviewedKind,
        atUtc: reviewedAt,
        ref: ElementRef(id: command.cardId, type: ElementType.card),
        durationMs: command.elapsedMs,
        metadata: <String, Object?>{
          'rating': command.rating.value,
          'practice': true,
        },
      ),
    );
    return Ok<ReviewOutcome>(
      ReviewOutcome(state: state, buriedSiblings: 0, isLeech: false),
    );
  }

  /// Pushes same-parent cards that are due today to the next day.
  Future<int> _burySiblings(ReviewCard command, CardState reviewed) async {
    final AppSettings settings = await _context.settings();
    if (!settings.cards.burySiblings) return 0;

    final List<Card> siblings = await _content.listSiblingCards(
      command.cardId,
    );
    if (siblings.isEmpty) return 0;

    final StudyDayCalendar calendar = await _context.calendar();
    final CardScheduler scheduler = await _context.cardScheduler();
    final StudyDay today = calendar.dayOf(command.timestampUtc);
    final DateTime tomorrowStart = calendar.startOfDayUtc(today.addDays(1));

    final entries = <RevlogEntry>[];
    for (final Card sibling in siblings) {
      final CardState? state = await _learning.findCardState(sibling.id);
      if (state == null) continue;
      if (!state.schedule.lifecycle.isSchedulable) continue;
      // A sibling already inside a learning step is mid-repetition; pushing
      // it to tomorrow would abandon work the user has started.
      if (state.memory.isIntradayStep) continue;
      if (!state.memory.isDueAt(command.timestampUtc)) continue;

      final CardState buried = scheduler.postpone(
        state,
        untilUtc: tomorrowStart,
        kind: DeferralKind.automatic,
      );
      await _learning.saveCardState(buried);
      entries.add(
        _journal.build(
          operationId: command.operationId.value,
          ref: ElementRef(id: sibling.id, type: ElementType.card),
          eventType: RevlogEventType.bury,
          atUtc: command.timestampUtc,
          before: _journal.cardSnapshot(state),
          after: _journal.cardSnapshot(buried),
          postponeCount: buried.memory.postponeCount,
          metadata: <String, Object?>{
            'sibling_of': command.cardId,
            'until': today.addDays(1).toString(),
          },
        ),
      );
    }
    if (entries.isEmpty) return 0;

    await _journal.appendAll(entries);
    await _learning.appendActivity(
      ActivityRecord(
        id: _ids.newId(),
        operationId: command.operationId.value,
        kind: kSiblingsBuriedKind,
        atUtc: command.timestampUtc,
        ref: reviewed.ref,
        metadata: <String, Object?>{'buried': entries.length},
      ),
    );
    return entries.length;
  }

  /// The card's own interval in days, for scaling a manual Later.
  double _intervalOf(CardState state) {
    final DateTime? last = state.memory.lastReviewAtUtc;
    if (last == null) return 1;
    final double days =
        state.memory.originalDueAtUtc.difference(last).inMinutes / 1440;
    return days < 1 ? 1 : days;
  }

  UnexpectedFailure _fail(
    AppCommand command,
    String kind,
    Object error,
    StackTrace stackTrace,
  ) {
    final UnexpectedFailure failure = UnexpectedFailure(
      'command $kind failed',
      cause: error,
      stackTrace: stackTrace,
    );
    _diagnostics.record(
      DiagnosticEvent(
        level: DiagnosticLevel.error,
        name: kind,
        timestampUtc: _clock.nowUtc(),
        operationId: command.operationId,
        failure: failure,
      ),
    );
    return failure;
  }
}
