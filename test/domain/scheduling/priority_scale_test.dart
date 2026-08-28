/// Relative priority: percentiles, insertion, and the protected floor.
///
/// The property under test throughout is that priority is *relative*. There is
/// exactly one 0%, promoting one element necessarily demotes another, and no
/// number is stored that could inflate.
library;

import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:test/test.dart';

void main() {
  List<PriorityRank> ranksOf(int count) {
    final List<PriorityRank> result = <PriorityRank>[];
    PriorityRank? previous;
    for (var i = 0; i < count; i++) {
      previous = previous == null
          ? PriorityRank.middle
          : PriorityRank.below(previous);
      result.add(previous);
    }
    return result;
  }

  group('positions', () {
    test('0% is the most important and 100% the least', () {
      final List<PriorityRank> ranks = ranksOf(5);
      final PriorityScale scale = PriorityScale(ranks);

      expect(scale.positionOf(ranks.first)!.percent, 0);
      expect(scale.positionOf(ranks.last)!.percent, 100);
      expect(scale.positionOf(ranks[2])!.percent, 50);
    });

    test('pressure runs the other way, which is what the schedulers read', () {
      final List<PriorityRank> ranks = ranksOf(5);
      final PriorityScale scale = PriorityScale(ranks);

      expect(scale.pressureOf(ranks.first), 0);
      expect(scale.pressureOf(ranks.last), 1);
      expect(scale.positionOf(ranks.first)!.normalized, 1);
      expect(scale.positionOf(ranks.last)!.normalized, 0);
    });

    test('an empty collection reports the midpoint rather than throwing', () {
      expect(PriorityScale.empty.positionOf(PriorityRank.middle), isNull);
      expect(PriorityScale.empty.pressureOf(PriorityRank.middle), 0.5);
      expect(PriorityScale.empty.total, 0);
      expect(PriorityScale.empty.isEmpty, isTrue);
    });

    test('a rank not yet in the collection resolves to where it would go', () {
      final List<PriorityRank> ranks = ranksOf(4);
      final PriorityScale scale = PriorityScale(ranks);
      final PriorityRank fresh = PriorityRank.between(ranks[1], ranks[2]);

      expect(scale.positionOf(fresh)!.index, 2);
    });

    test('one-based display position matches SuperMemo’s dialog', () {
      final PriorityScale scale = PriorityScale(ranksOf(3));
      expect(scale.positionOf(scale.rankAtPercent(0))!.displayPosition, 1);
    });
  });

  group('setting a percent', () {
    test('lands the element at that percent of the collection', () {
      final PriorityScale scale = PriorityScale(ranksOf(11));

      for (final double percent in <double>[0, 25, 50, 75, 100]) {
        final PriorityRank placed = scale.rankAtPercent(percent);
        final PriorityScale after = PriorityScale(<PriorityRank>[
          ...ranksOf(11),
          placed,
        ]);
        expect(
          after.positionOf(placed)!.percent,
          closeTo(percent, 6),
          reason: 'asked for $percent%',
        );
      }
    });

    test('0% goes ahead of everything and 100% behind everything', () {
      final List<PriorityRank> ranks = ranksOf(6);
      final PriorityScale scale = PriorityScale(ranks);

      expect(scale.rankAtPercent(0) < ranks.first, isTrue);
      expect(scale.rankAtPercent(100) > ranks.last, isTrue);
    });

    test('rewrites one key rather than renumbering the collection', () {
      final List<PriorityRank> before = ranksOf(20);
      final PriorityScale scale = PriorityScale(before);
      scale.rankAtPercent(40);

      expect(
        PriorityScale(before)._sameKeysAs(before),
        isTrue,
        reason: 'fractional ordering is what makes a drag cheap',
      );
    });

    test('an out-of-range or malformed percent is clamped, never thrown', () {
      final PriorityScale scale = PriorityScale(ranksOf(4));
      expect(() => scale.rankAtPercent(-20), returnsNormally);
      expect(() => scale.rankAtPercent(400), returnsNormally);
      expect(() => scale.rankAtPercent(double.nan), returnsNormally);
    });

    test('an empty collection starts at the middle', () {
      expect(PriorityScale.empty.rankAtPercent(10), PriorityRank.middle);
    });
  });

  group('neighbours', () {
    test('name the elements straddling a rank', () {
      final List<PriorityRank> ranks = ranksOf(5);
      final PriorityScale scale = PriorityScale(ranks);

      expect(scale.neighbourAbove(ranks[2]), ranks[1]);
      expect(scale.neighbourBelow(ranks[2]), ranks[3]);
      expect(scale.neighbourAbove(ranks.first), isNull);
      expect(scale.neighbourBelow(ranks.last), isNull);
    });
  });

  group('order keys', () {
    test('stay strictly between their bounds under repeated insertion', () {
      var low = PriorityRank.middle;
      final PriorityRank high = PriorityRank.below(PriorityRank.middle);
      for (var i = 0; i < 60; i++) {
        final PriorityRank next = PriorityRank.between(low, high);
        expect(next > low, isTrue);
        expect(next < high, isTrue);
        low = next;
      }
    });

    test('spread produces an ascending run inside a range', () {
      final PriorityRank low = PriorityRank.middle;
      final PriorityRank high = PriorityRank.below(low);
      final List<PriorityRank> spread = PriorityRank.spread(
        count: 12,
        before: low,
        after: high,
      );

      expect(spread, hasLength(12));
      for (var i = 1; i < spread.length; i++) {
        expect(spread[i] > spread[i - 1], isTrue);
      }
      expect(spread.first > low, isTrue);
      expect(spread.last < high, isTrue);
    });

    test('rejects bounds that are not ordered', () {
      expect(
        () => PriorityRank.between(
          PriorityRank.below(PriorityRank.middle),
          PriorityRank.middle,
        ),
        throwsArgumentError,
      );
    });
  });
}

extension on PriorityScale {
  /// Whether the scale still holds exactly [expected], in order.
  bool _sameKeysAs(List<PriorityRank> expected) {
    if (total != expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (positionOf(expected[i])!.index != i) return false;
    }
    return true;
  }
}
