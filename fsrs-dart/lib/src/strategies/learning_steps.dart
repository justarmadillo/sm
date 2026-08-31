/// The (re)learning step layout.
///
/// Steps are the short, intraday part of the schedule that FSRS does not model:
/// a step list like `['1m', '10m']` says a lapsed or new card comes back in one
/// minute, then ten, before day-scale intervals take over.
library;

import '../error.dart';
import '../js_compat.dart';
import '../models.dart';
import 'types.dart';

/// Parses a step such as `10m`, `2h` or `1d` into whole minutes.
int convertStepUnitToMinutes(String step) {
  if (step.isEmpty) {
    throw FSRSValidationError('Invalid step value: $step');
  }
  final unit = step.substring(step.length - 1);
  final value = jsParseInt(step.substring(0, step.length - 1));
  if (value == null || value < 0) {
    throw FSRSValidationError('Invalid step value: $step');
  }
  switch (unit) {
    case 'm':
      return value;
    case 'h':
      return value * 60;
    case 'd':
      return value * 1440;
    default:
      throw FSRSValidationError('Invalid step unit: $step, expected m/h/d');
  }
}

/// The default step layout.
///
/// Again always restarts at step 0. Hard uses the midpoint of the first two
/// steps, or 1.5x the only step. Good advances, and stops being offered once
/// there is no next step, which is how a card graduates to day-scale intervals.
/// In [State.review] only the relearning entry point after a lapse applies.
Map<Rating, LearningStepResult> basicLearningStepsStrategy(
  FSRSParameters params,
  State state,
  int curStep,
) =>
    _learningStepsStrategy(params, state, curStep, repeatsLaterHardStep: false);

/// Anki's step layout, where Hard repeats the current step after step zero.
Map<Rating, LearningStepResult> ankiLearningStepsStrategy(
  FSRSParameters params,
  State state,
  int curStep,
) =>
    _learningStepsStrategy(params, state, curStep, repeatsLaterHardStep: true);

Map<Rating, LearningStepResult> _learningStepsStrategy(
  FSRSParameters params,
  State state,
  int curStep, {
  required bool repeatsLaterHardStep,
}) {
  final learningSteps = state == State.relearning || state == State.review
      ? params.relearningSteps
      : params.learningSteps;
  final stepsLength = learningSteps.length;
  if (stepsLength == 0 || curStep >= stepsLength) {
    return <Rating, LearningStepResult>{};
  }

  final firstStep = learningSteps[0];

  int againInterval() => convertStepUnitToMinutes(firstStep);

  int hardInterval() {
    final currentStep = curStep < 0 ? 0 : curStep;
    if (repeatsLaterHardStep && currentStep > 0) {
      return convertStepUnitToMinutes(learningSteps[currentStep]);
    }
    if (stepsLength == 1) {
      final firstMinutes = convertStepUnitToMinutes(firstStep);
      final hardMinutes = firstMinutes * 1.5;
      return jsRound(
        repeatsLaterHardStep
            ? hardMinutes.clamp(0, firstMinutes + 1440).toDouble()
            : hardMinutes,
      );
    }
    final nextStep = learningSteps[1];
    return jsRound(
      (convertStepUnitToMinutes(firstStep) +
              convertStepUnitToMinutes(nextStep)) /
          2,
    );
  }

  String? stepInfo(int index) =>
      (index < 0 || index >= stepsLength) ? null : learningSteps[index];

  final result = <Rating, LearningStepResult>{};
  final currentInfo = stepInfo(curStep < 0 ? 0 : curStep);
  if (state == State.review) {
    result[Rating.again] = LearningStepResult(
      scheduledMinutes: convertStepUnitToMinutes(currentInfo!),
      nextStep: 0,
    );
    return result;
  }

  result[Rating.again] =
      LearningStepResult(scheduledMinutes: againInterval(), nextStep: 0);
  result[Rating.hard] =
      LearningStepResult(scheduledMinutes: hardInterval(), nextStep: curStep);

  final nextInfo = stepInfo(curStep + 1);
  if (nextInfo != null) {
    final nextMin = convertStepUnitToMinutes(nextInfo);
    // A zero-minute step is treated as absent, matching upstream's truthiness
    // check: a step of `0m` would otherwise schedule the card into the past.
    if (nextMin != 0) {
      result[Rating.good] = LearningStepResult(
        scheduledMinutes: jsRound(nextMin.toDouble()),
        nextStep: curStep + 1,
      );
    }
  }
  return result;
}
