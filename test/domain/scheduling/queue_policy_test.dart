/// The daily queue: eligibility, ordering, mixing, and admission.
library;

import 'package:incremental_reader/src/domain/scheduling/card_scheduler.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/priority_rank.dart';
import 'package:incremental_reader/src/domain/scheduling/queue_policy.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:incremental_reader/src/domain/scheduling/topic_scheduler.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 3, 5, 12);
  const StudyDay today = StudyDay(year: 2026, month: 3, day: 5, zoneId: 'UTC');

  /// Strict ordering, so a test asserting a sequence is asserting the rule
  /// rather than the day's shuffle.
  const QueueSettings strict = QueueSettings(randomization: 0);

  group('mixing', () {
    test('interleaves four cards then one topic and drains either stream', () {
      const QueuePolicy policy = QueuePolicy(settings: strict);
      final List<QueueCandidate> candidates = <QueueCandidate>[
        for (var i = 1; i <= 10; i++)
          _card('c${i.toString().padLeft(2, '0')}', dueAt: now),
        _topic('t1'),
        _topic('t2'),
      ];

      final QueuePlan plan = policy.build(
        candidates: candidates.reversed,
        nowUtc: now,
        today: today,
      );

      expect(plan.entries.map((QueueCandidate c) => c.ref.id), <String>[
        'c01',
        'c02',
        'c03',
        'c04',
        't1',
        'c05',
        'c06',
        'c07',
        'c08',
        't2',
        'c09',
        'c10',
      ]);
    });

    test('honours a configured proportion of topics', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(randomization: 0, cardsPerTopic: 2),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 6; i++) _card('c$i', dueAt: now),
          _topic('t1'),
          _topic('t2'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.entries.map((QueueCandidate c) => c.ref.id), <String>[
        'c1',
        'c2',
        't1',
        'c3',
        'c4',
        't2',
        'c5',
        'c6',
      ]);
    });

    test('the interleave floor keeps reading alive when items dominate', () {
      // A ratio the user set very wide, which without a floor would let a
      // hundred cards pass before a single topic appeared.
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          cardsPerTopic: 100,
          minTopicEvery: 5,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 12; i++) _card('c$i', dueAt: now),
          _topic('t1'),
        ],
        nowUtc: now,
        today: today,
      );

      final int topicIndex = plan.entries.indexWhere(
        (QueueCandidate c) => c.ref.type != ElementType.card,
      );
      expect(topicIndex, 5, reason: 'the floor promotes the topic on time');
    });
  });

  group('eligibility', () {
    test('uses exact UTC due time for intraday card eligibility', () {
      final QueuePlan plan = const QueuePolicy(settings: strict).build(
        candidates: <QueueCandidate>[
          _card('due-now', dueAt: now),
          _card('due-later', dueAt: now.add(const Duration(seconds: 1))),
          _topic('topic-due'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.entries.map((QueueCandidate c) => c.ref.id), <String>[
        'due-now',
        'topic-due',
      ]);
    });

    test('filters lifecycle and deferral before mixing', () {
      final StudyDay tomorrow = today.addDays(1);
      final QueuePlan plan = const QueuePolicy(settings: strict).build(
        candidates: <QueueCandidate>[
          _card(
            'suspended-card',
            dueAt: now,
            lifecycle: ElementLifecycle.suspended,
          ),
          _topic('dismissed-topic', lifecycle: ElementLifecycle.dismissed),
          _topic('deferred-topic', deferredUntil: tomorrow),
          _card('ok-card', dueAt: now),
          _topic('ok-topic'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.entries.map((QueueCandidate c) => c.ref.id), <String>[
        'ok-card',
        'ok-topic',
      ]);
    });
  });

  group('ordering', () {
    test('priority decides, and lateness breaks near ties', () {
      final PriorityScale scale = PriorityScale(<PriorityRank>[
        const PriorityRank('A'),
        const PriorityRank('M'),
        const PriorityRank('Z'),
      ]);
      final QueuePlan plan = QueuePolicy(settings: strict, scale: scale).build(
        candidates: <QueueCandidate>[
          _topic('bottom', priority: const PriorityRank('Z')),
          _topic('top', priority: const PriorityRank('A')),
          _topic('middle', priority: const PriorityRank('M')),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.entries.map((QueueCandidate c) => c.ref.id), <String>[
        'top',
        'middle',
        'bottom',
      ]);
    });

    test('a badly overdue mid-priority element surfaces before a fresh one '
        'just above it', () {
      // Adjacent percentiles in a real-sized collection: the priority gap is
      // small, so forty days of accumulated lateness outweighs it. Without
      // the overdue term, mid-priority material would go stale invisibly.
      final List<PriorityRank> ranks = <PriorityRank>[
        for (var i = 0; i < 20; i++) PriorityRank(String.fromCharCode(65 + i)),
      ];
      final QueuePlan plan =
          QueuePolicy(settings: strict, scale: PriorityScale(ranks)).build(
            candidates: <QueueCandidate>[
              _topic('fresh', priority: ranks[9]),
              _topic(
                'stale',
                priority: ranks[10],
                dueDay: today.addDays(-40),
                intervalDays: 2,
              ),
            ],
            nowUtc: now,
            today: today,
          );

      expect(plan.entries.first.ref.id, 'stale');
    });

    test('randomization is deterministic within a study day', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(randomization: 0.3),
      );
      Iterable<String> order() => policy
          .build(
            candidates: <QueueCandidate>[
              for (var i = 1; i <= 12; i++) _topic('t$i'),
            ],
            nowUtc: now,
            today: today,
          )
          .entries
          .map((QueueCandidate c) => c.ref.id);

      expect(
        order(),
        order(),
        reason: 'rebuilding mid-session must not move the user’s place',
      );
    });

    test('zero randomization gives strict priority ordering', () {
      final List<PriorityRank> ranks = <PriorityRank>[
        for (var i = 0; i < 8; i++) PriorityRank(String.fromCharCode(65 + i)),
      ];
      final QueuePlan plan =
          QueuePolicy(settings: strict, scale: PriorityScale(ranks)).build(
            candidates: <QueueCandidate>[
              for (var i = 7; i >= 0; i--) _topic('t$i', priority: ranks[i]),
            ],
            nowUtc: now,
            today: today,
          );

      expect(plan.entries.map((QueueCandidate c) => c.ref.id), <String>[
        for (var i = 0; i < 8; i++) 't$i',
      ]);
    });
  });

  group('admission', () {
    test('caps each stream and hands the rest back as overflow', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxCards: 3,
          maxTopics: 1,
          overloadTolerance: 1,
          protectedPercentile: 0,
          maxSharePerRoot: 1,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 6; i++) _card('c$i', dueAt: now, reps: 1),
          for (var i = 1; i <= 4; i++) _topic('t$i'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.counters.admittedCards, 3);
      expect(plan.counters.admittedTopics, 1);
      expect(plan.counters.overflowCards, 3);
      expect(plan.counters.overflowTopics, 3);
      expect(plan.overflow, hasLength(6));
    });

    test('new cards have their own sub-limit', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxCards: 10,
          maxNewCards: 2,
          overloadTolerance: 1,
          protectedPercentile: 0,
          maxSharePerRoot: 1,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 5; i++) _card('new$i', dueAt: now),
          for (var i = 1; i <= 3; i++) _card('old$i', dueAt: now, reps: 4),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.counters.admittedNewCards, 2);
      expect(plan.counters.admittedCards, 5);
      expect(
        plan.overflow.every((ScoredCandidate s) => s.candidate.isNewCard),
        isTrue,
      );
    });

    test('a started learning step is never deferred', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxCards: 0,
          overloadTolerance: 1,
          protectedPercentile: 0,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          _card('learning', dueAt: now, reps: 1, learning: true),
          _card('review', dueAt: now, reps: 4),
        ],
        nowUtc: now,
        today: today,
      );

      expect(
        plan.entries.map((QueueCandidate c) => c.ref.id),
        <String>['learning'],
        reason: 'a repetition already begun today is not the valve’s to shed',
      );
      expect(plan.overflow.single.ref.id, 'review');
    });

    test('the protected top percentile survives an overflowing day', () {
      final List<PriorityRank> ranks = <PriorityRank>[
        for (var i = 0; i < 10; i++) PriorityRank(String.fromCharCode(65 + i)),
      ];
      final QueuePolicy policy = QueuePolicy(
        settings: const QueueSettings(
          randomization: 0,
          maxTopics: 0,
          overloadTolerance: 1,
          protectedPercentile: 0.2,
          maxSharePerRoot: 1,
        ),
        scale: PriorityScale(ranks),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 0; i < 10; i++) _topic('t$i', priority: ranks[i]),
        ],
        nowUtc: now,
        today: today,
      );

      expect(
        plan.entries.map((QueueCandidate c) => c.ref.id),
        <String>['t0', 't1'],
        reason: 'without a floor the valve eventually defers everything',
      );
      expect(plan.counters.protectedElements, 2);
    });

    test('tolerance lets a small overshoot through untouched', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 10,
          overloadTolerance: 1.2,
          protectedPercentile: 0,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 12; i++) _topic('t$i'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.counters.admittedTopics, 12);
      expect(plan.overflow, isEmpty);
    });

    test('one article’s subtree cannot take over a session', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 100,
          overloadTolerance: 1,
          protectedPercentile: 0,
          maxSharePerRoot: 0.5,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 8; i++) _topic('big$i', rootId: 'big'),
          for (var i = 1; i <= 2; i++) _topic('other$i', rootId: 'other'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(
        plan.entries.where((QueueCandidate c) => c.rootId == 'big').length,
        lessThanOrEqualTo(5),
      );
      expect(
        plan.entries.map((QueueCandidate c) => c.ref.id),
        containsAll(<String>['other1', 'other2']),
      );
    });

    test('Study More raises the caps for one build only', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 2,
          overloadTolerance: 1,
          protectedPercentile: 0,
          maxSharePerRoot: 1,
        ),
      );
      List<QueueCandidate> candidates() => <QueueCandidate>[
        for (var i = 1; i <= 6; i++) _topic('t$i'),
      ];

      expect(
        policy
            .build(candidates: candidates(), nowUtc: now, today: today)
            .counters
            .admittedTopics,
        2,
      );
      expect(
        policy
            .build(
              candidates: candidates(),
              nowUtc: now,
              today: today,
              extraAdmissions: 3,
            )
            .counters
            .admittedTopics,
        5,
      );
    });
  });

  group('counters', () {
    test('protection reports the best priority that did not fit', () {
      final List<PriorityRank> ranks = <PriorityRank>[
        for (var i = 0; i < 5; i++) PriorityRank(String.fromCharCode(65 + i)),
      ];
      final QueuePolicy policy = QueuePolicy(
        settings: const QueueSettings(
          randomization: 0,
          maxTopics: 2,
          overloadTolerance: 1,
          protectedPercentile: 0,
          maxSharePerRoot: 1,
        ),
        scale: PriorityScale(ranks),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 0; i < 5; i++) _topic('t$i', priority: ranks[i]),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.counters.protectionPercent, closeTo(50, 0.001));
      expect(plan.counters.overflowRatio, closeTo(0.6, 0.001));
    });

    test('an empty day produces an empty plan', () {
      final QueuePlan plan = const QueuePolicy().build(
        candidates: const <QueueCandidate>[],
        nowUtc: now,
        today: today,
      );
      expect(plan.isEmpty, isTrue);
      expect(plan.counters.dueTotal, 0);
      expect(plan.counters.protectionPercent, 100);
    });
  });
}

QueueCandidate _card(
  String id, {
  required DateTime dueAt,
  ElementLifecycle lifecycle = ElementLifecycle.active,
  PriorityRank priority = PriorityRank.middle,
  int reps = 0,
  bool learning = false,
  String? rootId,
}) {
  const StudyDay day = StudyDay(year: 2026, month: 3, day: 5, zoneId: 'UTC');
  final bool isNew = reps == 0;
  return QueueCandidate.card(
    CardState(
      schedule: ElementSchedule(
        ref: ElementRef(id: id, type: ElementType.card),
        priority: priority,
        lifecycle: lifecycle,
        dueDay: day,
        originalDueDay: day,
        rootId: rootId,
      ),
      memory: CardMemory(
        cardId: id,
        state: isNew || learning
            ? CardLearningState.learning
            : CardLearningState.review,
        step: isNew || learning ? 0 : null,
        stability: isNew ? null : 10,
        difficulty: isNew ? null : 5,
        reps: reps,
        lapses: 0,
        lastReviewAtUtc: isNew
            ? null
            : dueAt.subtract(const Duration(days: 10)),
        dueAtUtc: dueAt,
        originalDueAtUtc: dueAt,
        deferredUntilUtc: null,
        schedulerVersion: kCardSchedulerVersion,
        parametersVersion: kCardParametersVersion,
      ),
    ),
    rootId: rootId,
  );
}

QueueCandidate _topic(
  String id, {
  ElementLifecycle lifecycle = ElementLifecycle.active,
  PriorityRank priority = PriorityRank.middle,
  StudyDay? dueDay,
  StudyDay? deferredUntil,
  double intervalDays = 7,
  String? rootId,
}) {
  const StudyDay today = StudyDay(year: 2026, month: 3, day: 5, zoneId: 'UTC');
  final StudyDay due = dueDay ?? today;
  return QueueCandidate.topic(
    TopicState(
      schedule: ElementSchedule(
        ref: ElementRef(id: id, type: ElementType.extract),
        priority: priority,
        lifecycle: lifecycle,
        dueDay: due,
        originalDueDay: due,
        deferredUntil: deferredUntil,
        deferralKind: deferredUntil == null
            ? DeferralKind.none
            : DeferralKind.manual,
        rootId: rootId,
      ),
      profileId: 'extract',
      stepIndex: 0,
      intervalDays: intervalDays,
    ),
    rootId: rootId,
  );
}
