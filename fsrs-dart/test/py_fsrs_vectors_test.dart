/// Cross-check against py-fsrs 6.3.2, the reference implementation of FSRS-6.
///
/// The ts-fsrs vectors prove this port is identical to the library it was
/// ported from; these prove that library implements the same FSRS-6 as the
/// Python reference, so a faithful port of a wrong formula would still fail
/// here.
///
/// Two deliberate, documented differences keep the comparison honest:
///
/// * ts-fsrs rounds every intermediate result to 8 decimal places and py-fsrs
///   does not, so values are compared to a relative tolerance rather than
///   bit-for-bit. The tolerance is far tighter than any scheduling decision.
/// * The two libraries do not share a card lifecycle (py-fsrs has no `New`
///   state, and orders review-state intervals differently), so what is compared
///   here is the algorithm — memory state and the primitives — not the
///   lifecycle. Lifecycle behaviour is pinned by the ts-fsrs vectors.
library;

import 'dart:math' as math;

import 'package:fsrs_dart/fsrs.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

/// Relative tolerance covering ts-fsrs's 8-decimal rounding, compounded over a
/// review sequence.
Matcher _closeToRelative(double expected, {double relative = 1e-6}) =>
    // The absolute floor is half a unit in the eighth decimal place, which is
    // the most ts-fsrs's rounding can move a value.
    closeTo(expected, math.max(5e-9, expected.abs() * relative));

void main() {
  final vectors = loadVectors('py_fsrs_v6_vectors.json');
  final algorithm = FSRSAlgorithm(null);
  final primitives = vectors['primitives']! as Map<String, Object?>;

  test('shares the FSRS-6 default parameters', () {
    expect(algorithm.parameters.w, doubles(vectors['parameters']));
    expect(defaultW, doubles(vectors['parameters']));
  });

  test('shares the decay and factor', () {
    final decayFactor = computeDecayFactor(algorithm.parameters.w);
    expect(decayFactor.decay, _closeToRelative(vectors['decay']! as double));
    expect(decayFactor.factor, _closeToRelative(vectors['factor']! as double));
  });

  test('initial stability', () {
    for (final entry in primitives['initial_stability']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final grade = Rating.fromValue((row['rating']! as num).toInt());
      expect(
        algorithm.initStability(grade),
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
  });

  test('initial difficulty', () {
    for (final entry in primitives['initial_difficulty']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final grade = Rating.fromValue((row['rating']! as num).toInt());
      expect(
        clamp(algorithm.initDifficulty(grade), 1, 10),
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
    for (final entry
        in primitives['initial_difficulty_unclamped']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final grade = Rating.fromValue((row['rating']! as num).toInt());
      expect(
        algorithm.initDifficulty(grade),
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
  });

  test('next difficulty', () {
    for (final entry in primitives['next_difficulty']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      expect(
        algorithm.nextDifficulty(
          (row['difficulty']! as num).toDouble(),
          Rating.fromValue((row['rating']! as num).toInt()),
        ),
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
  });

  test('short-term stability', () {
    for (final entry in primitives['short_term_stability']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      expect(
        algorithm.nextShortTermStability(
          (row['stability']! as num).toDouble(),
          Rating.fromValue((row['rating']! as num).toInt()),
        ),
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
  });

  test('stability after recall', () {
    for (final entry
        in primitives['next_recall_stability']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      // py-fsrs 6.3.2 floors stability at 0.001 but sets no ceiling, while
      // ts-fsrs also caps it at 36500 days. The cap only bites at a century of
      // stability, which no schedule reaches; apply it so the comparison is
      // about the formula rather than about the bound.
      final expected =
          math.min((row['value']! as num).toDouble(), sMax);
      expect(
        algorithm.nextRecallStability(
          (row['difficulty']! as num).toDouble(),
          (row['stability']! as num).toDouble(),
          (row['retrievability']! as num).toDouble(),
          Rating.fromValue((row['rating']! as num).toInt()),
        ),
        _closeToRelative(expected),
        reason: '$row',
      );
    }
  });

  test('stability after a lapse', () {
    // py-fsrs folds the short-term ceiling into `_next_forget_stability`;
    // ts-fsrs applies it one level up, in `next_state`. Compose it here so the
    // two are comparable.
    final w = algorithm.parameters.w;
    for (final entry
        in primitives['next_forget_stability']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final s = (row['stability']! as num).toDouble();
      final longTerm = algorithm.nextForgetStability(
        (row['difficulty']! as num).toDouble(),
        s,
        (row['retrievability']! as num).toDouble(),
      );
      final shortTermCeiling = s / math.exp(w[17] * w[18]);
      final actual = clamp(roundTo(shortTermCeiling, 8), sMin, longTerm);
      expect(
        actual,
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
  });

  test('next interval', () {
    for (final entry in primitives['next_interval']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final instance = FSRSAlgorithm(
        generatorParameters(
          requestRetention: (row['desired_retention']! as num).toDouble(),
        ),
      );
      expect(
        instance.nextInterval((row['stability']! as num).toDouble(), 0),
        (row['value']! as num).toInt(),
        reason: '$row',
      );
    }
  });

  test('retrievability', () {
    for (final entry in primitives['retrievability']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      expect(
        algorithm.forgettingCurve(
          (row['elapsed_days']! as num).toDouble(),
          (row['stability']! as num).toDouble(),
        ),
        _closeToRelative((row['value']! as num).toDouble()),
        reason: '$row',
      );
    }
  });

  group('review sequences', () {
    final start = DateTime.parse(vectors['start']! as String);
    for (final entry in vectors['sequences']! as List<Object?>) {
      final sequence = entry! as Map<String, Object?>;
      final label = sequence['label']! as String;

      test('$label tracks the same memory state', () {
        final scheduler = fsrs();
        var card = createEmptyCard(start);
        var now = start;

        final reviews = sequence['reviews']! as List<Object?>;
        for (var i = 0; i < reviews.length; i++) {
          final review = reviews[i]! as Map<String, Object?>;
          final offset = (review['offset_days']! as num).toInt();
          now = now.add(Duration(days: offset));

          expect(
            scheduler.getRetrievability(card, now),
            _closeToRelative(
              (review['retrievability_before']! as num).toDouble(),
            ),
            reason: '$label review $i: retrievability before',
          );

          final result = scheduler.next(
            card,
            now,
            Rating.fromValue((review['rating']! as num).toInt()),
          );
          card = result.card;

          expect(
            card.stability,
            _closeToRelative((review['stability']! as num).toDouble()),
            reason: '$label review $i: stability',
          );
          expect(
            card.difficulty,
            _closeToRelative((review['difficulty']! as num).toDouble()),
            reason: '$label review $i: difficulty',
          );
          expect(
            scheduler.nextInterval(card.stability, 0),
            (review['next_interval']! as num).toInt(),
            reason: '$label review $i: next interval',
          );
        }
      });
    }
  });
}
