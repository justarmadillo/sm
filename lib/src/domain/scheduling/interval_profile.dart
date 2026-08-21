/// Interval sequences that pace topics.
///
/// SuperMemo's own topic formulas are undocumented, so they are replaced with
/// something transparent: an explicit, user-editable list of day intervals per
/// profile. The final value repeats, so a long-lived topic settles into a
/// steady revisit rhythm instead of disappearing for years.
///
/// This answers "when should I continue processing this?", which is a pacing
/// question. It is deliberately *not* a memory model — that is what FSRS is
/// for, and only cards get it.
library;

import 'package:meta/meta.dart';

/// Identifier of the extract profile.
const String kExtractProfileId = 'extract';

/// A named sequence of day intervals.
@immutable
final class IntervalProfile {
  const IntervalProfile({required this.id, required this.days})
    : assert(days != const <int>[], 'a profile needs at least one interval');

  final String id;

  /// Intervals in days. Index by step; the last value repeats forever.
  final List<int> days;

  /// Interval to use when completing the encounter at [stepIndex].
  int intervalAt(int stepIndex) {
    if (stepIndex < 0) return days.first;
    return stepIndex >= days.length ? days.last : days[stepIndex];
  }

  /// The step after [stepIndex], saturating at the repeating tail.
  int nextStep(int stepIndex) {
    final next = stepIndex + 1;
    return next >= days.length ? days.length - 1 : next;
  }

  @override
  bool operator ==(Object other) => other is IntervalProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'IntervalProfile($id ${days.join(",")})';
}

/// Every profile the scheduler knows about.
@immutable
final class IntervalProfiles {
  const IntervalProfiles(this._byId);

  /// Profiles as the user has edited them in Settings.
  ///
  /// A profile whose sequence was emptied falls back to the shipped default,
  /// because a sequence with no intervals cannot schedule anything.
  factory IntervalProfiles.fromDays(Map<String, List<int>> days) {
    final Map<String, IntervalProfile> byId = <String, IntervalProfile>{};
    for (final MapEntry<String, List<int>> entry in days.entries) {
      if (entry.value.isEmpty) continue;
      byId[entry.key] = IntervalProfile(
        id: entry.key,
        days: List<int>.unmodifiable(entry.value),
      );
    }
    return byId.isEmpty ? IntervalProfiles.defaults() : IntervalProfiles(byId);
  }

  /// The shipped defaults. All of them are editable in Settings.
  factory IntervalProfiles.defaults() =>
      IntervalProfiles(<String, IntervalProfile>{
        'focused': const IntervalProfile(
          id: 'focused',
          days: <int>[1, 2, 3, 5, 7, 10, 14, 21, 30],
        ),
        'normal': const IntervalProfile(
          id: 'normal',
          days: <int>[1, 3, 7, 14, 30, 60, 120, 240, 365],
        ),
        'slow': const IntervalProfile(
          id: 'slow',
          days: <int>[7, 14, 30, 60, 120, 240, 365, 730],
        ),
        kExtractProfileId: const IntervalProfile(
          id: kExtractProfileId,
          days: <int>[1, 3, 7, 14, 30, 60, 120],
        ),
      });

  final Map<String, IntervalProfile> _byId;

  /// Every profile, by id.
  Map<String, IntervalProfile> get all =>
      Map<String, IntervalProfile>.unmodifiable(_byId);

  /// The profile named [id].
  ///
  /// Falls back to `normal` so a renamed or deleted profile degrades to
  /// ordinary pacing instead of stranding the element outside the queue.
  IntervalProfile byId(String id) =>
      _byId[id] ?? _byId['normal'] ?? _byId.values.first;

  /// A copy with [profile] replacing whatever shared its id.
  IntervalProfiles withProfile(IntervalProfile profile) => IntervalProfiles(
    <String, IntervalProfile>{..._byId, profile.id: profile},
  );
}
