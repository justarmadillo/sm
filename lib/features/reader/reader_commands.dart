/// Explicit commands for everything the Reader can change.
///
/// Every mutation is a named, immutable value carrying an operation id. That
/// id is what makes terminal actions safe: a Done that is retried after a
/// crash, a double-click, or a queue advancing twice must commit once, and the
/// command runner decides that by looking for the id in the activity log
/// by hoping the UI never fires twice.
library;

import 'dart:typed_data';

import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:meta/meta.dart';

/// Import markdown as a new source.
final class ImportSource extends AppCommand {
  ImportSource(
    super.operationId, {
    required this.title,
    required this.markdown,
    this.priorityPercent,
    super.timestampUtc,
  });

  final String title;
  final String markdown;

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
    this.isAutomatic = false,
    super.timestampUtc,
  });

  final ElementRef ref;

  /// Explicit target day, or null to scale the delay by the element's own
  /// interval — a fixed one day just returns it tomorrow into the same queue.
  final StudyDay? until;

  /// Whether the automatic postpone pass issued this, rather than the user.
  ///
  /// It selects the log's event type and nothing else: SM20 records both as
  /// the same low-level reschedule.
  final bool isAutomatic;
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

/// Keep the content, stop scheduling it.
final class DismissElement extends AppCommand {
  DismissElement(super.operationId, {required this.ref, super.timestampUtc});

  final ElementRef ref;
}

/// Undismiss: return a dismissed element to the pending store.
///
/// SM20 restores the status byte and nothing else — the schedule and the
/// priority Dismiss cleared stay cleared.
final class UndismissSource extends AppCommand {
  UndismissSource(super.operationId, {required this.ref, super.timestampUtc});

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

/// Replace the raw markdown of one block.
///
/// The common editing path. The block's byte range is known before the user
/// types, so committing produces an exact splice with nothing to infer.
///
/// [baseContentRevision] is the revision the editor was opened against. A
/// mismatch is refused rather than merged: two windows editing one source is
/// an ordinary situation, and silently overwriting the other one is not an
/// acceptable answer to it.
final class EditSourceBlock extends AppCommand {
  EditSourceBlock(
    super.operationId, {
    required this.sourceId,
    required this.blockId,
    required this.markdown,
    required this.baseContentRevision,
    super.timestampUtc,
  });

  final String sourceId;
  final String blockId;

  /// The block's new markdown. Blank removes the block.
  final String markdown;

  final int baseContentRevision;
}

/// Remove one block and the separator that went with it.
final class DeleteSourceBlock extends AppCommand {
  DeleteSourceBlock(
    super.operationId, {
    required this.sourceId,
    required this.blockId,
    required this.baseContentRevision,
    super.timestampUtc,
  });

  final String sourceId;
  final String blockId;
  final int baseContentRevision;
}

/// Add a new block after an existing one.
final class InsertSourceBlock extends AppCommand {
  InsertSourceBlock(
    super.operationId, {
    required this.sourceId,
    required this.afterBlockId,
    required this.markdown,
    required this.baseContentRevision,
    super.timestampUtc,
  });

  final String sourceId;
  final String afterBlockId;
  final String markdown;
  final int baseContentRevision;
}

/// One validated image whose immutable bytes are ready for app-owned storage.
@immutable
final class SourceImageImport {
  const SourceImageImport({
    required this.bytes,
    required this.altText,
    required this.sha256,
    required this.mime,
    required this.widthPx,
    required this.heightPx,
  });

  final Uint8List bytes;
  final String altText;
  final String sha256;
  final String mime;
  final int widthPx;
  final int heightPx;

  String get srcRef => 'ir-asset:$sha256';
}

/// Adds validated images as consecutive standalone blocks after one block.
final class InsertSourceImages extends AppCommand {
  InsertSourceImages(
    super.operationId, {
    required this.sourceId,
    required this.afterBlockId,
    required this.images,
    required this.baseContentRevision,
    super.timestampUtc,
  });

  final String sourceId;

  /// Block after which the images land, or null for an empty source.
  final String? afterBlockId;
  final List<SourceImageImport> images;
  final int baseContentRevision;
}

/// Swap a heading's section with the sibling section above or below it.
///
/// The Reader's outline is the document's own heading lines, so reordering it
/// reorders the text: a section carries its paragraphs with it. Expressed as
/// one splice over the two adjacent sections, which is why it needs no
/// machinery of its own beyond the commands above.
final class MoveSourceSection extends AppCommand {
  MoveSourceSection(
    super.operationId, {
    required this.sourceId,
    required this.blockId,
    required this.shouldMoveUp,
    required this.baseContentRevision,
    super.timestampUtc,
  });

  final String sourceId;

  /// The heading block at the top of the section being moved.
  final String blockId;

  final bool shouldMoveUp;
  final int baseContentRevision;
}

/// Reverse the most recent edit to a source's text.
///
/// Applied as an ordinary forward splice at a new revision, so the journal
/// stays append-only and replaying it remains total.
final class UndoSourceEdit extends AppCommand {
  UndoSourceEdit(
    super.operationId, {
    required this.sourceId,
    super.timestampUtc,
  });

  final String sourceId;
}
