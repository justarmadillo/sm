/// SM20's daily Outstanding queue.
///
/// Section 9 replaced a weighted-fair merge with something much more literal:
/// sort each type by an exact priority key, stochastically extract from each
/// sorted list, then interleave the two by an attempted-counter ratio. None of
/// it is a heuristic, so all of it is testable exactly — including how many
/// values it takes from the shared random stream.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:test/test.dart';

final StudyDay _today = StudyDay.parse('2026-03-05', zoneId: 'UTC');
final DateTime _now = DateTime.utc(2026, 3, 5, 10);

ElementSchedule _schedule(ElementRef ref, PriorityRank priority) =>
    ElementSchedule(
      ref: ref,
      priority: priority,
      dueDay: _today,
      originalDueDay: _today,
      lifecycle: ElementLifecycle.active,
    );

/// A memorized topic, due today.
QueueCandidate _topic(String id, PriorityRank priority) {
  final ElementRef ref = ElementRef(id: id, type: ElementType.source);
  return QueueCandidate.topic(
    TopicState(
      schedule: _schedule(ref, priority),
      status: Sm20ElementStatus.memorized,
      repetitionCount: 1,
      lapseCount: 0,
      storedInterval: 1,
      lastReviewDay: _today.addDays(-1),
      aFactorRaw: DelphiReal48.fromDouble(1.2),
      lastIntervalRatioRaw: DelphiReal48.fromDouble(1),
    ),
  );
}

/// A reviewed card, due now.
QueueCandidate _card(String id, PriorityRank priority) {
  final ElementRef ref = ElementRef(id: id, type: ElementType.card);
  return QueueCandidate.card(
    CardState(
      schedule: _schedule(ref, priority),
      memory: CardMemory(
        cardId: id,
        state: CardLearningState.review,
        step: null,
        stability: 5,
        difficulty: 5,
        reps: 1,
        lapses: 0,
        lastReviewAtUtc: _now.subtract(const Duration(days: 1)),
        dueAtUtc: _now.subtract(const Duration(hours: 1)),
        originalDueAtUtc: _now.subtract(const Duration(hours: 1)),
        schedulerVersion: 'test',
        parametersVersion: 'test',
        scheduledDays: 1,
      ),
    ),
  );
}

/// Ranks spread across the collection, best first.
List<PriorityRank> _ranks(int count) {
  final List<PriorityRank> ranks = <PriorityRank>[PriorityRank.middle];
  for (var i = 1; i < count; i += 1) {
    ranks.add(PriorityRank.below(ranks.last));
  }
  return ranks;
}

/// Randomization off, so section 9.3's gate never fires and extraction walks
/// the priority-sorted list in order. That isolates the merge from the draw.
const QueueSettings _ordered = QueueSettings(
  itemRandomization: 0,
  topicRandomization: 0,
);

QueuePolicy _policy(List<QueueCandidate> all, {QueueSettings? settings}) =>
    QueuePolicy(
      settings: settings ?? const QueueSettings(),
      scale: PriorityScale.sorted(<PriorityRank>[
        for (final QueueCandidate c in all) c.schedule.priority,
      ]),
    );

void main() {
  group('the item/topic merge ratio (section 9.4)', () {
    test('takes items while (1 - topicFraction) > ni / (ni + nt + 1)', () {
      // At the default 20 percent topic share the inequality first fails at
      // ni = 4, so the pattern is four items and then one topic.
      final List<PriorityRank> ranks = _ranks(20);
      final List<QueueCandidate> all = <QueueCandidate>[
        for (var i = 0; i < 10; i += 1) _card('card-$i', ranks[i]),
        for (var i = 0; i < 10; i += 1) _topic('topic-$i', ranks[10 + i]),
      ];
      final QueuePlan plan = _policy(all, settings: _ordered).build(
        candidates: all,
        nowUtc: _now,
        today: _today,
        prng: Sm20Prng(seed: 0),
        combinedOrder: <ElementRef>[for (final QueueCandidate c in all) c.ref],
        outstandingItemMembership: <ElementRef>{
          for (final QueueCandidate c in all)
            if (c.isCard) c.ref,
        },
      );

      final List<ElementType> types = <ElementType>[
        for (final QueueCandidate c in plan.entries) c.ref.type,
      ];
      expect(types.take(4), everyElement(ElementType.card));
      expect(types.elementAt(4), ElementType.source);
    });

    test('an exhausted type does not undo the counter it consumed', () {
      // Section 9.4 increments ni before discovering the item side is empty,
      // and deliberately does not roll it back. Everything after that point
      // is therefore topics, with no attempt to re-balance.
      final List<PriorityRank> ranks = _ranks(8);
      final List<QueueCandidate> all = <QueueCandidate>[
        _card('card-0', ranks[0]),
        for (var i = 1; i < 8; i += 1) _topic('topic-$i', ranks[i]),
      ];
      final QueuePlan plan = _policy(all, settings: _ordered).build(
        candidates: all,
        nowUtc: _now,
        today: _today,
        prng: Sm20Prng(seed: 0),
        combinedOrder: <ElementRef>[for (final QueueCandidate c in all) c.ref],
        outstandingItemMembership: <ElementRef>{all.first.ref},
      );

      expect(plan.entries, hasLength(8));
      expect(plan.entries.first.ref.type, ElementType.card);
      expect(
        plan.entries.skip(1).map((QueueCandidate c) => c.ref.type),
        everyElement(ElementType.source),
      );
    });

    test('a 100 percent topic share never reaches for an item first', () {
      final List<PriorityRank> ranks = _ranks(6);
      final List<QueueCandidate> all = <QueueCandidate>[
        for (var i = 0; i < 3; i += 1) _card('card-$i', ranks[i]),
        for (var i = 0; i < 3; i += 1) _topic('topic-$i', ranks[3 + i]),
      ];
      final QueuePlan plan =
          _policy(
            all,
            settings: const QueueSettings(
              topicPercent: 100,
              itemRandomization: 0,
              topicRandomization: 0,
            ),
          ).build(
            candidates: all,
            nowUtc: _now,
            today: _today,
            prng: Sm20Prng(seed: 0),
            combinedOrder: <ElementRef>[
              for (final QueueCandidate c in all) c.ref,
            ],
            outstandingItemMembership: <ElementRef>{
              for (final QueueCandidate c in all)
                if (c.isCard) c.ref,
            },
          );
      expect(plan.entries.first.ref.type, ElementType.source);
    });
  });

  group('randomization draws (section 9.3)', () {
    test('the merge itself consumes nothing', () {
      final List<PriorityRank> ranks = _ranks(6);
      final List<QueueCandidate> all = <QueueCandidate>[
        for (var i = 0; i < 3; i += 1) _card('card-$i', ranks[i]),
        for (var i = 0; i < 3; i += 1) _topic('topic-$i', ranks[3 + i]),
      ];
      final Sm20Prng prng = Sm20Prng(seed: 12345);
      final int before = prng.state.seed;
      _policy(all).build(
        candidates: all,
        nowUtc: _now,
        today: _today,
        prng: prng,
        combinedOrder: <ElementRef>[for (final QueueCandidate c in all) c.ref],
        outstandingItemMembership: <ElementRef>{
          for (final QueueCandidate c in all)
            if (c.isCard) c.ref,
        },
        // Without a sort there is no stochastic extraction, so the whole
        // build must be free of draws.
        sort: false,
      );
      expect(prng.state.seed, before);
    });

    test('a sorted build draws at least once per element', () {
      // Section 9.3 always consumes one value per element, and two more for
      // every branch that takes the random-depth path.
      final List<PriorityRank> ranks = _ranks(6);
      final List<QueueCandidate> all = <QueueCandidate>[
        for (var i = 0; i < 3; i += 1) _card('card-$i', ranks[i]),
        for (var i = 0; i < 3; i += 1) _topic('topic-$i', ranks[3 + i]),
      ];
      var draws = 0;
      final Sm20Prng counting = Sm20Prng(seed: 7);
      final Sm20Prng reference = Sm20Prng(seed: 7);
      _policy(all).build(
        candidates: all,
        nowUtc: _now,
        today: _today,
        prng: counting,
        combinedOrder: <ElementRef>[for (final QueueCandidate c in all) c.ref],
        outstandingItemMembership: <ElementRef>{
          for (final QueueCandidate c in all)
            if (c.isCard) c.ref,
        },
      );
      while (reference.state.seed != counting.state.seed && draws < 1000) {
        reference.advance();
        draws += 1;
      }
      expect(draws, greaterThanOrEqualTo(all.length));
    });

    test('fixed-size randomization is a permutation, not a resample', () {
      final List<int> values = <int>[for (var i = 0; i < 12; i += 1) i];
      final Sm20Prng prng = Sm20Prng(seed: 3);
      QueuePolicy.randomizeFixedSize<int>(values, prng);
      expect(values..sort(), <int>[for (var i = 0; i < 12; i += 1) i]);
    });
  });

  group('the stages (section 9.5)', () {
    test('Pending is never injected into the Outstanding merge', () {
      final List<PriorityRank> ranks = _ranks(4);
      final QueueCandidate pending = QueueCandidate.topic(
        TopicState(
          schedule: _schedule(
            const ElementRef(id: 'pending', type: ElementType.source),
            ranks[0],
          ),
          status: Sm20ElementStatus.pending,
          repetitionCount: 0,
          lapseCount: 0,
          storedInterval: 0,
          aFactorRaw: DelphiReal48.fromDouble(1.2),
          lastIntervalRatioRaw: DelphiReal48.fromDouble(1),
        ),
      );
      final List<QueueCandidate> all = <QueueCandidate>[
        pending,
        _topic('topic-1', ranks[1]),
        _card('card-1', ranks[2]),
      ];
      expect(pending.isPending, isTrue);

      final QueuePlan plan = _policy(all).build(
        candidates: all,
        nowUtc: _now,
        today: _today,
        prng: Sm20Prng(seed: 0),
        combinedOrder: <ElementRef>[
          for (final QueueCandidate c in all)
            if (!c.isPending) c.ref,
        ],
        outstandingItemMembership: <ElementRef>{all.last.ref},
        sort: false,
      );
      expect(
        plan.entries.map((QueueCandidate c) => c.ref),
        isNot(contains(pending.ref)),
      );
    });

    test('a stage plan carries its lane and nothing stochastic', () {
      final List<PriorityRank> ranks = _ranks(2);
      final List<QueueCandidate> drill = <QueueCandidate>[
        _topic('a', ranks[0]),
        _card('b', ranks[1]),
      ];
      final Sm20PrngState state = Sm20Prng(seed: 99).state;
      final QueuePlan plan = QueuePlan.stage(
        candidates: drill,
        lane: QueueLane.finalDrill,
        prngState: state,
      );
      expect(plan.entries, hasLength(2));
      expect(
        plan.scored.map((ScoredCandidate s) => s.lane),
        everyElement(QueueLane.finalDrill),
      );
      expect(plan.prngState.seed, state.seed);
    });
  });

  group('determinism', () {
    test('the same seed and inputs produce the same order', () {
      final List<PriorityRank> ranks = _ranks(10);
      final List<QueueCandidate> all = <QueueCandidate>[
        for (var i = 0; i < 5; i += 1) _card('card-$i', ranks[i]),
        for (var i = 0; i < 5; i += 1) _topic('topic-$i', ranks[5 + i]),
      ];
      List<String> run() => <String>[
        for (final QueueCandidate c
            in _policy(all)
                .build(
                  candidates: all,
                  nowUtc: _now,
                  today: _today,
                  prng: Sm20Prng(seed: 4242),
                  combinedOrder: <ElementRef>[
                    for (final QueueCandidate c in all) c.ref,
                  ],
                  outstandingItemMembership: <ElementRef>{
                    for (final QueueCandidate c in all)
                      if (c.isCard) c.ref,
                  },
                )
                .entries)
          c.ref.id,
      ];
      expect(run(), run());
    });

    test('an empty day produces an empty plan', () {
      final QueuePlan plan = const QueuePolicy().build(
        candidates: const <QueueCandidate>[],
        nowUtc: _now,
        today: _today,
        prng: Sm20Prng(seed: 0),
      );
      expect(plan.entries, isEmpty);
      expect(plan.isEmpty, isTrue);
    });
  });
}
