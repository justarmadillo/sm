/// The FSRS-6 formulas: the forgetting curve, initial and next difficulty,
/// stability after recall, after a lapse, and after a same-day review.
///
/// Every constant is a weight, never a literal: a formula change is a new
/// algorithm version, and a schedule written under one set of weights must
/// never be reinterpreted under another.
///
/// See https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
library;

import 'dart:math' as math;

import 'alea.dart';
import 'constant.dart';
import 'default.dart';
import 'error.dart';
import 'help.dart';
import 'js_compat.dart';
import 'models.dart';

/// The decay/factor pair derived from `w[20]`.
class DecayFactor {
  /// Creates a decay/factor pair.
  const DecayFactor({required this.decay, required this.factor});

  /// `decay = -w[20]`.
  final double decay;

  /// `factor = e^(ln(0.9) / decay) - 1`.
  final double factor;

  @override
  String toString() => 'DecayFactor(decay: $decay, factor: $factor)';
}

/// Computes the decay and factor from a decay value directly.
DecayFactor computeDecayFactorFromDecay(double decayValue) {
  final decay = -decayValue;
  final factor = math.exp(math.pow(decay, -1) * math.log(0.9)) - 1.0;
  return DecayFactor(decay: decay, factor: roundTo(factor, 8));
}

/// Computes the decay and factor from a parameter vector, reading `w[20]`.
DecayFactor computeDecayFactor(List<double> parameters) =>
    computeDecayFactorFromDecay(parameters[20]);

/// Probability of recall `t` days after a review of a memory with [stability].
///
/// `R(t, S) = (1 + FACTOR * t / (9 * S)) ^ DECAY`, in the form ts-fsrs
/// evaluates it.
double forgettingCurveWithDecay(
  double decayValue,
  double elapsedDays,
  double stability,
) {
  final df = computeDecayFactorFromDecay(decayValue);
  return roundTo(
    math.pow(1 + (df.factor * elapsedDays) / stability, df.decay).toDouble(),
    8,
  );
}

/// [forgettingCurveWithDecay], reading the decay out of a parameter vector.
double forgettingCurve(
  List<double> parameters,
  double elapsedDays,
  double stability,
) =>
    forgettingCurveWithDecay(parameters[20], elapsedDays, stability);

/// The FSRS-6 algorithm: stateless formulas over a parameter set.
///
/// [FSRS] adds the card lifecycle on top; this class knows only about memory
/// states and intervals.
class FSRSAlgorithm {
  /// Builds the algorithm from a parameter set, filling in defaults.
  FSRSAlgorithm(FSRSParameters? params)
      : _param = params ?? generatorParameters() {
    _intervalModifier = calculateIntervalModifier(_param.requestRetention);
  }

  FSRSParameters _param;
  late double _intervalModifier;
  String? _seed;

  /// The multiplier that turns stability into an interval at the configured
  /// target retention.
  double get intervalModifier => _intervalModifier;

  /// The seed the fuzz generator will use for the next interval.
  set seed(String seed) => _seed = seed;

  /// The current seed, or null if none was set.
  String? get currentSeed => _seed;

  /// The live parameter set.
  ///
  /// Mutating the returned object directly does **not** re-derive the interval
  /// modifier; assign through [parameters], [requestRetention] or [w] instead.
  FSRSParameters get parameters => _param;

  /// Replaces the whole parameter set.
  ///
  /// The assignment order reproduces ts-fsrs exactly, including one quirk worth
  /// knowing: `w` is migrated against the *previous* relearning steps and
  /// short-term flag, because upstream's proxy sees the keys in object order
  /// and `w` comes before both. Migrating against the new values would clip
  /// `w[17]`/`w[18]` differently and silently change schedules.
  set parameters(FSRSParameters params) => applyParameters(params);

  /// Rebuilds the parameter set from the given fields, defaulting every field
  /// that is not supplied — this mirrors `fsrs.parameters = {...}` upstream,
  /// which is a replacement rather than a patch.
  void updateParameters({
    double? requestRetention,
    int? maximumInterval,
    List<double>? w,
    bool? enableFuzz,
    bool? enableShortTerm,
    List<String>? learningSteps,
    List<String>? relearningSteps,
  }) {
    applyParameters(
      generatorParameters(
        requestRetention: requestRetention,
        maximumInterval: maximumInterval,
        w: w,
        enableFuzz: enableFuzz,
        enableShortTerm: enableShortTerm,
        learningSteps: learningSteps,
        relearningSteps: relearningSteps,
      ),
    );
  }

  /// Applies a complete parameter set field by field, in upstream's order.
  void applyParameters(FSRSParameters params) {
    requestRetention = params.requestRetention;
    _param.maximumInterval = params.maximumInterval;
    // `w` is migrated against the not-yet-updated steps and short-term flag.
    w = params.w;
    enableFuzz = params.enableFuzz;
    enableShortTerm = params.enableShortTerm;
    learningSteps = params.learningSteps;
    relearningSteps = params.relearningSteps;
  }

  /// Sets the target retention and re-derives the interval modifier.
  set requestRetention(double value) {
    if (value.isFinite) {
      _intervalModifier = calculateIntervalModifier(value);
    }
    _param.requestRetention = value;
  }

  /// Sets the interval ceiling, in days.
  set maximumInterval(int value) => _param.maximumInterval = value;

  /// Sets the weights: migrates, clips, and re-derives the interval modifier.
  set w(List<double> value) {
    final migrated = migrateParameters(
      value,
      _param.relearningSteps.length,
      _param.enableShortTerm,
    );
    _param.w = migrated;
    _intervalModifier = calculateIntervalModifier(_param.requestRetention);
  }

  /// Enables or disables interval fuzzing.
  set enableFuzz(bool value) => _param.enableFuzz = value;

  /// Enables or disables short-term (learning-step) scheduling.
  ///
  /// [FSRS] overrides this to also swap the scheduler implementation.
  set enableShortTerm(bool value) => _param.enableShortTerm = value;

  /// Sets the learning steps.
  set learningSteps(List<String> value) => _param.learningSteps = value;

  /// Sets the relearning steps.
  set relearningSteps(List<String> value) => _param.relearningSteps = value;

  /// The multiplier from stability to interval at [requestRetention].
  ///
  /// `I(r, s) = (r ^ (1 / DECAY) - 1) / FACTOR * s`.
  double calculateIntervalModifier(double requestRetention) {
    if (requestRetention <= 0 || requestRetention > 1) {
      throw FSRSValidationError(
        'Requested retention rate should be in the range (0,1]',
      );
    }
    final df = computeDecayFactor(_param.w);
    return roundTo(
      (math.pow(requestRetention, 1 / df.decay).toDouble() - 1) / df.factor,
      8,
    );
  }

  /// Probability of recall [elapsedDays] after a review, under the current
  /// weights.
  double forgettingCurve(double elapsedDays, double stability) =>
      forgettingCurveWithDecay(_param.w[20], elapsedDays, stability);

  /// Initial stability for a first review graded [g].
  ///
  /// `S_0(G) = max(w[G - 1], 0.1)`.
  double initStability(Rating g) => math.max(_param.w[g.value - 1], 0.1);

  /// Initial difficulty for a first review graded [g].
  ///
  /// `D_0(G) = w[4] - e^((G - 1) * w[5]) + 1`, unclamped here; callers clamp
  /// into `[1, 10]`.
  double initDifficulty(Rating g) {
    final w = _param.w;
    final d = w[4] - math.exp((g.value - 1) * w[5]) + 1;
    return roundTo(d, 8);
  }

  /// Applies fuzz to [ivl], or returns it rounded when fuzz is off or the
  /// interval is too short to be worth jittering.
  int applyFuzz(
    double ivl,
    num minimumInterval, {
    bool useAnkiBounds = false,
  }) {
    if (!_param.enableFuzz || ivl < 2.5) return jsRound(ivl);
    final generator = alea(_seed); // The seed stays private on purpose.
    final fuzzFactor = generator.call();
    final range = useAnkiBounds
        ? getAnkiFuzzRange(ivl, minimumInterval, _param.maximumInterval)
        : getFuzzRange(ivl, minimumInterval, _param.maximumInterval);
    return (fuzzFactor * (range.maxIvl - range.minIvl + 1) + range.minIvl)
        .floor();
  }

  /// The interval, in days, for a memory of stability [s].
  int nextInterval(
    double s,
    num elapsedDays, {
    int? previousInterval,
  }) {
    final newInterval = math.min(
      math.max(1, jsRound(s * _intervalModifier)),
      _param.maximumInterval,
    );
    if (previousInterval == null) {
      return applyFuzz(newInterval.toDouble(), elapsedDays);
    }
    final minimumInterval = minimumReviewFuzzInterval(
      newInterval.toDouble(),
      previousInterval,
      _param.maximumInterval,
    );
    return applyFuzz(
      newInterval.toDouble(),
      minimumInterval,
      useAnkiBounds: true,
    );
  }

  /// Damps a difficulty change so that a hard card gets harder more slowly.
  ///
  /// See https://github.com/open-spaced-repetition/fsrs4anki/issues/697
  double linearDamping(double deltaD, double oldD) =>
      roundTo((deltaD * (10 - oldD)) / 9, 8);

  /// Difficulty after a review of a card at difficulty [d] graded [g].
  ///
  /// `next_d = D + linear_damping(-w[6] * (g - 3), D)`, mean-reverted toward
  /// `D_0(Easy)` by `w[7]` and clamped into `[1, 10]`.
  double nextDifficulty(double d, Rating g) {
    final deltaD = -_param.w[6] * (g.value - 3);
    final nextD = d + linearDamping(deltaD, d);
    return clamp(meanReversion(initDifficulty(Rating.easy), nextD), 1, 10);
  }

  /// `w[7] * init + (1 - w[7]) * current`.
  double meanReversion(double init, double current) {
    final w = _param.w;
    return roundTo(w[7] * init + (1 - w[7]) * current, 8);
  }

  /// Stability after a successful recall.
  ///
  /// `S'_r = S * (1 + e^w8 * (11 - D) * S^-w9 * (e^((1-R) * w10) - 1)
  /// * w15 (if G = Hard) * w16 (if G = Easy))`.
  double nextRecallStability(double d, double s, double r, Rating g) {
    final w = _param.w;
    final hardPenalty = g == Rating.hard ? w[15] : 1;
    final easyBound = g == Rating.easy ? w[16] : 1;
    return roundTo(
      clamp(
        s *
            (1 +
                math.exp(w[8]) *
                    (11 - d) *
                    math.pow(s, -w[9]).toDouble() *
                    (math.exp((1 - r) * w[10]) - 1) *
                    hardPenalty *
                    easyBound),
        sMin,
        36500.0,
      ),
      8,
    );
  }

  /// Stability after a lapse.
  ///
  /// `S'_f = w11 * D^-w12 * ((S + 1)^w13 - 1) * e^(w14 * (1 - R))`.
  double nextForgetStability(double d, double s, double r) {
    final w = _param.w;
    return roundTo(
      clamp(
        w[11] *
            math.pow(d, -w[12]).toDouble() *
            (math.pow(s + 1, w[13]).toDouble() - 1) *
            math.exp((1 - r) * w[14]),
        sMin,
        36500.0,
      ),
      8,
    );
  }

  /// Stability after a same-day review.
  ///
  /// `S'_s = S * S^-w19 * e^(w17 * (G - 3 + w18))`, with the increment floored
  /// at 1 for Hard and better so that a same-day Hard cannot shrink stability.
  double nextShortTermStability(double s, Rating g) {
    final w = _param.w;
    final sinc = math.pow(s, -w[19]).toDouble() *
        math.exp(w[17] * (g.value - 3 + w[18]));
    final maskedSinc =
        g.value >= Rating.hard.value ? math.max(sinc, 1.0) : sinc;
    return roundTo(clamp(s * maskedSinc, sMin, 36500.0), 8);
  }

  /// The memory state after a review of [memoryState] graded [g] at [t] days.
  ///
  /// A null or zeroed [memoryState] means a first review, which initialises
  /// rather than updates. [Rating.manual] leaves the state untouched, because a
  /// calendar move is not a repetition.
  FSRSState nextState(FSRSState? memoryState, double t, Rating g, [double? r]) {
    final d = memoryState?.difficulty ?? 0;
    final s = memoryState?.stability ?? 0;
    if (t < 0) {
      throw FSRSValidationError('Invalid delta_t "$t"');
    }
    if (g.value < 0 || g.value > 4) {
      throw FSRSValidationError('Invalid grade "${g.value}"');
    }
    if (d == 0 && s == 0) {
      return FSRSState(
        difficulty: clamp(initDifficulty(g), 1, 10),
        stability: initStability(g),
      );
    }
    if (g == Rating.manual) {
      return FSRSState(difficulty: d, stability: s);
    }
    if (d < 1 || s < sMin) {
      throw FSRSValidationError(
        'Invalid memory state { difficulty: $d, stability: $s }',
      );
    }
    final w = _param.w;
    final retrievability = r ?? forgettingCurve(t, s);
    final double newS;
    if (t == 0 && _param.enableShortTerm) {
      newS = nextShortTermStability(s, g);
    } else if (g == Rating.again) {
      final sAfterFail = nextForgetStability(d, s, retrievability);
      var w17 = 0.0;
      var w18 = 0.0;
      if (_param.enableShortTerm) {
        w17 = w[17];
        w18 = w[18];
      }
      final nextSMin = s / math.exp(w17 * w18);
      newS = clamp(roundTo(nextSMin, 8), sMin, sAfterFail);
    } else {
      newS = nextRecallStability(d, s, retrievability, g);
    }

    final newD = nextDifficulty(d, g);
    return FSRSState(difficulty: newD, stability: newS);
  }
}
