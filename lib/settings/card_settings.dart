/// How recall cards are scheduled: the FSRS parameters and leech limits.
library;

import 'package:fsrs_dart/fsrs.dart' as fsrs;
import 'package:incremental_reader/settings/settings_list_equality.dart';

import 'package:meta/meta.dart';

/// FSRS knobs and item-review behaviours.
@immutable
final class CardSettings {
  const CardSettings({
    this.desiredRetention = 0.90,
    this.fsrsParameters = fsrs.defaultW,
    this.fsrsParametersVersion = 'fsrs_dart/5.4.1/defaultW',
    this.learningStepMinutes = const <int>[1, 10],
    this.relearningStepMinutes = const <int>[10],
    this.maximumIntervalDays = 36500,
    this.isFuzzingEnabled = true,
    this.shouldRescheduleAfterSettingsChange = true,
    this.leechLapses = 8,
    this.shouldBurySiblings = true,
    this.overlapContextBefore = 1,
    this.overlapContextAfter = 0,
  });

  final double desiredRetention;
  final List<double> fsrsParameters;
  final String fsrsParametersVersion;
  final List<int> learningStepMinutes;
  final List<int> relearningStepMinutes;
  final int maximumIntervalDays;
  final bool isFuzzingEnabled;
  final bool shouldRescheduleAfterSettingsChange;
  final int leechLapses;
  final bool shouldBurySiblings;
  final int overlapContextBefore;
  final int overlapContextAfter;

  CardSettings copyWith({
    double? desiredRetention,
    List<double>? fsrsParameters,
    String? fsrsParametersVersion,
    List<int>? learningStepMinutes,
    List<int>? relearningStepMinutes,
    int? maximumIntervalDays,
    bool? isFuzzingEnabled,
    bool? shouldRescheduleAfterSettingsChange,
    int? leechLapses,
    bool? shouldBurySiblings,
    int? overlapContextBefore,
    int? overlapContextAfter,
  }) => CardSettings(
    desiredRetention: desiredRetention ?? this.desiredRetention,
    fsrsParameters: fsrsParameters ?? this.fsrsParameters,
    fsrsParametersVersion: fsrsParametersVersion ?? this.fsrsParametersVersion,
    learningStepMinutes: learningStepMinutes ?? this.learningStepMinutes,
    relearningStepMinutes: relearningStepMinutes ?? this.relearningStepMinutes,
    maximumIntervalDays: maximumIntervalDays ?? this.maximumIntervalDays,
    isFuzzingEnabled: isFuzzingEnabled ?? this.isFuzzingEnabled,
    shouldRescheduleAfterSettingsChange:
        shouldRescheduleAfterSettingsChange ??
        this.shouldRescheduleAfterSettingsChange,
    leechLapses: leechLapses ?? this.leechLapses,
    shouldBurySiblings: shouldBurySiblings ?? this.shouldBurySiblings,
    overlapContextBefore: overlapContextBefore ?? this.overlapContextBefore,
    overlapContextAfter: overlapContextAfter ?? this.overlapContextAfter,
  );

  @override
  bool operator ==(Object other) =>
      other is CardSettings &&
      other.desiredRetention == desiredRetention &&
      doubleListsAreEqual(other.fsrsParameters, fsrsParameters) &&
      other.fsrsParametersVersion == fsrsParametersVersion &&
      intListsAreEqual(other.learningStepMinutes, learningStepMinutes) &&
      intListsAreEqual(other.relearningStepMinutes, relearningStepMinutes) &&
      other.maximumIntervalDays == maximumIntervalDays &&
      other.isFuzzingEnabled == isFuzzingEnabled &&
      other.shouldRescheduleAfterSettingsChange ==
          shouldRescheduleAfterSettingsChange &&
      other.leechLapses == leechLapses &&
      other.shouldBurySiblings == shouldBurySiblings &&
      other.overlapContextBefore == overlapContextBefore &&
      other.overlapContextAfter == overlapContextAfter;

  @override
  int get hashCode => Object.hashAll(<Object>[
    desiredRetention,
    Object.hashAll(fsrsParameters),
    fsrsParametersVersion,
    Object.hashAll(learningStepMinutes),
    Object.hashAll(relearningStepMinutes),
    maximumIntervalDays,
    isFuzzingEnabled,
    shouldRescheduleAfterSettingsChange,
    leechLapses,
    shouldBurySiblings,
    overlapContextBefore,
    overlapContextAfter,
  ]);
}
