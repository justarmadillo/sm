/// Persisted settings for the SM20 scheduler and the rest of the application.
///
/// Scheduler settings in this file mirror the controls and records described
/// by `SM20_AIO_SCHEDULER.md`. They intentionally do not retain the previous
/// capacity-based scheduler's fields or storage keys.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// Which study day an instant belongs to.
@immutable
final class StudyDaySettings {
  const StudyDaySettings({this.zoneId = 'UTC', this.rolloverMinutes = 240});

  /// IANA identifier of the user's home timezone.
  final String zoneId;

  /// Minutes after local midnight at which the study day rolls over.
  final int rolloverMinutes;

  StudyDaySettings copyWith({String? zoneId, int? rolloverMinutes}) =>
      StudyDaySettings(
        zoneId: zoneId ?? this.zoneId,
        rolloverMinutes: rolloverMinutes ?? this.rolloverMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is StudyDaySettings &&
      other.zoneId == zoneId &&
      other.rolloverMinutes == rolloverMinutes;

  @override
  int get hashCode => Object.hash(zoneId, rolloverMinutes);
}

/// SM20's daily Outstanding ordering and stage controls.
@immutable
final class QueueSettings {
  const QueueSettings({
    this.topicPercent = 20,
    this.itemRandomization = 0,
    this.topicRandomization = 0,
    this.autoSort = true,
    this.randomizeFinalDrill = false,
    this.confirmStageTransitions = true,
  });

  /// Percentage of topic-family elements in the merged Outstanding queue.
  final int topicPercent;

  /// Item randomization slider value, from 0 through 100.
  final int itemRandomization;

  /// Topic randomization slider value, from 0 through 100.
  final int topicRandomization;

  /// Whether Outstanding is sorted automatically once per study day.
  final bool autoSort;

  /// Whether Final Drill is randomized before it is served.
  final bool randomizeFinalDrill;

  /// Whether transitions into Final Drill and Pending require confirmation.
  final bool confirmStageTransitions;

  QueueSettings copyWith({
    int? topicPercent,
    int? itemRandomization,
    int? topicRandomization,
    bool? autoSort,
    bool? randomizeFinalDrill,
    bool? confirmStageTransitions,
  }) => QueueSettings(
    topicPercent: topicPercent ?? this.topicPercent,
    itemRandomization: itemRandomization ?? this.itemRandomization,
    topicRandomization: topicRandomization ?? this.topicRandomization,
    autoSort: autoSort ?? this.autoSort,
    randomizeFinalDrill: randomizeFinalDrill ?? this.randomizeFinalDrill,
    confirmStageTransitions:
        confirmStageTransitions ?? this.confirmStageTransitions,
  );

  @override
  bool operator ==(Object other) =>
      other is QueueSettings &&
      other.topicPercent == topicPercent &&
      other.itemRandomization == itemRandomization &&
      other.topicRandomization == topicRandomization &&
      other.autoSort == autoSort &&
      other.randomizeFinalDrill == randomizeFinalDrill &&
      other.confirmStageTransitions == confirmStageTransitions;

  @override
  int get hashCode => Object.hash(
    topicPercent,
    itemRandomization,
    topicRandomization,
    autoSort,
    randomizeFinalDrill,
    confirmStageTransitions,
  );
}

/// The first-interval range used by the browser Remember command.
@immutable
final class RememberSettings {
  const RememberSettings({
    this.firstIntervalLowDays = 1,
    this.firstIntervalHighDays = 1,
  });

  /// Inclusive lower endpoint of the initial interval range.
  final int firstIntervalLowDays;

  /// Inclusive upper endpoint. Zero requests the generated-interval path.
  final int firstIntervalHighDays;

  RememberSettings copyWith({
    int? firstIntervalLowDays,
    int? firstIntervalHighDays,
  }) => RememberSettings(
    firstIntervalLowDays: firstIntervalLowDays ?? this.firstIntervalLowDays,
    firstIntervalHighDays: firstIntervalHighDays ?? this.firstIntervalHighDays,
  );

  @override
  bool operator ==(Object other) =>
      other is RememberSettings &&
      other.firstIntervalLowDays == firstIntervalLowDays &&
      other.firstIntervalHighDays == firstIntervalHighDays;

  @override
  int get hashCode => Object.hash(firstIntervalLowDays, firstIntervalHighDays);
}

/// FSRS knobs and item-review behaviours.
@immutable
final class CardSettings {
  const CardSettings({
    this.desiredRetention = 0.90,
    this.learningStepMinutes = const <int>[1, 10],
    this.relearningStepMinutes = const <int>[10],
    this.maximumIntervalDays = 36500,
    this.enableFuzzing = true,
    this.leechLapses = 8,
    this.burySiblings = true,
  });

  final double desiredRetention;
  final List<int> learningStepMinutes;
  final List<int> relearningStepMinutes;
  final int maximumIntervalDays;
  final bool enableFuzzing;
  final int leechLapses;
  final bool burySiblings;

  CardSettings copyWith({
    double? desiredRetention,
    List<int>? learningStepMinutes,
    List<int>? relearningStepMinutes,
    int? maximumIntervalDays,
    bool? enableFuzzing,
    int? leechLapses,
    bool? burySiblings,
  }) => CardSettings(
    desiredRetention: desiredRetention ?? this.desiredRetention,
    learningStepMinutes: learningStepMinutes ?? this.learningStepMinutes,
    relearningStepMinutes: relearningStepMinutes ?? this.relearningStepMinutes,
    maximumIntervalDays: maximumIntervalDays ?? this.maximumIntervalDays,
    enableFuzzing: enableFuzzing ?? this.enableFuzzing,
    leechLapses: leechLapses ?? this.leechLapses,
    burySiblings: burySiblings ?? this.burySiblings,
  );

  @override
  bool operator ==(Object other) =>
      other is CardSettings &&
      other.desiredRetention == desiredRetention &&
      _sameInts(other.learningStepMinutes, learningStepMinutes) &&
      _sameInts(other.relearningStepMinutes, relearningStepMinutes) &&
      other.maximumIntervalDays == maximumIntervalDays &&
      other.enableFuzzing == enableFuzzing &&
      other.leechLapses == leechLapses &&
      other.burySiblings == burySiblings;

  @override
  int get hashCode => Object.hashAll(<Object>[
    desiredRetention,
    Object.hashAll(learningStepMinutes),
    Object.hashAll(relearningStepMinutes),
    maximumIntervalDays,
    enableFuzzing,
    leechLapses,
    burySiblings,
  ]);
}

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

/// Automatic postponement plus the collection's managed profile registry.
///
/// `Default` is a permanent profile slot because the automatic path loads it
/// by name. Other profiles can be saved under arbitrary non-empty names and
/// assigned to branches for the nested-profile merge described by SM20.
@immutable
final class PostponeSettings {
  const PostponeSettings({
    this.autoEnabled = true,
    this.defaultProfile = const SmartPostponeSettings(),
    this.namedProfiles = const <String, SmartPostponeSettings>{},
    this.branchProfileAssignments = const <int, String>{},
  });

  static const String defaultProfileName = 'Default';

  final bool autoEnabled;

  /// The undeletable profile used by automatic postponement.
  final SmartPostponeSettings defaultProfile;

  /// User-managed profiles, excluding the reserved [defaultProfileName].
  ///
  /// The map key is authoritative. Decoding and profile-management helpers
  /// keep each record's [SmartPostponeSettings.profileName] synchronized with
  /// that key.
  final Map<String, SmartPostponeSettings> namedProfiles;

  /// Branch-root element ID to managed profile name.
  ///
  /// Assignments may reference [defaultProfileName] or a key in
  /// [namedProfiles]. Deleting a named profile also deletes its assignments.
  final Map<int, String> branchProfileAssignments;

  /// Profile names in the same stable order used by the Settings list.
  List<String> get profileNames {
    final List<String> names = namedProfiles.keys.toList()..sort();
    return <String>[defaultProfileName, ...names];
  }

  /// Looks up a managed profile. `Default` can never be absent.
  SmartPostponeSettings? profileNamed(String name) =>
      name == defaultProfileName ? defaultProfile : namedProfiles[name];

  /// Adds or replaces a named profile.
  ///
  /// The reserved Default slot must be changed through [replaceDefault].
  PostponeSettings saveNamedProfile(
    String name,
    SmartPostponeSettings profile,
  ) {
    final String normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(name, 'name', 'profile name cannot be empty');
    }
    if (normalized == defaultProfileName) {
      throw ArgumentError.value(
        name,
        'name',
        'Default is the permanent automatic-postpone profile',
      );
    }
    return copyWith(
      namedProfiles: <String, SmartPostponeSettings>{
        ...namedProfiles,
        normalized: profile.copyWith(profileName: normalized),
      },
    );
  }

  /// Replaces the permanent Default slot from any managed profile record.
  PostponeSettings replaceDefault(SmartPostponeSettings profile) => copyWith(
    defaultProfile: profile.copyWith(profileName: defaultProfileName),
  );

  /// Deletes a named profile and every branch assignment that refers to it.
  PostponeSettings deleteNamedProfile(String name) {
    if (name == defaultProfileName || !namedProfiles.containsKey(name)) {
      return this;
    }
    return copyWith(
      namedProfiles: <String, SmartPostponeSettings>{
        for (final MapEntry<String, SmartPostponeSettings> entry
            in namedProfiles.entries)
          if (entry.key != name) entry.key: entry.value,
      },
      branchProfileAssignments: <int, String>{
        for (final MapEntry<int, String> entry
            in branchProfileAssignments.entries)
          if (entry.value != name) entry.key: entry.value,
      },
    );
  }

  /// Attaches a managed profile to a branch root.
  PostponeSettings assignBranchProfile(int rootElementId, String profileName) {
    if (rootElementId < 0 || rootElementId > 0xFFFFFFFF) {
      throw RangeError.range(rootElementId, 0, 0xFFFFFFFF, 'rootElementId');
    }
    if (profileNamed(profileName) == null) {
      throw ArgumentError.value(
        profileName,
        'profileName',
        'branch assignments must reference a managed profile',
      );
    }
    return copyWith(
      branchProfileAssignments: <int, String>{
        ...branchProfileAssignments,
        rootElementId: profileName,
      },
    );
  }

  /// Removes the profile attached to [rootElementId], if any.
  PostponeSettings unassignBranchProfile(int rootElementId) => copyWith(
    branchProfileAssignments: <int, String>{
      for (final MapEntry<int, String> entry
          in branchProfileAssignments.entries)
        if (entry.key != rootElementId) entry.key: entry.value,
    },
  );

  PostponeSettings copyWith({
    bool? autoEnabled,
    SmartPostponeSettings? defaultProfile,
    Map<String, SmartPostponeSettings>? namedProfiles,
    Map<int, String>? branchProfileAssignments,
  }) => PostponeSettings(
    autoEnabled: autoEnabled ?? this.autoEnabled,
    defaultProfile: defaultProfile ?? this.defaultProfile,
    namedProfiles: namedProfiles ?? this.namedProfiles,
    branchProfileAssignments:
        branchProfileAssignments ?? this.branchProfileAssignments,
  );

  @override
  bool operator ==(Object other) =>
      other is PostponeSettings &&
      other.autoEnabled == autoEnabled &&
      other.defaultProfile == defaultProfile &&
      _sameMap(other.namedProfiles, namedProfiles) &&
      _sameMap(other.branchProfileAssignments, branchProfileAssignments);

  @override
  int get hashCode => Object.hash(
    autoEnabled,
    _mapHash(namedProfiles),
    _mapHash(branchProfileAssignments),
    defaultProfile,
  );
}

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
      _sameNullableInts(other.intervalFactorMatrix, intervalFactorMatrix);

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

/// Reader behaviour that is a preference rather than a scheduling rule.
@immutable
final class ReaderSettings {
  const ReaderSettings({this.reminderWords = 500});

  final int reminderWords;

  ReaderSettings copyWith({int? reminderWords}) =>
      ReaderSettings(reminderWords: reminderWords ?? this.reminderWords);

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings && other.reminderWords == reminderWords;

  @override
  int get hashCode => reminderWords.hashCode;
}

/// The local rotating diagnostic log and the developer panel.
@immutable
final class DiagnosticsSettings {
  const DiagnosticsSettings({
    this.logEnabled = true,
    this.logMaxBytes = 2097152,
    this.logRetainedFiles = 5,
    this.showContentInPanel = false,
  });

  final bool logEnabled;
  final int logMaxBytes;
  final int logRetainedFiles;
  final bool showContentInPanel;

  DiagnosticsSettings copyWith({
    bool? logEnabled,
    int? logMaxBytes,
    int? logRetainedFiles,
    bool? showContentInPanel,
  }) => DiagnosticsSettings(
    logEnabled: logEnabled ?? this.logEnabled,
    logMaxBytes: logMaxBytes ?? this.logMaxBytes,
    logRetainedFiles: logRetainedFiles ?? this.logRetainedFiles,
    showContentInPanel: showContentInPanel ?? this.showContentInPanel,
  );

  @override
  bool operator ==(Object other) =>
      other is DiagnosticsSettings &&
      other.logEnabled == logEnabled &&
      other.logMaxBytes == logMaxBytes &&
      other.logRetainedFiles == logRetainedFiles &&
      other.showContentInPanel == showContentInPanel;

  @override
  int get hashCode => Object.hash(
    logEnabled,
    logMaxBytes,
    logRetainedFiles,
    showContentInPanel,
  );
}

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
        rolloverMinutes: _int(
          stored['study.rollover_minutes'],
          fallback.studyDay.rolloverMinutes,
          min: 0,
          max: 1439,
        ),
      ),
      queue: QueueSettings(
        topicPercent: _int(
          stored['queue.topic_percent'],
          fallback.queue.topicPercent,
          min: 0,
          max: 100,
        ),
        itemRandomization: _int(
          stored['queue.item_randomization'],
          fallback.queue.itemRandomization,
          min: 0,
          max: 100,
        ),
        topicRandomization: _int(
          stored['queue.topic_randomization'],
          fallback.queue.topicRandomization,
          min: 0,
          max: 100,
        ),
        autoSort: _bool(stored['queue.auto_sort'], fallback.queue.autoSort),
        randomizeFinalDrill: _bool(
          stored['queue.randomize_final_drill'],
          fallback.queue.randomizeFinalDrill,
        ),
        confirmStageTransitions: _bool(
          stored['queue.confirm_stage_transitions'],
          fallback.queue.confirmStageTransitions,
        ),
      ),
      remember: RememberSettings(
        firstIntervalLowDays: _int(
          stored['remember.first_interval_low_days'],
          fallback.remember.firstIntervalLowDays,
          min: 1,
          max: 365,
        ),
        firstIntervalHighDays: _int(
          stored['remember.first_interval_high_days'],
          fallback.remember.firstIntervalHighDays,
          min: 0,
          max: 365,
        ),
      ),
      cards: CardSettings(
        desiredRetention: _double(
          stored['card.desired_retention'],
          fallback.cards.desiredRetention,
          min: 0.7,
          max: 0.99,
        ),
        learningStepMinutes: _positiveIntListOr(
          stored['card.learning_steps'],
          fallback.cards.learningStepMinutes,
        ),
        relearningStepMinutes: _positiveIntListOr(
          stored['card.relearning_steps'],
          fallback.cards.relearningStepMinutes,
        ),
        maximumIntervalDays: _int(
          stored['card.maximum_interval_days'],
          fallback.cards.maximumIntervalDays,
          min: 1,
          max: 36500,
        ),
        enableFuzzing: _bool(
          stored['card.enable_fuzzing'],
          fallback.cards.enableFuzzing,
        ),
        leechLapses: _int(
          stored['card.leech_lapses'],
          fallback.cards.leechLapses,
          min: 1,
          max: 999,
        ),
        burySiblings: _bool(
          stored['card.bury_siblings'],
          fallback.cards.burySiblings,
        ),
      ),
      postpone: PostponeSettings(
        autoEnabled: _bool(
          stored['postpone.auto_enabled'],
          fallback.postpone.autoEnabled,
        ),
        namedProfiles: _namedProfilesOr(
          stored['postpone.named_profiles'],
          fallback.postpone.namedProfiles,
        ),
        branchProfileAssignments: _branchAssignmentsOr(
          stored['postpone.branch_profiles'],
          fallback.postpone.branchProfileAssignments,
        ),
        defaultProfile: SmartPostponeSettings(
          rootElementId: _int(
            stored['postpone.default.root_element_id'],
            smartFallback.rootElementId,
            min: 0,
            max: 0xFFFFFFFF,
          ),
          scope: _enumValue(
            stored['postpone.default.scope'],
            SmartPostponeScope.values,
            smartFallback.scope,
          ),
          method: _enumValue(
            stored['postpone.default.method'],
            SmartPostponeMethod.values,
            smartFallback.method,
          ),
          profileName:
              stored['postpone.default.profile_name'] ??
              smartFallback.profileName,
          subbranchMode: _enumValue(
            stored['postpone.default.subbranch_mode'],
            SmartPostponeSubbranchMode.values,
            smartFallback.subbranchMode,
          ),
          protectedCount: _int(
            stored['postpone.default.protected_count'],
            smartFallback.protectedCount,
            min: 1,
            max: 20000,
          ),
          includeNonOutstanding: _bool(
            stored['postpone.default.include_non_outstanding'],
            smartFallback.includeNonOutstanding,
          ),
          simulate: _bool(
            stored['postpone.default.simulate'],
            smartFallback.simulate,
          ),
          itemDelayPercent: _int(
            stored['postpone.default.item_delay_percent'],
            smartFallback.itemDelayPercent,
            min: 1,
            max: 400,
          ),
          topicDelayPercent: _int(
            stored['postpone.default.topic_delay_percent'],
            smartFallback.topicDelayPercent,
            min: 1,
            max: 1900,
          ),
          itemMaximumDelayDays: _int(
            stored['postpone.default.item_maximum_delay_days'],
            smartFallback.itemMaximumDelayDays,
            min: 1,
            max: 300,
          ),
          topicMaximumDelayDays: _int(
            stored['postpone.default.topic_maximum_delay_days'],
            smartFallback.topicMaximumDelayDays,
            min: 1,
            max: 500,
          ),
          itemMinimumDelayDays: _int(
            stored['postpone.default.item_minimum_delay_days'],
            smartFallback.itemMinimumDelayDays,
            min: 1,
            max: 30,
          ),
          topicMinimumDelayDays: _int(
            stored['postpone.default.topic_minimum_delay_days'],
            smartFallback.topicMinimumDelayDays,
            min: 1,
            max: 100,
          ),
          skipItems: _bool(
            stored['postpone.default.skip_items'],
            smartFallback.skipItems,
          ),
          skipTopics: _bool(
            stored['postpone.default.skip_topics'],
            smartFallback.skipTopics,
          ),
          itemAgeCutoffDays: _int(
            stored['postpone.default.item_age_cutoff_days'],
            smartFallback.itemAgeCutoffDays,
            min: 2,
            max: 4000,
          ),
          topicAgeCutoffDays: _int(
            stored['postpone.default.topic_age_cutoff_days'],
            smartFallback.topicAgeCutoffDays,
            min: 2,
            max: 4000,
          ),
          itemForgettingIndexCutoff: _int(
            stored['postpone.default.item_forgetting_index_cutoff'],
            smartFallback.itemForgettingIndexCutoff,
            min: 3,
            max: 20,
          ),
          topicAFactorCutoff: _double(
            stored['postpone.default.topic_a_factor_cutoff'],
            smartFallback.topicAFactorCutoff,
            min: 1.01,
            max: 6,
          ),
          itemPostponeCountCutoff: _int(
            stored['postpone.default.item_postpone_count_cutoff'],
            smartFallback.itemPostponeCountCutoff,
            min: 1,
            max: 255,
          ),
          topicPostponeCountCutoff: _int(
            stored['postpone.default.topic_postpone_count_cutoff'],
            smartFallback.topicPostponeCountCutoff,
            min: 1,
            max: 255,
          ),
          itemPriorityThreshold: _double(
            stored['postpone.default.item_priority_threshold'],
            smartFallback.itemPriorityThreshold,
            min: 0.01,
            max: 100,
          ),
          topicPriorityThreshold: _double(
            stored['postpone.default.topic_priority_threshold'],
            smartFallback.topicPriorityThreshold,
            min: 0.0001,
            max: 100,
          ),
          modifyItemByForgettingIndex: _bool(
            stored['postpone.default.modify_item_by_forgetting_index'],
            smartFallback.modifyItemByForgettingIndex,
          ),
          modifyTopicByAFactor: _bool(
            stored['postpone.default.modify_topic_by_a_factor'],
            smartFallback.modifyTopicByAFactor,
          ),
        ),
      ),
      mercy: MercySettings(
        mode: _enumValue(
          stored['mercy.mode'],
          MercyMode.values,
          fallback.mercy.mode,
        ),
        reschedulingDays: _int(
          stored['mercy.rescheduling_days'],
          fallback.mercy.reschedulingDays,
          min: 1,
          max: 3650,
        ),
        gatheringDays: _int(
          stored['mercy.gathering_days'],
          fallback.mercy.gatheringDays,
          min: 1,
          max: 3650,
        ),
        dailyCap: _int(
          stored['mercy.daily_cap'],
          fallback.mercy.dailyCap,
          min: 1,
          max: 5000,
        ),
        includeFuture: _bool(
          stored['mercy.include_future'],
          fallback.mercy.includeFuture,
        ),
        importanceWeight: _weight(
          stored['mercy.importance_weight'],
          fallback.mercy.importanceWeight,
        ),
        latenessWeight: _weight(
          stored['mercy.lateness_weight'],
          fallback.mercy.latenessWeight,
        ),
        investmentWeight: _weight(
          stored['mercy.investment_weight'],
          fallback.mercy.investmentWeight,
        ),
        easinessWeight: _weight(
          stored['mercy.easiness_weight'],
          fallback.mercy.easinessWeight,
        ),
        recencyWeight: _weight(
          stored['mercy.recency_weight'],
          fallback.mercy.recencyWeight,
        ),
        intervalFactorMatrix: _matrixOr(
          stored['mercy.interval_factor_matrix'],
          fallback.mercy.intervalFactorMatrix,
        ),
      ),
      reader: ReaderSettings(
        reminderWords: _int(
          stored['reader.reminder_words'],
          fallback.reader.reminderWords,
          min: 0,
          max: 100000,
        ),
      ),
      diagnostics: DiagnosticsSettings(
        logEnabled: _bool(
          stored['diagnostics.log_enabled'],
          fallback.diagnostics.logEnabled,
        ),
        logMaxBytes: _int(
          stored['diagnostics.log_max_bytes'],
          fallback.diagnostics.logMaxBytes,
          min: 4096,
          max: 536870912,
        ),
        logRetainedFiles: _int(
          stored['diagnostics.log_retained_files'],
          fallback.diagnostics.logRetainedFiles,
          min: 1,
          max: 100,
        ),
        showContentInPanel: _bool(
          stored['diagnostics.show_content'],
          fallback.diagnostics.showContentInPanel,
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
      'queue.auto_sort': '${queue.autoSort}',
      'queue.randomize_final_drill': '${queue.randomizeFinalDrill}',
      'queue.confirm_stage_transitions': '${queue.confirmStageTransitions}',
      'remember.first_interval_low_days': '${remember.firstIntervalLowDays}',
      'remember.first_interval_high_days': '${remember.firstIntervalHighDays}',
      'card.desired_retention': '${cards.desiredRetention}',
      'card.learning_steps': cards.learningStepMinutes.join(','),
      'card.relearning_steps': cards.relearningStepMinutes.join(','),
      'card.maximum_interval_days': '${cards.maximumIntervalDays}',
      'card.enable_fuzzing': '${cards.enableFuzzing}',
      'card.leech_lapses': '${cards.leechLapses}',
      'card.bury_siblings': '${cards.burySiblings}',
      'postpone.auto_enabled': '${postpone.autoEnabled}',
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
          '${smart.includeNonOutstanding}',
      'postpone.default.simulate': '${smart.simulate}',
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
      'postpone.default.skip_items': '${smart.skipItems}',
      'postpone.default.skip_topics': '${smart.skipTopics}',
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
          '${smart.modifyItemByForgettingIndex}',
      'postpone.default.modify_topic_by_a_factor':
          '${smart.modifyTopicByAFactor}',
      'mercy.mode': mercy.mode.name,
      'mercy.rescheduling_days': '${mercy.reschedulingDays}',
      'mercy.gathering_days': '${mercy.gatheringDays}',
      'mercy.daily_cap': '${mercy.dailyCap}',
      'mercy.include_future': '${mercy.includeFuture}',
      'mercy.importance_weight': '${mercy.importanceWeight}',
      'mercy.lateness_weight': '${mercy.latenessWeight}',
      'mercy.investment_weight': '${mercy.investmentWeight}',
      'mercy.easiness_weight': '${mercy.easinessWeight}',
      'mercy.recency_weight': '${mercy.recencyWeight}',
      // Empty explicitly clears a previously imported optional matrix.
      'mercy.interval_factor_matrix':
          mercy.intervalFactorMatrix?.join(',') ?? '',
      'reader.reminder_words': '${reader.reminderWords}',
      'diagnostics.log_enabled': '${diagnostics.logEnabled}',
      'diagnostics.log_max_bytes': '${diagnostics.logMaxBytes}',
      'diagnostics.log_retained_files': '${diagnostics.logRetainedFiles}',
      'diagnostics.show_content': '${diagnostics.showContentInPanel}',
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

const Object _notProvided = Object();

bool _sameInts(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _sameNullableInts(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  return _sameInts(a, b);
}

int _int(String? raw, int fallback, {required int min, required int max}) {
  final int? parsed = raw == null ? null : int.tryParse(raw.trim());
  if (parsed == null) return fallback;
  return parsed.clamp(min, max);
}

double _double(
  String? raw,
  double fallback, {
  required double min,
  required double max,
}) {
  final double? parsed = raw == null ? null : double.tryParse(raw.trim());
  if (parsed == null || !parsed.isFinite) return fallback;
  return parsed.clamp(min, max);
}

double _weight(String? raw, double fallback) =>
    _double(raw, fallback, min: 0, max: 1000000);

bool _bool(String? raw, bool fallback) => switch (raw?.trim().toLowerCase()) {
  'true' || '1' || 'yes' => true,
  'false' || '0' || 'no' => false,
  _ => fallback,
};

T _enumValue<T extends Enum>(String? raw, List<T> values, T fallback) {
  final String? normalized = raw?.trim();
  if (normalized == null) return fallback;
  for (final T value in values) {
    if (value.name == normalized) return value;
  }
  return fallback;
}

List<int> _positiveIntListOr(String? raw, List<int> fallback) {
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

List<int>? _matrixOr(String? raw, List<int>? fallback) {
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

bool _sameMap<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final MapEntry<K, V> entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Order-independent hash so two equal maps built in different insertion
/// orders — which decoding routinely produces — cannot disagree.
int _mapHash<K, V>(Map<K, V> map) {
  var accumulated = 0;
  for (final MapEntry<K, V> entry in map.entries) {
    accumulated ^= Object.hash(entry.key, entry.value);
  }
  return Object.hash(map.length, accumulated);
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

Map<String, SmartPostponeSettings> _namedProfilesOr(
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

Map<int, String> _branchAssignmentsOr(String? raw, Map<int, String> fallback) {
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
