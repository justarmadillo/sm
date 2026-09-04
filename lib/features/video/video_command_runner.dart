/// Runs every command that creates or changes a video or a range over one.
///
/// The invariants this file enforces, in order of how easy they are to break:
///
/// * **A range is created independent from birth.** Its own schedule, its own
///   priority, its own lifecycle — exactly like an extract. Finishing or
///   dismissing the video it came from changes nothing about a clip.
/// * **One video row per URL.** A second range over the same talk reuses the
///   existing row, or correcting a mistyped URL would fix only one of them.
/// * **Moving the resume position is not an edit and not a repetition.** It
///   writes one column, stamps nothing, and never touches a due date.
///
/// Cutting a clip uses SM20's own media-extraction rule
/// (`TopicScheduler.extractMedia`) rather than the text one: a clip has no
/// length in characters, and the executable already treats media differently —
/// one priority draw, and the parent's A-factor left alone.
library;

import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/documents/video_link.dart';
import 'package:incremental_reader/features/video/video_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/history/scheduling_journal.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/search_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';
import 'package:incremental_reader/storage/contracts/video_repository.dart';

/// Activity kind recorded when a video enters the collection.
const String kVideoImportedType = 'video.imported';

/// Activity kind recorded when a clip is cut from a video.
const String kVideoClipCreatedType = 'video.clip_created';

/// Activity kind recorded when the resume position moves.
const String kVideoResumeMovedType = 'video.resume_moved';

/// Activity kind recorded when a title, note, or range is rewritten.
const String kVideoEditedType = 'video.edited';

/// Runs the commands for importing videos and cutting clips out of them.
final class VideoCommandRunner {
  VideoCommandRunner({
    required VideoRepository videos,
    required LearningRepository learning,
    required SearchRepository search,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required SchedulingContext context,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _videos = videos,
       _learning = learning,
       _search = search,
       _transfer = transfer,
       _transactions = transactions,
       _context = context,
       _clock = clock,
       _ids = ids,
       _journal = SchedulingJournal(learning: learning, ids: ids),
       _diagnostics = diagnostics;

  final VideoRepository _videos;
  final LearningRepository _learning;
  final SearchRepository _search;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final SchedulingContext _context;
  final Clock _clock;
  final IdGenerator _ids;
  final SchedulingJournal _journal;
  final DiagnosticSink _diagnostics;

  /// The study day the clock currently falls in.
  Future<StudyDay> today() => _context.today();

  /// Adds a video and the range to study, in one transaction.
  Future<Result<VideoElement>> importVideo(ImportVideo command) =>
      _run<VideoElement>(command, kVideoImportedType, () async {
        final String url = command.url.trim();
        final String title = command.title.trim();
        if (url.isEmpty) {
          return const Err<VideoElement>(
            ValidationFailure('a video needs a link'),
          );
        }
        if (title.isEmpty) {
          return const Err<VideoElement>(
            ValidationFailure('a video needs a title'),
          );
        }
        final Result<Unit> range = _validateRange(
          command.startSeconds,
          command.endSeconds,
        );
        if (range case Err<Unit>(:final AppFailure failure)) {
          return Err<VideoElement>(failure);
        }

        // One row per URL: a second range over the same talk must not create
        // a second video, or correcting the link would fix only one of them.
        final DateTime now = _clock.nowUtc();
        Video? video = await _videos.findVideoByUrl(url);
        if (video == null) {
          video = Video(
            id: _ids.newId(),
            url: url,
            platform: detectVideoPlatform(url),
            durationSeconds: command.durationSeconds,
            addedAtUtc: now,
          );
          await _videos.insertVideo(video);
        }

        final VideoElement element = VideoElement(
          id: _ids.newId(),
          videoId: video.id,
          title: title,
          startSeconds: command.startSeconds,
          endSeconds: command.endSeconds,
          createdAtUtc: now,
        );
        final ElementRef ref = ElementRef(
          id: element.id,
          type: ElementType.video,
        );

        // Nothing has been claimed about importance yet, so the middle of the
        // order the video is about to join — resolved against the collection
        // rather than a shared constant, because identical keys collapse it.
        final PriorityScale scale = await _context.priorityScale();
        final PriorityRank rank = scale.rankAtPercent(
          command.priorityPercent ?? 50,
        );
        final double pressure = scale.including(rank).pressureOf(rank);

        final StudyDay day = await today();
        final TopicScheduler scheduler = await _context.topicScheduler();
        final TopicState topic = scheduler.createFor(
          ref: ref,
          today: day,
          buildSchedule: (StudyDay due) => ElementSchedule(
            ref: ref,
            priority: rank,
            lifecycle: ElementLifecycle.active,
            dueDay: due,
            originalDueDay: due,
            rootId: element.id,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );

        await _videos.insertVideoElement(element);
        await _learning.insertTopic(topic);
        await _admitToPending(ref);
        await _saveSearchDocument(element, title: title, rootId: element.id);
        await _journalCreation(command, topic, pressure);
        await _log(
          command,
          kVideoImportedType,
          ref: ref,
          metadata: <String, Object?>{
            'platform': video.platform.name,
            'range_seconds': element.rangeSeconds,
            'first_interval_days': topic.intervalDays,
          },
        );
        return Ok<VideoElement>(element);
      });

  /// Cuts a narrower range out of a video element, in one transaction.
  Future<Result<VideoElement>> addClip(AddVideoClip command) =>
      _run<VideoElement>(command, kVideoClipCreatedType, () async {
        final VideoElement? parent = await _videos.findVideoElement(
          command.parentVideoElementId,
        );
        if (parent == null) {
          return Err<VideoElement>(
            NotFoundFailure(
              'no such video',
              entity: 'video',
              id: command.parentVideoElementId,
            ),
          );
        }
        final Result<Unit> range = _validateRange(
          command.startSeconds,
          command.endSeconds,
        );
        if (range case Err<Unit>(:final AppFailure failure)) {
          return Err<VideoElement>(failure);
        }
        // A clip that reaches outside the range it was cut from is not a clip
        // of it, and would make "how much is left to mine" meaningless.
        if (command.startSeconds < parent.startSeconds ||
            command.endSeconds > parent.endSeconds) {
          return const Err<VideoElement>(
            ValidationFailure('that clip falls outside what you are watching'),
          );
        }

        final ElementRef parentRef = ElementRef(
          id: parent.id,
          type: ElementType.video,
        );
        final ElementSchedule? parentSchedule = await _learning.findSchedule(
          parentRef,
        );
        final TopicState? parentTopic = await _learning.findTopic(parentRef);
        if (parentSchedule == null || parentTopic == null) {
          return _missingSchedule<VideoElement>(parent.id);
        }

        final DateTime now = _clock.nowUtc();
        final VideoElement clip = VideoElement(
          id: _ids.newId(),
          videoId: parent.videoId,
          parentVideoElementId: parent.id,
          title: command.title?.trim().isEmpty ?? true
              ? null
              : command.title!.trim(),
          note: command.note,
          startSeconds: command.startSeconds,
          endSeconds: command.endSeconds,
          createdAtUtc: now,
        );
        final ElementRef ref = ElementRef(id: clip.id, type: ElementType.video);

        final StudyDay day = await today();
        final TopicScheduler scheduler = await _context.topicScheduler();
        final PriorityScale scale = await _context.priorityScale();
        // SM20's media rule, not its text one: a clip has no length in
        // characters, and the executable leaves the parent's A-factor alone
        // for media.
        final Sm20MediaExtraction extraction = scheduler.extractMedia(
          sourcePriorityPercent: scale.percentageOf(parentSchedule.priority),
        );
        final PriorityRank parentRank = scale.rankForSetPriority(
          parentSchedule.priority,
          extraction.sourcePriorityTarget,
        );
        final PriorityScale afterParent = scale.replacing(
          parentSchedule.priority,
          parentRank,
        );
        final PriorityRank clipRank = afterParent.rankAtPercent(
          extraction.childPriorityTarget,
        );

        TopicState topic = scheduler.createFor(
          ref: ref,
          today: day,
          initialAFactor: extraction.childAFactor,
          isMemorized: true,
          buildSchedule: (StudyDay due) => ElementSchedule(
            ref: ref,
            priority: clipRank,
            lifecycle: ElementLifecycle.active,
            dueDay: due,
            originalDueDay: due,
            rootId: parentSchedule.rootId ?? parent.id,
            parentElementId: parent.id,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
        final PriorityScale withClip = afterParent.including(clipRank);
        topic = topic.copyWith(
          schedule: topic.schedule.copyWith(
            priority: withClip.rankForSetPriority(
              clipRank,
              extraction.childPriorityTarget,
            ),
          ),
        );

        // Both revisions advance, which is what compareAndSwapTopic requires.
        // The text rule returns an updated source and bumps the record's own
        // revision on the way; the media rule leaves the parent's A-factor
        // alone and returns nothing, so the bump has to happen here.
        final TopicState updatedParent = parentTopic.copyWith(
          revision: parentTopic.revision + 1,
          schedule: parentTopic.schedule.copyWith(
            priority: parentRank,
            revision: parentTopic.schedule.revision + 1,
            updatedAtUtc: now,
          ),
        );

        await _videos.insertVideoElement(clip);
        if (!await _learning.compareAndSwapTopic(
          expected: parentTopic,
          replacement: updatedParent,
        )) {
          return const Err<VideoElement>(
            ConflictFailure('the video changed before commit'),
          );
        }
        await _learning.insertTopic(topic);
        await _context.saveRandomNumberState(extraction.randomNumberState);
        await _saveSearchDocument(
          clip,
          title: parent.displayTitle,
          rootId: parentSchedule.rootId ?? parent.id,
        );
        await _journal.append(
          operationId: command.operationId.value,
          ref: ref,
          eventType: ReviewLogEventType.created,
          atUtc: command.timestampUtc,
          after: _journal.topicSnapshot(
            topic,
            calendar: await _context.calendar(),
            pressure: withClip.pressureOf(topic.schedule.priority),
          ),
          scheduledDays: topic.intervalDays,
          metadata: <String, Object?>{
            'parent': parent.id,
            'first_interval_days': topic.intervalDays,
            'child_a_raw': topic.aFactorRaw.toString(),
            'source_priority_target': extraction.sourcePriorityTarget,
            'child_priority_target': extraction.childPriorityTarget,
          },
        );
        await _log(
          command,
          kVideoClipCreatedType,
          ref: ref,
          metadata: <String, Object?>{
            'parent': parent.id,
            'range_seconds': clip.rangeSeconds,
          },
        );
        return Ok<VideoElement>(clip);
      });

  /// Records how far the user says they got. Never advances the schedule.
  Future<Result<VideoElement>> setResume(SetVideoResume command) =>
      _run<VideoElement>(command, kVideoResumeMovedType, () async {
        final VideoElement? element = await _videos.findVideoElement(
          command.videoElementId,
        );
        if (element == null) return _missingVideo<VideoElement>(command.videoElementId);
        if (command.resumeSeconds < element.startSeconds ||
            command.resumeSeconds > element.endSeconds) {
          return const Err<VideoElement>(
            ValidationFailure('that time is outside what you are watching'),
          );
        }

        final VideoElement? updated = await _videos.saveVideoResume(
          element.id,
          command.resumeSeconds,
        );
        if (updated == null) return _missingVideo<VideoElement>(element.id);
        await _log(
          command,
          kVideoResumeMovedType,
          ref: ElementRef(id: element.id, type: ElementType.video),
          metadata: <String, Object?>{'seconds': command.resumeSeconds},
        );
        return Ok<VideoElement>(updated);
      });

  /// Rewrites a title, a note, or a range. Never advances the schedule.
  Future<Result<VideoElement>> editElement(EditVideoElement command) =>
      _run<VideoElement>(command, kVideoEditedType, () async {
        final VideoElement? element = await _videos.findVideoElement(
          command.videoElementId,
        );
        if (element == null) return _missingVideo<VideoElement>(command.videoElementId);

        final int start = command.startSeconds ?? element.startSeconds;
        final int end = command.endSeconds ?? element.endSeconds;
        final Result<Unit> range = _validateRange(start, end);
        if (range case Err<Unit>(:final AppFailure failure)) {
          return Err<VideoElement>(failure);
        }
        final String? title = command.title?.trim();
        if (!element.isClip && (title != null && title.isEmpty)) {
          return const Err<VideoElement>(
            ValidationFailure('a video needs a title'),
          );
        }

        // A narrowed range can strand the resume position outside it, and the
        // database refuses that pairing. Pulling it to the nearest end keeps
        // the two consistent without inventing progress the user never made.
        final int? resume = element.resumeSeconds?.clamp(start, end);

        final VideoElement updated = element.copyWith(
          title: title,
          note: command.note,
          startSeconds: start,
          endSeconds: end,
          resumeSeconds: resume,
          editedAtUtc: _clock.nowUtc(),
          revision: element.revision + 1,
        );
        await _videos.updateVideoElement(updated);

        final ElementRef ref = ElementRef(
          id: element.id,
          type: ElementType.video,
        );
        final ElementSchedule? schedule = await _learning.findSchedule(ref);
        final VideoElement? parent = updated.parentVideoElementId == null
            ? null
            : await _videos.findVideoElement(updated.parentVideoElementId!);
        await _saveSearchDocument(
          updated,
          title: parent?.displayTitle ?? updated.displayTitle,
          rootId: schedule?.rootId ?? updated.id,
        );
        await _log(command, kVideoEditedType, ref: ref);
        return Ok<VideoElement>(updated);
      });

  /// Refuses a range that holds nothing or starts before the video does.
  Result<Unit> _validateRange(int startSeconds, int endSeconds) {
    if (startSeconds < 0) {
      return const Err<Unit>(ValidationFailure('a time cannot be negative'));
    }
    if (endSeconds <= startSeconds) {
      return const Err<Unit>(
        ValidationFailure('the end has to come after the start'),
      );
    }
    return okUnit;
  }

  /// Puts a newly created element in front of the user's next session.
  Future<void> _admitToPending(ElementRef ref) async {
    final runtime = await _context.runtimeState();
    await _context.saveRuntimeState(
      runtime.copyWith(
        pending: <ElementRef>[
          ...runtime.pending.where((ElementRef value) => value != ref),
          ref,
        ],
      ),
    );
  }

  /// Indexes what there is to search: the name, and whatever was written.
  ///
  /// A video carries no transcript, so unlike a source there is no body to
  /// index until the user writes one. That is a real limitation of studying
  /// video and not something to paper over with the URL.
  Future<void> _saveSearchDocument(
    VideoElement element, {
    required String title,
    required String? rootId,
  }) => _search.saveDocument(
    SearchDocument(
      ref: ElementRef(id: element.id, type: ElementType.video),
      title: title,
      body: <String>[
        if (element.title != null) element.title!,
        element.rangeLabel,
        element.note,
      ].where((String part) => part.trim().isNotEmpty).join('\n'),
      sourceId: rootId,
      updatedAtUtc: element.editedAtUtc ?? element.createdAtUtc,
    ),
  );

  Future<void> _journalCreation(
    AppCommand command,
    TopicState topic,
    double pressure,
  ) async {
    final StudyDayCalendar calendar = await _context.calendar();
    await _journal.append(
      operationId: command.operationId.value,
      ref: topic.ref,
      eventType: ReviewLogEventType.created,
      atUtc: command.timestampUtc,
      after: _journal.topicSnapshot(
        topic,
        calendar: calendar,
        pressure: pressure,
      ),
      scheduledDays: topic.intervalDays,
      metadata: <String, Object?>{
        'first_interval_days': topic.intervalDays,
        'pressure': pressure,
      },
    );
  }

  /// Wraps a command body in a transaction, idempotency check, and tracing.
  Future<Result<T>> _run<T>(
    AppCommand command,
    String type,
    Future<Result<T>> Function() body,
  ) async {
    try {
      return await _transactions.run<Result<T>>(() async {
        if (await _learning.hasActivity(command.operationId.value, type)) {
          return Err<T>(
            ConflictFailure('operation ${command.operationId} already applied'),
          );
        }
        final Result<T> result = await body();
        if (result.isOk) await _transfer.advanceGeneration();
        _diagnostics.record(
          DiagnosticEvent(
            level: result.isOk ? DiagnosticLevel.info : DiagnosticLevel.warning,
            name: type,
            timestampUtc: _clock.nowUtc(),
            operationId: command.operationId,
            fields: <String, Object?>{'ok': result.isOk},
            failure: result.failureOrNull,
          ),
        );
        return result;
      });
    } on Object catch (error, stackTrace) {
      final UnexpectedFailure failure = UnexpectedFailure(
        'command $type failed',
        cause: error,
        stackTrace: stackTrace,
      );
      _diagnostics.record(
        DiagnosticEvent(
          level: DiagnosticLevel.error,
          name: type,
          timestampUtc: _clock.nowUtc(),
          operationId: command.operationId,
          failure: failure,
        ),
      );
      return Err<T>(failure);
    }
  }

  Future<void> _log(
    AppCommand command,
    String type, {
    ElementRef? ref,
    Map<String, Object?>? metadata,
  }) => _learning.appendActivity(
    ActivityRecord(
      id: _ids.newId(),
      operationId: command.operationId.value,
      type: type,
      atUtc: command.timestampUtc,
      ref: ref,
      metadata: metadata,
    ),
  );

  Err<T> _missingVideo<T>(String id) =>
      Err<T>(NotFoundFailure('no such video', entity: 'video', id: id));

  Err<T> _missingSchedule<T>(String id) => Err<T>(
    NotFoundFailure('no schedule for that element', entity: 'schedule', id: id),
  );
}
