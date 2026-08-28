/// How automatic postponement reacts to an overloaded day.///
/// Mirrors the controls described by `SM20_AIO_SCHEDULER.md`.
library;

import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:meta/meta.dart';

/// Automatic postponement plus the collection's managed profile registry.
///
/// `Default` is a permanent profile slot because the automatic path loads it
/// by name. Other profiles can be saved under arbitrary non-empty names and
/// assigned to branches for the nested-profile merge described by SM20.
@immutable
final class PostponeSettings {
  const PostponeSettings({
    this.isAutomaticPostponeEnabled = true,
    this.defaultProfile = const SmartPostponeSettings(),
    this.namedProfiles = const <String, SmartPostponeSettings>{},
    this.branchProfileAssignments = const <int, String>{},
  });

  static const String defaultProfileName = 'Default';

  final bool isAutomaticPostponeEnabled;

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
    bool? isAutomaticPostponeEnabled,
    SmartPostponeSettings? defaultProfile,
    Map<String, SmartPostponeSettings>? namedProfiles,
    Map<int, String>? branchProfileAssignments,
  }) => PostponeSettings(
    isAutomaticPostponeEnabled: isAutomaticPostponeEnabled ?? this.isAutomaticPostponeEnabled,
    defaultProfile: defaultProfile ?? this.defaultProfile,
    namedProfiles: namedProfiles ?? this.namedProfiles,
    branchProfileAssignments:
        branchProfileAssignments ?? this.branchProfileAssignments,
  );

  @override
  bool operator ==(Object other) =>
      other is PostponeSettings &&
      other.isAutomaticPostponeEnabled == isAutomaticPostponeEnabled &&
      other.defaultProfile == defaultProfile &&
      _sameMap(other.namedProfiles, namedProfiles) &&
      _sameMap(other.branchProfileAssignments, branchProfileAssignments);

  @override
  int get hashCode => Object.hash(
    isAutomaticPostponeEnabled,
    _mapHash(namedProfiles),
    _mapHash(branchProfileAssignments),
    defaultProfile,
  );
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
