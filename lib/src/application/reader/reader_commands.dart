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
    this.priorityPercent,
    super.timestampUtc,
  });

  final String title;
  final String markdown;
  final ReadingPace pace;
  final String? folderId;

  /// Where to place the article in the collection, `0` being most important.
  ///
  /// Null starts it in the middle. Set at import because an article's
  /// priority is also what decides how soon it first comes back.
  final double? priorityPercent;
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
    this.wordsRead = 0,
    this.extractsCreated = 0,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// Foreground time spent this encounter, logged from day one so time-based
  /// features remain possible even though v1 schedules by count.
  final int? foregroundMs;

  /// Words rendered between the session's opening position and its end.
  ///
  /// An input to the optional yield rule, which lets a productive source keep
  /// coming back and a barren one recede.
  final int wordsRead;

  /// Extracts taken during this session, the other half of that ratio.
  final int extractsCreated;
}

/// Later: move eligibility without advancing the interval sequence.
final class PostponeElement extends AppCommand {
  PostponeElement(
    super.operationId, {
    required this.ref,
    this.until,
    this.kind = DeferralKind.manual,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// Explicit target day, or null to scale the delay by the element's own
  /// interval — a fixed one day just returns it tomorrow into the same queue.
  final StudyDay? until;

  final DeferralKind kind;
}

/// Declare a source finished. Reaching the end of the text does not do this.
final class FinishSource extends AppCommand {
  FinishSource(super.operationId, {required this.sourceId, super.timestampUtc});

  final String sourceId;
}

/// Restore the exact canonical snapshot before the latest topic encounter.
/// The original event remains in history and an inverse event references it.
final class UndoLastTopicEncounter extends AppCommand {
  UndoLastTopicEncounter(
    super.operationId, {
    required this.ref,
    super.timestampUtc,
  });

  final ElementRef ref;
}

/// Explicitly finish either a source or an extract. Descendants are untouched.
final class FinishTopic extends AppCommand {
  FinishTopic(super.operationId, {required this.ref, super.timestampUtc});

  final ElementRef ref;
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

/// Set a topic's next interval by hand.
///
/// SuperMemo reads this as a priority signal — asking to see something in
/// eleven days rather than thirty says it matters more — but the priority
/// change stays a separate, visible command rather than a hidden side effect.
final class RescheduleTopic extends AppCommand {
  RescheduleTopic(
    super.operationId, {
    required this.ref,
    required this.intervalDays,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// Days from today. Zero makes the element due again immediately.
  final int intervalDays;
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
