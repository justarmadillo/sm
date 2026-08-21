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
  StudyMore(super.operationId, {required this.day, this.count, super.timestampUtc});

  final StudyDay day;

  /// How many elements to recall. Null uses the configured step.
  final int? count;
}

/// Spread an accumulated backlog across a horizon in one operation.
///
/// Auto-postpone handles daily drift but chews a three-week absence one day at
/// a time, which leaves the user staring at an impossible queue every morning.
/// Mercy resolves the whole backlog at once: the top of it lands within days,
/// the tail lands months out. That distribution is the correct outcome, not
/// damage control.
final class RunMercy extends AppCommand {
  RunMercy(
    super.operationId, {
    required this.day,
    this.horizonDays,
    this.dailyCap,
    super.timestampUtc,
  });

  final StudyDay day;

  /// Days to spread across. Null uses the configured horizon.
  final int? horizonDays;

  /// Elements to place on each day. Null uses the configured cap.
  final int? dailyCap;
}

/// Rebuild the full-text index from the materialized documents.
final class RebuildSearchIndex extends AppCommand {
  RebuildSearchIndex(super.operationId, {super.timestampUtc});
}
