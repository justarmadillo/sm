/// Every setting in the collection, as one immutable value.
///
/// Each group lives in its own file next to this one; this file composes
/// them and owns reading them back from stored key/value pairs.
library;

import 'dart:convert';

import 'package:incremental_reader/settings/card_settings.dart';
import 'package:incremental_reader/settings/diagnostics_settings.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:incremental_reader/settings/postpone_settings.dart';
import 'package:incremental_reader/settings/queue_settings.dart';
import 'package:incremental_reader/settings/reader_settings.dart';
import 'package:incremental_reader/settings/remember_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/settings/study_day_settings.dart';
import 'package:meta/meta.dart';

/// The complete persisted configuration of one collection.
@immutable
final class AppSettings {
  const AppSettings({
    this.studyDay = const StudyDaySettings(),
    this.queue = const QueueSettings(),
    this.remember = const RememberSettings(),
    this.cards = const CardSettings(),
    this.postpone = const PostponeSettings(),
    this.mercy = const MercySettings(),
    this.reader = const ReaderSettings(),
    this.diagnostics = const DiagnosticsSettings(),
  });

  /// Total decoder for flat settings rows.
  ///
  /// Unknown keys are ignored. Missing or malformed fields independently fall
  /// back to the shipped value; syntactically valid out-of-range numbers are
  /// clamped to the executable/UI domain.
  factory AppSettings.fromMap(Map<String, String> stored) {
    const AppSettings fallback = AppSettings();
    final SmartPostponeSettings smartFallback =
        fallback.postpone.defaultProfile;

    return AppSettings(
      studyDay: StudyDaySettings(
        zoneId: stored['study.zone_id'] ?? fallback.studyDay.zoneId,
        rolloverMinutes: _readInt(
          stored['study.rollover_minutes'],
          fallback.studyDay.rolloverMinutes,
          min: 0,
          max: 1439,
        ),
      ),
      queue: QueueSettings(
        topicPercent: _readInt(
          stored['queue.topic_percent'],
          fallback.queue.topicPercent,
          min: 0,
          max: 100,
        ),
        itemRandomization: _readInt(
          stored['queue.item_randomization'],
          fallback.queue.itemRandomization,
          min: 0,
          max: 100,
        ),
        topicRandomization: _readInt(
          stored['queue.topic_randomization'],
          fallback.queue.topicRandomization,
          min: 0,
          max: 100,
        ),
        shouldSortAutomatically: _readBool(stored['queue.auto_sort'], fallback.queue.shouldSortAutomatically),
        shouldRandomizeFinalDrill: _readBool(
          stored['queue.randomize_final_drill'],
          fallback.queue.shouldRandomizeFinalDrill,
        ),
        shouldConfirmStageTransitions: _readBool(
          stored['queue.confirm_stage_transitions'],
          fallback.queue.shouldConfirmStageTransitions,
        ),
      ),
      remember: RememberSettings(
        firstIntervalLowDays: _readInt(
          stored['remember.first_interval_low_days'],
          fallback.remember.firstIntervalLowDays,
          min: 1,
          max: 365,
        ),
        firstIntervalHighDays: _readInt(
          stored['remember.first_interval_high_days'],
          fallback.remember.firstIntervalHighDays,
          min: 0,
          max: 365,
        ),
      ),
      cards: CardSettings(
        desiredRetention: _readDouble(
          stored['card.desired_retention'],
          fallback.cards.desiredRetention,
          min: 0.7,
          max: 0.99,
        ),
        learningStepMinutes: _readPositiveIntList(
          stored['card.learning_steps'],
          fallback.cards.learningStepMinutes,
        ),
        relearningStepMinutes: _readPositiveIntList(
          stored['card.relearning_steps'],
          fallback.cards.relearningStepMinutes,
        ),
        maximumIntervalDays: _readInt(
          stored['card.maximum_interval_days'],
          fallback.cards.maximumIntervalDays,
          min: 1,
          max: 36500,
        ),
        isFuzzingEnabled: _readBool(
          stored['card.enable_fuzzing'],
          fallback.cards.isFuzzingEnabled,
        ),
        leechLapses: _readInt(
          stored['card.leech_lapses'],
          fallback.cards.leechLapses,
          min: 1,
          max: 999,
        ),
        shouldBurySiblings: _readBool(
          stored['card.bury_siblings'],
          fallback.cards.shouldBurySiblings,
        ),
      ),
      postpone: PostponeSettings(
        isAutomaticPostponeEnabled: _readBool(
          stored['postpone.auto_enabled'],
          fallback.postpone.isAutomaticPostponeEnabled,
        ),
        namedProfiles: _readNamedProfiles(
          stored['postpone.named_profiles'],
          fallback.postpone.namedProfiles,
        ),
        branchProfileAssignments: _readBranchAssignments(
          stored['postpone.branch_profiles'],
          fallback.postpone.branchProfileAssignments,
        ),
        defaultProfile: SmartPostponeSettings(
          rootElementId: _readInt(
            stored['postpone.default.root_element_id'],
            smartFallback.rootElementId,
            min: 0,
            max: 0xFFFFFFFF,
          ),
          scope: _readEnum(
            stored['postpone.default.scope'],
            SmartPostponeScope.values,
            smartFallback.scope,
          ),
          method: _readEnum(
            stored['postpone.default.method'],
            SmartPostponeMethod.values,
            smartFallback.method,
          ),
          profileName:
              stored['postpone.default.profile_name'] ??
              smartFallback.profileName,
          subbranchMode: _readEnum(
            stored['postpone.default.subbranch_mode'],
            SmartPostponeSubbranchMode.values,
            smartFallback.subbranchMode,
          ),
          protectedCount: _readInt(
            stored['postpone.default.protected_count'],
            smartFallback.protectedCount,
            min: 1,
            max: 20000,
          ),
          shouldIncludeNonOutstanding: _readBool(
            stored['postpone.default.include_non_outstanding'],
            smartFallback.shouldIncludeNonOutstanding,
          ),
          isSimulationOnly: _readBool(
            stored['postpone.default.simulate'],
            smartFallback.isSimulationOnly,
          ),
          itemDelayPercent: _readInt(
            stored['postpone.default.item_delay_percent'],
            smartFallback.itemDelayPercent,
            min: 1,
            max: 400,
          ),
          topicDelayPercent: _readInt(
            stored['postpone.default.topic_delay_percent'],
            smartFallback.topicDelayPercent,
            min: 1,
            max: 1900,
          ),
          itemMaximumDelayDays: _readInt(
            stored['postpone.default.item_maximum_delay_days'],
            smartFallback.itemMaximumDelayDays,
            min: 1,
            max: 300,
          ),
          topicMaximumDelayDays: _readInt(
            stored['postpone.default.topic_maximum_delay_days'],
            smartFallback.topicMaximumDelayDays,
            min: 1,
            max: 500,
          ),
          itemMinimumDelayDays: _readInt(
            stored['postpone.default.item_minimum_delay_days'],
            smartFallback.itemMinimumDelayDays,
            min: 1,
            max: 30,
          ),
          topicMinimumDelayDays: _readInt(
            stored['postpone.default.topic_minimum_delay_days'],
            smartFallback.topicMinimumDelayDays,
            min: 1,
            max: 100,
          ),
          shouldSkipItems: _readBool(
            stored['postpone.default.skip_items'],
            smartFallback.shouldSkipItems,
          ),
          shouldSkipTopics: _readBool(
            stored['postpone.default.skip_topics'],
            smartFallback.shouldSkipTopics,
          ),
          itemAgeCutoffDays: _readInt(
            stored['postpone.default.item_age_cutoff_days'],
            smartFallback.itemAgeCutoffDays,
            min: 2,
            max: 4000,
          ),
          topicAgeCutoffDays: _readInt(
            stored['postpone.default.topic_age_cutoff_days'],
            smartFallback.topicAgeCutoffDays,
            min: 2,
            max: 4000,
          ),
          itemForgettingIndexCutoff: _readInt(
            stored['postpone.default.item_forgetting_index_cutoff'],
            smartFallback.itemForgettingIndexCutoff,
            min: 3,
            max: 20,
          ),
          topicAFactorCutoff: _readDouble(
            stored['postpone.default.topic_a_factor_cutoff'],
            smartFallback.topicAFactorCutoff,
            min: 1.01,
            max: 6,
          ),
          itemPostponeCountCutoff: _readInt(
            stored['postpone.default.item_postpone_count_cutoff'],
            smartFallback.itemPostponeCountCutoff,
            min: 1,
            max: 255,
          ),
          topicPostponeCountCutoff: _readInt(
            stored['postpone.default.topic_postpone_count_cutoff'],
            smartFallback.topicPostponeCountCutoff,
            min: 1,
            max: 255,
          ),
          itemPriorityThreshold: _readDouble(
            stored['postpone.default.item_priority_threshold'],
            smartFallback.itemPriorityThreshold,
            min: 0.01,
            max: 100,
          ),
          topicPriorityThreshold: _readDouble(
            stored['postpone.default.topic_priority_threshold'],
            smartFallback.topicPriorityThreshold,
            min: 0.0001,
            max: 100,
          ),
          shouldModifyItemByForgettingIndex: _readBool(
            stored['postpone.default.modify_item_by_forgetting_index'],
            smartFallback.shouldModifyItemByForgettingIndex,
          ),
          shouldModifyTopicByAFactor: _readBool(
            stored['postpone.default.modify_topic_by_a_factor'],
            smartFallback.shouldModifyTopicByAFactor,
          ),
        ),
      ),
      mercy: MercySettings(
        mode: _readEnum(
          stored['mercy.mode'],
          MercyMode.values,
          fallback.mercy.mode,
        ),
        reschedulingDays: _readInt(
          stored['mercy.rescheduling_days'],
          fallback.mercy.reschedulingDays,
          min: 1,
          max: 3650,
        ),
        gatheringDays: _readInt(
          stored['mercy.gathering_days'],
          fallback.mercy.gatheringDays,
          min: 1,
          max: 3650,
        ),
        dailyCap: _readInt(
          stored['mercy.daily_cap'],
          fallback.mercy.dailyCap,
          min: 1,
          max: 5000,
        ),
        shouldIncludeFuture: _readBool(
          stored['mercy.include_future'],
          fallback.mercy.shouldIncludeFuture,
        ),
        importanceWeight: _readFsrsWeight(
          stored['mercy.importance_weight'],
          fallback.mercy.importanceWeight,
        ),
        latenessWeight: _readFsrsWeight(
          stored['mercy.lateness_weight'],
          fallback.mercy.latenessWeight,
        ),
        investmentWeight: _readFsrsWeight(
          stored['mercy.investment_weight'],
          fallback.mercy.investmentWeight,
        ),
        easinessWeight: _readFsrsWeight(
          stored['mercy.easiness_weight'],
          fallback.mercy.easinessWeight,
        ),
        recencyWeight: _readFsrsWeight(
          stored['mercy.recency_weight'],
          fallback.mercy.recencyWeight,
        ),
        intervalFactorMatrix: _readIntMatrix(
          stored['mercy.interval_factor_matrix'],
          fallback.mercy.intervalFactorMatrix,
        ),
      ),
      reader: ReaderSettings(
        reminderWords: _readInt(
          stored['reader.reminder_words'],
          fallback.reader.reminderWords,
          min: 0,
          max: 100000,
        ),
      ),
      diagnostics: DiagnosticsSettings(
        isLogEnabled: _readBool(
          stored['diagnostics.log_enabled'],
          fallback.diagnostics.isLogEnabled,
        ),
        logMaxBytes: _readInt(
          stored['diagnostics.log_max_bytes'],
          fallback.diagnostics.logMaxBytes,
          min: 4096,
          max: 536870912,
        ),
        logRetainedFiles: _readInt(
          stored['diagnostics.log_retained_files'],
          fallback.diagnostics.logRetainedFiles,
          min: 1,
          max: 100,
        ),
        shouldShowContentInPanel: _readBool(
          stored['diagnostics.show_content'],
          fallback.diagnostics.shouldShowContentInPanel,
        ),
      ),
    );
  }

  final StudyDaySettings studyDay;
  final QueueSettings queue;
  final RememberSettings remember;
  final CardSettings cards;
  final PostponeSettings postpone;
  final MercySettings mercy;
  final ReaderSettings reader;
  final DiagnosticsSettings diagnostics;

  /// Flat storage form. It contains no keys from the replaced scheduler.
  Map<String, String> toMap() {
    final SmartPostponeSettings smart = postpone.defaultProfile;
    return <String, String>{
      'study.zone_id': studyDay.zoneId,
      'study.rollover_minutes': '${studyDay.rolloverMinutes}',
      'queue.topic_percent': '${queue.topicPercent}',
      'queue.item_randomization': '${queue.itemRandomization}',
      'queue.topic_randomization': '${queue.topicRandomization}',
      'queue.auto_sort': '${queue.shouldSortAutomatically}',
      'queue.randomize_final_drill': '${queue.shouldRandomizeFinalDrill}',
      'queue.confirm_stage_transitions': '${queue.shouldConfirmStageTransitions}',
      'remember.first_interval_low_days': '${remember.firstIntervalLowDays}',
      'remember.first_interval_high_days': '${remember.firstIntervalHighDays}',
      'card.desired_retention': '${cards.desiredRetention}',
      'card.learning_steps': cards.learningStepMinutes.join(','),
      'card.relearning_steps': cards.relearningStepMinutes.join(','),
      'card.maximum_interval_days': '${cards.maximumIntervalDays}',
      'card.enable_fuzzing': '${cards.isFuzzingEnabled}',
      'card.leech_lapses': '${cards.leechLapses}',
      'card.bury_siblings': '${cards.shouldBurySiblings}',
      'postpone.auto_enabled': '${postpone.isAutomaticPostponeEnabled}',
      'postpone.named_profiles': _encodeNamedProfiles(postpone.namedProfiles),
      'postpone.branch_profiles': _encodeBranchAssignments(
        postpone.branchProfileAssignments,
      ),
      'postpone.default.root_element_id': '${smart.rootElementId}',
      'postpone.default.scope': smart.scope.name,
      'postpone.default.method': smart.method.name,
      'postpone.default.profile_name': smart.profileName,
      'postpone.default.subbranch_mode': smart.subbranchMode.name,
      'postpone.default.protected_count': '${smart.protectedCount}',
      'postpone.default.include_non_outstanding':
          '${smart.shouldIncludeNonOutstanding}',
      'postpone.default.simulate': '${smart.isSimulationOnly}',
      'postpone.default.item_delay_percent': '${smart.itemDelayPercent}',
      'postpone.default.topic_delay_percent': '${smart.topicDelayPercent}',
      'postpone.default.item_maximum_delay_days':
          '${smart.itemMaximumDelayDays}',
      'postpone.default.topic_maximum_delay_days':
          '${smart.topicMaximumDelayDays}',
      'postpone.default.item_minimum_delay_days':
          '${smart.itemMinimumDelayDays}',
      'postpone.default.topic_minimum_delay_days':
          '${smart.topicMinimumDelayDays}',
      'postpone.default.skip_items': '${smart.shouldSkipItems}',
      'postpone.default.skip_topics': '${smart.shouldSkipTopics}',
      'postpone.default.item_age_cutoff_days': '${smart.itemAgeCutoffDays}',
      'postpone.default.topic_age_cutoff_days': '${smart.topicAgeCutoffDays}',
      'postpone.default.item_forgetting_index_cutoff':
          '${smart.itemForgettingIndexCutoff}',
      'postpone.default.topic_a_factor_cutoff': '${smart.topicAFactorCutoff}',
      'postpone.default.item_postpone_count_cutoff':
          '${smart.itemPostponeCountCutoff}',
      'postpone.default.topic_postpone_count_cutoff':
          '${smart.topicPostponeCountCutoff}',
      'postpone.default.item_priority_threshold':
          '${smart.itemPriorityThreshold}',
      'postpone.default.topic_priority_threshold':
          '${smart.topicPriorityThreshold}',
      'postpone.default.modify_item_by_forgetting_index':
          '${smart.shouldModifyItemByForgettingIndex}',
      'postpone.default.modify_topic_by_a_factor':
          '${smart.shouldModifyTopicByAFactor}',
      'mercy.mode': mercy.mode.name,
      'mercy.rescheduling_days': '${mercy.reschedulingDays}',
      'mercy.gathering_days': '${mercy.gatheringDays}',
      'mercy.daily_cap': '${mercy.dailyCap}',
      'mercy.include_future': '${mercy.shouldIncludeFuture}',
      'mercy.importance_weight': '${mercy.importanceWeight}',
      'mercy.lateness_weight': '${mercy.latenessWeight}',
      'mercy.investment_weight': '${mercy.investmentWeight}',
      'mercy.easiness_weight': '${mercy.easinessWeight}',
      'mercy.recency_weight': '${mercy.recencyWeight}',
      // Empty explicitly clears a previously imported optional matrix.
      'mercy.interval_factor_matrix':
          mercy.intervalFactorMatrix?.join(',') ?? '',
      'reader.reminder_words': '${reader.reminderWords}',
      'diagnostics.log_enabled': '${diagnostics.isLogEnabled}',
      'diagnostics.log_max_bytes': '${diagnostics.logMaxBytes}',
      'diagnostics.log_retained_files': '${diagnostics.logRetainedFiles}',
      'diagnostics.show_content': '${diagnostics.shouldShowContentInPanel}',
    };
  }

  AppSettings copyWith({
    StudyDaySettings? studyDay,
    QueueSettings? queue,
    RememberSettings? remember,
    CardSettings? cards,
    PostponeSettings? postpone,
    MercySettings? mercy,
    ReaderSettings? reader,
    DiagnosticsSettings? diagnostics,
  }) => AppSettings(
    studyDay: studyDay ?? this.studyDay,
    queue: queue ?? this.queue,
    remember: remember ?? this.remember,
    cards: cards ?? this.cards,
    postpone: postpone ?? this.postpone,
    mercy: mercy ?? this.mercy,
    reader: reader ?? this.reader,
    diagnostics: diagnostics ?? this.diagnostics,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.studyDay == studyDay &&
      other.queue == queue &&
      other.remember == remember &&
      other.cards == cards &&
      other.postpone == postpone &&
      other.mercy == mercy &&
      other.reader == reader &&
      other.diagnostics == diagnostics;

  @override
  int get hashCode => Object.hash(
    studyDay,
    queue,
    remember,
    cards,
    postpone,
    mercy,
    reader,
    diagnostics,
  );
}

int _readInt(String? raw, int fallback, {required int min, required int max}) {
  final int? parsed = raw == null ? null : int.tryParse(raw.trim());
  if (parsed == null) return fallback;
  return parsed.clamp(min, max);
}

double _readDouble(
  String? raw,
  double fallback, {
  required double min,
  required double max,
}) {
  final double? parsed = raw == null ? null : double.tryParse(raw.trim());
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed.clamp(min, max);
}

double _readFsrsWeight(String? raw, double fallback) =>
    _readDouble(raw, fallback, min: 0, max: 1000000);

bool _readBool(String? raw, bool fallback) => switch (raw?.trim().toLowerCase()) {
  'true' || '1' || 'yes' => true,
  'false' || '0' || 'no' => false,
  _ => fallback,
};

T _readEnum<T extends Enum>(String? raw, List<T> values, T fallback) {
  final String? normalized = raw?.trim();
  if (normalized == null) return fallback;
  for (final T value in values) {
    if (value.name == normalized) return value;
  }
  return fallback;
}

List<int> _readPositiveIntList(String? raw, List<int> fallback) {
  if (raw == null) return fallback;
  final List<String> parts = raw.split(',');
  if (parts.isEmpty) return fallback;
  final values = <int>[];
  for (final String part in parts) {
    final int? value = int.tryParse(part.trim());
    if (value == null || value <= 0) return fallback;
    values.add(value);
  }
  return values.isEmpty ? fallback : List<int>.unmodifiable(values);
}

List<int>? _readIntMatrix(String? raw, List<int>? fallback) {
  if (raw == null) return fallback;
  if (raw.trim().isEmpty) return null;
  final List<String> parts = raw.split(',');
  if (parts.length != 400) return fallback;
  final values = <int>[];
  for (final String part in parts) {
    final int? value = int.tryParse(part.trim());
    if (value == null || value < 0 || value > 0xFFFF) return fallback;
    values.add(value);
  }
  return List<int>.unmodifiable(values);
}

/// Encodes managed profiles as a JSON object keyed by profile name.
///
/// The empty string is written for an empty registry so a stored value always
/// exists and clearing the last profile is durable rather than a missing key
/// that decoding would read as "keep the fallback".
String _encodeNamedProfiles(Map<String, SmartPostponeSettings> profiles) {
  if (profiles.isEmpty) return '';
  final List<String> names = profiles.keys.toList()..sort();
  return jsonEncode(<String, Object?>{
    for (final String name in names) name: profiles[name]!.toJson(),
  });
}

Map<String, SmartPostponeSettings> _readNamedProfiles(
  String? raw,
  Map<String, SmartPostponeSettings> fallback,
) {
  if (raw == null) return fallback;
  if (raw.trim().isEmpty) return const <String, SmartPostponeSettings>{};
  final Object? decoded = _tryDecodeJson(raw);
  if (decoded is! Map<String, Object?>) return fallback;
  final profiles = <String, SmartPostponeSettings>{};
  for (final MapEntry<String, Object?> entry in decoded.entries) {
    final String name = entry.key.trim();
    if (name.isEmpty || name == PostponeSettings.defaultProfileName) continue;
    final Object? record = entry.value;
    if (record is! Map<String, Object?>) continue;
    // The map key is authoritative, so a record whose stored name drifted
    // from its key cannot resurrect a profile under a second name.
    profiles[name] = SmartPostponeSettings.fromJson(
      record,
    ).copyWith(profileName: name);
  }
  return Map<String, SmartPostponeSettings>.unmodifiable(profiles);
}

/// Encodes branch assignments as `rootElementId=profileName` pairs.
String _encodeBranchAssignments(Map<int, String> assignments) {
  if (assignments.isEmpty) return '';
  final List<int> roots = assignments.keys.toList()..sort();
  return jsonEncode(<String, Object?>{
    for (final int root in roots) '$root': assignments[root],
  });
}

Map<int, String> _readBranchAssignments(String? raw, Map<int, String> fallback) {
  if (raw == null) return fallback;
  if (raw.trim().isEmpty) return const <int, String>{};
  final Object? decoded = _tryDecodeJson(raw);
  if (decoded is! Map<String, Object?>) return fallback;
  final assignments = <int, String>{};
  for (final MapEntry<String, Object?> entry in decoded.entries) {
    final int? root = int.tryParse(entry.key);
    final Object? name = entry.value;
    if (root == null || root < 0 || root > 0xFFFFFFFF) continue;
    if (name is! String || name.trim().isEmpty) continue;
    assignments[root] = name.trim();
  }
  return Map<int, String>.unmodifiable(assignments);
}

Object? _tryDecodeJson(String raw) {
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}
