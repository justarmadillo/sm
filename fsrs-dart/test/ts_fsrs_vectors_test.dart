/// Identity check against ts-fsrs 5.4.1.
///
/// Every expectation in this file was produced by running the reference
/// implementation itself (see `tool/gen_ts_vectors.mts`), so a failure here
/// means the port diverged — not that a hand-copied number was mistyped.
/// Comparisons are exact: doubles must match bit for bit, not approximately.
library;

import 'package:fsrs_dart/fsrs.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vectors = loadVectors('ts_fsrs_vectors.json');

  group('walks', () {
    final walks = vectors['walks']! as List<Object?>;
    for (final entry in walks) {
      final walk = entry! as Map<String, Object?>;
      final name = walk['name']! as String;

      test('$name reproduces every scheduled card, log and seed', () {
        final params = walk['params']! as Map<String, Object?>;
        final scheduler = fsrs(
          requestRetention: (params['request_retention'] as num?)?.toDouble(),
          maximumInterval: (params['maximum_interval'] as num?)?.toInt(),
          w: params['w'] == null ? null : doubles(params['w']),
          enableFuzz: params['enable_fuzz'] as bool?,
          enableShortTerm: params['enable_short_term'] as bool?,
          learningSteps: params['learning_steps'] == null
              ? null
              : strings(params['learning_steps']),
          relearningSteps: params['relearning_steps'] == null
              ? null
              : strings(params['relearning_steps']),
        );

        final resolved = walk['resolved_parameters']! as Map<String, Object?>;
        expect(
          scheduler.parameters.requestRetention,
          resolved['request_retention'],
          reason: 'request_retention',
        );
        expect(scheduler.parameters.maximumInterval,
            resolved['maximum_interval']);
        expect(scheduler.parameters.w, doubles(resolved['w']));
        expect(scheduler.parameters.enableFuzz, resolved['enable_fuzz']);
        expect(
          scheduler.parameters.enableShortTerm,
          resolved['enable_short_term'],
        );
        expect(
          scheduler.parameters.learningSteps,
          strings(resolved['learning_steps']),
        );
        expect(
          scheduler.parameters.relearningSteps,
          strings(resolved['relearning_steps']),
        );
        expect(scheduler.intervalModifier, walk['interval_modifier']);

        // Capture the seed the default strategy derives, without changing it.
        final seeds = <String>[];
        scheduler.useStrategy(StrategyMode.seed, (SchedulerContext context) {
          final seed = defaultInitSeedStrategy(context);
          seeds.add(seed);
          return seed;
        });

        var card = cardFromVector(
          (walk['steps']! as List<Object?>).isEmpty
              ? <String, Object?>{}
              : ((walk['steps']! as List<Object?>).first!
                      as Map<String, Object?>)['card_before']!
                  as Map<String, Object?>,
        );

        final steps = walk['steps']! as List<Object?>;
        for (var i = 0; i < steps.length; i++) {
          final step = steps[i]! as Map<String, Object?>;
          final now = DateTime.parse(step['now']! as String);
          final grade = Rating.fromValue((step['grade']! as num).toInt());

          expect(
            serializeCard(card),
            step['card_before'],
            reason: '$name step $i: card before review',
          );

          expect(
            scheduler.getRetrievability(card, now),
            step['retrievability'],
            reason: '$name step $i: retrievability',
          );
          expect(
            scheduler.getRetrievabilityFormatted(card, now),
            step['retrievability_text'],
            reason: '$name step $i: retrievability text',
          );

          seeds.clear();
          final preview = scheduler.repeat(card, now);
          final expectedPreview = step['preview']! as Map<String, Object?>;
          for (final g in grades) {
            final expected =
                expectedPreview['${g.value}']! as Map<String, Object?>;
            expect(
              serializeCard(preview[g].card),
              expected['card'],
              reason: '$name step $i: ${g.name} card',
            );
            expect(
              serializeLog(preview[g].log),
              expected['log'],
              reason: '$name step $i: ${g.name} log',
            );
          }
          expect(seeds.first, step['seed'], reason: '$name step $i: seed');

          final chosen = preview[grade];
          expect(
            serializeCard(scheduler.rollback(chosen.card, chosen.log)),
            step['rollback'],
            reason: '$name step $i: rollback',
          );

          final forgotten = scheduler.forget(chosen.card, now);
          final expectedForget = step['forget']! as Map<String, Object?>;
          expect(serializeCard(forgotten.card), expectedForget['card'],
              reason: '$name step $i: forget card');
          expect(serializeLog(forgotten.log), expectedForget['log'],
              reason: '$name step $i: forget log');

          final forgottenReset =
              scheduler.forget(chosen.card, now, resetCount: true);
          final expectedForgetReset =
              step['forget_reset']! as Map<String, Object?>;
          expect(
            serializeCard(forgottenReset.card),
            expectedForgetReset['card'],
            reason: '$name step $i: forget(reset) card',
          );
          expect(
            serializeLog(forgottenReset.log),
            expectedForgetReset['log'],
            reason: '$name step $i: forget(reset) log',
          );

          // `next` must agree with the preview it came from.
          final single = scheduler.next(card, now, grade);
          expect(serializeCard(single.card), serializeCard(chosen.card));
          expect(serializeLog(single.log), serializeLog(chosen.log));

          card = chosen.card;
        }
      });
    }
  });

  group('algorithm primitives', () {
    final primitives = vectors['primitives']! as Map<String, Object?>;
    final algorithm = FSRSAlgorithm(null);

    test('init_stability', () {
      for (final entry in primitives['init_stability']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        final grade = Rating.fromValue((row['grade']! as num).toInt());
        expect(algorithm.initStability(grade), row['value']);
      }
    });

    test('init_difficulty', () {
      for (final entry in primitives['init_difficulty']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        final grade = Rating.fromValue((row['grade']! as num).toInt());
        expect(algorithm.initDifficulty(grade), row['value']);
      }
    });

    test('next_difficulty', () {
      for (final entry in primitives['next_difficulty']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          algorithm.nextDifficulty(
            (row['difficulty']! as num).toDouble(),
            Rating.fromValue((row['grade']! as num).toInt()),
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('linear_damping', () {
      for (final entry in primitives['linear_damping']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          algorithm.linearDamping(
            (row['delta_d']! as num).toDouble(),
            (row['old_d']! as num).toDouble(),
          ),
          row['value'],
        );
      }
    });

    test('mean_reversion', () {
      for (final entry in primitives['mean_reversion']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          algorithm.meanReversion(
            (row['init']! as num).toDouble(),
            (row['current']! as num).toDouble(),
          ),
          row['value'],
        );
      }
    });

    test('next_recall_stability', () {
      for (final entry
          in primitives['next_recall_stability']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          algorithm.nextRecallStability(
            (row['difficulty']! as num).toDouble(),
            (row['stability']! as num).toDouble(),
            (row['retrievability']! as num).toDouble(),
            Rating.fromValue((row['grade']! as num).toInt()),
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('next_forget_stability', () {
      for (final entry
          in primitives['next_forget_stability']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          algorithm.nextForgetStability(
            (row['difficulty']! as num).toDouble(),
            (row['stability']! as num).toDouble(),
            (row['retrievability']! as num).toDouble(),
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('next_short_term_stability', () {
      for (final entry
          in primitives['next_short_term_stability']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          algorithm.nextShortTermStability(
            (row['stability']! as num).toDouble(),
            Rating.fromValue((row['grade']! as num).toInt()),
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('next_state', () {
      for (final entry in primitives['next_state']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        final expected = row['value']! as Map<String, Object?>;
        final state = algorithm.nextState(
          FSRSState(
            stability: (row['stability']! as num).toDouble(),
            difficulty: (row['difficulty']! as num).toDouble(),
          ),
          (row['elapsed_days']! as num).toDouble(),
          Rating.fromValue((row['grade']! as num).toInt()),
        );
        expect(state.stability, expected['stability'], reason: '$row');
        expect(state.difficulty, expected['difficulty'], reason: '$row');
      }
    });

    test('forgetting_curve', () {
      for (final entry in primitives['forgetting_curve']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          forgettingCurve(
            defaultW,
            (row['elapsed_days']! as num).toDouble(),
            (row['stability']! as num).toDouble(),
          ),
          row['value'],
          reason: '$row',
        );
        expect(
          algorithm.forgettingCurve(
            (row['elapsed_days']! as num).toDouble(),
            (row['stability']! as num).toDouble(),
          ),
          row['value'],
        );
      }
    });

    test('next_interval', () {
      for (final entry in primitives['next_interval']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        final instance = FSRSAlgorithm(
          generatorParameters(
            requestRetention: (row['request_retention']! as num).toDouble(),
          ),
        );
        expect(instance.intervalModifier, row['interval_modifier']);
        expect(
          instance.nextInterval((row['stability']! as num).toDouble(), 0),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('decay factor', () {
      for (final entry in primitives['decay_factor']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        final expected = row['value']! as Map<String, Object?>;
        final actual =
            computeDecayFactorFromDecay((row['decay']! as num).toDouble());
        expect(actual.decay, expected['decay']);
        expect(actual.factor, expected['factor']);
      }
    });
  });

  test('fuzz ranges', () {
    for (final entry in vectors['fuzz_ranges']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final expected = row['value']! as Map<String, Object?>;
      final range = getFuzzRange(
        (row['interval']! as num).toDouble(),
        (row['elapsed_days']! as num).toInt(),
        (row['maximum_interval']! as num).toInt(),
      );
      expect(range.minIvl, expected['min_ivl'], reason: '$row');
      expect(range.maxIvl, expected['max_ivl'], reason: '$row');
    }
  });

  test('alea reproduces the reference stream', () {
    for (final entry in vectors['alea']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final seed = row['seed']! as String;
      final prng = alea(seed);
      for (final expected in row['values']! as List<Object?>) {
        expect(prng.call(), expected, reason: 'alea($seed) stream');
      }
      for (final expected in row['int32s']! as List<Object?>) {
        expect(prng.int32(), expected, reason: 'alea($seed).int32');
      }
      for (final expected in row['doubles']! as List<Object?>) {
        expect(prng.double53(), expected, reason: 'alea($seed).double');
      }
      final expectedState = row['state']! as Map<String, Object?>;
      expect(prng.state.c, expectedState['c']);
      expect(prng.state.s0, expectedState['s0']);
      expect(prng.state.s1, expectedState['s1']);
      expect(prng.state.s2, expectedState['s2']);
    }
  });

  group('date helpers', () {
    final helpers = vectors['date_helpers']! as Map<String, Object?>;

    test('dateDiffInDays', () {
      for (final entry in helpers['date_diff_in_days']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          dateDiffInDays(
            DateTime.parse(row['last']! as String),
            DateTime.parse(row['cur']! as String),
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('date_diff', () {
      for (final entry in helpers['date_diff']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        final unit = row['unit'] == 'days'
            ? DateDiffUnit.days
            : DateDiffUnit.minutes;
        expect(
          dateDiff(
            DateTime.parse(row['now']! as String),
            DateTime.parse(row['pre']! as String),
            unit,
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('date_scheduler', () {
      final start = DateTime.parse(vectors['start']! as String);
      for (final entry in helpers['date_scheduler']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          iso(
            dateScheduler(
              start,
              (row['t']! as num),
              isDay: row['is_day']! as bool,
            ),
          ),
          row['value'],
          reason: '$row',
        );
      }
    });

    test('show_diff_message', () {
      final start = DateTime.parse(vectors['start']! as String);
      for (final entry in helpers['show_diff_message']! as List<Object?>) {
        final row = entry! as Map<String, Object?>;
        expect(
          showDiffMessage(
            DateTime.parse(row['due']! as String),
            start,
            unit: row['unit']! as bool,
          ),
          row['value'],
          reason: '$row',
        );
      }
    });
  });

  test('parameter migration and clipping', () {
    for (final entry in vectors['parameter_migration']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final input = doubles(row['input']);
      final steps = (row['relearning_steps']! as num).toInt();
      final shortTerm = row['short_term']! as bool;
      expect(
        migrateParameters(input, steps, shortTerm),
        doubles(row['migrated']),
        reason: '$row',
      );
      if (row['clipped'] != null) {
        expect(
          clipParameters(input, steps, shortTerm),
          doubles(row['clipped']),
          reason: '$row',
        );
      }
    }
  });

  test('step units', () {
    for (final entry in vectors['step_units']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      expect(
        convertStepUnitToMinutes(row['step']! as String),
        row['minutes'],
        reason: '$row',
      );
    }
  });

  test('learning step layouts', () {
    for (final entry in vectors['learning_step_layouts']! as List<Object?>) {
      final row = entry! as Map<String, Object?>;
      final params = generatorParameters(
        learningSteps: strings(row['learning_steps']),
        relearningSteps: strings(row['relearning_steps']),
      );
      final layout = basicLearningStepsStrategy(
        params,
        State.fromValue((row['state']! as num).toInt()),
        (row['cur_step']! as num).toInt(),
      );
      final expected = row['layout']! as Map<String, Object?>;
      expect(
        layout.length,
        expected.length,
        reason: 'layout size for $row',
      );
      expected.forEach((String key, Object? value) {
        final info = value! as Map<String, Object?>;
        final actual = layout[Rating.fromValue(int.parse(key))];
        expect(actual, isNotNull, reason: 'missing grade $key in $row');
        expect(actual!.scheduledMinutes, info['scheduled_minutes'],
            reason: '$row');
        expect(actual.nextStep, info['next_step'], reason: '$row');
      });
    }
  });

  group('reschedule', () {
    for (final entry in vectors['reschedule']! as List<Object?>) {
      final testCase = entry! as Map<String, Object?>;
      test('${testCase['name']}', () {
        final scheduler = fsrs();
        final reviews = <FSRSHistory>[
          for (final review in testCase['reviews']! as List<Object?>)
            FSRSHistory(
              rating: Rating.fromValue(
                ((review! as Map<String, Object?>)['rating']! as num).toInt(),
              ),
              review: DateTime.parse(
                (review as Map<String, Object?>)['review']! as String,
              ),
              due: review['due'] == null
                  ? null
                  : DateTime.parse(review['due']! as String),
              state: review['state'] == null
                  ? null
                  : State.fromValue((review['state']! as num).toInt()),
              stability: (review['stability'] as num?)?.toDouble(),
              difficulty: (review['difficulty'] as num?)?.toDouble(),
            ),
        ];

        final result = scheduler.reschedule(
          createEmptyCard(testCase['first_card_due']! as String),
          reviews: reviews,
          skipManual: testCase['skip_manual']! as bool,
          updateMemoryState: testCase['update_memory_state']! as bool,
          now: DateTime.parse(testCase['now']! as String),
          firstCard: createEmptyCard(testCase['first_card_due']! as String),
        );

        final expectedCollections =
            testCase['collections']! as List<Object?>;
        expect(result.collections.length, expectedCollections.length);
        for (var i = 0; i < expectedCollections.length; i++) {
          final expected = expectedCollections[i]! as Map<String, Object?>;
          expect(serializeCard(result.collections[i].card), expected['card'],
              reason: 'collection $i card');
          expect(serializeLog(result.collections[i].log), expected['log'],
              reason: 'collection $i log');
        }

        final expectedItem = testCase['reschedule_item'];
        if (expectedItem == null) {
          expect(result.rescheduleItem, isNull);
        } else {
          final expected = expectedItem as Map<String, Object?>;
          expect(serializeCard(result.rescheduleItem!.card), expected['card']);
          expect(serializeLog(result.rescheduleItem!.log), expected['log']);
        }
      });
    }
  });
}
