/// How Smart Postpone chooses what to push out, and by how much.///
/// Mirrors the controls described by `SM20_AIO_SCHEDULER.md`.
library;

import 'package:meta/meta.dart';

/// Population used by a Smart Postpone run.
enum SmartPostponeScope { global, branch, browser }

/// How Smart Postpone decides how many elements remain unpostponed.
enum SmartPostponeMethod { parameters, topCount }

/// How profiles attached to nested branches affect the active profile.
enum SmartPostponeSubbranchMode { respect, ignore, conservative, liberal }

/// SM20's complete user-visible Smart Postpone profile record.
@immutable
final class SmartPostponeSettings {
  const SmartPostponeSettings({
    this.rootElementId = 0,
    this.scope = SmartPostponeScope.global,
    this.method = SmartPostponeMethod.topCount,
    this.profileName = 'Default',
    this.subbranchMode = SmartPostponeSubbranchMode.ignore,
    this.protectedCount = 50,
    this.includeNonOutstanding = false,
    this.simulate = false,
    this.itemDelayPercent = 20,
    this.topicDelayPercent = 50,
    this.itemMaximumDelayDays = 50,
    this.topicMaximumDelayDays = 100,
    this.itemMinimumDelayDays = 1,
    this.topicMinimumDelayDays = 6,
    this.skipItems = false,
    this.skipTopics = false,
    this.itemAgeCutoffDays = 500,
    this.topicAgeCutoffDays = 800,
    this.itemForgettingIndexCutoff = 6,
    this.topicAFactorCutoff = 1.03,
    this.itemPostponeCountCutoff = 50,
    this.topicPostponeCountCutoff = 100,
    this.itemPriorityThreshold = 6,
    this.topicPriorityThreshold = 3,
    this.modifyItemByForgettingIndex = true,
    this.modifyTopicByAFactor = true,
  });

  final int rootElementId;
  final SmartPostponeScope scope;
  final SmartPostponeMethod method;
  final String profileName;
  final SmartPostponeSubbranchMode subbranchMode;
  final int protectedCount;
  final bool includeNonOutstanding;
  final bool simulate;
  final int itemDelayPercent;
  final int topicDelayPercent;
  final int itemMaximumDelayDays;
  final int topicMaximumDelayDays;
  final int itemMinimumDelayDays;
  final int topicMinimumDelayDays;
  final bool skipItems;
  final bool skipTopics;
  final int itemAgeCutoffDays;
  final int topicAgeCutoffDays;
  final int itemForgettingIndexCutoff;
  final double topicAFactorCutoff;
  final int itemPostponeCountCutoff;
  final int topicPostponeCountCutoff;
  final double itemPriorityThreshold;
  final double topicPriorityThreshold;

  /// Preserved profile flag; the SM20 evaluator does not read it.
  final bool modifyItemByForgettingIndex;

  /// Preserved profile flag; the SM20 evaluator does not read it.
  final bool modifyTopicByAFactor;

  /// Lossless storage form of the complete SM20 `0x47` profile record.
  ///
  /// Named profiles are persisted as JSON rather than as flat dotted keys
  /// because their names are user data and the record must round-trip every
  /// field, including the two flags the evaluator deliberately ignores.
  Map<String, Object?> toJson() => <String, Object?>{
    'root_element_id': rootElementId,
    'scope': scope.name,
    'method': method.name,
    'profile_name': profileName,
    'subbranch_mode': subbranchMode.name,
    'protected_count': protectedCount,
    'include_non_outstanding': includeNonOutstanding,
    'simulate': simulate,
    'item_delay_percent': itemDelayPercent,
    'topic_delay_percent': topicDelayPercent,
    'item_maximum_delay_days': itemMaximumDelayDays,
    'topic_maximum_delay_days': topicMaximumDelayDays,
    'item_minimum_delay_days': itemMinimumDelayDays,
    'topic_minimum_delay_days': topicMinimumDelayDays,
    'skip_items': skipItems,
    'skip_topics': skipTopics,
    'item_age_cutoff_days': itemAgeCutoffDays,
    'topic_age_cutoff_days': topicAgeCutoffDays,
    'item_forgetting_index_cutoff': itemForgettingIndexCutoff,
    'topic_a_factor_cutoff': topicAFactorCutoff,
    'item_postpone_count_cutoff': itemPostponeCountCutoff,
    'topic_postpone_count_cutoff': topicPostponeCountCutoff,
    'item_priority_threshold': itemPriorityThreshold,
    'topic_priority_threshold': topicPriorityThreshold,
    'modify_item_by_forgetting_index': modifyItemByForgettingIndex,
    'modify_topic_by_a_factor': modifyTopicByAFactor,
  };

  /// Rebuilds a record, falling back to [fallback] field by field.
  ///
  /// A corrupt or partial entry degrades to the fallback profile instead of
  /// dropping the whole managed profile, which would silently unassign every
  /// branch that referenced it.
  static SmartPostponeSettings fromJson(
    Map<String, Object?> json, {
    SmartPostponeSettings fallback = const SmartPostponeSettings(),
  }) => SmartPostponeSettings(
    rootElementId: _jsonInt(
      json['root_element_id'],
      fallback.rootElementId,
      min: 0,
      max: 0xFFFFFFFF,
    ),
    scope: _jsonEnum(json['scope'], SmartPostponeScope.values, fallback.scope),
    method: _jsonEnum(
      json['method'],
      SmartPostponeMethod.values,
      fallback.method,
    ),
    profileName: json['profile_name'] is String
        ? json['profile_name']! as String
        : fallback.profileName,
    subbranchMode: _jsonEnum(
      json['subbranch_mode'],
      SmartPostponeSubbranchMode.values,
      fallback.subbranchMode,
    ),
    protectedCount: _jsonInt(
      json['protected_count'],
      fallback.protectedCount,
      min: 0,
      max: 10000,
    ),
    includeNonOutstanding: _jsonBool(
      json['include_non_outstanding'],
      fallback.includeNonOutstanding,
    ),
    simulate: _jsonBool(json['simulate'], fallback.simulate),
    itemDelayPercent: _jsonInt(
      json['item_delay_percent'],
      fallback.itemDelayPercent,
      min: 1,
      max: 1000,
    ),
    topicDelayPercent: _jsonInt(
      json['topic_delay_percent'],
      fallback.topicDelayPercent,
      min: 1,
      max: 1000,
    ),
    itemMaximumDelayDays: _jsonInt(
      json['item_maximum_delay_days'],
      fallback.itemMaximumDelayDays,
      min: 1,
      max: 10000,
    ),
    topicMaximumDelayDays: _jsonInt(
      json['topic_maximum_delay_days'],
      fallback.topicMaximumDelayDays,
      min: 1,
      max: 10000,
    ),
    itemMinimumDelayDays: _jsonInt(
      json['item_minimum_delay_days'],
      fallback.itemMinimumDelayDays,
      min: 1,
      max: 10000,
    ),
    topicMinimumDelayDays: _jsonInt(
      json['topic_minimum_delay_days'],
      fallback.topicMinimumDelayDays,
      min: 1,
      max: 10000,
    ),
    skipItems: _jsonBool(json['skip_items'], fallback.skipItems),
    skipTopics: _jsonBool(json['skip_topics'], fallback.skipTopics),
    itemAgeCutoffDays: _jsonInt(
      json['item_age_cutoff_days'],
      fallback.itemAgeCutoffDays,
      min: 2,
      max: 4000,
    ),
    topicAgeCutoffDays: _jsonInt(
      json['topic_age_cutoff_days'],
      fallback.topicAgeCutoffDays,
      min: 2,
      max: 4000,
    ),
    itemForgettingIndexCutoff: _jsonInt(
      json['item_forgetting_index_cutoff'],
      fallback.itemForgettingIndexCutoff,
      min: 3,
      max: 20,
    ),
    topicAFactorCutoff: _jsonDouble(
      json['topic_a_factor_cutoff'],
      fallback.topicAFactorCutoff,
      min: 1.01,
      max: 6,
    ),
    itemPostponeCountCutoff: _jsonInt(
      json['item_postpone_count_cutoff'],
      fallback.itemPostponeCountCutoff,
      min: 1,
      max: 255,
    ),
    topicPostponeCountCutoff: _jsonInt(
      json['topic_postpone_count_cutoff'],
      fallback.topicPostponeCountCutoff,
      min: 1,
      max: 255,
    ),
    itemPriorityThreshold: _jsonDouble(
      json['item_priority_threshold'],
      fallback.itemPriorityThreshold,
      min: 0.01,
      max: 100,
    ),
    topicPriorityThreshold: _jsonDouble(
      json['topic_priority_threshold'],
      fallback.topicPriorityThreshold,
      min: 0.0001,
      max: 100,
    ),
    modifyItemByForgettingIndex: _jsonBool(
      json['modify_item_by_forgetting_index'],
      fallback.modifyItemByForgettingIndex,
    ),
    modifyTopicByAFactor: _jsonBool(
      json['modify_topic_by_a_factor'],
      fallback.modifyTopicByAFactor,
    ),
  );

  SmartPostponeSettings copyWith({
    int? rootElementId,
    SmartPostponeScope? scope,
    SmartPostponeMethod? method,
    String? profileName,
    SmartPostponeSubbranchMode? subbranchMode,
    int? protectedCount,
    bool? includeNonOutstanding,
    bool? simulate,
    int? itemDelayPercent,
    int? topicDelayPercent,
    int? itemMaximumDelayDays,
    int? topicMaximumDelayDays,
    int? itemMinimumDelayDays,
    int? topicMinimumDelayDays,
    bool? skipItems,
    bool? skipTopics,
    int? itemAgeCutoffDays,
    int? topicAgeCutoffDays,
    int? itemForgettingIndexCutoff,
    double? topicAFactorCutoff,
    int? itemPostponeCountCutoff,
    int? topicPostponeCountCutoff,
    double? itemPriorityThreshold,
    double? topicPriorityThreshold,
    bool? modifyItemByForgettingIndex,
    bool? modifyTopicByAFactor,
  }) => SmartPostponeSettings(
    rootElementId: rootElementId ?? this.rootElementId,
    scope: scope ?? this.scope,
    method: method ?? this.method,
    profileName: profileName ?? this.profileName,
    subbranchMode: subbranchMode ?? this.subbranchMode,
    protectedCount: protectedCount ?? this.protectedCount,
    includeNonOutstanding: includeNonOutstanding ?? this.includeNonOutstanding,
    simulate: simulate ?? this.simulate,
    itemDelayPercent: itemDelayPercent ?? this.itemDelayPercent,
    topicDelayPercent: topicDelayPercent ?? this.topicDelayPercent,
    itemMaximumDelayDays: itemMaximumDelayDays ?? this.itemMaximumDelayDays,
    topicMaximumDelayDays: topicMaximumDelayDays ?? this.topicMaximumDelayDays,
    itemMinimumDelayDays: itemMinimumDelayDays ?? this.itemMinimumDelayDays,
    topicMinimumDelayDays: topicMinimumDelayDays ?? this.topicMinimumDelayDays,
    skipItems: skipItems ?? this.skipItems,
    skipTopics: skipTopics ?? this.skipTopics,
    itemAgeCutoffDays: itemAgeCutoffDays ?? this.itemAgeCutoffDays,
    topicAgeCutoffDays: topicAgeCutoffDays ?? this.topicAgeCutoffDays,
    itemForgettingIndexCutoff:
        itemForgettingIndexCutoff ?? this.itemForgettingIndexCutoff,
    topicAFactorCutoff: topicAFactorCutoff ?? this.topicAFactorCutoff,
    itemPostponeCountCutoff:
        itemPostponeCountCutoff ?? this.itemPostponeCountCutoff,
    topicPostponeCountCutoff:
        topicPostponeCountCutoff ?? this.topicPostponeCountCutoff,
    itemPriorityThreshold: itemPriorityThreshold ?? this.itemPriorityThreshold,
    topicPriorityThreshold:
        topicPriorityThreshold ?? this.topicPriorityThreshold,
    modifyItemByForgettingIndex:
        modifyItemByForgettingIndex ?? this.modifyItemByForgettingIndex,
    modifyTopicByAFactor: modifyTopicByAFactor ?? this.modifyTopicByAFactor,
  );

  @override
  bool operator ==(Object other) =>
      other is SmartPostponeSettings &&
      other.rootElementId == rootElementId &&
      other.scope == scope &&
      other.method == method &&
      other.profileName == profileName &&
      other.subbranchMode == subbranchMode &&
      other.protectedCount == protectedCount &&
      other.includeNonOutstanding == includeNonOutstanding &&
      other.simulate == simulate &&
      other.itemDelayPercent == itemDelayPercent &&
      other.topicDelayPercent == topicDelayPercent &&
      other.itemMaximumDelayDays == itemMaximumDelayDays &&
      other.topicMaximumDelayDays == topicMaximumDelayDays &&
      other.itemMinimumDelayDays == itemMinimumDelayDays &&
      other.topicMinimumDelayDays == topicMinimumDelayDays &&
      other.skipItems == skipItems &&
      other.skipTopics == skipTopics &&
      other.itemAgeCutoffDays == itemAgeCutoffDays &&
      other.topicAgeCutoffDays == topicAgeCutoffDays &&
      other.itemForgettingIndexCutoff == itemForgettingIndexCutoff &&
      other.topicAFactorCutoff == topicAFactorCutoff &&
      other.itemPostponeCountCutoff == itemPostponeCountCutoff &&
      other.topicPostponeCountCutoff == topicPostponeCountCutoff &&
      other.itemPriorityThreshold == itemPriorityThreshold &&
      other.topicPriorityThreshold == topicPriorityThreshold &&
      other.modifyItemByForgettingIndex == modifyItemByForgettingIndex &&
      other.modifyTopicByAFactor == modifyTopicByAFactor;

  @override
  int get hashCode => Object.hashAll(<Object>[
    rootElementId,
    scope,
    method,
    profileName,
    subbranchMode,
    protectedCount,
    includeNonOutstanding,
    simulate,
    itemDelayPercent,
    topicDelayPercent,
    itemMaximumDelayDays,
    topicMaximumDelayDays,
    itemMinimumDelayDays,
    topicMinimumDelayDays,
    skipItems,
    skipTopics,
    itemAgeCutoffDays,
    topicAgeCutoffDays,
    itemForgettingIndexCutoff,
    topicAFactorCutoff,
    itemPostponeCountCutoff,
    topicPostponeCountCutoff,
    itemPriorityThreshold,
    topicPriorityThreshold,
    modifyItemByForgettingIndex,
    modifyTopicByAFactor,
  ]);
}

int _jsonInt(Object? raw, int fallback, {required int min, required int max}) {
  final int? value = raw is int
      ? raw
      : raw is num
      ? raw.round()
      : null;
  if (value == null || value < min || value > max) return fallback;
  return value;
}

double _jsonDouble(
  Object? raw,
  double fallback, {
  required double min,
  required double max,
}) {
  if (raw is! num) return fallback;
  final double value = raw.toDouble();
  if (value.isNaN || value < min || value > max) return fallback;
  return value;
}

bool _jsonBool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

T _jsonEnum<T extends Enum>(Object? raw, List<T> values, T fallback) {
  if (raw is! String) return fallback;
  for (final T value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
