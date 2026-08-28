/// Commands that shape the day's queue.
///
/// None of these is a review. They move eligibility and nothing else: no
/// interval grows, no memory state changes, no encounter is fabricated. That
/// separation is what lets the log distinguish "the user could not get to
/// this" from "the user got this wrong", which are opposite facts about the
/// same element.
library;

import 'package:incremental_reader/src/application/app_command.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/sm20_postpone.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';

/// Open or resume the day's SM20 queues and run the one-shot automatic sort.
final class RunDailyAdmission extends AppCommand {
  RunDailyAdmission(super.operationId, {required this.day, super.timestampUtc});

  /// The study day being admitted.
  final StudyDay day;
}

/// Which learning stage the user asked for by hand.
///
/// SM20 falls back through Outstanding, Final Drill and Pending on its own,
/// but the Learn menu also enters the two fallback stages directly. Choosing a
/// stage never fabricates work: it selects which existing queue is presented.
enum Sm20StageRequest {
  /// `Learn -> Stages -> 1. Outstanding material`. The way back: without it a
  /// user who entered a fallback stage would be held there until its queue
  /// emptied.
  outstanding(0),

  /// `Learn -> Stages -> 3. Final drill`, Ctrl+F4. Its hint in the executable
  /// is "Go through the final revision of the material repeated recently".
  finalDrill(1),

  /// `Learn -> Stages -> 2. New material`, whose hint is "Learn new material
  /// (i.e. commit it to your memory)".
  ///
  /// This is not `Random learning`. That command is a separate menu entry
  /// which reviews the same pending elements in randomized order, and is
  /// therefore this stage preceded by a randomization of the pending queue.
  newMaterial(2);

  const Sm20StageRequest(this.learningMode);

  /// The stored learning-mode byte this stage corresponds to.
  final int learningMode;
}

/// Enter a fallback learning stage without waiting for Outstanding to empty.
///
/// The automatic chain in section 9.5 is a default, not the only way in. This
/// command is the Learn menu's explicit entry, so it presents the requested
/// stage even while Outstanding still has work.
final class EnterLearningStage extends AppCommand {
  EnterLearningStage(
    super.operationId, {
    required this.day,
    required this.stage,
    super.timestampUtc,
  });

  final StudyDay day;
  final Sm20StageRequest stage;
}

/// `Cut drills`: eliminate every element scheduled for the final drill.
///
/// Drill membership is the only thing this touches. No due date, interval, A,
/// priority or repetition count changes, because drill membership was never
/// part of any of them.
final class CutDrills extends AppCommand {
  CutDrills(super.operationId, {required this.day, super.timestampUtc});

  final StudyDay day;
}

/// Which stored queue a manual randomization reorders.
enum Sm20RandomizableQueue {
  /// `Randomize repetitions`: "Randomize the sequence of outstanding items".
  outstanding,

  /// `Randomize drill`, prompted with "Do you want to randomize final drill?".
  finalDrill,

  /// `Randomize pending`, prompted with "Do you want to randomize pending
  /// queue?".
  pending,
}

/// Reorder one stored queue with the section 9.6 fixed-size swap.
///
/// This consumes the shared PRNG exactly as the automatic randomizations do —
/// one draw per element — so a manual reshuffle shifts every later stochastic
/// decision, which is the executable's behavior and not a defect.
final class RandomizeQueue extends AppCommand {
  RandomizeQueue(
    super.operationId, {
    required this.day,
    required this.queue,
    super.timestampUtc,
  });

  final StudyDay day;
  final Sm20RandomizableQueue queue;
}

/// What a manual stage or queue command did.
final class Sm20QueueCommandOutcome {
  const Sm20QueueCommandOutcome({
    required this.affected,
    required this.learningMode,
  });

  /// Elements reordered, or removed by Cut drills.
  final int affected;

  /// The learning mode in force after the command.
  final int learningMode;
}

/// Runs the Smart Postpone dialog record over its resolved source population.
///
/// Global scope reads Outstanding. Branch/browser scope receives the exact
/// source queue from the caller; a missing browser population falls back to
/// global Outstanding, matching the executable dialog.
final class RunSmartPostpone extends AppCommand {
  RunSmartPostpone(
    super.operationId, {
    required this.day,
    this.profile,
    this.sourcePopulation,
    this.applicableSubbranchProfiles = const <SmartPostponeSettings>[],
    super.timestampUtc,
  });

  final StudyDay day;
  final SmartPostponeSettings? profile;
  final List<ElementRef>? sourcePopulation;
  final List<SmartPostponeSettings> applicableSubbranchProfiles;
}

/// Result shown by Smart Postpone simulation and real execution.
final class AppliedSmartPostpone {
  const AppliedSmartPostpone({required this.result, required this.written});

  final SmartPostponeResult result;
  final int written;
}

/// Compute a Mercy redistribution without writing anything.
///
/// Mercy is exceptional bulk recovery, not the daily valve, so it is a
/// three-step conversation: preview, confirm, apply. The preview is pure —
/// it reads schedules, scores candidates, and returns the proposed calendar
/// with exact ordering and target days, so the user can refuse a plan they do
/// not like before a single row moves.
final class PreviewMercy extends AppCommand {
  PreviewMercy(
    super.operationId, {
    required this.day,
    this.reschedulingDays,
    this.gatheringDays,
    this.elementsPerDay,
    this.solveFromDailyCap = false,
    this.includeFuture,
    this.mode,
    this.subset,
    super.timestampUtc,
  });

  final StudyDay day;

  /// R, the number of target days. Null uses the Mercy setting.
  final int? reschedulingDays;

  /// G, the collection gathering horizon. Null uses the Mercy setting.
  final int? gatheringDays;

  /// C, the capacity-dialog input. When supplied, the exact SM20 solver
  /// derives R/G from the current ScheduledCount calendar.
  final int? elementsPerDay;

  /// True when C was the last edited capacity control. False means R/G were
  /// edited and C is recomputed from them.
  final bool solveFromDailyCap;

  /// Whether G may extend into future scheduled repetitions.
  final bool? includeFuture;

  /// Exact score ordering mode. Null uses the persisted setting.
  final MercyMode? mode;

  /// Null gathers the collection. A non-null list runs subset Mercy (the
  /// executable's Learning > Spread path) in supplied order.
  final List<ElementRef>? subset;
}

/// Commit a previewed Mercy batch.
///
/// Fails rather than writing if any candidate revision or active adjustment
/// changed since the preview: a stale plan would move the wrong material.
final class ApplyMercy extends AppCommand {
  ApplyMercy(
    super.operationId, {
    required this.day,
    required this.batchId,
    super.timestampUtc,
  });

  final StudyDay day;

  /// The previewed batch the user confirmed.
  final String batchId;
}

/// Reverse an applied Mercy batch exactly.
///
/// Restores the canonical topic/card states that existed before the batch and
/// appends an inverse event. Nothing is deleted.
final class UndoMercy extends AppCommand {
  UndoMercy(
    super.operationId, {
    required this.day,
    required this.batchId,
    super.timestampUtc,
  });

  final StudyDay day;
  final String batchId;
}

/// Rebuild the full-text index from the materialized documents.
final class RebuildSearchIndex extends AppCommand {
  RebuildSearchIndex(super.operationId, {super.timestampUtc});
}
