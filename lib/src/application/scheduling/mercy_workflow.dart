/// Durable preview and canonical-state snapshots for SM20 Mercy.
///
/// The executable's Mercy command is a bulk low-level reschedule.  These
/// application records make the app's preview/apply conversation durable
/// without introducing a second due-date store: apply writes the real topic
/// or card schedule, and undo restores the exact canonical state it replaced.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/mercy.dart';
import '../../domain/scheduling/priority_rank.dart';
import '../../domain/scheduling/sm20_numeric.dart';
import '../../domain/scheduling/study_day.dart';
import '../../domain/scheduling/topic_scheduler.dart';
import '../../domain/settings/app_settings.dart';

const String kSm20MercyPolicyVersion = 'sm20-mercy/1';

/// One fixed assignment shown in a preview and later applied verbatim.
@immutable
final class MercyPreviewItem {
  const MercyPreviewItem({
    required this.ref,
    required this.fromDay,
    required this.toDay,
    required this.score,
    required this.sourceIndex,
    required this.orderedIndex,
    required this.scheduleRevision,
    required this.schedulerRevision,
    required this.canonicalBefore,
  });

  final ElementRef ref;
  final StudyDay fromDay;
  final StudyDay toDay;
  final int score;
  final int sourceIndex;
  final int orderedIndex;
  final int scheduleRevision;
  final int schedulerRevision;

  /// Exact topic/card state used to compute the preview.  Apply compares the
  /// live value with this token before making the first write.
  final String canonicalBefore;
}

/// Per-target-day counts used by the confirmation dialog.
@immutable
final class MercyDailyLoad {
  const MercyDailyLoad({
    required this.day,
    required this.cards,
    required this.topics,
  });

  final StudyDay day;
  final int cards;
  final int topics;
  int get total => cards + topics;
}

/// Exact, persistable result of the pure SM20 Mercy engine.
@immutable
final class MercyPreview {
  const MercyPreview({
    required this.today,
    required this.collectionLearningStartDay,
    required this.gatheringDays,
    required this.reschedulingDays,
    required this.mode,
    required this.items,
    required this.gatheredCount,
    required this.blockSize,
    required this.randomDraws,
    required this.prngSeedBefore,
    required this.prngSeedAfter,
    required this.deletedPlaceholderCount,
    this.gatherMode = Sm20MercyGatherMode.collection,
  });

  factory MercyPreview.fromPlan({
    required Sm20MercyPlan plan,
    required StudyDay today,
    required StudyDay collectionLearningStartDay,
    required int gatheringDays,
    required MercyMode mode,
    required int prngSeedBefore,
    required Map<ElementRef, String> canonicalStates,
    Sm20MercyGatherMode gatherMode = Sm20MercyGatherMode.collection,
  }) => MercyPreview(
    today: today,
    collectionLearningStartDay: collectionLearningStartDay,
    gatheringDays: gatheringDays,
    reschedulingDays: plan.reschedulingDays,
    mode: mode,
    gatherMode: gatherMode,
    gatheredCount: plan.gathered.length,
    blockSize: plan.blockSize,
    randomDraws: plan.randomDraws,
    prngSeedBefore: prngSeedBefore,
    prngSeedAfter: plan.prngState.seed,
    deletedPlaceholderCount: plan.deletedPlaceholderCount,
    items: List<MercyPreviewItem>.unmodifiable(<MercyPreviewItem>[
      for (final Sm20MercyAssignment assignment in plan.assignments)
        MercyPreviewItem(
          ref: assignment.ref,
          fromDay: assignment.candidate.scheduledDay,
          toDay: assignment.targetDay,
          score: assignment.score.value,
          sourceIndex: assignment.sourceIndex,
          orderedIndex: assignment.orderedIndex,
          scheduleRevision: assignment.candidate.revision,
          schedulerRevision: assignment.candidate.revision,
          canonicalBefore: canonicalStates[assignment.ref]!,
        ),
    ]),
  );

  factory MercyPreview.fromJson(String source) {
    final Map<String, Object?> map = _object(jsonDecode(source), 'preview');
    final String zoneId = map['zone_id']! as String;
    return MercyPreview(
      today: _day(map['today']! as int, zoneId),
      collectionLearningStartDay: _day(
        map['learning_start_day']! as int,
        zoneId,
      ),
      gatheringDays: map['gathering_days']! as int,
      reschedulingDays: map['rescheduling_days']! as int,
      mode: MercyMode.values[map['mode']! as int],
      gatherMode: Sm20MercyGatherMode.values[map['gather_mode']! as int],
      gatheredCount: map['gathered_count']! as int,
      blockSize: map['block_size']! as int,
      randomDraws: map['random_draws']! as int,
      prngSeedBefore: map['prng_seed_before']! as int,
      prngSeedAfter: map['prng_seed_after']! as int,
      deletedPlaceholderCount: map['deleted_placeholder_count']! as int,
      items: List<MercyPreviewItem>.unmodifiable(<MercyPreviewItem>[
        for (final Object? raw in map['items']! as List<Object?>)
          (() {
            final Map<String, Object?> value = _object(raw, 'preview item');
            return MercyPreviewItem(
              ref: _ref(value),
              fromDay: _day(value['from_day']! as int, zoneId),
              toDay: _day(value['to_day']! as int, zoneId),
              score: value['score']! as int,
              sourceIndex: value['source_index']! as int,
              orderedIndex: value['ordered_index']! as int,
              scheduleRevision: value['schedule_revision']! as int,
              schedulerRevision: value['scheduler_revision']! as int,
              canonicalBefore: value['canonical_before']! as String,
            );
          })(),
      ]),
    );
  }

  final StudyDay today;
  final StudyDay collectionLearningStartDay;
  final int gatheringDays;
  final int reschedulingDays;
  final MercyMode mode;
  final Sm20MercyGatherMode gatherMode;
  final List<MercyPreviewItem> items;
  final int gatheredCount;
  final int blockSize;
  final int randomDraws;
  final int prngSeedBefore;
  final int prngSeedAfter;
  final int deletedPlaceholderCount;

  int get selectedCount => items.length;
  int get selectedCardCount => items
      .where((MercyPreviewItem value) => value.ref.type == ElementType.card)
      .length;
  int get selectedTopicCount => selectedCount - selectedCardCount;
  int get inputCandidateCount => gatheredCount;

  List<MercyDailyLoad> get afterLoad {
    final Map<int, ({int cards, int topics})> counts =
        <int, ({int cards, int topics})>{};
    for (final MercyPreviewItem item in items) {
      final current = counts[item.toDay.epochDay] ?? (cards: 0, topics: 0);
      counts[item.toDay.epochDay] = item.ref.type == ElementType.card
          ? (cards: current.cards + 1, topics: current.topics)
          : (cards: current.cards, topics: current.topics + 1);
    }
    final List<int> days = counts.keys.toList()..sort();
    return List<MercyDailyLoad>.unmodifiable(<MercyDailyLoad>[
      for (final int epoch in days)
        MercyDailyLoad(
          day: _day(epoch, today.zoneId),
          cards: counts[epoch]!.cards,
          topics: counts[epoch]!.topics,
        ),
    ]);
  }

  String toJson() => jsonEncode(<String, Object?>{
    'version': 1,
    'policy_version': kSm20MercyPolicyVersion,
    'zone_id': today.zoneId,
    'today': today.epochDay,
    'learning_start_day': collectionLearningStartDay.epochDay,
    'gathering_days': gatheringDays,
    'rescheduling_days': reschedulingDays,
    'mode': mode.index,
    'gather_mode': gatherMode.index,
    'gathered_count': gatheredCount,
    'block_size': blockSize,
    'random_draws': randomDraws,
    'prng_seed_before': prngSeedBefore,
    'prng_seed_after': prngSeedAfter,
    'deleted_placeholder_count': deletedPlaceholderCount,
    'items': <Map<String, Object?>>[
      for (final MercyPreviewItem item in items)
        <String, Object?>{
          ..._refMap(item.ref),
          'from_day': item.fromDay.epochDay,
          'to_day': item.toDay.epochDay,
          'score': item.score,
          'source_index': item.sourceIndex,
          'ordered_index': item.orderedIndex,
          'schedule_revision': item.scheduleRevision,
          'scheduler_revision': item.schedulerRevision,
          'canonical_before': item.canonicalBefore,
        },
    ],
  });
}

/// Canonical before/after token for one applied assignment.
@immutable
final class MercyAppliedItemSnapshot {
  const MercyAppliedItemSnapshot({
    required this.ref,
    required this.beforeState,
    required this.afterState,
    required this.fromDay,
    required this.toDay,
    required this.appliedEventId,
  });

  final ElementRef ref;
  final String beforeState;
  final String afterState;
  final StudyDay fromDay;
  final StudyDay toDay;
  final String appliedEventId;
}

/// Everything required to validate and exactly restore one applied batch.
@immutable
final class MercyAppliedBatchSnapshot {
  const MercyAppliedBatchSnapshot({
    required this.batchId,
    required this.appliedEventId,
    required this.policyVersion,
    required this.studyDay,
    required this.items,
  });

  final String batchId;
  final String appliedEventId;
  final String policyVersion;
  final StudyDay studyDay;
  final List<MercyAppliedItemSnapshot> items;
}

/// A stale preview/undo is refused before any canonical state is written.
final class StaleMercyPreview implements Exception {
  const StaleMercyPreview(this.message, {this.changed = const <ElementRef>[]});

  final String message;
  final Iterable<ElementRef> changed;

  @override
  String toString() => message;
}

/// Durable row backing preview -> apply -> undo across restarts.
@immutable
final class StoredMercyBatch {
  const StoredMercyBatch({
    required this.batchId,
    required this.previewOperationId,
    required this.policyVersion,
    required this.previewJson,
    required this.createdAtUtc,
    this.applyOperationId,
    this.undoOperationId,
    this.appliedSnapshotJson,
    this.appliedAtUtc,
    this.undoneAtUtc,
  });

  final String batchId;
  final String previewOperationId;
  final String policyVersion;
  final String previewJson;
  final DateTime createdAtUtc;
  final String? applyOperationId;
  final String? undoOperationId;
  final String? appliedSnapshotJson;
  final DateTime? appliedAtUtc;
  final DateTime? undoneAtUtc;

  bool get isApplied => appliedAtUtc != null && undoneAtUtc == null;
  MercyPreview get preview => MercyPreview.fromJson(previewJson);
  MercyAppliedBatchSnapshot get appliedSnapshot =>
      decodeMercyAppliedBatch(appliedSnapshotJson!);

  StoredMercyBatch copyWith({
    String? applyOperationId,
    String? undoOperationId,
    String? appliedSnapshotJson,
    DateTime? appliedAtUtc,
    DateTime? undoneAtUtc,
  }) => StoredMercyBatch(
    batchId: batchId,
    previewOperationId: previewOperationId,
    policyVersion: policyVersion,
    previewJson: previewJson,
    createdAtUtc: createdAtUtc,
    applyOperationId: applyOperationId ?? this.applyOperationId,
    undoOperationId: undoOperationId ?? this.undoOperationId,
    appliedSnapshotJson: appliedSnapshotJson ?? this.appliedSnapshotJson,
    appliedAtUtc: appliedAtUtc ?? this.appliedAtUtc,
    undoneAtUtc: undoneAtUtc ?? this.undoneAtUtc,
  );
}

String encodeMercyAppliedBatch(MercyAppliedBatchSnapshot snapshot) =>
    jsonEncode(<String, Object?>{
      'version': 1,
      'batch_id': snapshot.batchId,
      'applied_event_id': snapshot.appliedEventId,
      'policy_version': snapshot.policyVersion,
      'study_day': snapshot.studyDay.epochDay,
      'zone_id': snapshot.studyDay.zoneId,
      'items': <Map<String, Object?>>[
        for (final MercyAppliedItemSnapshot item in snapshot.items)
          <String, Object?>{
            ..._refMap(item.ref),
            'before_state': item.beforeState,
            'after_state': item.afterState,
            'from_day': item.fromDay.epochDay,
            'to_day': item.toDay.epochDay,
            'applied_event_id': item.appliedEventId,
          },
      ],
    });

MercyAppliedBatchSnapshot decodeMercyAppliedBatch(String source) {
  final Map<String, Object?> map = _object(jsonDecode(source), 'Mercy batch');
  final String zoneId = map['zone_id']! as String;
  return MercyAppliedBatchSnapshot(
    batchId: map['batch_id']! as String,
    appliedEventId: map['applied_event_id']! as String,
    policyVersion: map['policy_version']! as String,
    studyDay: _day(map['study_day']! as int, zoneId),
    items:
        List<MercyAppliedItemSnapshot>.unmodifiable(<MercyAppliedItemSnapshot>[
          for (final Object? raw in map['items']! as List<Object?>)
            (() {
              final Map<String, Object?> value = _object(raw, 'Mercy item');
              return MercyAppliedItemSnapshot(
                ref: _ref(value),
                beforeState: value['before_state']! as String,
                afterState: value['after_state']! as String,
                fromDay: _day(value['from_day']! as int, zoneId),
                toDay: _day(value['to_day']! as int, zoneId),
                appliedEventId: value['applied_event_id']! as String,
              );
            })(),
        ]),
  );
}

/// Lossless canonical topic token used by preview CAS and batch undo.
String encodeMercyTopicState(TopicState state) => jsonEncode(<String, Object?>{
  'kind': 'topic',
  'schedule': _scheduleMap(state.schedule),
  'status': state.status.index,
  'repetition_count': state.repetitionCount,
  'lapse_count': state.lapseCount,
  'stored_interval': state.storedInterval,
  'last_review_day': state.lastReviewDay?.epochDay,
  'a_factor_raw': state.aFactorRaw.toString(),
  'last_interval_ratio_raw': state.lastIntervalRatioRaw.toString(),
  'history_block_id': state.historyBlockId,
  'recent_postponement_count': state.recentPostponementCount,
  'total_postponement_count': state.totalPostponementCount,
  'learning_control': state.learningControl,
  'encounters_since_last_card': state.encountersSinceLastCard,
  'revision': state.revision,
});

TopicState decodeMercyTopicState(String source) {
  final Map<String, Object?> map = _object(jsonDecode(source), 'topic state');
  final ElementSchedule schedule = _schedule(
    _object(map['schedule'], 'topic schedule'),
  );
  final int? lastReview = map['last_review_day'] as int?;
  return TopicState(
    schedule: schedule,
    status: Sm20ElementStatus.values[map['status']! as int],
    repetitionCount: map['repetition_count']! as int,
    lapseCount: map['lapse_count']! as int,
    storedInterval: map['stored_interval']! as int,
    lastReviewDay: lastReview == null
        ? null
        : _day(lastReview, schedule.dueDay.zoneId),
    aFactorRaw: _real48(map['a_factor_raw']! as String),
    lastIntervalRatioRaw: _real48(map['last_interval_ratio_raw']! as String),
    historyBlockId: map['history_block_id']! as int,
    recentPostponementCount: map['recent_postponement_count']! as int,
    totalPostponementCount: map['total_postponement_count']! as int,
    learningControl: map['learning_control']! as int,
    encountersSinceLastCard: map['encounters_since_last_card']! as int,
    revision: map['revision']! as int,
  );
}

/// Lossless canonical card token used by preview CAS and batch undo.
String encodeMercyCardState(CardState state) => jsonEncode(<String, Object?>{
  'kind': 'card',
  'schedule': _scheduleMap(state.schedule),
  'memory': state.memory.toMap(),
});

CardState decodeMercyCardState(String source) {
  final Map<String, Object?> map = _object(jsonDecode(source), 'card state');
  return CardState(
    schedule: _schedule(_object(map['schedule'], 'card schedule')),
    memory: CardMemory.fromMap(_object(map['memory'], 'card memory')),
  );
}

Map<String, Object?> _scheduleMap(ElementSchedule value) => <String, Object?>{
  ..._refMap(value.ref),
  'priority': value.priority.orderKey,
  'lifecycle': value.lifecycle.index,
  'due_day': value.dueDay.epochDay,
  'original_due_day': value.originalDueDay.epochDay,
  'zone_id': value.dueDay.zoneId,
  'root_id': value.rootId,
  'parent_element_id': value.parentElementId,
  'ordinal': value.ordinal,
  'created_at_utc': value.createdAtUtc?.millisecondsSinceEpoch,
  'updated_at_utc': value.updatedAtUtc?.millisecondsSinceEpoch,
  'revision': value.revision,
  'legacy_due_provenance': value.legacyDueProvenance.index,
};

ElementSchedule _schedule(Map<String, Object?> map) {
  final String zoneId = map['zone_id']! as String;
  final int? created = map['created_at_utc'] as int?;
  final int? updated = map['updated_at_utc'] as int?;
  return ElementSchedule(
    ref: _ref(map),
    priority: PriorityRank(map['priority']! as String),
    lifecycle: ElementLifecycle.values[map['lifecycle']! as int],
    dueDay: _day(map['due_day']! as int, zoneId),
    originalDueDay: _day(map['original_due_day']! as int, zoneId),
    rootId: map['root_id'] as String?,
    parentElementId: map['parent_element_id'] as String?,
    ordinal: map['ordinal'] as int?,
    createdAtUtc: created == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(created, isUtc: true),
    updatedAtUtc: updated == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updated, isUtc: true),
    revision: map['revision']! as int,
    legacyDueProvenance:
        LegacyDueProvenance.values[map['legacy_due_provenance']! as int],
  );
}

Map<String, Object?> _refMap(ElementRef ref) => <String, Object?>{
  'element_id': ref.id,
  'element_type': ref.type.index,
};

ElementRef _ref(Map<String, Object?> map) => ElementRef(
  id: map['element_id']! as String,
  type: ElementType.values[map['element_type']! as int],
);

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$name must be an object');
  }
  return value.cast<String, Object?>();
}

StudyDay _day(int epochDay, String zoneId) {
  final DateTime date = DateTime.fromMillisecondsSinceEpoch(
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

DelphiReal48 _real48(String hex) {
  if (hex.length != 12) throw const FormatException('invalid Real48 payload');
  return DelphiReal48.fromBytes(<int>[
    for (var offset = 0; offset < 12; offset += 2)
      int.parse(hex.substring(offset, offset + 2), radix: 16),
  ]);
}
