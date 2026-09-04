/// Saves and loads videos and the ranges taken over them, using Drift.
///
/// SQL and row mapping, nothing else. No repository decides an interval, a
/// lifecycle transition, or whether an operation is allowed.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/storage/contracts/video_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/row_converters.dart';

/// Video aggregate: videos and their scheduled ranges.
final class DriftVideoRepository implements VideoRepository {
  const DriftVideoRepository(this._database);

  final AppDatabase _database;

  @override
  Future<void> insertVideo(Video video) =>
      _database.into(_database.videos).insert(videoToCompanion(video));

  @override
  Future<Video?> findVideo(String id) async {
    final row = await (_database.select(
      _database.videos,
    )..where(($VideosTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : videoFromRow(row);
  }

  @override
  Future<Video?> findVideoByUrl(String url) async {
    final row = await (_database.select(
      _database.videos,
    )..where(($VideosTable t) => t.url.equals(url))).getSingleOrNull();
    return row == null ? null : videoFromRow(row);
  }

  @override
  Future<void> updateVideo(Video video) async {
    await (_database.update(
      _database.videos,
    )..where(($VideosTable t) => t.id.equals(video.id))).write(
      VideosCompanion(
        url: Value<String>(video.url),
        platform: Value<int>(video.platform.index),
        durationSeconds: Value<int?>(video.durationSeconds),
      ),
    );
  }

  @override
  Future<void> deleteVideo(String id) async {
    await (_database.delete(
      _database.videos,
    )..where(($VideosTable t) => t.id.equals(id))).go();
  }

  @override
  Future<void> insertVideoElement(VideoElement element) => _database
      .into(_database.videoElements)
      .insert(videoElementToCompanion(element));

  @override
  Future<VideoElement?> findVideoElement(String id) async {
    final row = await (_database.select(
      _database.videoElements,
    )..where(($VideoElementsTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : videoElementFromRow(row);
  }

  @override
  Future<List<VideoElement>> listVideoElementsOfVideo(String videoId) async {
    final rows =
        await (_database.select(_database.videoElements)
              ..where(($VideoElementsTable t) => t.videoId.equals(videoId))
              ..orderBy(<OrderClauseGenerator<$VideoElementsTable>>[
                ($VideoElementsTable t) => OrderingTerm.asc(t.startSeconds),
                ($VideoElementsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <VideoElement>[for (final row in rows) videoElementFromRow(row)];
  }

  @override
  Future<List<VideoElement>> listVideoElementsOfParent(
    String parentVideoElementId,
  ) async {
    final rows =
        await (_database.select(_database.videoElements)
              ..where(
                ($VideoElementsTable t) =>
                    t.parentVideoElementId.equals(parentVideoElementId),
              )
              ..orderBy(<OrderClauseGenerator<$VideoElementsTable>>[
                ($VideoElementsTable t) => OrderingTerm.asc(t.startSeconds),
                ($VideoElementsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <VideoElement>[for (final row in rows) videoElementFromRow(row)];
  }

  @override
  Future<List<VideoElement>> listVideoElements() async {
    final rows =
        await (_database.select(_database.videoElements)
              ..orderBy(<OrderClauseGenerator<$VideoElementsTable>>[
                ($VideoElementsTable t) => OrderingTerm.asc(t.createdAtUtc),
              ]))
            .get();
    return <VideoElement>[for (final row in rows) videoElementFromRow(row)];
  }

  @override
  Future<void> updateVideoElement(VideoElement element) async {
    await (_database.update(
      _database.videoElements,
    )..where(($VideoElementsTable t) => t.id.equals(element.id))).write(
      VideoElementsCompanion(
        title: Value<String?>(element.title),
        note: Value<String>(element.note),
        startSeconds: Value<int>(element.startSeconds),
        endSeconds: Value<int>(element.endSeconds),
        resumeSeconds: Value<int?>(element.resumeSeconds),
        editedAtUtc: Value<int?>(
          element.editedAtUtc == null ? null : toEpochMs(element.editedAtUtc!),
        ),
        revision: Value<int>(element.revision),
      ),
    );
  }

  @override
  Future<VideoElement?> saveVideoResume(String id, int resumeSeconds) async {
    await (_database.update(
      _database.videoElements,
    )..where(($VideoElementsTable t) => t.id.equals(id))).write(
      VideoElementsCompanion(resumeSeconds: Value<int>(resumeSeconds)),
    );
    return findVideoElement(id);
  }

  @override
  Future<void> deleteVideoElement(String id) async {
    await (_database.delete(
      _database.videoElements,
    )..where(($VideoElementsTable t) => t.id.equals(id))).go();
  }
}
