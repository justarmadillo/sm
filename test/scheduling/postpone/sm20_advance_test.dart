/// The Advance selection and draw arithmetic of section 8.5.
///
/// The property these tests exist to pin is the draw accounting: exactly one
/// PRNG value per draw-eligible record, consumed before the rejection test, so
/// every later feature sharing the one global stream stays reproducible.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:test/test.dart';

void main() {
  group('Advance selection', () {
    test('type masks select exactly the executable\'s two record types', () {
      expect(Sm20AdvanceScope.topics.typeMask, 1);
      expect(Sm20AdvanceScope.items.typeMask, 2);
      expect(Sm20AdvanceScope.all.typeMask, 3);
      expect(Sm20AdvanceScope.topics.includes(ElementType.source), isTrue);
      expect(Sm20AdvanceScope.topics.includes(ElementType.extract), isTrue);
      expect(Sm20AdvanceScope.topics.includes(ElementType.card), isFalse);
      expect(Sm20AdvanceScope.items.includes(ElementType.card), isTrue);
      expect(Sm20AdvanceScope.items.includes(ElementType.source), isFalse);
      expect(Sm20AdvanceScope.all.includes(ElementType.source), isTrue);
      expect(Sm20AdvanceScope.all.includes(ElementType.card), isTrue);
    });

    test('the horizon respects the dialog bounds per scope', () {
      expect(Sm20AdvanceScope.topics.minimumDays, 1);
      expect(Sm20AdvanceScope.items.minimumDays, 2);
      expect(Sm20AdvanceScope.all.minimumDays, 2);
      expect(kSm20AdvanceDefaultDays, 30);
      expect(kSm20AdvanceMaximumDays, 500);

      expect(
        () => _run(<Sm20AdvanceCandidate>[], horizonDays: 0),
        throwsRangeError,
      );
      expect(
        () => _run(<Sm20AdvanceCandidate>[], horizonDays: 501),
        throwsRangeError,
      );
      expect(
        () => _run(
          <Sm20AdvanceCandidate>[],
          scope: Sm20AdvanceScope.items,
          horizonDays: 1,
        ),
        throwsRangeError,
      );
    });

    test('records rejected before the draw consume no randomness', () {
      final Sm20Prng prng = Sm20Prng(seed: 0x12345678);
      final Sm20AdvanceResult result = _run(<Sm20AdvanceCandidate>[
        // Wrong type for the scope.
        _candidate('card', type: ElementType.card, interval: 200),
        // Not memorized.
        _candidate('pending', memorized: false, interval: 200),
        // Reviewed today.
        _candidate('today', interval: 200, lastReview: 100),
        // Never reviewed.
        _candidate('fresh', interval: 200, lastReview: null),
        // Interval already inside the horizon.
        _candidate('short', interval: 30),
      ], prng: prng);

      expect(result.considered, 0);
      expect(result.randomDraws, 0);
      expect(result.decisions, isEmpty);
      expect(prng.state.seed, 0x12345678);
    });

    test('a rejected r still consumes its draw', () {
      // With a one-day horizon, `r` is 1 or 2 and the interval is 2, so about
      // half of these are rejected — yet every candidate that reached the
      // test drew exactly once, which is the property the stream depends on.
      final Sm20Prng prng = Sm20Prng(seed: 0x12345678);
      final Sm20AdvanceResult result = _run(
        <Sm20AdvanceCandidate>[
          for (var i = 0; i < 16; i++) _candidate('topic-$i', interval: 2),
        ],
        horizonDays: 1,
        prng: prng,
      );

      expect(result.considered, 16);
      expect(result.randomDraws, 16);
      expect(result.decisions.length, inInclusiveRange(1, 15));
      for (final Sm20AdvanceDecision decision in result.decisions) {
        expect(decision.newInterval, 1);
      }
    });

    test('the topic branch schedules r days from today', () {
      final Sm20Prng prng = Sm20Prng(seed: 0x12345678);
      final Sm20AdvanceResult result = _run(<Sm20AdvanceCandidate>[
        _candidate('topic', interval: 400, lastReview: 20),
      ], prng: prng);

      final Sm20AdvanceDecision decision = result.decisions.single;
      expect(decision.isItem, isFalse);
      expect(decision.newInterval, inInclusiveRange(1, 31));
      expect(decision.targetDay, _day(100).addDays(decision.newInterval));
      expect(decision.oldInterval, 400);
      expect(result.randomDraws, 1);
    });

    test('the item branch re-expresses r as days since the last review', () {
      final Sm20Prng prng = Sm20Prng(seed: 0x9e3779b9);
      final Sm20AdvanceResult result = _run(
        <Sm20AdvanceCandidate>[
          _candidate(
            'card',
            type: ElementType.card,
            interval: 400,
            lastReview: 60,
          ),
        ],
        scope: Sm20AdvanceScope.items,
        prng: prng,
      );

      final Sm20AdvanceDecision decision = result.decisions.single;
      expect(decision.isItem, isTrue);
      // r counted from the last review, never below the two-day floor.
      expect(decision.newInterval, greaterThanOrEqualTo(2));
      expect(decision.targetDay, _day(60).addDays(decision.newInterval));
      expect(
        decision.newInterval,
        // today - lastReview + rawDraw, and the raw draw is in 1..30+1.
        inInclusiveRange(41, 71),
      );
    });

    test('a stale item is floored at two days rather than moved backwards', () {
      final Sm20Prng prng = Sm20Prng(seed: 0x12345678);
      final Sm20AdvanceResult result = _run(
        <Sm20AdvanceCandidate>[
          // The last review is in the future relative to today, which the
          // floor is what keeps from producing a negative interval.
          _candidate(
            'card',
            type: ElementType.card,
            interval: 400,
            lastReview: 400,
          ),
        ],
        scope: Sm20AdvanceScope.items,
        prng: prng,
      );

      expect(result.considered, 1);
      expect(result.randomDraws, 1);
      expect(result.decisions.single.newInterval, 2);
    });

    test('All advances topics and items in one shared stream', () {
      final Sm20Prng shared = Sm20Prng(seed: 0x12345678);
      final Sm20AdvanceResult result = _run(
        <Sm20AdvanceCandidate>[
          _candidate('topic', interval: 400, lastReview: 20),
          _candidate(
            'card',
            type: ElementType.card,
            interval: 400,
            lastReview: 20,
          ),
        ],
        scope: Sm20AdvanceScope.all,
        prng: shared,
      );

      expect(result.considered, 2);
      expect(result.randomDraws, 2);
      expect(result.prngState.seed, shared.state.seed);
      expect(result.decisions.map((Sm20AdvanceDecision d) => d.isItem), <bool>[
        false,
        true,
      ]);
    });

    test('the same seed reproduces the same run exactly', () {
      List<int> intervalsFor(int seed) => _run(
        <Sm20AdvanceCandidate>[
          for (var i = 0; i < 12; i++) _candidate('topic-$i', interval: 400),
        ],
        prng: Sm20Prng(seed: seed),
      ).decisions.map((Sm20AdvanceDecision d) => d.newInterval).toList();

      expect(intervalsFor(0x12345678), intervalsFor(0x12345678));
      expect(intervalsFor(0x12345678), isNot(intervalsFor(0x9e3779b9)));
    });
  });
}

Sm20AdvanceResult _run(
  List<Sm20AdvanceCandidate> source, {
  Sm20AdvanceScope scope = Sm20AdvanceScope.topics,
  int horizonDays = kSm20AdvanceDefaultDays,
  Sm20Prng? prng,
}) => const Sm20AdvanceEngine().run(
  source: source,
  scope: scope,
  horizonDays: horizonDays,
  today: _day(100),
  prng: prng ?? Sm20Prng(seed: 0x12345678),
);

Sm20AdvanceCandidate _candidate(
  String id, {
  ElementType type = ElementType.source,
  bool memorized = true,
  int interval = 100,
  int? lastReview = 10,
}) => Sm20AdvanceCandidate(
  ref: ElementRef(id: id, type: type),
  isMemorized: memorized,
  storedInterval: interval,
  lastReviewDay: lastReview == null ? null : _day(lastReview),
);

StudyDay _day(int epochDay) => const StudyDay(
  year: 1970,
  month: 1,
  day: 1,
  zoneId: 'UTC',
).addDays(epochDay);
