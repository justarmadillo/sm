/// What the app promises about saving and loading the videos you study.
///
/// Videos and the ranges taken over them. Nothing here mentions Drift, SQL, or
/// Flutter, so a screen can be tested against a hand-written stand-in.
///
/// Kept apart from `ContentRepository` rather than added to it: that interface
/// is already the largest in the app, and a video shares none of its
/// vocabulary — no markdown, no blocks, no byte ranges, no splices.
library;

import 'package:incremental_reader/documents/video.dart';

/// Videos and the ranges the user has chosen to study over them.
abstract interface class VideoRepository {
  /// Stores a video the collection has not seen before.
  Future<void> insertVideo(Video video);

  /// The video with [id], or null.
  Future<Video?> findVideo(String id);

  /// The video already stored for [url], or null.
  ///
  /// Adding a second range over a talk must not create a second video row, or
  /// correcting the URL would fix only one of them.
  Future<Video?> findVideoByUrl(String url);

  /// Replaces a video's mutable fields: URL, platform, duration.
  Future<void> updateVideo(Video video);

  /// Removes a video outright.
  ///
  /// Refused by the database while any element still names it, so the caller
  /// deletes the elements first.
  Future<void> deleteVideo(String id);

  /// Stores a new range over a video.
  Future<void> insertVideoElement(VideoElement element);

  /// The element with [id], or null.
  Future<VideoElement?> findVideoElement(String id);

  /// Every range over [videoId], earliest start first.
  Future<List<VideoElement>> listVideoElementsOfVideo(String videoId);

  /// Clips cut directly from [parentVideoElementId], earliest start first.
  Future<List<VideoElement>> listVideoElementsOfParent(
    String parentVideoElementId,
  );

  /// Every video element in the collection, oldest first.
  ///
  /// The Browser draws one tree over the whole collection, so it needs them
  /// all in one read.
  Future<List<VideoElement>> listVideoElements();

  /// Replaces an element's editable fields: title, note, and range.
  Future<void> updateVideoElement(VideoElement element);

  /// Updates only how far the user says they got, and returns the stored
  /// element.
  ///
  /// Separate from [updateVideoElement] for the same reason the reader's
  /// marker is separate from its text: moving a position is not an edit, and
  /// must not stamp the element as edited.
  Future<VideoElement?> saveVideoResume(String id, int resumeSeconds);

  /// Removes an element outright. Used by Undo, which must leave no trace.
  Future<void> deleteVideoElement(String id);
}
