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

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/features/review/review_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/history/scheduler_event.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/repositories.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';

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
final class ReviewCommandRunner {
  ReviewCommandRunner({
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
        final ReviewRecord? alreadyReviewed = await _learning
            .findReviewByOperationId(command.operationId.value);
        if (alreadyReviewed != null) {
          return _replayReview(command, alreadyReviewed);
        }
        if (await _content.findCard(command.cardId) == null) {
          return Err<ReviewOutcome>(
            NotFoundFailure('no such card', entity: 'card', id: command.cardId),
          );
        }
        final CardState? before = await _learning.findCardState(command.cardId);
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
        if (!await _learning.compareAndSwapCardState(
          expected: before,
          replacement: transition.state,
        )) {
          return const Err<ReviewOutcome>(
            ConflictFailure('the card changed before the review committed'),
          );
        }
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
        final StudyDayCalendar calendar = await _context.calendar();
        await _journal.appendScheduler(
          operationId: command.operationId.value,
          ref: before.ref,
          eventType: SchedulerEventType.cardReviewed,
          atUtc: reviewedAt,
          studyDay: calendar.dayOf(reviewedAt),
          policyVersion: 'card_review_policy_v1',
          schedulerName: transition.state.memory.schedulerName,
          schedulerVersion: transition.state.memory.schedulerVersion,
          stateBefore: before.memory.canonicalFsrsJson(),
          stateAfter: transition.state.memory.canonicalFsrsJson(),
          algorithmicDueBefore: SchedulerEvent.encodeUtcDue(
            before.memory.dueAtUtc,
          ),
          algorithmicDueAfter: SchedulerEvent.encodeUtcDue(
            transition.state.memory.dueAtUtc,
          ),
          metadata: <String, Object?>{
            'rating': command.rating.value,
            'buried_siblings': buried,
            if (leech) 'leech': true,
          },
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
              'buried_siblings': buried,
              if (leech) 'leech': true,
            },
          ),
        );
        await _removeFromQueues(before.ref);
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

  Future<Result<ReviewOutcome>> _replayReview(
    ReviewCard command,
    ReviewRecord record,
  ) async {
    if (record.cardId != command.cardId ||
        record.rating != command.rating ||
        record.isPractice != command.isPractice) {
      return Err<ReviewOutcome>(
        ConflictFailure(
          'operation ${command.operationId} was used for a different review',
        ),
      );
    }
    final CardState? current = await _learning.findCardState(record.cardId);
    if (current == null) {
      return Err<ReviewOutcome>(
        NotFoundFailure(
          'no memory state for that card',
          entity: 'card_memory',
          id: record.cardId,
        ),
      );
    }
    final StudyDayCalendar calendar = await _context.calendar();
    final CardMemory memory = record.postState;
    final CardState originalOutcome = CardState(
      schedule: current.schedule.copyWith(
        dueDay: calendar.dayOf(memory.dueAtUtc),
        originalDueDay: calendar.dayOf(memory.originalDueAtUtc),
      ),
      memory: memory,
    );
    final SchedulerEvent? event = await _learning
        .findSchedulerEventByOperationId(
          command.operationId.value,
          eventType: command.isPractice
              ? SchedulerEventType.practiceReviewed
              : SchedulerEventType.cardReviewed,
        );
    final int buried =
        (event?.metadata?['buried_siblings'] as num?)?.toInt() ?? 0;
    final CardScheduler scheduler = await _context.cardScheduler();
    return Ok<ReviewOutcome>(
      ReviewOutcome(
        state: originalOutcome,
        buriedSiblings: buried,
        isLeech: !command.isPractice && scheduler.isLeech(memory),
      ),
    );
  }

  /// Restores the state the last grade was applied on top of.
  Future<Result<CardState>> undoLastReview(UndoLastReview command) async {
    try {
      return await _transactions.run<Result<CardState>>(() async {
        final SchedulerEvent? priorUndo = await _learning
            .findSchedulerEventByOperationId(
              command.operationId.value,
              eventType: SchedulerEventType.cardReviewUndone,
            );
        if (priorUndo != null && priorUndo.element != null) {
          final CardState? replayed = await _learning.findCardState(
            priorUndo.element!.id,
          );
          if (replayed != null) return Ok<CardState>(replayed);
        }
        final ReviewRecord? record = command.cardId == null
            ? await _learning.findLastReviewOverall()
            : await _learning.findLastReview(command.cardId!);
        if (record == null) {
          return const Err<CardState>(
            ConflictFailure('there is no grade to take back'),
          );
        }
        final CardState? current = await _learning.findCardState(record.cardId);
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
        final SchedulerEvent? originalEvent = await _learning
            .findSchedulerEventByOperationId(
              record.operationId,
              eventType: SchedulerEventType.cardReviewed,
            );
        if (originalEvent == null) {
          return const Err<CardState>(
            ConflictFailure('that legacy review has no complete undo snapshot'),
          );
        }
        if (current.memory.canonicalFsrsJson() !=
            record.postState.canonicalFsrsJson()) {
          return const Err<CardState>(
            ConflictFailure('the card changed after that review'),
          );
        }
        final CardState restored = scheduler.undo(current, record);
        final StudyDayCalendar calendar = await _context.calendar();
        if (!await _learning.compareAndSwapCardState(
          expected: current,
          replacement: restored,
        )) {
          return const Err<CardState>(
            ConflictFailure('the card changed before undo committed'),
          );
        }
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
        await _journal.appendScheduler(
          operationId: command.operationId.value,
          ref: current.ref,
          eventType: SchedulerEventType.cardReviewUndone,
          atUtc: command.timestampUtc,
          studyDay: calendar.dayOf(command.timestampUtc),
          policyVersion: 'card_review_policy_v1',
          schedulerName: restored.memory.schedulerName,
          schedulerVersion: restored.memory.schedulerVersion,
          stateBefore: current.memory.canonicalFsrsJson(),
          stateAfter: restored.memory.canonicalFsrsJson(),
          algorithmicDueBefore: SchedulerEvent.encodeUtcDue(
            current.memory.dueAtUtc,
          ),
          algorithmicDueAfter: SchedulerEvent.encodeUtcDue(
            restored.memory.dueAtUtc,
          ),
          undoesEventId: originalEvent.id,
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
        await _restoreToOutstanding(restored);
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
          final CardState? replayed = await _learning.findCardState(
            command.cardId,
          );
          if (replayed != null) return Ok<CardState>(replayed);
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
        final StudyDay today = calendar.dayOf(command.timestampUtc);
        final runtime = await _context.runtimeState();
        final bool alreadyOutstanding = runtime.outstanding.contains(state.ref);
        final StudyDay until = command.until ?? today;
        final bool sameDayGuard =
            command.until == null &&
            !alreadyOutstanding &&
            state.memory.lastReviewAtUtc != null &&
            calendar.dayOf(state.memory.lastReviewAtUtc!) == today;
        final CardScheduler scheduler = await _context.cardScheduler();
        final CardState after = command.until == null && alreadyOutstanding
            ? state
            : sameDayGuard
            ? state
            : scheduler.rescheduleElement(
                state,
                targetDay: until,
                today: today,
              );
        if (after != state &&
            !await _learning.compareAndSwapCardState(
              expected: state,
              replacement: after,
            )) {
          return const Err<CardState>(
            ConflictFailure('the card changed before Later committed'),
          );
        }
        await _placeInOutstanding(
          state.ref,
          include: !state.memory.isNew && until <= today,
        );
        await _journal.append(
          operationId: command.operationId.value,
          ref: ElementRef(id: command.cardId, type: ElementType.card),
          eventType: command.isAutomatic
              ? RevlogEventType.autoPostpone
              : RevlogEventType.postpone,
          atUtc: command.timestampUtc,
          before: _journal.cardSnapshot(state),
          after: _journal.cardSnapshot(after),
          scheduledDays: _intervalOf(state),
          postponeCount: state.memory.postponeCount,
          metadata: <String, Object?>{
            'until': until.toString(),
            'queue_only': command.until == null && alreadyOutstanding,
            if (sameDayGuard) 'same_day_guard': true,
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
              'automatic': command.isAutomatic,
            },
          ),
        );
        await _transfer.advanceGeneration();
        return Ok<CardState>(after);
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
    final StudyDayCalendar calendar = await _context.calendar();
    await _journal.appendScheduler(
      operationId: command.operationId.value,
      ref: state.ref,
      eventType: SchedulerEventType.practiceReviewed,
      atUtc: reviewedAt,
      studyDay: calendar.dayOf(reviewedAt),
      policyVersion: 'card_review_policy_v1',
      schedulerName: state.memory.schedulerName,
      schedulerVersion: state.memory.schedulerVersion,
      stateBefore: state.memory.canonicalFsrsJson(),
      stateAfter: state.memory.canonicalFsrsJson(),
      algorithmicDueBefore: SchedulerEvent.encodeUtcDue(state.memory.dueAtUtc),
      algorithmicDueAfter: SchedulerEvent.encodeUtcDue(state.memory.dueAtUtc),
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

    final List<Card> siblings = await _content.listSiblingCards(command.cardId);
    if (siblings.isEmpty) return 0;

    final StudyDayCalendar calendar = await _context.calendar();
    final StudyDay today = calendar.dayOf(command.timestampUtc);
    final StudyDay tomorrow = today.addDays(1);
    final CardScheduler scheduler = await _context.cardScheduler();

    final entries = <RevlogEntry>[];
    for (final Card sibling in siblings) {
      final CardState? state = await _learning.findCardState(sibling.id);
      if (state == null) continue;
      if (!state.schedule.lifecycle.isSchedulable) continue;
      // A sibling already inside a learning step is mid-repetition; pushing
      // it to tomorrow would abandon work the user has started.
      if (state.memory.isIntradayStep) continue;
      if (!state.memory.isDueAt(command.timestampUtc)) {
        continue;
      }
      final CardState after = scheduler.rescheduleElement(
        state,
        targetDay: tomorrow,
        today: today,
      );
      if (!await _learning.compareAndSwapCardState(
        expected: state,
        replacement: after,
      )) {
        continue;
      }
      await _placeInOutstanding(state.ref, include: false);
      entries.add(
        _journal.build(
          operationId: command.operationId.value,
          ref: ElementRef(id: sibling.id, type: ElementType.card),
          eventType: RevlogEventType.bury,
          atUtc: command.timestampUtc,
          before: _journal.cardSnapshot(state),
          after: _journal.cardSnapshot(after),
          postponeCount: state.memory.postponeCount,
          metadata: <String, Object?>{
            'sibling_of': command.cardId,
            'until': tomorrow.toString(),
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

  Future<void> _removeFromQueues(ElementRef ref) async {
    final runtime = await _context.runtimeState();
    await _context.saveRuntimeState(
      runtime.copyWith(
        outstanding: runtime.outstanding
            .where((ElementRef value) => value != ref)
            .toList(),
        outstandingItems: runtime.outstandingItems
            .where((ElementRef value) => value != ref)
            .toList(),
        outstandingTopics: runtime.outstandingTopics
            .where((ElementRef value) => value != ref)
            .toList(),
        finalDrill: runtime.finalDrill
            .where((ElementRef value) => value != ref)
            .toList(),
        pending: runtime.pending
            .where((ElementRef value) => value != ref)
            .toList(),
      ),
    );
  }

  Future<void> _placeInOutstanding(
    ElementRef ref, {
    required bool include,
    bool atFront = false,
  }) async {
    final runtime = await _context.runtimeState();
    final List<ElementRef> outstanding = runtime.outstanding
        .where((ElementRef value) => value != ref)
        .toList();
    final List<ElementRef> items = runtime.outstandingItems
        .where((ElementRef value) => value != ref)
        .toList();
    if (include) {
      if (atFront) {
        outstanding.insert(0, ref);
        items.insert(0, ref);
      } else {
        outstanding.add(ref);
        items.add(ref);
      }
    }
    await _context.saveRuntimeState(
      runtime.copyWith(outstanding: outstanding, outstandingItems: items),
    );
  }

  Future<void> _restoreToOutstanding(CardState state) async {
    if (!state.memory.isNew) {
      await _placeInOutstanding(state.ref, include: true, atFront: true);
      return;
    }
    final runtime = await _context.runtimeState();
    final List<ElementRef> pending =
        runtime.pending.where((ElementRef value) => value != state.ref).toList()
          ..insert(0, state.ref);
    await _context.saveRuntimeState(
      runtime.copyWith(
        pending: pending,
        outstanding: runtime.outstanding
            .where((ElementRef value) => value != state.ref)
            .toList(),
        outstandingItems: runtime.outstandingItems
            .where((ElementRef value) => value != state.ref)
            .toList(),
      ),
    );
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
