/// The complete incremental-video loop, over the real stack.
///
/// Add a video → mark where you got to → cut clips → formulate a card →
/// Done, and then the queue. Every assertion here is about the thing that
/// makes video worth having as its own element type rather than a note: a
/// clip is scheduled independently, and the whole talk keeps coming back.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/search/search_query.dart';
import 'package:incremental_reader/features/video/video_commands.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/review_log.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _url = 'https://www.youtube.com/watch?v=lecture1';

extension _Fixtures on AppHarness {
  /// A two-hour talk, of which only the first twenty minutes are worth it.
  Future<VideoElement> addTalk() async => (await video.importVideo(
    ImportVideo(
      operation(),
      url: _url,
      title: 'Retinal detachment',
      startSeconds: 0,
      endSeconds: 1200,
      durationSeconds: 7200,
      timestampUtc: clock.nowUtc(),
    ),
  )).unwrap();

  Future<VideoElement> cutClip(
    VideoElement parent, {
    required int startSeconds,
    required int endSeconds,
    String note = 'the point',
  }) async => (await video.addClip(
    AddVideoClip(
      operation(),
      parentVideoElementId: parent.id,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      note: note,
      timestampUtc: clock.nowUtc(),
    ),
  )).unwrap();
}

void main() {
  late AppHarness harness;

  setUp(() {
    harness = AppHarness(operationPrefix: 'video-loop');
  });

  tearDown(() => harness.database.close());

  test('a video enters the collection as a scheduled topic', () async {
    final VideoElement talk = await harness.addTalk();
    final ElementRef ref = ElementRef(id: talk.id, type: ElementType.video);

    final TopicState? topic = await harness.learning.findTopic(ref);
    expect(topic, isNotNull, reason: 'a video is a topic, scheduled by SM20');
    expect(topic!.schedule.lifecycle, ElementLifecycle.active);
    expect(topic.schedule.rootId, talk.id, reason: 'a talk is its own root');
    expect(talk.isClip, isFalse);
    expect(talk.rangeSeconds, 1200);
  });

  test('a second range over the same talk reuses the one video row', () async {
    final VideoElement first = await harness.addTalk();
    final VideoElement second = (await harness.video.importVideo(
      ImportVideo(
        harness.operation(),
        url: _url,
        title: 'Retinal detachment, the second hour',
        startSeconds: 3600,
        endSeconds: 5400,
        timestampUtc: harness.clock.nowUtc(),
      ),
    )).unwrap();

    expect(second.videoId, first.videoId);
    // Correcting a mistyped link has to be one write, not one per range.
    expect(
      await harness.videos.listVideoElementsOfVideo(first.videoId),
      hasLength(2),
    );
  });

  test('a clip is scheduled independently of the talk it came from', () async {
    final VideoElement talk = await harness.addTalk();
    final VideoElement clip = await harness.cutClip(
      talk,
      startSeconds: 252,
      endSeconds: 450,
    );

    final ElementRef clipRef = ElementRef(id: clip.id, type: ElementType.video);
    final TopicState? clipTopic = await harness.learning.findTopic(clipRef);
    expect(clipTopic, isNotNull);
    expect(clip.isClip, isTrue);
    expect(clip.parentVideoElementId, talk.id);
    expect(
      clipTopic!.schedule.rootId,
      talk.id,
      reason: 'a clip keeps the talk as its root, the way an extract does',
    );
    expect(
      clipTopic.schedule.priority,
      isNot(
        equals(
          (await harness.learning.findTopic(
            ElementRef(id: talk.id, type: ElementType.video),
          ))!.schedule.priority,
        ),
      ),
      reason: 'the media extraction rule draws the clip its own priority',
    );
  });

  test('a clip outside the range it is cut from is refused', () async {
    final VideoElement talk = await harness.addTalk();
    final result = await harness.video.addClip(
      AddVideoClip(
        harness.operation(),
        parentVideoElementId: talk.id,
        startSeconds: 1100,
        endSeconds: 1400,
        timestampUtc: harness.clock.nowUtc(),
      ),
    );
    expect(result.isErr, isTrue);
    expect(await harness.videos.listVideoElementsOfParent(talk.id), isEmpty);
  });

  test('the resume position is bounded by the range it belongs to', () async {
    final VideoElement talk = await harness.addTalk();

    final ok = await harness.video.setResume(
      SetVideoResume(
        harness.operation(),
        videoElementId: talk.id,
        resumeSeconds: 600,
      ),
    );
    expect(ok.isOk, isTrue);
    expect(ok.unwrap().watchedFraction, 0.5);

    final outside = await harness.video.setResume(
      SetVideoResume(
        harness.operation(),
        videoElementId: talk.id,
        resumeSeconds: 5000,
      ),
    );
    expect(outside.isErr, isTrue);
    expect(
      (await harness.videos.findVideoElement(talk.id))!.resumeSeconds,
      600,
      reason: 'a refused position must not have been written',
    );
  });

  test('cards formulate from a clip and cite it', () async {
    final VideoElement talk = await harness.addTalk();
    final VideoElement clip = await harness.cutClip(
      talk,
      startSeconds: 252,
      endSeconds: 450,
      note: 'Scleral buckling is preferred in young phakic patients.',
    );

    final List<Card> cards = (await harness.formulation.formulate(
      FormulateCards(
        harness.operation(),
        parent: CardParent.video(clip.id),
        drafts: const <CardDraft>[
          QaCardDraft(
            question: 'When is scleral buckling preferred?',
            answer: 'Young phakic patients.',
          ),
        ],
        timestampUtc: harness.clock.nowUtc(),
      ),
    )).unwrap();

    expect(cards, hasLength(1));
    expect(cards.single.parent, CardParent.video(clip.id));
    // The polymorphic parent has to survive the round trip through SQL, which
    // stores the element-type index and nothing else.
    final List<Card> reloaded = await harness.content.listCardsOfVideo(clip.id);
    expect(reloaded.single.id, cards.single.id);
    expect(reloaded.single.parent!.isVideo, isTrue);
  });

  test('a video encounter advances the talk and logs it', () async {
    final VideoElement talk = await harness.addTalk();
    await harness.video.setResume(
      SetVideoResume(
        harness.operation(),
        videoElementId: talk.id,
        resumeSeconds: 600,
      ),
    );
    final ElementRef ref = ElementRef(id: talk.id, type: ElementType.video);
    final TopicState before = (await harness.learning.findTopic(ref))!;

    final TopicState after = (await harness.reader.completeEncounter(
      CompleteTopicEncounter(
        harness.operation(),
        ref: ref,
        timestampUtc: harness.clock.nowUtc(),
      ),
    )).unwrap();

    expect(after.repetitionCount, before.repetitionCount + 1);
    expect(
      after.schedule.dueDay.daysUntil(before.schedule.dueDay),
      lessThanOrEqualTo(0),
      reason: 'a repetition moves the talk forward, never back',
    );

    final log = await harness.learning.listReviewLogForElement(ref);
    expect(
      log.map((ReviewLogEntry entry) => entry.after.readFraction),
      contains(0.5),
      reason: 'watched seconds over range seconds is the video read fraction',
    );
  });

  test('the queue offers videos alongside articles and cards', () async {
    final VideoElement talk = await harness.addTalk();
    await harness.cutClip(talk, startSeconds: 252, endSeconds: 450);

    final QueueProjection projection = await harness.queueQuery.load();
    final Iterable<ElementRef> refs = projection.entries.map(
      (QueueEntry entry) => entry.ref,
    );
    expect(
      refs,
      contains(ElementRef(id: talk.id, type: ElementType.video)),
      reason:
          'a video that is scheduled but never admitted is the failure this '
          'whole element type exists to avoid',
    );
    final QueueEntry entry = projection.entries.firstWhere(
      (QueueEntry candidate) => candidate.ref.id == talk.id,
    );
    expect(entry.title, 'Retinal detachment');
    // A freshly added video has never been repeated, so it arrives in the
    // Pending lane, whose label is Learn for every element type.
    expect(entry.lane, QueueLane.pending);
    expect(entry.actionLabel, 'Learn');
  });

  test('the note is searchable and the clip is findable by it', () async {
    final VideoElement talk = await harness.addTalk();
    final VideoElement clip = await harness.cutClip(
      talk,
      startSeconds: 252,
      endSeconds: 450,
      note: 'Pneumatic retinopexy needs a superior break.',
    );

    final List<SearchResult> results = await harness.searchQuery.run(
      'retinopexy',
    );
    expect(
      results.map((SearchResult result) => result.hit.ref),
      contains(ElementRef(id: clip.id, type: ElementType.video)),
    );
  });

  test('deleting a talk with clips is refused before the clips go', () async {
    final VideoElement talk = await harness.addTalk();
    final VideoElement clip = await harness.cutClip(
      talk,
      startSeconds: 252,
      endSeconds: 450,
    );

    await expectLater(
      harness.videos.deleteVideoElement(talk.id),
      throwsA(anything),
      reason: 'the database is the backstop against orphaning a clip',
    );

    await harness.videos.deleteVideoElement(clip.id);
    await harness.videos.deleteVideoElement(talk.id);
    expect(await harness.videos.listVideoElements(), isEmpty);
  });
}
