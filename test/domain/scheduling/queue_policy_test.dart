/// The authoritative daily-queue invariants: eligibility, independent lanes,
/// bounded ranking, admission, deterministic mixing, and restart continuity.
library;

import 'dart:convert';

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

  /// Strict presentation ranking makes sequence assertions test the rule,
  /// rather than a deterministic but intentionally shuffled order.
  const QueueSettings strict = QueueSettings(randomization: 0);

  group('weighted fair merge', () {
    test(
      'targets four card opportunities then one topic and drains either',
      () {
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

        expect(_entryIds(plan), <String>[
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
      },
    );

    test('honours a configured card/topic target', () {
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

      expect(_entryIds(plan), <String>[
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

    test(
      'never permits more than eight ordinary cards while topics remain',
      () {
        const QueuePolicy policy = QueuePolicy(
          settings: QueueSettings(
            randomization: 0,
            cardsPerTopic: 100,
            minTopicEvery: 8,
          ),
        );
        final QueuePlan plan = policy.build(
          candidates: <QueueCandidate>[
            for (var i = 1; i <= 18; i++)
              _card('c${i.toString().padLeft(2, '0')}', dueAt: now),
            _topic('t1'),
            _topic('t2'),
          ],
          nowUtc: now,
          today: today,
        );

        final List<int> topicIndexes = <int>[
          for (var i = 0; i < plan.entries.length; i++)
            if (!plan.entries[i].isCard) i,
        ];
        expect(topicIndexes, <int>[8, 17]);
      },
    );

    test('mandatory steps inject at the next card opportunity', () {
      const QueuePolicy policy = QueuePolicy(settings: strict);
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          _card(
            'mandatory',
            dueAt: now,
            reps: 1,
            state: CardLearningState.learning,
          ),
          _card('c1', dueAt: now, reps: 4),
          _card('c2', dueAt: now, reps: 4),
          _topic('topic'),
        ],
        nowUtc: now,
        today: today,
        mergeCursor: const QueueMergeCursor(ordinaryCardsSinceTopic: 3),
      );

      expect(_entryIds(plan), <String>['mandatory', 'c1', 'topic', 'c2']);
    });

    test('a topic opportunity already due precedes a mandatory injection', () {
      const QueuePolicy policy = QueuePolicy(settings: strict);
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          _card(
            'mandatory',
            dueAt: now,
            reps: 1,
            state: CardLearningState.relearning,
          ),
          _card('card', dueAt: now, reps: 4),
          _topic('topic'),
        ],
        nowUtc: now,
        today: today,
        mergeCursor: const QueueMergeCursor(ordinaryCardsSinceTopic: 4),
      );

      expect(_entryIds(plan), <String>['topic', 'mandatory', 'card']);
    });

    test('restart cursor reproduces the exact remaining suffix', () {
      const QueuePolicy policy = QueuePolicy(settings: strict);
      final List<QueueCandidate> candidates = <QueueCandidate>[
        _card(
          'mandatory',
          dueAt: now,
          reps: 1,
          state: CardLearningState.learning,
        ),
        for (var i = 1; i <= 11; i++)
          _card('c${i.toString().padLeft(2, '0')}', dueAt: now, reps: 4),
        for (var i = 1; i <= 3; i++) _topic('t$i'),
      ];
      final QueuePlan full = policy.build(
        candidates: candidates,
        nowUtc: now,
        today: today,
      );
      const int consumedCount = 7;
      var cursor = QueueMergeCursor.zero;
      final Set<ElementRef> completed = <ElementRef>{};
      for (final QueueCandidate entry in full.entries.take(consumedCount)) {
        cursor = cursor.after(entry);
        completed.add(entry.ref);
      }

      final QueuePlan remaining = policy.build(
        candidates: candidates,
        nowUtc: now,
        today: today,
        completedInActivePlan: completed,
        mergeCursor: cursor,
      );

      expect(_entryIds(remaining), _entryIds(full).skip(consumedCount));
      expect(
        _planBytes(remaining),
        _planBytes(
          policy.build(
            candidates: candidates.reversed,
            nowUtc: now,
            today: today,
            completedInActivePlan: completed,
            mergeCursor: cursor,
          ),
        ),
      );
    });

    test('an empty stream wastes no capacity and preserves its cursor', () {
      const QueueMergeCursor cursor = QueueMergeCursor(
        ordinaryCardsSinceTopic: 3,
      );
      final QueuePlan cardsOnly = const QueuePolicy(settings: strict).build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 6; i++) _card('c$i', dueAt: now, reps: 3),
        ],
        nowUtc: now,
        today: today,
        mergeCursor: cursor,
      );
      final QueuePlan empty = const QueuePolicy(settings: strict).build(
        candidates: const <QueueCandidate>[],
        nowUtc: now,
        today: today,
        mergeCursor: cursor,
      );

      expect(cardsOnly.entries, hasLength(6));
      expect(cardsOnly.nextMergeCursor.ordinaryCardsSinceTopic, 9);
      expect(empty.nextMergeCursor, cursor);
    });
  });

  group('eligibility and lanes', () {
    test('uses exact UTC due time for intraday-card eligibility', () {
      final QueuePlan plan = const QueuePolicy(settings: strict).build(
        candidates: <QueueCandidate>[
          _card(
            'due-now',
            dueAt: now,
            reps: 1,
            state: CardLearningState.learning,
          ),
          _card(
            'due-later',
            dueAt: now.add(const Duration(seconds: 1)),
            reps: 1,
            state: CardLearningState.learning,
          ),
          _topic('topic-due'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(_entryIds(plan), <String>['due-now', 'topic-due']);
    });

    test('filters lifecycle, adjustment, scope, and completed work first', () {
      final StudyDay tomorrow = today.addDays(1);
      final QueueCandidate completed = _card('completed', dueAt: now, reps: 3);
      final QueuePlan plan = const QueuePolicy(settings: strict).build(
        candidates: <QueueCandidate>[
          _card(
            'suspended-card',
            dueAt: now,
            lifecycle: ElementLifecycle.suspended,
          ),
          _topic('dismissed-topic', lifecycle: ElementLifecycle.dismissed),
          _topic('deferred-topic', deferredUntil: tomorrow),
          _card('outside-scope', dueAt: now, reps: 3),
          completed,
          _topic('eligible-topic'),
        ],
        nowUtc: now,
        today: today,
        completedInActivePlan: <ElementRef>{completed.ref},
        inScope: (QueueCandidate candidate) =>
            candidate.ref.id != 'outside-scope',
      );

      expect(_entryIds(plan), <String>['eligible-topic']);
      expect(plan.scored, hasLength(1));
    });

    test('classifies every required lane after canonical protection', () {
      final List<PriorityRank> ranks = _ranks(6);
      final QueuePlan plan =
          QueuePolicy(
            settings: const QueueSettings(
              randomization: 0,
              maxCards: 20,
              maxTopics: 20,
              protectedPercentile: 0.25,
            ),
            scale: PriorityScale(ranks),
          ).build(
            candidates: <QueueCandidate>[
              _card(
                'mandatory',
                dueAt: now,
                reps: 1,
                state: CardLearningState.learning,
                priority: ranks[5],
              ),
              _card(
                'protected-review',
                dueAt: now,
                reps: 3,
                priority: ranks[0],
              ),
              _card('regular-review', dueAt: now, reps: 3, priority: ranks[3]),
              _card('new', dueAt: now, priority: ranks[2]),
              _topic('protected-topic', priority: ranks[1]),
              _topic('regular-topic', priority: ranks[4]),
            ],
            nowUtc: now,
            today: today,
          );

      final Map<String, QueueLane> lanes = <String, QueueLane>{
        for (final ScoredCandidate scored in plan.scored)
          scored.ref.id: scored.lane,
      };
      expect(lanes, <String, QueueLane>{
        'mandatory': QueueLane.mandatoryIntradayStep,
        'protected-review': QueueLane.protectedDueReview,
        'regular-review': QueueLane.regularDueReview,
        'new': QueueLane.availableNewCard,
        'protected-topic': QueueLane.protectedDueTopic,
        'regular-topic': QueueLane.regularDueTopic,
      });
    });
  });

  group('bounded deterministic ranking', () {
    test('priority fraction is lower-is-better', () {
      final List<PriorityRank> ranks = _ranks(3);
      final QueuePlan plan =
          QueuePolicy(settings: strict, scale: PriorityScale(ranks)).build(
            candidates: <QueueCandidate>[
              _topic('bottom', priority: ranks[2]),
              _topic('top', priority: ranks[0]),
              _topic('middle', priority: ranks[1]),
            ],
            nowUtc: now,
            today: today,
          );

      expect(_entryIds(plan), <String>['top', 'middle', 'bottom']);
      expect(
        plan.scored.map((ScoredCandidate s) => s.score),
        everyElement(inInclusiveRange(0, 1)),
      );
    });

    test('lateness moves only within the bounded 0.05 neighbourhood', () {
      final List<PriorityRank> ranks = _ranks(101);
      final QueuePolicy policy = QueuePolicy(
        settings: strict,
        scale: PriorityScale(ranks),
      );
      final QueuePlan neighbours = policy.build(
        candidates: <QueueCandidate>[
          _topic('fresh-neighbour', priority: ranks[49]),
          _topic(
            'stale-neighbour',
            priority: ranks[50],
            dueDay: today.addDays(-40),
            intervalDays: 2,
          ),
        ],
        nowUtc: now,
        today: today,
      );
      final QueuePlan distant = policy.build(
        candidates: <QueueCandidate>[
          _topic('fresh-top', priority: ranks.first),
          _topic(
            'stale-bottom',
            priority: ranks.last,
            dueDay: today.addDays(-400),
            intervalDays: 1,
          ),
        ],
        nowUtc: now,
        today: today,
      );

      expect(neighbours.entries.first.ref.id, 'stale-neighbour');
      expect(distant.entries.first.ref.id, 'fresh-top');
      expect(
        distant.scored.map((ScoredCandidate s) => s.latenessShift),
        everyElement(inInclusiveRange(0, 0.05)),
      );
    });

    test('score is priority fraction minus lateness shift plus jitter', () {
      final List<PriorityRank> ranks = _ranks(3);
      final QueuePlan plan =
          QueuePolicy(settings: strict, scale: PriorityScale(ranks)).build(
            candidates: <QueueCandidate>[
              _topic(
                'stale-bottom',
                priority: ranks.last,
                dueDay: today.addDays(-100),
                intervalDays: 1,
              ),
            ],
            nowUtc: now,
            today: today,
          );
      final ScoredCandidate scored = plan.scored.single;

      expect(scored.priorityFraction, 1);
      expect(scored.overdueRatio, 1);
      expect(scored.latenessShift, 0.05);
      expect(scored.jitter, 0);
      expect(scored.score, closeTo(0.95, 1e-12));
    });

    test('jitter is stable, lane-seeded, and within half the amplitude', () {
      final List<PriorityRank> ranks = _ranks(20);
      final QueuePolicy policy = QueuePolicy(
        settings: const QueueSettings(
          randomization: 0.2,
          maxTopics: 100,
          protectedPercentile: 0,
        ),
        scale: PriorityScale(ranks),
        datasetId: 'dataset-a',
      );
      final List<QueueCandidate> candidates = <QueueCandidate>[
        for (var i = 0; i < ranks.length; i++)
          _topic('t$i', priority: ranks[i]),
      ];
      final QueuePlan first = policy.build(
        candidates: candidates,
        nowUtc: now,
        today: today,
      );
      final QueuePlan second = policy.build(
        candidates: candidates.reversed,
        nowUtc: now,
        today: today,
      );

      expect(
        first.scored.map((ScoredCandidate s) => s.jitter.abs()),
        everyElement(lessThanOrEqualTo(0.1)),
      );
      expect(_planBytes(first), _planBytes(second));
    });
  });

  group('admission', () {
    test('card and topic maxima use separate capacity ledgers', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxCards: 3,
          maxTopics: 1,
          protectedPercentile: 0,
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
    });

    test(
      'regular reviews consume capacity first and excluded review blocks New',
      () {
        final List<PriorityRank> ranks = _ranks(5);
        final QueuePlan plan =
            QueuePolicy(
              settings: const QueueSettings(
                randomization: 0,
                maxCards: 2,
                maxNewCards: 2,
                protectedPercentile: 0,
              ),
              scale: PriorityScale(ranks),
            ).build(
              candidates: <QueueCandidate>[
                _card('new-top-1', dueAt: now, priority: ranks[0]),
                _card('new-top-2', dueAt: now, priority: ranks[1]),
                _card('review-1', dueAt: now, reps: 4, priority: ranks[2]),
                _card('review-2', dueAt: now, reps: 4, priority: ranks[3]),
                _card('review-3', dueAt: now, reps: 4, priority: ranks[4]),
              ],
              nowUtc: now,
              today: today,
            );

        expect(_entryIds(plan), <String>['review-1', 'review-2']);
        expect(plan.counters.admittedNewCards, 0);
        expect(
          plan.overflow.map((ScoredCandidate s) => s.ref.id),
          containsAll(<String>['review-3', 'new-top-1', 'new-top-2']),
        );
      },
    );

    test('New uses its sub-limit only after every due review fits', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxCards: 10,
          maxNewCards: 2,
          protectedPercentile: 0,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 5; i++) _card('new$i', dueAt: now),
          for (var i = 1; i <= 3; i++) _card('review$i', dueAt: now, reps: 4),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.counters.admittedNewCards, 2);
      expect(plan.counters.admittedCards, 5);
      expect(
        plan.overflow.every(
          (ScoredCandidate scored) => scored.candidate.isNewCard,
        ),
        isTrue,
      );
    });

    test('all due learning and relearning steps bypass the unique cap', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxCards: 0,
          protectedPercentile: 0,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          _card(
            'learning',
            dueAt: now,
            reps: 1,
            state: CardLearningState.learning,
          ),
          _card(
            'relearning',
            dueAt: now.subtract(const Duration(minutes: 1)),
            reps: 5,
            state: CardLearningState.relearning,
          ),
          _card('review', dueAt: now, reps: 4),
          _card('new', dueAt: now),
        ],
        nowUtc: now,
        today: today,
      );

      expect(_entryIds(plan), <String>['relearning', 'learning']);
      expect(
        plan.overflow.map((ScoredCandidate s) => s.ref.id),
        containsAll(<String>['review', 'new']),
      );
    });

    test(
      'protected topics survive massive overload despite extreme jitter',
      () {
        final List<PriorityRank> ranks = _ranks(100);
        final QueuePlan plan =
            QueuePolicy(
              settings: const QueueSettings(
                randomization: 1,
                maxTopics: 0,
                protectedPercentile: 0.02,
              ),
              scale: PriorityScale(ranks),
              datasetId: 'protection-test',
            ).build(
              candidates: <QueueCandidate>[
                for (var i = 0; i < ranks.length; i++)
                  _topic('t$i', priority: ranks[i]),
              ],
              nowUtc: now,
              today: today,
            );

        expect(
          plan.entries.map((QueueCandidate c) => c.ref.id).toSet(),
          <String>{'t0', 't1'},
        );
        expect(plan.counters.protectedElements, 2);
        expect(plan.overflow, hasLength(98));
        expect(
          plan.overflow.any((ScoredCandidate scored) => scored.isProtected),
          isFalse,
        );
      },
    );

    test(
      'protected reviews may exceed cap and still cannot make room for New',
      () {
        final List<PriorityRank> ranks = _ranks(10);
        final QueuePlan plan =
            QueuePolicy(
              settings: const QueueSettings(
                randomization: 0,
                maxCards: 1,
                maxNewCards: 10,
                protectedPercentile: 0.2,
              ),
              scale: PriorityScale(ranks),
            ).build(
              candidates: <QueueCandidate>[
                _card('protected-1', dueAt: now, reps: 4, priority: ranks[0]),
                _card('protected-2', dueAt: now, reps: 4, priority: ranks[1]),
                _card('regular', dueAt: now, reps: 4, priority: ranks[2]),
                _card('new', dueAt: now, priority: ranks[9]),
              ],
              nowUtc: now,
              today: today,
            );

        expect(_entryIds(plan), <String>['protected-1', 'protected-2']);
        expect(plan.counters.admittedCards, 2);
        expect(plan.counters.admittedNewCards, 0);
        expect(
          plan.overflow.map((ScoredCandidate s) => s.ref.id),
          containsAll(<String>['regular', 'new']),
        );
      },
    );

    test('caps are maxima, never a target the valve may overshoot', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 10,
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

      expect(plan.counters.admittedTopics, 10);
      expect(plan.counters.overflowTopics, 2);
    });

    test('one article cannot be throttled by an unstated share rule', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 100,
          protectedPercentile: 0,
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

      expect(plan.entries, hasLength(10));
      expect(
        plan.entries.where((QueueCandidate c) => c.rootId == 'big'),
        hasLength(8),
      );
    });

    test('auto-postpone toggle cannot turn a maximum into a quota hint', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 2,
          protectedPercentile: 0,
          autoPostpone: false,
        ),
      );
      final QueuePlan plan = policy.build(
        candidates: <QueueCandidate>[
          for (var i = 1; i <= 4; i++) _topic('t$i'),
        ],
        nowUtc: now,
        today: today,
      );

      expect(plan.counters.admittedTopics, 2);
      expect(plan.counters.overflowTopics, 2);
    });

    test('Study More raises each cap for one build only', () {
      const QueuePolicy policy = QueuePolicy(
        settings: QueueSettings(
          randomization: 0,
          maxTopics: 2,
          protectedPercentile: 0,
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
      expect(
        policy
            .build(candidates: candidates(), nowUtc: now, today: today)
            .counters
            .admittedTopics,
        2,
      );
    });
  });

  group('determinism and counters', () {
    test('identical inputs produce byte-identical complete plans', () {
      final List<PriorityRank> ranks = _ranks(40);
      final QueuePolicy policy = QueuePolicy(
        settings: const QueueSettings(
          randomization: 0.05,
          maxCards: 12,
          maxNewCards: 3,
          maxTopics: 7,
          protectedPercentile: 0.05,
        ),
        scale: PriorityScale(ranks),
        datasetId: 'stable-dataset',
      );
      final List<QueueCandidate> candidates = <QueueCandidate>[
        for (var i = 0; i < 20; i++)
          _card(
            'c$i',
            dueAt: now.subtract(Duration(hours: i)),
            reps: i.isEven ? 4 : 0,
            priority: ranks[i],
          ),
        for (var i = 20; i < 40; i++)
          _topic('t$i', priority: ranks[i], dueDay: today.addDays(-(i % 5))),
      ];

      final String first = _planBytes(
        policy.build(candidates: candidates, nowUtc: now, today: today),
      );
      final String second = _planBytes(
        policy.build(
          candidates: candidates.reversed,
          nowUtc: now,
          today: today,
        ),
      );
      expect(first, second);
    });

    test('thousands of preloaded candidates are ranked in one domain pass', () {
      final List<PriorityRank> ranks = _ranks(2000);
      final QueuePolicy policy = QueuePolicy(
        settings: const QueueSettings(
          randomization: 0.05,
          maxTopics: 2500,
          protectedPercentile: 0.01,
        ),
        scale: PriorityScale(ranks),
      );
      final List<QueueCandidate> candidates = <QueueCandidate>[
        for (var i = 0; i < ranks.length; i++)
          _topic('t$i', priority: ranks[i]),
      ];

      final QueuePlan plan = policy.build(
        candidates: candidates,
        nowUtc: now,
        today: today,
      );
      expect(plan.scored, hasLength(2000));
      expect(plan.overflow, isEmpty);
    });

    test('protection reports the best canonical priority that did not fit', () {
      final List<PriorityRank> ranks = _ranks(5);
      final QueuePlan plan =
          QueuePolicy(
            settings: const QueueSettings(
              randomization: 0,
              maxTopics: 2,
              protectedPercentile: 0,
            ),
            scale: PriorityScale(ranks),
          ).build(
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

List<String> _entryIds(QueuePlan plan) => <String>[
  for (final QueueCandidate candidate in plan.entries) candidate.ref.id,
];

List<PriorityRank> _ranks(int count) => <PriorityRank>[
  for (var i = 0; i < count; i++)
    PriorityRank('r${i.toString().padLeft(5, '0')}'),
];

String _planBytes(QueuePlan plan) => jsonEncode(<String, Object?>{
  'entries': <String>[
    for (final QueueCandidate candidate in plan.entries)
      candidate.ref.toString(),
  ],
  'overflow': <Map<String, Object?>>[
    for (final ScoredCandidate scored in plan.overflow) _scoredBytes(scored),
  ],
  'scored': <Map<String, Object?>>[
    for (final ScoredCandidate scored in plan.scored) _scoredBytes(scored),
  ],
  'counters': plan.counters.toMetadata(),
  'merge_cursor': plan.nextMergeCursor.ordinaryCardsSinceTopic,
});

Map<String, Object?> _scoredBytes(ScoredCandidate scored) => <String, Object?>{
  'ref': scored.ref.toString(),
  'lane': scored.lane.name,
  'score': scored.score,
  'priority_fraction': scored.priorityFraction,
  'overdue_ratio': scored.overdueRatio,
  'lateness_shift': scored.latenessShift,
  'jitter': scored.jitter,
  'protected': scored.isProtected,
};

QueueCandidate _card(
  String id, {
  required DateTime dueAt,
  ElementLifecycle lifecycle = ElementLifecycle.active,
  PriorityRank priority = PriorityRank.middle,
  int reps = 0,
  CardLearningState? state,
  String? rootId,
}) {
  const StudyDay day = StudyDay(year: 2026, month: 3, day: 5, zoneId: 'UTC');
  final bool isNew = reps == 0;
  final CardLearningState actualState =
      state ?? (isNew ? CardLearningState.learning : CardLearningState.review);
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
        state: actualState,
        step: actualState == CardLearningState.review ? null : 0,
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
