/// How Mercy redistributes a backlog across future days.///
/// Mirrors the controls described by `SM20_AIO_SCHEDULER.md`.
library;

import 'package:meta/meta.dart';

/// Ordering used by Mercy before it redistributes candidates.
enum MercyMode { highScoreFirst, lowScoreFirst, sourceOrder, random }

/// SM20 Mercy scoring, gathering, and capacity-planner settings.
@immutable
final class MercySettings {
  const MercySettings({
    this.mode = MercyMode.highScoreFirst,
    this.reschedulingDays = 14,
    this.gatheringDays = 14,
    this.dailyCap = 100,
    this.shouldIncludeFuture = false,
    this.importanceWeight = 10,
    this.latenessWeight = 3,
    this.investmentWeight = 4,
    this.easinessWeight = 1,
    this.recencyWeight = 1,
  });

  final MercyMode mode;
  final int reschedulingDays;
  final int gatheringDays;
  final int dailyCap;
  final bool shouldIncludeFuture;
  final double importanceWeight;
  final double latenessWeight;
  final double investmentWeight;
  final double easinessWeight;
  final double recencyWeight;

  MercySettings copyWith({
    MercyMode? mode,
    int? reschedulingDays,
    int? gatheringDays,
    int? dailyCap,
    bool? shouldIncludeFuture,
    double? importanceWeight,
    double? latenessWeight,
    double? investmentWeight,
    double? easinessWeight,
    double? recencyWeight,
  }) => MercySettings(
    mode: mode ?? this.mode,
    reschedulingDays: reschedulingDays ?? this.reschedulingDays,
    gatheringDays: gatheringDays ?? this.gatheringDays,
    dailyCap: dailyCap ?? this.dailyCap,
    shouldIncludeFuture: shouldIncludeFuture ?? this.shouldIncludeFuture,
    importanceWeight: importanceWeight ?? this.importanceWeight,
    latenessWeight: latenessWeight ?? this.latenessWeight,
    investmentWeight: investmentWeight ?? this.investmentWeight,
    easinessWeight: easinessWeight ?? this.easinessWeight,
    recencyWeight: recencyWeight ?? this.recencyWeight,
  );

  @override
  bool operator ==(Object other) =>
      other is MercySettings &&
      other.mode == mode &&
      other.reschedulingDays == reschedulingDays &&
      other.gatheringDays == gatheringDays &&
      other.dailyCap == dailyCap &&
      other.shouldIncludeFuture == shouldIncludeFuture &&
      other.importanceWeight == importanceWeight &&
      other.latenessWeight == latenessWeight &&
      other.investmentWeight == investmentWeight &&
      other.easinessWeight == easinessWeight &&
      other.recencyWeight == recencyWeight;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    mode,
    reschedulingDays,
    gatheringDays,
    dailyCap,
    shouldIncludeFuture,
    importanceWeight,
    latenessWeight,
    investmentWeight,
    easinessWeight,
    recencyWeight,
  ]);
}
