/// The overload valve: three distinct postponement mechanisms.
///
/// A collection is expected to exceed learning capacity — that is the normal
/// state of incremental reading, not an error — so something has to shed load.
/// Priority *sorts* the queue; it does not *shrink* it. This file is what
/// shrinks it, and it is deliberately three separate mechanisms because
/// conflating them is where the failure modes come from:
///
/// * **Manual Later** — the user says "wrong task right now". Delay scales
///   with the element's own interval, because a fixed +1 day just returns the
///   element tomorrow into an equally full queue.
/// * **Auto-postpone** — the day is over its cap, so the lowest-priority
///   excess is pushed out. Proportional to interval, graded by priority,
///   dispersed so the overflow does not re-clump on one future day.
/// * **Mercy** — a backlog after an absence, spread across a horizon in one
///   operation instead of being chewed one day at a time.
///
/// Every function here is pure and takes its randomness from a seeded
/// [DeterministicRandom], so a retried command lands on the same date as its
/// first attempt and the same backlog always spreads the same way.
///
/// What none of them may ever do: touch stability, difficulty, reps, the last
/// review instant, an interval, or an interval step. A postpone is not a
/// review. Overwriting the last review instant on a postpone destroys the
/// retention signal the whole schedule is built from.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../settings/app_settings.dart';
import 'deterministic_random.dart';

/// How far out one element is being pushed, and why.
@immutable
final class PostponeDecision {
  const PostponeDecision({
    required this.delayDays,
    required this.pressure,
    required this.baseDays,
    required this.dispersalFactor,
  });

  /// Whole days added to today. Never less than one: a postponement that
  /// leaves an element due today has postponed nothing.
  final int delayDays;

  /// Priority pressure used, `0` at the top of the collection.
  final double pressure;

  /// The delay before priority grading and dispersal.
  final double baseDays;

  /// The multiplier drawn from the dispersal band.
  final double dispersalFactor;

  /// Log-friendly form; carries the inputs so the arithmetic can be audited.
  Map<String, Object?> toMetadata() => <String, Object?>{
    'delay_days': delayDays,
    'pressure': pressure,
    'base_days': baseDays,
    'dispersal': dispersalFactor,
  };
}

/// Pure delay arithmetic for the three postponement mechanisms.
@immutable
final class OverloadValve {
  const OverloadValve({this.settings = const PostponeSettings()});

  final PostponeSettings settings;

  /// Delay for a manual Later on an element whose interval is
  /// [intervalDays].
  ///
  /// Scaling by the element's own interval is the point: "later" on a two-day
  /// topic and on a one-year card should not mean the same thing.
  PostponeDecision later({required double intervalDays, required String seed}) {
    final DeterministicRandom random = DeterministicRandom(seed);
    final double fraction = random.between(
      'later',
      settings.laterMinFraction,
      settings.laterMaxFraction,
    );
    final double raw = math.max(1, intervalDays) * fraction;
    final int days = _clampDays(raw.round(), settings.laterMaxDays);
    return PostponeDecision(
      delayDays: days,
      pressure: 0,
      baseDays: raw,
      dispersalFactor: fraction,
    );
  }

  /// Delay for one element the daily valve is shedding.
  ///
  /// Three properties matter and all three are visible in the formula: the
  /// delay is proportional to the interval, so young elements are not lost to
  /// the void while mature ones recede far; it is graded by priority, so
  /// bottom-decile material is pushed several times further than top; and it
  /// is dispersed, so a day's overflow does not land together and recreate
  /// the same overload on a single future day.
  PostponeDecision autoPostpone({
    required double intervalDays,
    required double pressure,
    required String seed,
  }) {
    final double p = pressure.isNaN ? 0.5 : pressure.clamp(0, 1);
    final DeterministicRandom random = DeterministicRandom(seed);
    final double dispersal = random.between(
      'dispersal',
      1 - settings.autoDispersal,
      1 + settings.autoDispersal,
    );
    final double base = math.max(
      1,
      math.max(1, intervalDays) * settings.autoBaseFraction,
    );
    final double raw =
        base * (1 + settings.autoPriorityMultiplier * p) * dispersal;
    return PostponeDecision(
      delayDays: _clampDays(raw.round(), settings.autoMaxDays),
      pressure: p,
      baseDays: base,
      dispersalFactor: dispersal,
    );
  }

  /// Days from today for the element at [index] of a priority-sorted backlog.
  ///
  /// The first [PostponeSettings.mercyDailyCap] elements land tomorrow, the
  /// next batch the day after, and so on until the horizon; the tail beyond
  /// it is pushed progressively further, worst priority furthest. That
  /// distribution *is* the correct outcome after a three-week absence, not
  /// damage control: the top of the backlog comes back within days and the
  /// bottom comes back in months.
  int mercyDelayDays(int index) {
    if (index < 0) return 1;
    final int cap = math.max(1, settings.mercyDailyCap);
    final int day = index ~/ cap;
    if (day <= settings.mercyHorizonDays) return math.max(1, day + 1);
    final int overflowRank = index - settings.mercyHorizonDays * cap;
    final int extra = (overflowRank / cap * 3).floor();
    return _clampDays(
      settings.mercyHorizonDays + 1 + extra,
      settings.autoMaxDays,
    );
  }

  int _clampDays(int days, int maximum) {
    if (days < 1) return 1;
    return days > maximum ? maximum : days;
  }
}
