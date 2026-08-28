/// How Mercy redistributes a backlog across future days.///
/// Mirrors the controls described by `SM20_AIO_SCHEDULER.md`.
library;

import 'package:incremental_reader/settings/settings_list_equality.dart';

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
    this.includeFuture = false,
    this.importanceWeight = 10,
    this.latenessWeight = 3,
    this.investmentWeight = 4,
    this.easinessWeight = 1,
    this.recencyWeight = 1,
    this.intervalFactorMatrix,
  });

  final MercyMode mode;
  final int reschedulingDays;
  final int gatheringDays;
  final int dailyCap;
  final bool includeFuture;
  final double importanceWeight;
  final double latenessWeight;
  final double investmentWeight;
  final double easinessWeight;
  final double recencyWeight;

  /// Optional row-major 20 by 20 UInt16 matrix, scaled by 1000.
  ///
  /// The executable does not ship one universal matrix; it is live collection
  /// state. Null means no matrix has yet been imported for this collection.
  final List<int>? intervalFactorMatrix;

  MercySettings copyWith({
    MercyMode? mode,
    int? reschedulingDays,
    int? gatheringDays,
    int? dailyCap,
    bool? includeFuture,
    double? importanceWeight,
    double? latenessWeight,
    double? investmentWeight,
    double? easinessWeight,
    double? recencyWeight,
    Object? intervalFactorMatrix = _notProvided,
  }) => MercySettings(
    mode: mode ?? this.mode,
    reschedulingDays: reschedulingDays ?? this.reschedulingDays,
    gatheringDays: gatheringDays ?? this.gatheringDays,
    dailyCap: dailyCap ?? this.dailyCap,
    includeFuture: includeFuture ?? this.includeFuture,
    importanceWeight: importanceWeight ?? this.importanceWeight,
    latenessWeight: latenessWeight ?? this.latenessWeight,
    investmentWeight: investmentWeight ?? this.investmentWeight,
    easinessWeight: easinessWeight ?? this.easinessWeight,
    recencyWeight: recencyWeight ?? this.recencyWeight,
    intervalFactorMatrix: identical(intervalFactorMatrix, _notProvided)
        ? this.intervalFactorMatrix
        : intervalFactorMatrix as List<int>?,
  );

  @override
  bool operator ==(Object other) =>
      other is MercySettings &&
      other.mode == mode &&
      other.reschedulingDays == reschedulingDays &&
      other.gatheringDays == gatheringDays &&
      other.dailyCap == dailyCap &&
      other.includeFuture == includeFuture &&
      other.importanceWeight == importanceWeight &&
      other.latenessWeight == latenessWeight &&
      other.investmentWeight == investmentWeight &&
      other.easinessWeight == easinessWeight &&
      other.recencyWeight == recencyWeight &&
      nullableIntListsAreEqual(other.intervalFactorMatrix, intervalFactorMatrix);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    mode,
    reschedulingDays,
    gatheringDays,
    dailyCap,
    includeFuture,
    importanceWeight,
    latenessWeight,
    investmentWeight,
    easinessWeight,
    recencyWeight,
    intervalFactorMatrix == null ? null : Object.hashAll(intervalFactorMatrix!),
  ]);
}

const Object _notProvided = Object();
