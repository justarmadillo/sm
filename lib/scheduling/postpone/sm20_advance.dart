/// SM20's Advance command: pull a run of future work closer to today.
///
/// This file owns only the selection and draw arithmetic of section 8.5,
/// because that is the part where an inexact port silently diverges: the draw
/// is consumed *before* the rejection test, so an implementation that computes
/// `r` lazily produces a different global PRNG stream for every later feature.
/// The writes themselves belong to the two schedulers — a topic Advance is a
/// real forced bulk repetition, an item Advance is a low-level reschedule.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:meta/meta.dart';

/// Which record types one Advance run selects.
///
/// The masks are the executable's: bit 0 is a normal topic and bit 1 an item,
/// so [all] is exactly "topics plus items" — every other record type is
/// outside this command, not merely filtered out later.
enum Sm20AdvanceScope {
  topics(1),
  items(2),
  all(3);

  const Sm20AdvanceScope(this.typeMask);

  final int typeMask;

  bool includes(ElementType type) =>
      (1 << (type == ElementType.card ? 1 : 0)) & typeMask != 0;

  /// Lowest horizon the dialog accepts. Items need two days because their
  /// branch floors the resulting interval at 2.
  int get minimumDays => this == Sm20AdvanceScope.topics ? 1 : 2;
}

/// Largest horizon the Advance dialog accepts.
const int kSm20AdvanceMaximumDays = 500;

/// Default horizon the Advance dialog opens with.
const int kSm20AdvanceDefaultDays = 30;

/// One record offered to the Advance engine.
@immutable
final class Sm20AdvanceCandidate {
  const Sm20AdvanceCandidate({
    required this.ref,
    required this.isMemorized,
    required this.storedInterval,
    this.lastReviewDay,
  });

  final ElementRef ref;

  /// Only status 1 is advanced; pending and dismissed records are skipped
  /// before the draw, so they cannot perturb the stream either.
  final bool isMemorized;

  final int storedInterval;
  final StudyDay? lastReviewDay;

  bool get isItem => ref.type == ElementType.card;
}

/// What Advance decided for one record.
@immutable
final class Sm20AdvanceDecision {
  const Sm20AdvanceDecision({
    required this.ref,
    required this.isItem,
    required this.newInterval,
    required this.targetDay,
    required this.oldInterval,
  });

  final ElementRef ref;
  final bool isItem;

  /// Interval the forced topic repetition commits, or the item's day offset
  /// from its last review.
  final int newInterval;

  /// Day the element is scheduled on.
  final StudyDay targetDay;

  final int oldInterval;
}

/// Complete outcome of one Advance pass.
@immutable
final class Sm20AdvanceResult {
  const Sm20AdvanceResult({
    required this.scope,
    required this.horizonDays,
    required this.decisions,
    required this.considered,
    required this.randomDraws,
    required this.randomNumberState,
  });

  final Sm20AdvanceScope scope;
  final int horizonDays;
  final List<Sm20AdvanceDecision> decisions;

  /// Records that reached the draw, whether or not they were advanced.
  final int considered;

  final int randomDraws;
  final Sm20RandomNumberGeneratorState randomNumberState;
}

/// The exact selection and draw arithmetic of section 8.5.
final class Sm20AdvanceEngine {
  const Sm20AdvanceEngine();

  /// Evaluates [source] in its supplied order.
  ///
  /// [horizonDays] is the dialog's D. Exactly one PRNG value is drawn per
  /// draw-eligible record — including one that the `r >= old_interval` test
  /// then rejects, which is why the draw is taken before that test rather
  /// than after it.
  Sm20AdvanceResult run({
    required Iterable<Sm20AdvanceCandidate> source,
    required Sm20AdvanceScope scope,
    required int horizonDays,
    required StudyDay today,
    required Sm20RandomNumberGenerator randomNumbers,
  }) {
    if (horizonDays < scope.minimumDays ||
        horizonDays > kSm20AdvanceMaximumDays) {
      throw RangeError.range(
        horizonDays,
        scope.minimumDays,
        kSm20AdvanceMaximumDays,
        'horizonDays',
      );
    }
    final int drawsBefore = randomNumbers.drawCount;
    final List<Sm20AdvanceDecision> decisions = <Sm20AdvanceDecision>[];
    var considered = 0;

    for (final Sm20AdvanceCandidate candidate in source) {
      if (!scope.includes(candidate.ref.type)) continue;
      if (!candidate.isMemorized) continue;
      final StudyDay? last = candidate.lastReviewDay;
      // A record reviewed today is refused before the draw. The topic writer
      // refuses a future last-review value as well, but that record has
      // already consumed its draw by then — a corrupt row must not shift the
      // stream differently from the executable's.
      if (last == null || last == today) continue;
      final int oldInterval = candidate.storedInterval;
      if (oldInterval <= horizonDays) continue;

      considered += 1;
      var r = sm20RoundEven(randomNumbers.nextDouble() * horizonDays) + 1;
      if (candidate.isItem) {
        // The item branch aims at a day rather than an interval, then
        // re-expresses it as days since the last review with a floor of two.
        final StudyDay target = today.addDays(r);
        final int fromLastReview = last.daysUntil(target);
        r = fromLastReview < 2 ? 2 : fromLastReview;
      }
      if (r >= oldInterval) continue;

      decisions.add(
        Sm20AdvanceDecision(
          ref: candidate.ref,
          isItem: candidate.isItem,
          newInterval: r,
          targetDay: candidate.isItem ? last.addDays(r) : today.addDays(r),
          oldInterval: oldInterval,
        ),
      );
    }

    return Sm20AdvanceResult(
      scope: scope,
      horizonDays: horizonDays,
      decisions: List<Sm20AdvanceDecision>.unmodifiable(decisions),
      considered: considered,
      randomDraws: randomNumbers.drawCount - drawsBefore,
      randomNumberState: randomNumbers.state,
    );
  }
}
