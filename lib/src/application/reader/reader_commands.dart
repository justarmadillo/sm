/// Explicit commands for everything the Reader can change.
///
/// Every mutation is a named, immutable value carrying an operation id. That
/// id is what makes terminal actions safe: a Done that is retried after a
/// crash, a double-click, or a queue advancing twice must commit once, and the
/// handler decides that by looking for the id in the activity log rather than
/// by hoping the UI never fires twice.
library;

import '../../domain/content/reader_anchor.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/study_day.dart';
import '../app_command.dart';

/// Import markdown as a new source.
final class ImportSource extends AppCommand {
  ImportSource(
    super.operationId, {
    required this.title,
    required this.markdown,
    this.pace = ReadingPace.normal,
    this.folderId,
    super.timestampUtc,
  });

  final String title;
  final String markdown;
  final ReadingPace pace;
  final String? folderId;
}

/// Place the authoritative resume marker.
///
/// The one Reader gesture that counts as progress. It does not advance the
/// schedule — position and schedule are separate questions.
final class MoveResumeMarker extends AppCommand {
  MoveResumeMarker(
    super.operationId, {
    required this.sourceId,
    required this.anchor,
    super.timestampUtc,
  });

  final String sourceId;
  final ReaderAnchor anchor;
}

/// Record the last stable scroll position.
///
/// Written on pause, close, and process death. Never progress, never a
/// schedule change, and freely overwritten by more scrolling.
final class SaveSoftPosition extends AppCommand {
  SaveSoftPosition(
    super.operationId, {
    required this.sourceId,
    required this.anchor,
    super.timestampUtc,
  });

  final String sourceId;
  final ReaderAnchor anchor;
}

/// Promote the soft position to the authoritative marker.
final class ConfirmSoftPosition extends AppCommand {
  ConfirmSoftPosition(
    super.operationId, {
    required this.sourceId,
    super.timestampUtc,
  });

  final String sourceId;
}

/// Done: one encounter is complete, advance the schedule once.
final class CompleteTopicEncounter extends AppCommand {
  CompleteTopicEncounter(
    super.operationId, {
    required this.ref,
    this.foregroundMs,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// Foreground time spent this encounter, logged from day one so time-based
  /// features remain possible even though v1 schedules by count.
  final int? foregroundMs;
}

/// Later: move eligibility without advancing the interval sequence.
final class PostponeElement extends AppCommand {
  PostponeElement(
    super.operationId, {
    required this.ref,
    required this.until,
    this.kind = DeferralKind.manual,
    super.timestampUtc,
  });

  final ElementRef ref;
  final StudyDay until;
  final DeferralKind kind;
}

/// Declare a source finished. Reaching the end of the text does not do this.
final class FinishSource extends AppCommand {
  FinishSource(super.operationId, {required this.sourceId, super.timestampUtc});

  final String sourceId;
}

/// Keep the content, stop scheduling it.
final class DismissElement extends AppCommand {
  DismissElement(super.operationId, {required this.ref, super.timestampUtc});

  final ElementRef ref;
}

/// Temporarily remove an element from scheduling.
final class SuspendElement extends AppCommand {
  SuspendElement(super.operationId, {required this.ref, super.timestampUtc});

  final ElementRef ref;
}

/// Return a suspended, dismissed, or finished element to the queue.
final class ReactivateElement extends AppCommand {
  ReactivateElement(super.operationId, {required this.ref, super.timestampUtc});

  final ElementRef ref;
}

/// Change an element's relative priority.
final class SetPriority extends AppCommand {
  SetPriority(
    super.operationId, {
    required this.ref,
    required this.rank,
    super.timestampUtc,
  });

  final ElementRef ref;
  final PriorityRank rank;
}

/// Change how a source is paced, without touching its position or step.
final class SetReadingPace extends AppCommand {
  SetReadingPace(
    super.operationId, {
    required this.sourceId,
    required this.pace,
    super.timestampUtc,
  });

  final String sourceId;
  final ReadingPace pace;
}

/// Rename a source.
final class RenameSource extends AppCommand {
  RenameSource(
    super.operationId, {
    required this.sourceId,
    required this.title,
    super.timestampUtc,
  });

  final String sourceId;
  final String title;
}

/// Soft-delete a source while retaining content and every descendant.
final class DeleteSource extends AppCommand {
  DeleteSource(super.operationId, {required this.sourceId, super.timestampUtc});

  final String sourceId;
}
