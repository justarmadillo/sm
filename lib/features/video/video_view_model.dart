/// ViewModel for processing one range of a video.
///
/// The same shape as the Extract screen's, because a video range is processed
/// the same way: open it, do some of it, mark where you got to, cut what is
/// worth keeping, then Done or Later. Done, Later and Dismiss go through the
/// Reader's command runner unchanged — they take an `ElementRef` of any type,
/// and a second implementation would be a second set of scheduling rules.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/documents/video_link.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/extract/extract_providers.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/reader/reader_providers.dart';
import 'package:incremental_reader/features/video/video_commands.dart';
import 'package:incremental_reader/features/video/video_providers.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// Whether the range is being processed or only consulted.
enum VideoMode { scheduled, browse }

@immutable
final class VideoRequest {
  const VideoRequest({required this.videoElementId, this.mode = VideoMode.browse});

  final String videoElementId;
  final VideoMode mode;

  @override
  bool operator ==(Object other) =>
      other is VideoRequest &&
      other.videoElementId == videoElementId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(videoElementId, mode);
}

@immutable
final class VideoUiState {
  const VideoUiState({
    required this.element,
    required this.video,
    required this.topic,
    required this.mode,
    required this.clips,
    required this.cards,
    this.effectiveDueDay,
    this.lastClipId,
    this.message,
    this.isBusy = false,
    this.isDone = false,
  });

  final VideoElement element;
  final Video video;
  final TopicState topic;
  final VideoMode mode;

  /// Clips cut directly out of this range.
  final List<VideoElement> clips;
  final List<Card> cards;

  /// When this range may next be presented, adjustments included.
  final StudyDay? effectiveDueDay;
  final String? lastClipId;
  final UiMessage? message;
  final bool isBusy;
  final bool isDone;

  bool get canMutate => mode == VideoMode.scheduled;

  /// Where Open should land: where the user got to, or the range's start.
  int get openAtSeconds => element.resumeSeconds ?? element.startSeconds;

  /// The link to hand the platform, and whether it carries the time.
  VideoOpenLink get openLink => videoOpenLink(
    url: video.url,
    platform: video.platform,
    atSeconds: openAtSeconds,
  );

  /// Seconds of this range that no clip covers yet.
  ///
  /// The video answer to "is there anything left to mine here".
  int get unclippedSeconds => secondsOutside(
    startSeconds: element.startSeconds,
    endSeconds: element.endSeconds,
    covered: <(int, int)>[
      for (final VideoElement clip in clips)
        (clip.startSeconds, clip.endSeconds),
    ],
  );

  VideoUiState copyWith({
    VideoElement? element,
    Video? video,
    TopicState? topic,
    VideoMode? mode,
    List<VideoElement>? clips,
    List<Card>? cards,
    StudyDay? effectiveDueDay,
    String? lastClipId,
    bool shouldClearLastClip = false,
    UiMessage? message,
    bool shouldClearMessage = false,
    bool? isBusy,
    bool? isDone,
  }) => VideoUiState(
    element: element ?? this.element,
    video: video ?? this.video,
    topic: topic ?? this.topic,
    mode: mode ?? this.mode,
    clips: clips ?? this.clips,
    cards: cards ?? this.cards,
    effectiveDueDay: effectiveDueDay ?? this.effectiveDueDay,
    lastClipId: shouldClearLastClip ? null : (lastClipId ?? this.lastClipId),
    message: shouldClearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
    isDone: isDone ?? this.isDone,
  );
}

/// The Video screen's ViewModel, one per open range.
///
/// `arg` below is Riverpod's name for the value the screen was opened with —
/// here the [VideoRequest] passed to `videoViewModelProvider(...)`. It is
/// inherited from `FamilyAsyncNotifier` and cannot be renamed.
final class VideoViewModel
    extends FamilyAsyncNotifier<VideoUiState, VideoRequest> {
  DateTime? _sessionStartedAt;

  @override
  Future<VideoUiState> build(VideoRequest arg) async {
    _sessionStartedAt = ref.read(clockProvider).nowUtc();
    return _load(arg.mode);
  }

  Future<VideoUiState> _load(VideoMode mode) async {
    final videos = ref.read(videoRepositoryProvider);
    final VideoElement? element = await videos.findVideoElement(
      arg.videoElementId,
    );
    if (element == null) {
      throw StateError('video ${arg.videoElementId} is not in the library');
    }
    final Video? video = await videos.findVideo(element.videoId);
    if (video == null) {
      throw StateError('video ${arg.videoElementId} has lost its link');
    }
    final TopicState? topic = await ref
        .read(learningRepositoryProvider)
        .findTopic(ElementRef(id: element.id, type: ElementType.video));
    if (topic == null) {
      throw StateError('video ${arg.videoElementId} has no schedule');
    }
    return VideoUiState(
      element: element,
      video: video,
      topic: topic,
      mode: mode,
      clips: await videos.listVideoElementsOfParent(element.id),
      cards: await ref
          .read(contentRepositoryProvider)
          .listCardsOfVideo(element.id),
      effectiveDueDay: await ref.read(effectiveDueQueryProvider).forTopic(topic),
    );
  }

  void continueScheduled() {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || current.canMutate) return;
    state = AsyncValue<VideoUiState>.data(
      current.copyWith(
        mode: VideoMode.scheduled,
        message: const UiMessage('Processing for today'),
      ),
    );
  }

  /// Records how far the user says they got.
  ///
  /// Allowed while browsing, like editing an extract's text: saying where you
  /// stopped is not processing the element, and losing the position because
  /// the screen was opened from the tree would be worse than the alternative.
  Future<void> setResume(int seconds) => _command<VideoElement>(
    (OperationId operation) => ref
        .read(videoCommandRunnerProvider)
        .setResume(
          SetVideoResume(
            operation,
            videoElementId: arg.videoElementId,
            resumeSeconds: seconds,
          ),
        ),
    apply: (VideoUiState latest, VideoElement element) =>
        latest.copyWith(element: element),
  );

  /// Rewrites the note, the title, or the range.
  Future<void> edit({
    String? title,
    String? note,
    int? startSeconds,
    int? endSeconds,
  }) => _command<VideoElement>(
    (OperationId operation) => ref
        .read(videoCommandRunnerProvider)
        .editElement(
          EditVideoElement(
            operation,
            videoElementId: arg.videoElementId,
            title: title,
            note: note,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
          ),
        ),
    apply: (VideoUiState latest, VideoElement element) =>
        latest.copyWith(element: element),
    success: (_) => 'Saved',
  );

  /// Cuts a clip out of this range, scheduled independently from birth.
  Future<VideoElement?> addClip({
    required int startSeconds,
    required int endSeconds,
    String note = '',
    String? title,
  }) async {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || !current.canMutate || current.isBusy) return null;
    state = AsyncValue<VideoUiState>.data(current.copyWith(isBusy: true));
    final Result<VideoElement> result = await ref
        .read(videoCommandRunnerProvider)
        .addClip(
          AddVideoClip(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parentVideoElementId: current.element.id,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            note: note,
            title: title,
          ),
        );
    final VideoUiState latest = state.valueOrNull ?? current;
    if (result.isErr) {
      state = AsyncValue<VideoUiState>.data(
        latest.copyWith(
          isBusy: false,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return null;
    }
    final VideoElement created = result.unwrap();
    state = AsyncValue<VideoUiState>.data(
      latest.copyWith(
        clips: await _reloadClips(latest.element.id),
        lastClipId: created.id,
        isBusy: false,
        message: const UiMessage('Clip cut'),
      ),
    );
    return created;
  }

  Future<void> done() async {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .completeEncounter(
            CompleteTopicEncounter(
              operation,
              ref: current.topic.ref,
              foregroundMs: _foregroundMs(),
            ),
          ),
      apply: (VideoUiState latest, TopicState topic) =>
          latest.copyWith(topic: topic, isDone: true),
    );
  }

  /// Later: moves eligibility without advancing anything.
  Future<void> later({int? days}) async {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    final StudyDay? until = days == null
        ? null
        : (await ref.read(readerCommandRunnerProvider).today()).addDays(days);
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .postpone(
            PostponeElement(operation, ref: current.topic.ref, until: until),
          ),
      apply: (VideoUiState latest, TopicState topic) =>
          latest.copyWith(topic: topic, isDone: true),
    );
  }

  Future<void> dismiss() async {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || !current.canMutate) return;
    await _command<TopicState>(
      (OperationId operation) => ref
          .read(readerCommandRunnerProvider)
          .dismiss(DismissElement(operation, ref: current.topic.ref)),
      apply: (VideoUiState latest, TopicState topic) =>
          latest.copyWith(topic: topic, isDone: true),
    );
  }

  /// Creates linked cards without advancing or dismissing this range.
  Future<bool> formulate(List<CardDraft> drafts) async {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || !current.canMutate || current.isBusy) return false;
    state = AsyncValue<VideoUiState>.data(current.copyWith(isBusy: true));
    final Result<List<Card>> result = await ref
        .read(formulationCommandRunnerProvider)
        .formulate(
          FormulateCards(
            OperationId(ref.read(idGeneratorProvider).newId()),
            parent: CardParent.video(current.element.id),
            drafts: drafts,
          ),
        );
    final VideoUiState latest = state.valueOrNull ?? current;
    if (result.isErr) {
      state = AsyncValue<VideoUiState>.data(
        latest.copyWith(
          isBusy: false,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return false;
    }
    final List<Card> cards = result.unwrap();
    state = AsyncValue<VideoUiState>.data(
      latest.copyWith(
        cards: await ref
            .read(contentRepositoryProvider)
            .listCardsOfVideo(latest.element.id),
        isBusy: false,
        message: UiMessage(
          '${cards.length} card${cards.length == 1 ? '' : 's'} created',
        ),
      ),
    );
    return true;
  }

  void shouldClearMessage() {
    final VideoUiState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<VideoUiState>.data(
      current!.copyWith(shouldClearMessage: true),
    );
  }

  Future<List<VideoElement>> _reloadClips(String elementId) =>
      ref.read(videoRepositoryProvider).listVideoElementsOfParent(elementId);

  int? _foregroundMs() {
    final DateTime? started = _sessionStartedAt;
    if (started == null) return null;
    return ref.read(clockProvider).nowUtc().difference(started).inMilliseconds;
  }

  Future<void> _command<T>(
    Future<Result<T>> Function(OperationId operation) run, {
    required VideoUiState Function(VideoUiState state, T value) apply,
    String Function(T value)? success,
  }) async {
    final VideoUiState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<VideoUiState>.data(current.copyWith(isBusy: true));
    final Result<T> result = await run(
      OperationId(ref.read(idGeneratorProvider).newId()),
    );
    final VideoUiState latest = state.valueOrNull ?? current;
    state = AsyncValue<VideoUiState>.data(
      result.fold(
        (T value) => apply(latest, value).copyWith(
          isBusy: false,
          message: success == null ? null : UiMessage(success(value)),
        ),
        (AppFailure failure) => latest.copyWith(
          isBusy: false,
          message: UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }
}

final AsyncNotifierProviderFamily<VideoViewModel, VideoUiState, VideoRequest>
videoViewModelProvider =
    AsyncNotifierProvider.family<VideoViewModel, VideoUiState, VideoRequest>(
      VideoViewModel.new,
    );
