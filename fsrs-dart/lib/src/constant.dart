/// The FSRS-6 constants: default parameters, default steps, and the clamp
/// table that keeps a supplied parameter vector inside the region the model was
/// fitted on.
///
/// Values are copied verbatim from ts-fsrs 5.4.1 (`src/constant.ts`); changing
/// one silently reinterprets every schedule written under the old value.
library;

/// Package version, mirroring the ts-fsrs release this port tracks.
const String tsFsrsVersion = '5.4.1';

/// Default target retention.
const double defaultRequestRetention = 0.9;

/// Default ceiling on a scheduled interval, in days.
const int defaultMaximumInterval = 36500;

/// Fuzz is off by default: identical inputs must give identical schedules.
const bool defaultEnableFuzz = false;

/// Short-term (learning-step) scheduling is on by default.
const bool defaultEnableShortTerm = true;

/// New -> Learning, Learning -> Learning.
const List<String> defaultLearningSteps = <String>['1m', '10m'];

/// Relearning -> Relearning.
const List<String> defaultRelearningSteps = <String>['10m'];

/// The version banner ts-fsrs exposes.
const String fsrsVersion = 'v$tsFsrsVersion using FSRS-6.0';

/// Lower bound on stability, in days.
const double sMin = 0.001;

/// Upper bound on stability, in days.
const double sMax = 36500.0;

/// Upper bound on an *initial* stability, in days.
const double initSMax = 100.0;

/// The decay FSRS-5 used, still the fallback when migrating short vectors.
const double fsrs5DefaultDecay = 0.5;

/// The default FSRS-6 decay (`w[20]`).
const double fsrs6DefaultDecay = 0.1542;

/// The default FSRS-6 weight vector.
const List<double> defaultW = <double>[
  0.212,
  1.2931,
  2.3065,
  8.2956,
  6.4133,
  0.8334,
  3.0194,
  0.001,
  1.8722,
  0.1666,
  0.796,
  1.4835,
  0.0614,
  0.2629,
  1.6483,
  0.6014,
  1.8729,
  0.5425,
  0.0912,
  0.0658,
  fsrs6DefaultDecay,
];

/// The nominal ceiling on `w[17]` and `w[18]`.
const double w17W18Ceiling = 2.0;

/// Per-parameter `[min, max]` clamps, in weight order.
///
/// [w17w18Ceiling] is lowered by `clipParameters` when there is more than one
/// relearning step, so that repeated short-term boosts cannot exceed the
/// stability they are boosting. [enableShortTerm] only moves the floor of
/// `w[19]`: with short-term scheduling on, the last-stability exponent may not
/// be exactly zero.
List<List<double>> clampParameters(
  double w17w18Ceiling, [
  bool enableShortTerm = defaultEnableShortTerm,
]) =>
    <List<double>>[
      <double>[sMin, initSMax], // initial stability (Again)
      <double>[sMin, initSMax], // initial stability (Hard)
      <double>[sMin, initSMax], // initial stability (Good)
      <double>[sMin, initSMax], // initial stability (Easy)
      <double>[1.0, 10.0], // initial difficulty (Good)
      <double>[0.001, 4.0], // initial difficulty (multiplier)
      <double>[0.001, 4.0], // difficulty (multiplier)
      <double>[0.001, 0.75], // difficulty (multiplier)
      <double>[0.0, 4.5], // stability (exponent)
      <double>[0.0, 0.8], // stability (negative power)
      <double>[0.001, 3.5], // stability (exponent)
      <double>[0.001, 5.0], // fail stability (multiplier)
      <double>[0.001, 0.25], // fail stability (negative power)
      <double>[0.001, 0.9], // fail stability (power)
      <double>[0.0, 4.0], // fail stability (exponent)
      <double>[0.0, 1.0], // stability (multiplier for Hard)
      <double>[1.0, 6.0], // stability (multiplier for Easy)
      <double>[0.0, w17w18Ceiling], // short-term stability (exponent)
      <double>[0.0, w17w18Ceiling], // short-term stability (exponent)
      <double>[
        enableShortTerm ? 0.01 : 0.0,
        0.8,
      ], // short-term last-stability (exponent)
      <double>[0.1, 0.8], // decay
    ];
