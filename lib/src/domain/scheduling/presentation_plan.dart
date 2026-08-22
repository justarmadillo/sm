/// Durable identity and cursor for one StudyDay presentation plan.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import 'element.dart';
import 'queue_policy.dart';
import 'study_day.dart';

@immutable
final class PresentationPlanIdentity {
  const PresentationPlanIdentity({
    required this.studyDay,
    required this.policyVersion,
    required this.settingsRevision,
    required this.datasetGeneration,
    required this.candidateRevision,
    required this.deterministicSeedVersion,
  });

  factory PresentationPlanIdentity.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, Object?>;
    return PresentationPlanIdentity(
      studyDay: _day(map['study_day']! as int, map['zone_id']! as String),
      policyVersion: map['policy_version']! as String,
      settingsRevision: map['settings_revision']! as String,
      datasetGeneration: map['dataset_generation']! as int,
      candidateRevision: map['candidate_revision']! as String,
      deterministicSeedVersion: map['deterministic_seed_version']! as String,
    );
  }

  final StudyDay studyDay;
  final String policyVersion;
  final String settingsRevision;
  final int datasetGeneration;
  final String candidateRevision;
  final String deterministicSeedVersion;

  /// Whether [other] was planned under the same rules as this identity.
  ///
  /// Deliberately narrower than equality. `candidateRevision` and
  /// `datasetGeneration` change on every review, so requiring full equality to
  /// resume would rebuild the plan after each answer and reshuffle the rest of
  /// the session. The rules that decide *which* work belongs to the day —
  /// the day itself, the policy, its seed, and the settings — are what must
  /// hold for a remaining plan to still be the same plan.
  bool sharesBasisWith(PresentationPlanIdentity other) =>
      studyDay == other.studyDay &&
      policyVersion == other.policyVersion &&
      settingsRevision == other.settingsRevision &&
      deterministicSeedVersion == other.deterministicSeedVersion;

  Map<String, Object?> toMap() => <String, Object?>{
    'study_day': studyDay.epochDay,
    'zone_id': studyDay.zoneId,
    'policy_version': policyVersion,
    'settings_revision': settingsRevision,
    'dataset_generation': datasetGeneration,
    'candidate_revision': candidateRevision,
    'deterministic_seed_version': deterministicSeedVersion,
  };

  String toJson() => jsonEncode(toMap());

  @override
  bool operator ==(Object other) =>
      other is PresentationPlanIdentity && toJson() == other.toJson();

  @override
  int get hashCode => Object.hashAll(<Object?>[
    studyDay,
    policyVersion,
    settingsRevision,
    datasetGeneration,
    candidateRevision,
    deterministicSeedVersion,
  ]);
}

@immutable
final class PresentationPlanEntry {
  const PresentationPlanEntry({required this.ref, required this.lane});

  factory PresentationPlanEntry.fromMap(Map<String, Object?> map) =>
      PresentationPlanEntry(
        ref: ElementRef(
          id: map['id']! as String,
          type: ElementType.values[map['type']! as int],
        ),
        lane: QueueLane.values[map['lane']! as int],
      );

  final ElementRef ref;
  final QueueLane lane;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': ref.id,
    'type': ref.type.index,
    'lane': lane.index,
  };
}

@immutable
final class StoredPresentationPlan {
  const StoredPresentationPlan({
    required this.identity,
    required this.remainingEntries,
    required this.mergeCursor,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final PresentationPlanIdentity identity;
  final List<PresentationPlanEntry> remainingEntries;
  final QueueMergeCursor mergeCursor;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  String entriesJson() => jsonEncode(<Map<String, Object?>>[
    for (final entry in remainingEntries) entry.toMap(),
  ]);

  static List<PresentationPlanEntry> decodeEntries(String source) =>
      List<PresentationPlanEntry>.unmodifiable(
        (jsonDecode(source) as List<Object?>).cast<Map<String, Object?>>().map(
          PresentationPlanEntry.fromMap,
        ),
      );

  StoredPresentationPlan consume(ElementRef ref, DateTime atUtc) {
    final List<PresentationPlanEntry> remaining = remainingEntries.toList();
    final int index = remaining.indexWhere(
      (PresentationPlanEntry entry) => entry.ref == ref,
    );
    if (index < 0) return this;
    final PresentationPlanEntry consumed = remaining.removeAt(index);
    final int cardsSinceTopic = switch (consumed.lane) {
      QueueLane.mandatoryIntradayStep => mergeCursor.ordinaryCardsSinceTopic,
      QueueLane.protectedDueTopic || QueueLane.regularDueTopic => 0,
      _ => mergeCursor.ordinaryCardsSinceTopic + 1,
    };
    return StoredPresentationPlan(
      identity: identity,
      remainingEntries: List<PresentationPlanEntry>.unmodifiable(remaining),
      mergeCursor: QueueMergeCursor(ordinaryCardsSinceTopic: cardsSinceTopic),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: atUtc,
    );
  }
}

StudyDay _day(int epochDay, String zoneId) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return StudyDay(
    year: date.year,
    month: date.month,
    day: date.day,
    zoneId: zoneId,
  );
}
