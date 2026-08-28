import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_postpone.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:test/test.dart';

void main() {
  group('Smart Postpone eligibility and delay', () {
    test('simulation uses exact formula and consumes no PRNG values', () {
      final Sm20PostponeCandidate candidate = _candidate(
        'item',
        type: ElementType.card,
        rank: 'B',
        lastReview: 90,
        interval: 10,
        forgettingIndex: 6,
      );
      final Sm20Prng prng = Sm20Prng(seed: 0x12345678);
      final SmartPostponeResult result = const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[candidate],
        profile: const SmartPostponeSettings(
          method: SmartPostponeMethod.parameters,
          simulate: true,
          itemDelayPercent: 20,
          itemMinimumDelayDays: 1,
          itemMaximumDelayDays: 50,
          itemPriorityThreshold: 0.01,
        ),
        priorityScale: PriorityScale(<PriorityRank>[
          const PriorityRank('A'),
          const PriorityRank('B'),
          const PriorityRank('C'),
        ]),
        today: _day(100),
        prng: prng,
      );

      expect(result.randomDraws, 0);
      expect(prng.drawCount, 0);
      expect(result.decisions, hasLength(1));
      final SmartPostponeDecision decision = result.decisions.single;
      expect(decision.priorityPercent, 50);
      expect(decision.ageDays, 10);
      // round_even(10*1.2)-10 = 2;
      // round_even(2*2*sqrt(.5)) = 3.
      expect(decision.delayDays, 3);
      expect(decision.factor, 1.3);
      expect(decision.newIntervalDays, 13);
      expect(decision.targetDay, _day(103));
      expect(decision.writesRecord, isFalse);
    });

    test('real ordinary candidate disperses with exactly two global draws', () {
      final Sm20PostponeCandidate candidate = _candidate(
        'topic',
        type: ElementType.source,
        rank: 'B',
        lastReview: 80,
        interval: 20,
        aFactor: 2,
      );
      final Sm20Prng expectedPrng = Sm20Prng(seed: 77);
      final int expectedDelay = sm20RoundEven(
        sm20Spread(center: 14, width: 7, prng: expectedPrng),
      );
      final Sm20Prng actualPrng = Sm20Prng(seed: 77);
      final SmartPostponeResult result = const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[candidate],
        profile: const SmartPostponeSettings(
          method: SmartPostponeMethod.parameters,
          topicDelayPercent: 50,
          topicMinimumDelayDays: 1,
          topicMaximumDelayDays: 100,
          topicAFactorCutoff: 1.01,
          topicPriorityThreshold: 0.0001,
        ),
        priorityScale: PriorityScale(<PriorityRank>[
          const PriorityRank('A'),
          const PriorityRank('B'),
          const PriorityRank('C'),
        ]),
        today: _day(100),
        prng: actualPrng,
      );

      // raw=10; round_even(20*sqrt(.5))=14 before dispersion.
      expect(result.decisions.single.delayDays, expectedDelay);
      expect(result.randomDraws, 2);
      expect(actualPrng.state, expectedPrng.state);
    });

    test('generic type uses factor 1.01, no profile clamps, and two draws', () {
      final Sm20PostponeCandidate candidate = Sm20PostponeCandidate(
        ref: const ElementRef(id: 'generic', type: ElementType.source),
        priority: const PriorityRank('B'),
        storedInterval: 100,
        lastReviewDay: _day(0),
        totalPostponements: 0,
        isOutstanding: true,
        isMemorized: true,
        typeCode: 5,
      );
      final Sm20Prng expectedPrng = Sm20Prng(seed: 91);
      final int expectedDelay = sm20RoundEven(
        sm20Spread(center: 1, width: 0.5, prng: expectedPrng),
      );
      final Sm20Prng actualPrng = Sm20Prng(seed: 91);
      final SmartPostponeResult result = const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[candidate],
        profile: const SmartPostponeSettings(
          method: SmartPostponeMethod.parameters,
          itemMinimumDelayDays: 30,
          topicMinimumDelayDays: 100,
        ),
        priorityScale: PriorityScale(<PriorityRank>[
          const PriorityRank('A'),
          const PriorityRank('B'),
          const PriorityRank('C'),
        ]),
        today: _day(100),
        prng: actualPrng,
      );

      // round_even(100*1.01)-100 = 1; priority scaling also rounds to 1.
      expect(result.decisions.single.delayDays, expectedDelay);
      expect(result.decisions.single.factor, (100 + expectedDelay) / 100);
      expect(result.randomDraws, 2);
      expect(actualPrng.state, expectedPrng.state);
    });

    test('dispersion is not clamped back to the configured delay bounds', () {
      Sm20Prng? selected;
      int? dispersed;
      for (var seed = 0; seed < 1000; seed += 1) {
        final Sm20Prng probe = Sm20Prng(seed: seed);
        final int value = sm20RoundEven(
          sm20Spread(center: 10, width: 5, prng: probe),
        );
        if (value > 10) {
          selected = Sm20Prng(seed: seed);
          dispersed = value;
          break;
        }
      }
      expect(selected, isNotNull);
      final SmartPostponeResult result = const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[
          _candidate(
            'item',
            type: ElementType.card,
            rank: 'C',
            lastReview: 0,
            interval: 100,
          ),
        ],
        profile: const SmartPostponeSettings(
          method: SmartPostponeMethod.parameters,
          itemDelayPercent: 10,
          itemMinimumDelayDays: 10,
          itemMaximumDelayDays: 10,
          itemPriorityThreshold: 0.01,
        ),
        priorityScale: PriorityScale(<PriorityRank>[
          const PriorityRank('A'),
          const PriorityRank('B'),
          const PriorityRank('C'),
        ]),
        today: _day(100),
        prng: selected!,
      );

      expect(result.decisions.single.delayDays, dispersed);
      expect(result.decisions.single.delayDays, greaterThan(10));
    });

    test('pending reviewed Today follows Delay Element interval-one edge', () {
      final SmartPostponeResult result = const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[
          _candidate(
            'pending',
            type: ElementType.source,
            rank: 'B',
            lastReview: 100,
            interval: 0,
            outstanding: false,
            memorized: false,
            aFactor: 2,
          ),
        ],
        profile: const SmartPostponeSettings(
          method: SmartPostponeMethod.parameters,
          includeNonOutstanding: true,
          simulate: true,
          topicPriorityThreshold: 0.0001,
        ),
        priorityScale: PriorityScale(<PriorityRank>[
          const PriorityRank('A'),
          const PriorityRank('B'),
        ]),
        today: _day(100),
        prng: Sm20Prng(seed: 0),
      );

      expect(result.decisions.single.ageDays, 1);
      expect(result.decisions.single.newIntervalDays, 1);
      expect(result.decisions.single.targetDay, _day(101));
    });

    test('cutoff comparisons preserve strict executable boundaries', () {
      final PriorityScale scale = PriorityScale(<PriorityRank>[
        const PriorityRank('A'),
        const PriorityRank('B'),
        const PriorityRank('C'),
      ]);
      SmartPostponeResult run(
        Sm20PostponeCandidate candidate,
        SmartPostponeSettings profile,
      ) => const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[candidate],
        profile: profile,
        priorityScale: scale,
        today: _day(100),
        prng: Sm20Prng(seed: 1),
      );

      const SmartPostponeSettings item = SmartPostponeSettings(
        method: SmartPostponeMethod.parameters,
        simulate: true,
        itemAgeCutoffDays: 10,
        itemForgettingIndexCutoff: 6,
        itemPostponeCountCutoff: 50,
        itemPriorityThreshold: 50,
      );
      expect(
        run(
          _candidate(
            'age-equal',
            type: ElementType.card,
            rank: 'B',
            lastReview: 90,
            interval: 10,
          ),
          item,
        ).decisions,
        isEmpty,
      ); // age >= cutoff
      expect(
        run(
          _candidate(
            'fi-equal',
            type: ElementType.card,
            rank: 'B',
            lastReview: 91,
            interval: 9,
            forgettingIndex: 6,
          ),
          item,
        ).decisions,
        hasLength(1),
      ); // FI >= cutoff
      expect(
        run(
          _candidate(
            'count-equal',
            type: ElementType.card,
            rank: 'B',
            lastReview: 91,
            interval: 9,
            postponements: 50,
          ),
          item,
        ).decisions,
        isEmpty,
      ); // count >= cutoff
      expect(
        run(
          _candidate(
            'priority-equal',
            type: ElementType.card,
            rank: 'B',
            lastReview: 91,
            interval: 9,
          ),
          item,
        ).decisions,
        hasLength(1),
      ); // P >= threshold

      const SmartPostponeSettings topic = SmartPostponeSettings(
        method: SmartPostponeMethod.parameters,
        simulate: true,
        topicAFactorCutoff: 1.2,
        topicPriorityThreshold: 0.0001,
      );
      expect(
        run(
          _candidate(
            'a-equal',
            type: ElementType.source,
            rank: 'B',
            lastReview: 91,
            interval: 9,
            aFactor: 1.2,
          ),
          topic,
        ).decisions,
        isEmpty,
      ); // A <= cutoff
      expect(
        run(
          _candidate(
            'a-above',
            type: ElementType.source,
            rank: 'B',
            lastReview: 91,
            interval: 9,
            aFactor: 1.200001,
          ),
          topic,
        ).decisions,
        hasLength(1),
      );
    });

    test(
      'protected method sorts low importance first then forces to target',
      () {
        final List<Sm20PostponeCandidate> candidates = <Sm20PostponeCandidate>[
          _candidate('a', type: ElementType.card, rank: 'A'),
          _candidate('b', type: ElementType.card, rank: 'B'),
          _candidate('c', type: ElementType.card, rank: 'C'),
          _candidate('d', type: ElementType.card, rank: 'D'),
        ];
        final SmartPostponeResult result = const SmartPostponeEngine().run(
          source: candidates,
          profile: const SmartPostponeSettings(
            method: SmartPostponeMethod.topCount,
            protectedCount: 2,
            skipItems: true,
            itemMinimumDelayDays: 1,
            itemMaximumDelayDays: 5,
          ),
          priorityScale: PriorityScale(
            candidates.map((Sm20PostponeCandidate value) => value.priority),
          ),
          today: _day(100),
          prng: Sm20Prng(seed: 3),
        );

        expect(result.sourceOrder.map((ElementRef value) => value.id), [
          'd',
          'c',
          'b',
          'a',
        ]);
        expect(result.forcedPassRan, isTrue);
        expect(result.randomDraws, 0);
        expect(
          result.decisions.map((SmartPostponeDecision value) => value.pass),
          everyElement(SmartPostponePass.forced),
        );
        expect(result.postponed.map((ElementRef value) => value.id), [
          'd',
          'c',
        ]);
        expect(
          result.decisions.map(
            (SmartPostponeDecision value) => value.delayDays,
          ),
          [5, 4],
        );
        expect(result.unpostponed.map((ElementRef value) => value.id), [
          'b',
          'a',
        ]);
      },
    );

    test('ordinary pass precedes forced pass and only ordinary draws', () {
      final List<Sm20PostponeCandidate> candidates = <Sm20PostponeCandidate>[
        _candidate('a', type: ElementType.card, rank: 'A', forgettingIndex: 0),
        _candidate('b', type: ElementType.card, rank: 'B', forgettingIndex: 0),
        _candidate('c', type: ElementType.card, rank: 'C', forgettingIndex: 0),
        _candidate('d', type: ElementType.card, rank: 'D', forgettingIndex: 6),
      ];
      final SmartPostponeResult result = const SmartPostponeEngine().run(
        source: candidates,
        profile: const SmartPostponeSettings(
          method: SmartPostponeMethod.topCount,
          protectedCount: 2,
          itemPriorityThreshold: 0.01,
        ),
        priorityScale: PriorityScale(
          candidates.map((Sm20PostponeCandidate value) => value.priority),
        ),
        today: _day(100),
        prng: Sm20Prng(seed: 8),
      );

      expect(result.forcedPassRan, isTrue);
      expect(
        result.decisions.map((SmartPostponeDecision value) => value.ref.id),
        <String>['d', 'c'],
      );
      expect(
        result.decisions.map((SmartPostponeDecision value) => value.pass),
        <SmartPostponePass>[
          SmartPostponePass.ordinary,
          SmartPostponePass.forced,
        ],
      );
      expect(result.randomDraws, 2);
    });

    test(
      'raw source count includes deleted and excluded protected remainder',
      () {
        final List<Sm20PostponeCandidate> candidates = <Sm20PostponeCandidate>[
          Sm20PostponeCandidate(
            ref: const ElementRef(id: 'deleted', type: ElementType.card),
            priority: const PriorityRank('D'),
            storedInterval: 10,
            lastReviewDay: _day(90),
            totalPostponements: 0,
            isOutstanding: true,
            isMemorized: true,
            isDeleted: true,
          ),
          _candidate(
            'excluded',
            type: ElementType.card,
            rank: 'C',
            outstanding: false,
          ),
          _candidate('b', type: ElementType.card, rank: 'B'),
          _candidate('a', type: ElementType.card, rank: 'A'),
        ];
        final SmartPostponeResult result = const SmartPostponeEngine().run(
          source: candidates,
          profile: const SmartPostponeSettings(
            method: SmartPostponeMethod.topCount,
            protectedCount: 2,
            itemPriorityThreshold: 0.01,
          ),
          priorityScale: PriorityScale(
            candidates.map((Sm20PostponeCandidate value) => value.priority),
          ),
          today: _day(100),
          prng: Sm20Prng(seed: 8),
        );

        expect(result.postponed.map((ElementRef value) => value.id), <String>[
          'b',
          'a',
        ]);
        expect(result.unpostponed.map((ElementRef value) => value.id), <String>[
          'deleted',
          'excluded',
        ]);
      },
    );

    test('include non-outstanding bypasses only membership exclusion', () {
      final Sm20PostponeCandidate candidate = _candidate(
        'pending',
        type: ElementType.source,
        rank: 'B',
        outstanding: false,
        memorized: false,
        aFactor: 2,
      );
      SmartPostponeResult run(bool include) => const SmartPostponeEngine().run(
        source: <Sm20PostponeCandidate>[candidate],
        profile: SmartPostponeSettings(
          method: SmartPostponeMethod.parameters,
          includeNonOutstanding: include,
          simulate: true,
          topicPriorityThreshold: 0.0001,
        ),
        priorityScale: PriorityScale(<PriorityRank>[
          const PriorityRank('A'),
          candidate.priority,
        ]),
        today: _day(100),
        prng: Sm20Prng(seed: 0),
      );

      expect(run(false).decisions, isEmpty);
      expect(run(true).decisions, hasLength(1));
    });
  });

  group('Smart Postpone profile merge', () {
    test('conservative and liberal directions match the profile routine', () {
      const SmartPostponeSettings child = SmartPostponeSettings(
        itemDelayPercent: 30,
        itemMinimumDelayDays: 4,
        itemMaximumDelayDays: 70,
        itemAgeCutoffDays: 900,
        itemPostponeCountCutoff: 80,
        itemPriorityThreshold: 9,
        itemForgettingIndexCutoff: 4,
        topicAFactorCutoff: 1.02,
        skipItems: true,
      );
      final SmartPostponeSettings conservative = mergeSmartPostponeProfiles(
        const SmartPostponeSettings(
          subbranchMode: SmartPostponeSubbranchMode.conservative,
          itemDelayPercent: 20,
          itemMinimumDelayDays: 6,
          itemMaximumDelayDays: 50,
          itemAgeCutoffDays: 500,
          itemPostponeCountCutoff: 50,
          itemPriorityThreshold: 6,
          itemForgettingIndexCutoff: 6,
          topicAFactorCutoff: 1.03,
        ),
        const <SmartPostponeSettings>[child],
      );
      expect(conservative.itemDelayPercent, 20);
      expect(conservative.itemMinimumDelayDays, 4);
      expect(conservative.itemMaximumDelayDays, 50);
      expect(conservative.itemAgeCutoffDays, 500);
      expect(conservative.itemPostponeCountCutoff, 50);
      expect(conservative.itemPriorityThreshold, 6);
      expect(conservative.itemForgettingIndexCutoff, 6);
      expect(conservative.topicAFactorCutoff, 1.03);
      expect(conservative.skipItems, isTrue);

      final SmartPostponeSettings liberal = mergeSmartPostponeProfiles(
        const SmartPostponeSettings(
          subbranchMode: SmartPostponeSubbranchMode.liberal,
          itemDelayPercent: 20,
          itemMinimumDelayDays: 6,
          itemMaximumDelayDays: 50,
          itemAgeCutoffDays: 500,
          itemPostponeCountCutoff: 50,
          itemPriorityThreshold: 6,
          itemForgettingIndexCutoff: 6,
          topicAFactorCutoff: 1.03,
          skipItems: true,
        ),
        const <SmartPostponeSettings>[child],
      );
      expect(liberal.itemDelayPercent, 30);
      expect(liberal.itemMinimumDelayDays, 6);
      expect(liberal.itemMaximumDelayDays, 70);
      expect(liberal.itemAgeCutoffDays, 900);
      expect(liberal.itemPostponeCountCutoff, 80);
      expect(liberal.itemPriorityThreshold, 9);
      expect(liberal.itemForgettingIndexCutoff, 4);
      expect(liberal.topicAFactorCutoff, 1.02);
      expect(liberal.skipItems, isTrue);
    });

    test('Respect copies the most specific profile and Ignore keeps base', () {
      const SmartPostponeSettings child = SmartPostponeSettings(
        profileName: 'child',
        itemDelayPercent: 73,
      );
      const SmartPostponeSettings grandchild = SmartPostponeSettings(
        profileName: 'grandchild',
        itemDelayPercent: 91,
      );
      final SmartPostponeSettings respected = mergeSmartPostponeProfiles(
        const SmartPostponeSettings(
          subbranchMode: SmartPostponeSubbranchMode.respect,
        ),
        const <SmartPostponeSettings>[child, grandchild],
      );
      const SmartPostponeSettings ignoredBase = SmartPostponeSettings(
        profileName: 'base',
        subbranchMode: SmartPostponeSubbranchMode.ignore,
        itemDelayPercent: 22,
      );
      final SmartPostponeSettings ignored = mergeSmartPostponeProfiles(
        ignoredBase,
        const <SmartPostponeSettings>[child, grandchild],
      );

      expect(respected, grandchild);
      expect(ignored, same(ignoredBase));
    });
  });

  group('automatic postponement', () {
    test('stale and count gates use strict boundaries and record Today', () {
      final DateTime now = DateTime.utc(2024, 1, 20);
      AutoPostponeRequest request({
        required Duration idle,
        int outstanding = 10,
      }) => AutoPostponeRequest(
        today: _day(100),
        nowUtc: now,
        autoEnabled: true,
        lastAutoRunDay: null,
        collectionNonempty: true,
        lastCollectionUseUtc: now.subtract(idle),
        force: false,
        combinedOutstandingCount: outstanding,
        collectionLearningStartDay: _day(0),
        scheduledElements: const <Sm20PostponeCandidate>[],
        defaultProfile: const SmartPostponeSettings(),
        priorityScale: PriorityScale.empty,
      );

      final AutoPostponeResult exactTen = const AutoPostponeEngine().run(
        request(idle: const Duration(days: 10)),
        Sm20Prng(seed: 0),
      );
      expect(exactTen.outcome, AutoPostponeOutcome.outstandingGate);
      expect(exactTen.lastAutoRunDay, _day(100));
      expect(exactTen.disableAutoPostpone, isFalse);

      final AutoPostponeResult stale = const AutoPostponeEngine().run(
        request(idle: const Duration(days: 10, microseconds: 1)),
        Sm20Prng(seed: 0),
      );
      expect(stale.outcome, AutoPostponeOutcome.staleCollectionDisabled);
      expect(stale.lastAutoRunDay, isNull);
      expect(stale.disableAutoPostpone, isTrue);
    });

    test('requires more than ten overdue rows then runs Default profile', () {
      final List<Sm20PostponeCandidate> candidates = <Sm20PostponeCandidate>[
        for (var index = 0; index < 11; index += 1)
          _candidate(
            '$index',
            type: ElementType.card,
            rank: 'K${String.fromCharCode(65 + index)}',
            scheduled: 99,
          ),
      ];
      final AutoPostponeResult result = const AutoPostponeEngine().run(
        AutoPostponeRequest(
          today: _day(100),
          nowUtc: DateTime.utc(2024, 1, 20),
          autoEnabled: true,
          lastAutoRunDay: null,
          collectionNonempty: true,
          lastCollectionUseUtc: DateTime.utc(2024, 1, 19),
          force: false,
          combinedOutstandingCount: 11,
          collectionLearningStartDay: _day(0),
          scheduledElements: candidates,
          defaultProfile: const SmartPostponeSettings(
            method: SmartPostponeMethod.parameters,
            itemPriorityThreshold: 0.01,
          ),
          priorityScale: PriorityScale(<PriorityRank>[
            const PriorityRank('A'),
            ...candidates.map((Sm20PostponeCandidate value) => value.priority),
          ]),
        ),
        Sm20Prng(seed: 5),
      );

      expect(result.outcome, AutoPostponeOutcome.ran);
      expect(result.overdueCount, 11);
      expect(result.lastAutoRunDay, _day(100));
      expect(result.smartPostpone!.profile.profileName, isEmpty);
      expect(result.smartPostpone!.profile.includeNonOutstanding, isFalse);
      expect(result.smartPostpone!.decisions, hasLength(11));
      expect(result.smartPostpone!.randomDraws, 22);
    });
  });
}

Sm20PostponeCandidate _candidate(
  String id, {
  required ElementType type,
  required String rank,
  int lastReview = 90,
  int interval = 10,
  int postponements = 0,
  double aFactor = 2,
  double forgettingIndex = 10,
  bool outstanding = true,
  bool memorized = true,
  int? scheduled,
}) => Sm20PostponeCandidate(
  ref: ElementRef(id: id, type: type),
  priority: PriorityRank(rank),
  storedInterval: interval,
  lastReviewDay: _day(lastReview),
  totalPostponements: postponements,
  isOutstanding: outstanding,
  isMemorized: memorized,
  scheduledDay: scheduled == null ? null : _day(scheduled),
  aFactor: aFactor,
  forgettingIndex: forgettingIndex,
);

StudyDay _day(int epochDay) => const StudyDay(
  year: 1970,
  month: 1,
  day: 1,
  zoneId: 'UTC',
).addDays(epochDay);
