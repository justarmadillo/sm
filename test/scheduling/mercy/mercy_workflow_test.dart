library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/mercy/mercy.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:test/test.dart';

void main() {
  group('MercyPreview persistence', () {
    test('round-trips the exact canonical engine plan', () {
      const ElementRef topicRef = ElementRef(
        id: 'topic-1',
        type: ElementType.source,
      );
      const ElementRef cardRef = ElementRef(
        id: 'card-1',
        type: ElementType.card,
      );
      final Sm20MercyCandidate topic = _candidate(
        ref: topicRef,
        scheduledDay: _day(8),
        revision: 7,
      );
      final Sm20MercyCandidate card = _candidate(
        ref: cardRef,
        scheduledDay: _day(9),
        revision: 11,
      );
      final Sm20MercyScore topicScore = _score(800000);
      final Sm20MercyScore cardScore = _score(700000);
      final Sm20MercyPlan plan = Sm20MercyPlan(
        gathered: <Sm20MercyCandidate>[card, topic],
        ordered: <Sm20MercyCandidate?>[topic, card],
        assignments: <Sm20MercyAssignment>[
          Sm20MercyAssignment(
            candidate: topic,
            score: topicScore,
            sourceIndex: 1,
            orderedIndex: 0,
            targetDay: _day(10),
          ),
          Sm20MercyAssignment(
            candidate: card,
            score: cardScore,
            sourceIndex: 0,
            orderedIndex: 1,
            targetDay: _day(11),
          ),
        ],
        scores: <ElementRef, Sm20MercyScore>{
          topicRef: topicScore,
          cardRef: cardScore,
        },
        reschedulingDays: 2,
        blockSize: 1,
        randomDraws: 2,
        prngState: Sm20PrngState(0x10203040),
        deletedPlaceholderCount: 0,
      );

      final MercyPreview preview = MercyPreview.fromPlan(
        plan: plan,
        today: _day(10),
        collectionLearningStartDay: _day(1),
        gatheringDays: 10,
        mode: MercyMode.random,
        gatherMode: Sm20MercyGatherMode.collection,
        prngSeedBefore: 0x01020304,
        canonicalStates: <ElementRef, String>{
          topicRef: '{"kind":"topic"}',
          cardRef: '{"kind":"card"}',
        },
      );

      final String encoded = preview.toJson();
      final MercyPreview decoded = MercyPreview.fromJson(encoded);

      expect(decoded.toJson(), encoded);
      expect(decoded.selectedCount, 2);
      expect(decoded.selectedCardCount, 1);
      expect(decoded.selectedTopicCount, 1);
      expect(decoded.gatheredCount, 2);
      expect(decoded.mode, MercyMode.random);
      expect(decoded.gatherMode, Sm20MercyGatherMode.collection);
      expect(decoded.prngSeedBefore, 0x01020304);
      expect(decoded.prngSeedAfter, 0x10203040);
      expect(decoded.items.first.scheduleRevision, 7);
      expect(decoded.items.first.canonicalBefore, '{"kind":"topic"}');
      expect(
        decoded.afterLoad
            .map(
              (MercyDailyLoad load) =>
                  (load.day, load.cards, load.topics, load.total),
            )
            .toList(),
        <(StudyDay, int, int, int)>[(_day(10), 0, 1, 1), (_day(11), 1, 0, 1)],
      );
    });

    test(
      'retains deleted subset placeholders without inventing assignments',
      () {
        const ElementRef missing = ElementRef(
          id: 'missing',
          type: ElementType.extract,
        );
        final Sm20MercyCandidate placeholder = _candidate(
          ref: missing,
          scheduledDay: _day(10),
          isScheduled: false,
          isDeleted: true,
        );
        final MercyPreview preview = MercyPreview.fromPlan(
          plan: Sm20MercyPlan(
            gathered: <Sm20MercyCandidate>[placeholder],
            ordered: const <Sm20MercyCandidate?>[null],
            assignments: const <Sm20MercyAssignment>[],
            scores: const <ElementRef, Sm20MercyScore>{},
            reschedulingDays: 1,
            blockSize: 1,
            randomDraws: 0,
            prngState: Sm20PrngState(9),
            deletedPlaceholderCount: 1,
          ),
          today: _day(10),
          collectionLearningStartDay: _day(1),
          gatheringDays: 10,
          mode: MercyMode.sourceOrder,
          gatherMode: Sm20MercyGatherMode.subset,
          prngSeedBefore: 9,
          canonicalStates: const <ElementRef, String>{},
        );

        expect(preview.gatheredCount, 1);
        expect(preview.selectedCount, 0);
        expect(preview.deletedPlaceholderCount, 1);
        expect(preview.afterLoad, isEmpty);
        expect(
          MercyPreview.fromJson(preview.toJson()).deletedPlaceholderCount,
          1,
        );
      },
    );
  });

  group('canonical state tokens', () {
    test('topic state round-trips losslessly', () {
      final TopicState topic = TopicState(
        schedule: _schedule(
          const ElementRef(id: 'topic-state', type: ElementType.extract),
          dueDay: _day(17),
          revision: 13,
        ),
        status: Sm20ElementStatus.memorized,
        repetitionCount: 14,
        lapseCount: 3,
        storedInterval: 19,
        lastReviewDay: _day(7),
        aFactorRaw: DelphiReal48.fromBytes(const <int>[
          0x81,
          0x9a,
          0x99,
          0x99,
          0x99,
          0x19,
        ]),
        lastIntervalRatioRaw: DelphiReal48.fromDouble(1.75),
        historyBlockId: 23,
        recentPostponementCount: 2,
        totalPostponementCount: 5,
        learningControl: 4,
        encountersSinceLastCard: 6,
        revision: 17,
      );

      final String encoded = encodeMercyTopicState(topic);
      final TopicState decoded = decodeMercyTopicState(encoded);

      expect(encodeMercyTopicState(decoded), encoded);
      expect(decoded.schedule.ref, topic.schedule.ref);
      expect(decoded.schedule.priority, topic.schedule.priority);
      expect(decoded.schedule.dueDay, topic.schedule.dueDay);
      expect(decoded.status, topic.status);
      expect(decoded.aFactorRaw, topic.aFactorRaw);
      expect(decoded.lastIntervalRatioRaw, topic.lastIntervalRatioRaw);
      expect(decoded.revision, 17);
    });

    test('card state round-trips losslessly', () {
      final CardState card = CardState(
        schedule: _schedule(
          const ElementRef(id: 'card-state', type: ElementType.card),
          dueDay: _day(15),
          revision: 9,
        ),
        memory: CardMemory(
          cardId: 'card-state',
          state: CardLearningState.review,
          step: null,
          stability: 12.5,
          difficulty: 6.25,
          reps: 8,
          lapses: 2,
          lastReviewAtUtc: DateTime.utc(2026, 3, 3, 9),
          dueAtUtc: DateTime.utc(2026, 3, 15, 9),
          originalDueAtUtc: DateTime.utc(2026, 3, 15, 9),
          schedulerVersion: kCardSchedulerVersion,
          parametersVersion: kCardParametersVersion,
          postponeCount: 4,
          scheduledDays: 12,
          revision: 12,
        ),
      );

      final String encoded = encodeMercyCardState(card);
      final CardState decoded = decodeMercyCardState(encoded);

      expect(encodeMercyCardState(decoded), encoded);
      expect(decoded, card);
      expect(decoded.memory.reps, 8);
      expect(decoded.memory.postponeCount, 4);
    });
  });

  test('applied batch snapshot round-trips exact before/after tokens', () {
    final MercyAppliedBatchSnapshot snapshot = MercyAppliedBatchSnapshot(
      batchId: 'batch-1',
      appliedEventId: 'event-batch',
      policyVersion: kSm20MercyPolicyVersion,
      studyDay: _day(10),
      items: <MercyAppliedItemSnapshot>[
        MercyAppliedItemSnapshot(
          ref: const ElementRef(id: 'topic-1', type: ElementType.source),
          beforeState: '{"due":10}',
          afterState: '{"due":12}',
          fromDay: _day(10),
          toDay: _day(12),
          appliedEventId: 'event-item',
        ),
      ],
    );

    final String encoded = encodeMercyAppliedBatch(snapshot);
    final MercyAppliedBatchSnapshot decoded = decodeMercyAppliedBatch(encoded);

    expect(encodeMercyAppliedBatch(decoded), encoded);
    expect(decoded.batchId, 'batch-1');
    expect(decoded.policyVersion, kSm20MercyPolicyVersion);
    expect(decoded.items.single.beforeState, '{"due":10}');
    expect(decoded.items.single.afterState, '{"due":12}');
  });
}

Sm20MercyCandidate _candidate({
  required ElementRef ref,
  required StudyDay scheduledDay,
  int revision = 1,
  bool isScheduled = true,
  bool isDeleted = false,
}) => Sm20MercyCandidate(
  ref: ref,
  priority: PriorityRank.middle,
  scheduledDay: scheduledDay,
  lastReviewDay: _day(3),
  repetitionCount: 4,
  lapseCount: 1,
  storedInterval: 5,
  revision: revision,
  isScheduled: isScheduled,
  isDeleted: isDeleted,
);

Sm20MercyScore _score(int value) => Sm20MercyScore(
  value: value,
  recency: 0.1,
  investment: 0.2,
  importance: 0.3,
  lateness: 0.4,
  easiness: 0.5,
  investmentBase: 2,
);

ElementSchedule _schedule(
  ElementRef ref, {
  required StudyDay dueDay,
  required int revision,
}) => ElementSchedule(
  ref: ref,
  priority: const PriorityRank('Q'),
  lifecycle: ElementLifecycle.active,
  dueDay: dueDay,
  originalDueDay: dueDay,
  rootId: 'root-1',
  parentElementId: 'parent-1',
  ordinal: 5,
  createdAtUtc: DateTime.utc(2026, 3, 1, 8),
  updatedAtUtc: DateTime.utc(2026, 3, 2, 8),
  revision: revision,
);

StudyDay _day(int day) =>
    StudyDay(year: 2026, month: 3, day: day, zoneId: 'UTC');
