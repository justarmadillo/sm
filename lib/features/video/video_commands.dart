/// Every request that creates or changes a video or a range over one.
///
/// Done, Later and Dismiss are deliberately absent: a video is a topic, and
/// those commands already take an `ElementRef` of any type, so the video
/// screen sends the very same `CompleteTopicEncounter`, `PostponeElement` and
/// `DismissElement` the Reader does. A second set would be a second set of
/// scheduling rules.
library;

import 'package:incremental_reader/shared/command_base.dart';

/// Adds a video to the collection, with the range to be studied.
final class ImportVideo extends AppCommand {
  ImportVideo(
    super.operationId, {
    required this.url,
    required this.title,
    required this.startSeconds,
    required this.endSeconds,
    this.durationSeconds,
    this.priorityPercent,
    super.timestampUtc,
  });

  final String url;
  final String title;

  /// The part of the video worth studying, which is often not all of it.
  final int startSeconds;
  final int endSeconds;

  /// Whole-video length, when the user typed it.
  final int? durationSeconds;

  /// Where in the collection's order this lands, or null for the middle.
  final double? priorityPercent;
}

/// Cuts a narrower range out of a video element, with a note.
final class AddVideoClip extends AppCommand {
  AddVideoClip(
    super.operationId, {
    required this.parentVideoElementId,
    required this.startSeconds,
    required this.endSeconds,
    this.note = '',
    this.title,
    super.timestampUtc,
  });

  final String parentVideoElementId;
  final int startSeconds;
  final int endSeconds;

  /// What the user wrote about the clip. Cards formulate from this.
  final String note;

  /// An optional name; without one the clip is listed by its times.
  final String? title;
}

/// Records how far the user says they got. Never advances the schedule.
final class SetVideoResume extends AppCommand {
  SetVideoResume(
    super.operationId, {
    required this.videoElementId,
    required this.resumeSeconds,
    super.timestampUtc,
  });

  final String videoElementId;
  final int resumeSeconds;
}

/// Rewrites a video element's title, note, or range.
final class EditVideoElement extends AppCommand {
  EditVideoElement(
    super.operationId, {
    required this.videoElementId,
    this.title,
    this.note,
    this.startSeconds,
    this.endSeconds,
    super.timestampUtc,
  });

  final String videoElementId;

  /// Null leaves the stored value alone; every field here is optional so one
  /// dialog can save only what it actually offered.
  final String? title;
  final String? note;
  final int? startSeconds;
  final int? endSeconds;
}
