/// Parameter construction: clipping, validation, migration from older FSRS
/// versions, and the empty card.
///
/// A parameter vector arriving from an optimizer, a user, or an older release
/// is not trusted: it is clipped into the region FSRS-6 was fitted on before it
/// can reach a formula.
library;

import 'dart:math' as math;

import 'constant.dart';
import 'convert.dart';
import 'error.dart';
import 'help.dart';
import 'js_compat.dart';
import 'models.dart';

/// Clips [parameters] element-wise into the FSRS-6 clamp table.
///
/// With more than one relearning step the ceiling on `w[17]` and `w[18]` is
/// tightened, so that post-lapse stability multiplied by the short-term boost
/// of every relearning step still cannot exceed the stability it started from.
List<double> clipParameters(
  List<double> parameters,
  int numRelearningSteps, [
  bool enableShortTerm = defaultEnableShortTerm,
]) {
  final clip = clampParameters(w17W18Ceiling, enableShortTerm)
      .take(parameters.length)
      .toList();
  if (math.max(0, numRelearningSteps) > 1) {
    // PLS = w11 * D ^ -w12 * [(S + 1) ^ w13 - 1] * e ^ (w14 * (1 - R))
    // PLS * e ^ (num_relearning_steps * w17 * w18) should be <= S.
    // With D = 1, R = 0.7, S = 1 this reduces to
    //   w17 * w18 <= -[ln(w11) + ln(2 ^ w13 - 1) + w14 * 0.3] / steps
    // Clamp w11/w13/w14 first so log() never receives <= 0.
    final w11 = clamp(_at(parameters, 11), clip[11][0], clip[11][1]);
    final w13 = clamp(_at(parameters, 13), clip[13][0], clip[13][1]);
    final w14 = clamp(_at(parameters, 14), clip[14][0], clip[14][1]);
    final value =
        -(math.log(w11) + math.log(math.pow(2.0, w13) - 1.0) + w14 * 0.3) /
            numRelearningSteps;

    // sqrt turns the product constraint into a per-parameter ceiling, so each
    // one individually satisfies the bound.
    final ceiling = clamp(
      roundTo(math.sqrt(math.max(value, 0)), 8),
      0.01,
      w17W18Ceiling,
    );
    if (clip.length > 17) clip[17] = <double>[clip[17][0], ceiling];
    if (clip.length > 18) clip[18] = <double>[clip[18][0], ceiling];
  }
  return <double>[
    for (var i = 0; i < clip.length; i++)
      clamp(_at(parameters, i), clip[i][0], clip[i][1]),
  ];
}

double _at(List<double> parameters, int index) =>
    index < parameters.length ? jsNumOrZero(parameters[index]) : 0.0;

/// Returns [parameters] unchanged, or throws if the vector cannot be used.
///
/// FSRS v4, v5 and v6 have 17, 19 and 21 weights respectively; anything else is
/// a mistake rather than something to migrate.
List<double> checkParameters(List<double> parameters) {
  for (final param in parameters) {
    if (!param.isFinite) {
      throw FSRSValidationError(
        'Non-finite or NaN value in parameters $parameters',
      );
    }
  }
  if (parameters.length != 17 &&
      parameters.length != 19 &&
      parameters.length != 21) {
    throw FSRSValidationError(
      'Invalid parameter length: ${parameters.length}. '
      'Must be 17, 19 or 21 for FSRSv4, 5 and 6 respectively.',
    );
  }
  return parameters;
}

/// Brings a v4 (17), v5 (19) or v6 (21) vector up to 21 clipped weights.
///
/// An unrecognised length falls back to the defaults rather than throwing, so
/// that a corrupted stored vector degrades to a working scheduler; use
/// [checkParameters] first when a mistake should be loud.
List<double> migrateParameters(
  List<double>? parameters, [
  int numRelearningSteps = 0,
  bool enableShortTerm = defaultEnableShortTerm,
]) {
  if (parameters == null) {
    return List<double>.of(defaultW);
  }
  switch (parameters.length) {
    case 21:
      return clipParameters(
        List<double>.of(parameters),
        numRelearningSteps,
        enableShortTerm,
      );
    case 19:
      return <double>[
        ...clipParameters(
          List<double>.of(parameters),
          numRelearningSteps,
          enableShortTerm,
        ),
        0.0,
        fsrs5DefaultDecay,
      ];
    case 17:
      final w = clipParameters(
        List<double>.of(parameters),
        numRelearningSteps,
        enableShortTerm,
      );
      w[4] = jsToFixedNumber(w[5] * 2.0 + w[4], 8);
      w[5] = jsToFixedNumber(math.log(w[5] * 3.0 + 1.0) / 3.0, 8);
      w[6] = jsToFixedNumber(w[6] + 0.5, 8);
      return <double>[...w, 0.0, 0.0, 0.0, fsrs5DefaultDecay];
    default:
      return List<double>.of(defaultW);
  }
}

/// Builds a complete parameter set, filling in defaults and migrating [w].
///
/// Anything left null takes its default, which is also what happens to a value
/// of zero for [requestRetention] and [maximumInterval] — upstream uses `||`
/// there, and a zero would be nonsense in either case.
FSRSParameters generatorParameters({
  double? requestRetention,
  int? maximumInterval,
  List<double>? w,
  bool? enableFuzz,
  bool? enableShortTerm,
  List<String>? learningSteps,
  List<String>? relearningSteps,
}) {
  final steps = learningSteps ?? List<String>.of(defaultLearningSteps);
  final relearnSteps = relearningSteps ?? List<String>.of(defaultRelearningSteps);
  final shortTerm = enableShortTerm ?? defaultEnableShortTerm;
  final weights = migrateParameters(w, relearnSteps.length, shortTerm);

  return FSRSParameters(
    requestRetention: (requestRetention == null || requestRetention == 0)
        ? defaultRequestRetention
        : requestRetention,
    maximumInterval: (maximumInterval == null || maximumInterval == 0)
        ? defaultMaximumInterval
        : maximumInterval,
    w: weights,
    enableFuzz: enableFuzz ?? defaultEnableFuzz,
    enableShortTerm: shortTerm,
    learningSteps: List<String>.of(steps),
    relearningSteps: List<String>.of(relearnSteps),
  );
}

/// Creates an unstudied card due at [now] (defaults to the current instant).
Card createEmptyCard([Object? now]) =>
    Card.empty(now == null ? DateTime.now() : TypeConvert.time(now));
