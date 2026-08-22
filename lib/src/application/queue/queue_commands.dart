/// Commands that shape the day's queue.
///
/// None of these is a review. They move eligibility and nothing else: no
/// interval grows, no memory state changes, no encounter is fabricated. That
/// separation is what lets the log distinguish "the user could not get to
/// this" from "the user got this wrong", which are opposite facts about the
/// same element.
library;

import '../../domain/scheduling/study_day.dart';
import '../app_command.dart';

/// Apply the day's admission caps, deferring what does not fit.
///
/// Runs when the queue is built. Exactly-once per study day: the operation id
/// is derived from the day, so rebuilding the queue five times in a session
/// defers nothing a second time.
final class RunDailyAdmission extends AppCommand {
  RunDailyAdmission(
    super.operationId, {
    required this.day,
    this.extraAdmissions = 0,
    super.timestampUtc,
  });

  /// The study day being admitted.
  final StudyDay day;

  /// Temporary headroom above the configured caps, from Study More.
  final int extraAdmissions;
}

/// Take back some of what the valve deferred today.
///
/// Recalls automatic deferrals only. A manual Later stands: the user said
/// "not now", and asking for more work is not them changing their mind about
/// a specific element.
final class StudyMore extends AppCommand {
  StudyMore(
    super.operationId, {
    required this.day,
    this.count,
    super.timestampUtc,
  });

  final StudyDay day;

  /// How many elements to recall. Null uses the configured step.
  final int? count;
}

/// Compute a Mercy redistribution without writing anything.
///
/// Mercy is exceptional bulk recovery, not the daily valve, so it is a
/// three-step conversation: preview, confirm, apply. The preview is pure —
/// it reads schedules, scores candidates, and returns the proposed calendar
/// plus every exclusion, so the user can refuse a plan they do not like
/// before a single row moves.
final class PreviewMercy extends AppCommand {
  PreviewMercy(
    super.operationId, {
    required this.day,
    this.horizonDays,
    this.dailyCap,
    this.branchRootId,
    this.collectingPeriodDays,
    this.includeFutureRepetitions = false,
    this.includeProtected = false,
    this.overrideManualLater = false,
    super.timestampUtc,
  });

  final StudyDay day;

  /// Days to spread across. Null uses the configured horizon.
  final int? horizonDays;

  /// Most elements Mercy may place on one day. Null uses the configured cap.
  final int? dailyCap;

  /// Restricts the scope to one source subtree. Null means the collection.
  final String? branchRootId;

  /// How far back the backlog is collected from. Null collects everything
  /// outstanding.
  final int? collectingPeriodDays;

  /// Whether work already scheduled beyond today may also be moved.
  final bool includeFutureRepetitions;

  /// Opt in to redistributing protected top-priority material.
  final bool includeProtected;

  /// Opt in to clearing manual Later bounds, which are otherwise preserved.
  final bool overrideManualLater;
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
/// Restores the adjustment set that existed before the batch and appends an
/// inverse event. Nothing is deleted, and canonical schedules never move.
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
