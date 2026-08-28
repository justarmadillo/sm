/// Application transactions for SM20's browser Learning command group.
///
/// Three properties hold across every command here:
///
/// * **The selection order is the algorithm's order.** Add to outstanding
///   counts insertions as it walks, and Advance draws once per draw-eligible
///   record, so a runner that reordered or parallelized the selection would
///   produce a different collection and a different PRNG stream.
/// * **One global random stream.** Any command that can draw takes the
///   persisted seed, runs, and writes the advanced seed back in the same
///   transaction — never a feature-local generator.
/// * **Only Remember and Advance-on-a-topic are repetitions.** Everything else
///   here either clears state the executable clears or moves queue membership;
///   none of it may adapt A or invent a review.
library;

import 'package:incremental_reader/features/priority/browser_commands.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kBrowserReviewKind = 'sm20.browser.review';
const String kBrowserRememberKind = 'sm20.browser.remember';
const String kBrowserForgetKind = 'sm20.browser.forget';
const String kBrowserDismissKind = 'sm20.browser.dismiss';
const String kBrowserUndismissKind = 'sm20.browser.undismiss';
const String kBrowserDoneKind = 'sm20.browser.done';
const String kBrowserFinalDrillKind = 'sm20.browser.add_to_drill';
const String kBrowserOutstandingKind = 'sm20.browser.add_to_outstanding';
const String kBrowserResetHistoryKind = 'sm20.browser.reset_history';
const String kBrowserSetAKind = 'sm20.browser.set_a';
const String kBrowserModifyAKind = 'sm20.browser.modify_a';
const String kBrowserAdvanceKind = 'sm20.browser.advance';

/// The browser's bulk Learning commands.
final class BrowserCommandRunner {
  BrowserCommandRunner({
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// Modes 4, 5, and 6: build the review source and enter the learning mode.
  ///
  /// Opening a review changes no record. The mode is collection state because
  /// it decides which interval branch a later commit uses — mode 4 the
  /// ordinary one, modes 5 and 6 the forced-topic one.
  Future<Result<BrowserCommandOutcome>> startReview(
    StartBrowserReview command,
  ) => _run(command, kBrowserReviewKind, (StudyDay _) async {
    final List<ElementRef> source = <ElementRef>[];
    for (final ElementRef ref in command.refs) {
      final ElementSchedule? schedule = await _learning.findSchedule(ref);
      if (schedule == null) continue;
      if (command.mode == Sm20ReviewMode.reviewTopics &&
          ref.type == ElementType.card) {
        continue;
      }
      source.add(ref);
    }
    final Sm20CollectionState runtime = await _context.runtimeState();
    await _context.saveRuntimeState(
      runtime.copyWith(
        learningMode: command.mode.value,
        subsetQueues: <String, List<ElementRef>>{
          ...runtime.subsetQueues,
          'review:${command.mode.value}': source,
        },
      ),
    );
    return BrowserCommandOutcome(
      changedRefs: source,
      skipped: command.refs.length - source.length,
    );
  });

  /// Remember: accepts pending and dismissed topics, refuses memorized ones.
  ///
  /// Cards are skipped: FSRS owns item memory here, and its own first
  /// interval comes from the first genuine grade rather than from a dialog.
  Future<Result<BrowserCommandOutcome>> remember(RememberElements command) =>
      _run(command, kBrowserRememberKind, (StudyDay day) async {
        final AppSettings settings = await _context.settings();
        final TopicScheduler scheduler = await _context.topicScheduler();
        final PriorityScale scale = await _context.priorityScale();
        final List<ElementRef> changedRefs = <ElementRef>[];
        var skipped = 0;

        for (final ElementRef ref in command.refs) {
          final TopicState? topic = await _topic(ref);
          if (topic == null) {
            skipped += 1;
            continue;
          }
          final TopicTransition transition = scheduler.remember(
            topic,
            day,
            firstIntervalLow: settings.remember.firstIntervalLowDays,
            firstIntervalHigh: settings.remember.firstIntervalHighDays,
            priorityScale: scale,
          );
          if (!transition.isChange) {
            skipped += 1;
            continue;
          }
          await _writeTopic(
            command,
            before: topic,
            after: transition.state,
            eventType: RevlogEventType.topicRead,
          );
          changedRefs.add(ref);
        }
        await _context.savePrngState(scheduler.prng.state);
        return BrowserCommandOutcome(
          changedRefs: changedRefs,
          skipped: skipped,
          randomDraws: scheduler.prng.drawCount,
        );
      });

  /// Forget: clear a memorized record back to pending.
  ///
  /// For a card this resets FSRS memory to a brand-new card. The executable's
  /// item branch also writes its own difficulty constant, which belongs to
  /// SM20's item model and has no FSRS counterpart; resetting to a new card
  /// is the FSRS-native meaning of the same command.
  Future<Result<BrowserCommandOutcome>> forget(ForgetElements command) =>
      _run(command, kBrowserForgetKind, (StudyDay day) async {
        final TopicScheduler scheduler = await _context.topicScheduler();
        final List<ElementRef> changedRefs = <ElementRef>[];
        var skipped = 0;

        for (final ElementRef ref in command.refs) {
          if (ref.type == ElementType.card) {
            final CardState? card = await _learning.findCardState(ref.id);
            if (card == null || card.memory.reps == 0) {
              skipped += 1;
              continue;
            }
            final CardState after = card.copyWith(
              schedule: card.schedule.copyWith(
                dueDay: day,
                originalDueDay: day,
                revision: card.schedule.revision + 1,
                updatedAtUtc: command.timestampUtc,
              ),
              memory: CardMemory.newCard(
                cardId: card.memory.cardId,
                dueAtUtc: command.timestampUtc,
              ),
            );
            await _learning.saveCardState(after);
            await _logCard(
              command,
              before: card,
              after: after,
              eventType: RevlogEventType.resume,
            );
            changedRefs.add(ref);
            continue;
          }
          final TopicState? topic = await _topic(ref);
          if (topic == null) {
            skipped += 1;
            continue;
          }
          final TopicTransition transition = scheduler.forget(topic, day);
          if (!transition.isChange) {
            skipped += 1;
            continue;
          }
          await _writeTopic(
            command,
            before: topic,
            after: transition.state,
            eventType: RevlogEventType.resume,
          );
          changedRefs.add(ref);
        }
        await _removeFromQueues(changedRefs, shouldIncludeFinalDrill: true);
        return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
      });

  /// Dismiss: stop scheduling and send the record to priority 100.
  Future<Result<BrowserCommandOutcome>> dismiss(DismissElements command) =>
      _run(command, kBrowserDismissKind, (StudyDay day) async {
        final TopicScheduler scheduler = await _context.topicScheduler();
        var scale = await _context.priorityScale();
        final List<ElementRef> changedRefs = <ElementRef>[];
        var skipped = 0;

        for (final ElementRef ref in command.refs) {
          if (ref.type == ElementType.card) {
            final CardState? card = await _learning.findCardState(ref.id);
            if (card == null ||
                card.schedule.lifecycle == ElementLifecycle.dismissed) {
              skipped += 1;
              continue;
            }
            final PriorityRank bottom = scale.rankForSetPriority(
              card.schedule.priority,
              100,
            );
            final CardState after = card.copyWith(
              schedule: card.schedule.copyWith(
                lifecycle: ElementLifecycle.dismissed,
                priority: bottom,
                revision: card.schedule.revision + 1,
                updatedAtUtc: command.timestampUtc,
              ),
            );
            await _learning.saveCardState(after);
            await _logCard(
              command,
              before: card,
              after: after,
              eventType: RevlogEventType.dismiss,
            );
            scale = scale.replacing(card.schedule.priority, bottom);
            changedRefs.add(ref);
            continue;
          }
          final TopicState? topic = await _topic(ref);
          if (topic == null) {
            skipped += 1;
            continue;
          }
          final TopicTransition transition = scheduler.dismiss(
            topic,
            day,
            priorityScale: scale,
          );
          if (!transition.isChange) {
            skipped += 1;
            continue;
          }
          await _writeTopic(
            command,
            before: topic,
            after: transition.state,
            eventType: RevlogEventType.dismiss,
          );
          // Every insertion shifts the live order, so the next element in the
          // same selection must be ranked against the collection as it now is.
          scale = scale.replacing(
            topic.schedule.priority,
            transition.state.schedule.priority,
          );
          changedRefs.add(ref);
        }
        await _removeFromQueues(changedRefs, shouldIncludeFinalDrill: true);
        return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
      });

  /// Undismiss: the status byte only. Dismiss's cleared fields stay cleared.
  Future<Result<BrowserCommandOutcome>> undismiss(UndismissElements command) =>
      _run(command, kBrowserUndismissKind, (StudyDay day) async {
        final TopicScheduler scheduler = await _context.topicScheduler();
        final List<ElementRef> changedRefs = <ElementRef>[];
        var skipped = 0;

        for (final ElementRef ref in command.refs) {
          if (ref.type == ElementType.card) {
            final CardState? card = await _learning.findCardState(ref.id);
            if (card == null ||
                card.schedule.lifecycle != ElementLifecycle.dismissed) {
              skipped += 1;
              continue;
            }
            final CardState after = card.copyWith(
              schedule: card.schedule.copyWith(
                lifecycle: ElementLifecycle.active,
                revision: card.schedule.revision + 1,
                updatedAtUtc: command.timestampUtc,
              ),
            );
            await _learning.saveCardState(after);
            await _logCard(
              command,
              before: card,
              after: after,
              eventType: RevlogEventType.resume,
            );
            changedRefs.add(ref);
            continue;
          }
          final TopicState? topic = await _topic(ref);
          if (topic == null) {
            skipped += 1;
            continue;
          }
          final TopicTransition transition = scheduler.undismiss(topic);
          if (!transition.isChange) {
            skipped += 1;
            continue;
          }
          await _writeTopic(
            command,
            before: topic,
            after: transition.state,
            eventType: RevlogEventType.resume,
          );
          changedRefs.add(ref);
        }
        return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
      });

  /// Done: the scheduler-visible half of deletion.
  ///
  /// Content and tree placement are the content model's business; what this
  /// owes the scheduler is removal from every store, queue, and the rankable
  /// population, which the deleted status is.
  Future<Result<BrowserCommandOutcome>> done(DoneElements command) =>
      _run(command, kBrowserDoneKind, (StudyDay day) async {
        final TopicScheduler scheduler = await _context.topicScheduler();
        final List<ElementRef> changedRefs = <ElementRef>[];
        var skipped = 0;

        for (final ElementRef ref in command.refs) {
          if (ref.type == ElementType.card) {
            final CardState? card = await _learning.findCardState(ref.id);
            if (card == null ||
                card.schedule.lifecycle == ElementLifecycle.deleted) {
              skipped += 1;
              continue;
            }
            final CardState after = card.copyWith(
              schedule: card.schedule.copyWith(
                lifecycle: ElementLifecycle.deleted,
                revision: card.schedule.revision + 1,
                updatedAtUtc: command.timestampUtc,
              ),
            );
            await _learning.saveCardState(after);
            await _logCard(
              command,
              before: card,
              after: after,
              eventType: RevlogEventType.dismiss,
            );
            changedRefs.add(ref);
            continue;
          }
          final TopicState? topic = await _topic(ref);
          if (topic == null) {
            skipped += 1;
            continue;
          }
          final TopicTransition transition = scheduler.delete(topic, day);
          if (!transition.isChange) {
            skipped += 1;
            continue;
          }
          await _writeTopic(
            command,
            before: topic,
            after: transition.state,
            eventType: RevlogEventType.dismiss,
          );
          changedRefs.add(ref);
        }
        await _removeFromQueues(changedRefs, shouldIncludeFinalDrill: true);
        return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
      });

  /// Add to drill: queue membership only, appended once, in selection order.
  Future<Result<BrowserCommandOutcome>> addToFinalDrill(
    AddToFinalDrill command,
  ) => _run(command, kBrowserFinalDrillKind, (StudyDay _) async {
    final Sm20CollectionState runtime = await _context.runtimeState();
    final List<ElementRef> drill = <ElementRef>[...runtime.finalDrill];
    final Set<ElementRef> present = drill.toSet();
    final List<ElementRef> changedRefs = <ElementRef>[];
    var skipped = 0;

    for (final ElementRef ref in command.refs) {
      final ElementSchedule? schedule = await _learning.findSchedule(ref);
      if (schedule == null ||
          schedule.lifecycle == ElementLifecycle.deleted ||
          !present.add(ref)) {
        skipped += 1;
        continue;
      }
      drill.add(ref);
      changedRefs.add(ref);
    }
    if (changedRefs.isNotEmpty) {
      await _context.saveRuntimeState(runtime.copyWith(finalDrill: drill));
    }
    return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
  });

  /// Add to outstanding, or Add all.
  ///
  /// This is not a queue-only command: every successful insertion also
  /// multiplies the element's numeric priority target by `0.9`, which is what
  /// makes repeatedly pulling something forward compound into importance.
  Future<Result<BrowserCommandOutcome>> addToOutstanding(
    AddToOutstanding command,
  ) => _run(command, kBrowserOutstandingKind, (StudyDay day) async {
    if (command.everyWhich < 1 || command.everyWhich > 100) {
      throw RangeError.range(command.everyWhich, 1, 100, 'everyWhich');
    }
    final Sm20CollectionState runtime = await _context.runtimeState();
    final TopicScheduler scheduler = await _context.topicScheduler();
    var scale = await _context.priorityScale();
    final List<ElementRef> outstanding = <ElementRef>[...runtime.outstanding];
    final List<ElementRef> changedRefs = <ElementRef>[];
    var skipped = 0;
    var target = command.everyWhich < 3 ? command.everyWhich : 3;

    for (final ElementRef ref in command.refs) {
      final _BrowserRecord? record = await _record(ref);
      if (record == null || !record.isMemorized) {
        skipped += 1;
        continue;
      }
      // Positions are one-based here because SM20 uses zero to mean absent.
      final int position = outstanding.indexOf(ref) + 1;
      if (position != 0 && position < target) {
        skipped += 1;
        continue;
      }
      if (record.lastReviewDay == day) {
        if (!command.shouldRescheduleSameDay) {
          skipped += 1;
          continue;
        }
        await _rescheduleTo(command, record, targetDay: day, today: day);
      }

      if (position != 0) outstanding.remove(ref);
      final int index = target - 1 < outstanding.length
          ? target - 1
          : outstanding.length;
      outstanding.insert(index, ref);

      final double percent = scale.percentageOf(record.priority);
      final PriorityRank raised = scale.rankForSetPriority(
        record.priority,
        percent * 0.9,
      );
      await _setPriority(command, ref, raised);
      scale = scale.replacing(record.priority, raised);
      changedRefs.add(ref);
      target += command.everyWhich;
    }

    if (changedRefs.isNotEmpty) {
      final Set<ElementRef> members = outstanding.toSet();
      await _context.saveRuntimeState(
        runtime.copyWith(
          prngSeed: scheduler.prng.state.seed,
          outstanding: outstanding,
          outstandingItems: <ElementRef>[
            for (final ElementRef ref in runtime.outstandingItems)
              if (members.contains(ref)) ref,
            for (final ElementRef ref in changedRefs)
              if (ref.type == ElementType.card &&
                  !runtime.outstandingItems.contains(ref))
                ref,
          ],
          outstandingTopics: <ElementRef>[
            for (final ElementRef ref in runtime.outstandingTopics)
              if (members.contains(ref)) ref,
            for (final ElementRef ref in changedRefs)
              if (ref.type != ElementType.card &&
                  !runtime.outstandingTopics.contains(ref))
                ref,
          ],
        ),
      );
    }
    return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
  });

  /// Reset history: drop the external history block and nothing else.
  ///
  /// Despite the caption it resets no counter, interval, A, or due date. The
  /// name is the executable's, and matching it exactly matters more than
  /// making it read sensibly.
  Future<Result<BrowserCommandOutcome>> resetHistory(
    ResetElementHistory command,
  ) => _run(command, kBrowserResetHistoryKind, (StudyDay _) async {
    final TopicScheduler scheduler = await _context.topicScheduler();
    final List<ElementRef> changedRefs = <ElementRef>[];
    var skipped = 0;

    for (final ElementRef ref in command.refs) {
      final TopicState? topic = await _topic(ref);
      if (topic == null || topic.historyBlockId == 0) {
        skipped += 1;
        continue;
      }
      await _learning.saveTopic(scheduler.resetHistory(topic));
      changedRefs.add(ref);
    }
    return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
  });

  /// Set A: store an A-factor directly on normal topics.
  Future<Result<BrowserCommandOutcome>> setAFactor(SetTopicAFactor command) =>
      _run(command, kBrowserSetAKind, (StudyDay _) async {
        final TopicScheduler scheduler = await _context.topicScheduler();
        return _editAFactor(
          command,
          (TopicState topic) => scheduler.setAFactor(topic, command.value),
        );
      });

  /// Modify A: `A = 1.01 + m * (A - 1.01)` on normal topics.
  Future<Result<BrowserCommandOutcome>> modifyAFactor(
    ModifyTopicAFactor command,
  ) => _run(command, kBrowserModifyAKind, (StudyDay _) async {
    final TopicScheduler scheduler = await _context.topicScheduler();
    return _editAFactor(
      command,
      (TopicState topic) => scheduler.modifyAFactor(topic, command.multiplier),
    );
  });

  /// Advance: pull a run of future work closer to today.
  ///
  /// A topic Advance is a real forced bulk repetition — it adapts A and
  /// priority with the bulk denominators — while an item Advance is only a
  /// low-level reschedule. Both share the one draw the engine already took.
  Future<Result<BrowserCommandOutcome>> advance(AdvanceElements command) =>
      _run(command, kBrowserAdvanceKind, (StudyDay day) async {
        final Sm20CollectionState runtime = await _context.runtimeState();
        final Sm20Prng prng = Sm20Prng(seed: runtime.prngSeed);
        final List<Sm20AdvanceCandidate> source = <Sm20AdvanceCandidate>[];
        final Map<ElementRef, _BrowserRecord> records =
            <ElementRef, _BrowserRecord>{};
        for (final ElementRef ref in command.refs) {
          final _BrowserRecord? record = await _record(ref);
          if (record == null) continue;
          records[ref] = record;
          source.add(
            Sm20AdvanceCandidate(
              ref: ref,
              isMemorized: record.isMemorized,
              storedInterval: record.storedInterval,
              lastReviewDay: record.lastReviewDay,
            ),
          );
        }

        final Sm20AdvanceResult result = const Sm20AdvanceEngine().run(
          source: source,
          scope: command.scope,
          horizonDays: command.horizonDays,
          today: day,
          prng: prng,
        );

        final TopicScheduler scheduler = TopicScheduler(prng: prng);
        final PriorityScale scale = await _context.priorityScale();
        final List<ElementRef> changedRefs = <ElementRef>[];
        for (final Sm20AdvanceDecision decision in result.decisions) {
          final _BrowserRecord record = records[decision.ref]!;
          if (decision.isItem) {
            await _rescheduleTo(
              command,
              record,
              targetDay: decision.targetDay,
              today: day,
            );
            changedRefs.add(decision.ref);
            continue;
          }
          final TopicTransition transition = scheduler.forceRepetition(
            record.topic!,
            day,
            interval: decision.newInterval,
            isBulkOperation: true,
            priorityScale: scale,
          );
          if (!transition.isChange) continue;
          await _writeTopic(
            command,
            before: record.topic!,
            after: transition.state,
            eventType: RevlogEventType.topicRead,
          );
          changedRefs.add(decision.ref);
        }

        // The draws are consumed whether or not a decision survived, so the
        // seed is written back even for a run that changed nothing.
        await _context.savePrngState(prng.state);
        return BrowserCommandOutcome(
          changedRefs: changedRefs,
          skipped: command.refs.length - changedRefs.length,
          randomDraws: result.randomDraws,
        );
      });

  Future<BrowserCommandOutcome> _editAFactor(
    BrowserSelectionCommand command,
    TopicState Function(TopicState topic) edit,
  ) async {
    final List<ElementRef> changedRefs = <ElementRef>[];
    var skipped = 0;
    for (final ElementRef ref in command.refs) {
      final TopicState? topic = await _topic(ref);
      // Deleted records are refused by the outer dispatcher; pending,
      // memorized, and dismissed type-zero records are all eligible.
      if (topic == null || topic.status == Sm20ElementStatus.deleted) {
        skipped += 1;
        continue;
      }
      final TopicState edited = edit(topic);
      if (edited.aFactorRaw.bytes.join(',') ==
          topic.aFactorRaw.bytes.join(',')) {
        skipped += 1;
        continue;
      }
      await _learning.saveTopic(edited);
      changedRefs.add(ref);
    }
    return BrowserCommandOutcome(changedRefs: changedRefs, skipped: skipped);
  }

  Future<TopicState?> _topic(ElementRef ref) async =>
      ref.type == ElementType.card ? null : _learning.findTopic(ref);

  Future<_BrowserRecord?> _record(ElementRef ref) async {
    if (ref.type == ElementType.card) {
      final CardState? card = await _learning.findCardState(ref.id);
      if (card == null) return null;
      final StudyDayCalendar calendar = await _context.calendar();
      return _BrowserRecord.card(card, calendar: calendar);
    }
    final TopicState? topic = await _learning.findTopic(ref);
    return topic == null ? null : _BrowserRecord.topic(topic);
  }

  /// A low-level reschedule, shared by Add all and the Advance item branch.
  Future<void> _rescheduleTo(
    BrowserSelectionCommand command,
    _BrowserRecord record, {
    required StudyDay targetDay,
    required StudyDay today,
  }) async {
    if (record.card case final CardState card) {
      final CardScheduler cards = await _context.cardScheduler();
      final CardState moved = cards.rescheduleElement(
        card,
        targetDay: targetDay,
        today: today,
      );
      final CardState after = moved.copyWith(
        schedule: moved.schedule.copyWith(updatedAtUtc: command.timestampUtc),
      );
      await _learning.saveCardState(after);
      await _logCard(
        command,
        before: card,
        after: after,
        eventType: RevlogEventType.manualReschedule,
      );
      return;
    }
    final TopicScheduler topics = await _context.topicScheduler();
    final TopicState before = record.topic!;
    final TopicTransition moved = topics.rescheduleElement(
      before,
      targetDay: targetDay,
      today: today,
    );
    await _writeTopic(
      command,
      before: before,
      after: moved.state,
      eventType: RevlogEventType.manualReschedule,
    );
  }

  Future<void> _setPriority(
    BrowserSelectionCommand command,
    ElementRef ref,
    PriorityRank rank,
  ) async {
    final ElementSchedule? schedule = await _learning.findSchedule(ref);
    if (schedule == null) return;
    await _learning.saveSchedule(
      schedule.copyWith(
        priority: rank,
        revision: schedule.revision + 1,
        updatedAtUtc: command.timestampUtc,
      ),
    );
  }

  Future<void> _writeTopic(
    BrowserSelectionCommand command, {
    required TopicState before,
    required TopicState after,
    required RevlogEventType eventType,
  }) async {
    final TopicState stored = after.copyWith(
      schedule: after.schedule.copyWith(updatedAtUtc: command.timestampUtc),
    );
    await _learning.saveTopic(stored);
    final StudyDayCalendar calendar = await _context.calendar();
    final PriorityScale scale = await _context.priorityScale();
    await _journal.append(
      operationId: _itemOperation(command, before.ref),
      ref: before.ref,
      eventType: eventType,
      atUtc: command.timestampUtc,
      before: _journal.topicSnapshot(
        before,
        calendar: calendar,
        pressure: scale.pressureOf(before.schedule.priority),
      ),
      after: _journal.topicSnapshot(
        stored,
        calendar: calendar,
        pressure: scale.pressureOf(stored.schedule.priority),
      ),
      scheduledDays: stored.intervalDays,
      postponeCount: stored.totalPostponementCount,
      schedulerVersion: stored.schedulerVersion,
    );
  }

  Future<void> _logCard(
    BrowserSelectionCommand command, {
    required CardState before,
    required CardState after,
    required RevlogEventType eventType,
  }) async {
    final PriorityScale scale = await _context.priorityScale();
    await _journal.append(
      operationId: _itemOperation(command, before.schedule.ref),
      ref: before.schedule.ref,
      eventType: eventType,
      atUtc: command.timestampUtc,
      before: _journal.cardSnapshot(
        before,
        pressure: scale.pressureOf(before.schedule.priority),
      ),
      after: _journal.cardSnapshot(
        after,
        pressure: scale.pressureOf(after.schedule.priority),
      ),
      scheduledDays: after.memory.scheduledDays,
      postponeCount: after.memory.postponeCount,
      schedulerVersion: after.memory.schedulerVersion,
      parametersVersion: after.memory.parametersVersion,
    );
  }

  String _itemOperation(BrowserSelectionCommand command, ElementRef ref) =>
      '${command.operationId.value}:${ref.type.name}:${ref.id}';

  /// Drops [refs] from every durable queue store.
  Future<void> _removeFromQueues(
    List<ElementRef> refs, {
    required bool shouldIncludeFinalDrill,
  }) async {
    if (refs.isEmpty) return;
    final Set<ElementRef> gone = refs.toSet();
    final Sm20CollectionState runtime = await _context.runtimeState();
    List<ElementRef> without(List<ElementRef> queue) => <ElementRef>[
      for (final ElementRef ref in queue)
        if (!gone.contains(ref)) ref,
    ];
    await _context.saveRuntimeState(
      runtime.copyWith(
        outstanding: without(runtime.outstanding),
        outstandingItems: without(runtime.outstandingItems),
        outstandingTopics: without(runtime.outstandingTopics),
        pending: without(runtime.pending),
        finalDrill: shouldIncludeFinalDrill
            ? without(runtime.finalDrill)
            : runtime.finalDrill,
      ),
    );
  }

  /// One transaction, one activity row, one diagnostic event.
  Future<Result<BrowserCommandOutcome>> _run(
    BrowserSelectionCommand command,
    String kind,
    Future<BrowserCommandOutcome> Function(StudyDay day) body,
  ) async {
    try {
      return await _transactions.run<Result<BrowserCommandOutcome>>(() async {
        if (await _learning.hasActivity(command.operationId.value, kind)) {
          // A resent bulk command is the same command: replaying it would
          // insert, raise, or advance a second time.
          return const Ok<BrowserCommandOutcome>(BrowserCommandOutcome.empty());
        }
        final BrowserCommandOutcome outcome = await body(command.day);
        await _learning.appendActivity(
          ActivityRecord(
            id: _ids.newId(),
            operationId: command.operationId.value,
            kind: kind,
            atUtc: command.timestampUtc,
            metadata: <String, Object?>{
              'day': command.day.toString(),
              'selected': command.refs.length,
              'changed': outcome.changedRefCount,
              'skipped': outcome.skipped,
              'random_draws': outcome.randomDraws,
            },
          ),
        );
        if (outcome.changedRefCount > 0) await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: DiagnosticLevel.info,
            name: kind,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: <String, Object?>{
              'selected': command.refs.length,
              'changed': outcome.changedRefCount,
              'skipped': outcome.skipped,
            },
          ),
        );
        return Ok<BrowserCommandOutcome>(outcome);
      });
    } on Object catch (error, stackTrace) {
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
      return Err<BrowserCommandOutcome>(failure);
    }
  }
}

/// One selected record, whichever family it belongs to.
final class _BrowserRecord {
  _BrowserRecord.topic(TopicState value)
    : topic = value,
      card = null,
      isMemorized = value.status == Sm20ElementStatus.memorized,
      storedInterval = value.storedInterval,
      lastReviewDay = value.lastReviewDay,
      priority = value.schedule.priority;

  _BrowserRecord.card(CardState value, {required StudyDayCalendar calendar})
    : topic = null,
      card = value,
      isMemorized = value.memory.reps > 0,
      storedInterval = value.memory.scheduledDays == null
          ? 0
          : value.memory.scheduledDays!.round(),
      lastReviewDay = value.memory.lastReviewAtUtc == null
          ? null
          : calendar.dayOf(value.memory.lastReviewAtUtc!),
      priority = value.schedule.priority;

  final TopicState? topic;
  final CardState? card;
  final bool isMemorized;
  final int storedInterval;
  final StudyDay? lastReviewDay;
  final PriorityRank priority;
}
