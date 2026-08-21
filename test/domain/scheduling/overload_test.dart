/// The overload valve: manual Later, auto-postpone, and Mercy.
library;

import 'package:incremental_reader/src/domain/scheduling/deterministic_random.dart';
import 'package:incremental_reader/src/domain/scheduling/overload.dart';
import 'package:incremental_reader/src/domain/settings/app_settings.dart';
import 'package:test/test.dart';

void main() {
  const OverloadValve valve = OverloadValve();

  group('manual Later', () {
    test('scales with the element’s own interval', () {
      final int short = valve
          .later(intervalDays: 2, seed: 'op:e1')
          .delayDays;
      final int long = valve
          .later(intervalDays: 365, seed: 'op:e1')
          .delayDays;

      expect(short, inInclusiveRange(1, 1));
      expect(
        long,
        inInclusiveRange(36, 110),
        reason: '10–30% of a year, not a flat day',
      );
    });

    test('never returns the element the same day', () {
      for (var i = 0; i < 50; i++) {
        expect(
          valve.later(intervalDays: 0, seed: 'op:$i').delayDays,
          greaterThanOrEqualTo(1),
        );
      }
    });

    test('is deterministic, so a retried command lands on the same date', () {
      expect(
        valve.later(intervalDays: 30, seed: 'op-7:extract:x1').delayDays,
        valve.later(intervalDays: 30, seed: 'op-7:extract:x1').delayDays,
      );
    });

    test('is clamped', () {
      expect(
        valve.later(intervalDays: 100000, seed: 's').delayDays,
        lessThanOrEqualTo(365),
      );
    });
  });

  group('auto-postpone', () {
    test('pushes the bottom of the collection several times further than '
        'the top', () {
      // Dispersal off and a long interval, so the ratio is the priority
      // multiplier itself rather than the multiplier plus rounding.
      const OverloadValve exact = OverloadValve(
        settings: PostponeSettings(autoDispersal: 0),
      );
      final int top = exact
          .autoPostpone(intervalDays: 300, pressure: 0, seed: 'a')
          .delayDays;
      final int bottom = exact
          .autoPostpone(intervalDays: 300, pressure: 1, seed: 'a')
          .delayDays;
      expect(top, 30);
      expect(bottom, 150);
      expect(bottom / top, closeTo(5, 1e-9));
    });

    test('is proportional to the interval, so young elements are not lost', () {
      final int young = valve
          .autoPostpone(intervalDays: 2, pressure: 0.5, seed: 'b')
          .delayDays;
      final int mature = valve
          .autoPostpone(intervalDays: 365, pressure: 0.5, seed: 'b')
          .delayDays;
      expect(young, lessThan(5));
      expect(mature, greaterThan(50));
    });

    test('disperses, so a day’s overflow does not re-clump on one date', () {
      final Set<int> days = <int>{
        for (var i = 0; i < 40; i++)
          valve
              .autoPostpone(intervalDays: 60, pressure: 0.5, seed: 'day:e$i')
              .delayDays,
      };
      expect(
        days.length,
        greaterThan(3),
        reason: 'without dispersal every element lands on the same future day',
      );
    });

    test('dispersal can be switched off for a fully predictable delay', () {
      const OverloadValve exact = OverloadValve(
        settings: PostponeSettings(autoDispersal: 0),
      );
      final Set<int> days = <int>{
        for (var i = 0; i < 20; i++)
          exact
              .autoPostpone(intervalDays: 60, pressure: 0.5, seed: 'e$i')
              .delayDays,
      };
      expect(days, hasLength(1));
    });

    test('reports the inputs it used, so the arithmetic can be audited', () {
      final PostponeDecision decision = valve.autoPostpone(
        intervalDays: 10,
        pressure: 0.25,
        seed: 'audit',
      );
      final Map<String, Object?> metadata = decision.toMetadata();
      expect(metadata['pressure'], 0.25);
      expect(metadata['base_days'], 1);
      expect(metadata['delay_days'], decision.delayDays);
    });
  });

  group('Mercy', () {
    test('lands the top of a backlog within days and the tail months out', () {
      const OverloadValve spread = OverloadValve(
        settings: PostponeSettings(mercyHorizonDays: 14, mercyDailyCap: 10),
      );

      expect(spread.mercyDelayDays(0), 1);
      expect(spread.mercyDelayDays(9), 1);
      expect(spread.mercyDelayDays(10), 2);
      expect(spread.mercyDelayDays(139), 14);
      // Past the horizon, worst priority furthest.
      expect(spread.mercyDelayDays(200), greaterThan(15));
      expect(
        spread.mercyDelayDays(1000),
        greaterThan(spread.mercyDelayDays(200)),
      );
    });

    test('never schedules anything for today', () {
      for (var i = 0; i < 200; i++) {
        expect(valve.mercyDelayDays(i), greaterThanOrEqualTo(1));
      }
    });

    test('is monotonic in backlog position', () {
      var previous = 0;
      for (var i = 0; i < 500; i += 7) {
        final int delay = valve.mercyDelayDays(i);
        expect(delay, greaterThanOrEqualTo(previous));
        previous = delay;
      }
    });
  });

  group('deterministic randomness', () {
    test('the hash is stable, not Dart’s per-run hashCode', () {
      expect(stableHash('queue:UTC:2026-03-05'), stableHash('queue:UTC:2026-03-05'));
      expect(stableHash('a'), isNot(stableHash('b')));
      expect(stableHash(''), isNonNegative);
    });

    test('draws are reproducible per seed and key', () {
      final DeterministicRandom a = DeterministicRandom('day-1');
      final DeterministicRandom b = DeterministicRandom('day-1');
      final DeterministicRandom c = DeterministicRandom('day-2');

      expect(a.unit('e1'), b.unit('e1'));
      expect(a.unit('e1'), isNot(c.unit('e1')));
      expect(a.unit('e1'), isNot(a.unit('e2')));
    });

    test('draws stay inside their range', () {
      final DeterministicRandom random = DeterministicRandom('range');
      for (var i = 0; i < 200; i++) {
        expect(random.unit('k$i'), inInclusiveRange(0, 1));
        expect(random.symmetric('k$i', 0.05), inInclusiveRange(-0.05, 0.05));
        expect(random.between('k$i', 2, 5), inInclusiveRange(2, 5));
      }
    });
  });
}
