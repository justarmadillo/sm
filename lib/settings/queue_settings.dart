/// How today's queue is filled: daily caps and the topic/card mix.///
/// Mirrors the controls described by `SM20_AIO_SCHEDULER.md`.
library;

import 'package:meta/meta.dart';

/// SM20's daily Outstanding ordering and stage controls.
@immutable
final class QueueSettings {
  const QueueSettings({
    this.topicPercent = 20,
    this.itemRandomization = 0,
    this.topicRandomization = 0,
    this.shouldSortAutomatically = true,
    this.shouldRandomizeFinalDrill = false,
    this.shouldConfirmStageTransitions = true,
  });

  /// Percentage of topic-family elements in the merged Outstanding queue.
  final int topicPercent;

  /// Item randomization slider value, from 0 through 100.
  final int itemRandomization;

  /// Topic randomization slider value, from 0 through 100.
  final int topicRandomization;

  /// Whether Outstanding is sorted automatically once per study day.
  final bool shouldSortAutomatically;

  /// Whether Final Drill is randomized before it is served.
  final bool shouldRandomizeFinalDrill;

  /// Whether transitions into Final Drill and Pending require confirmation.
  final bool shouldConfirmStageTransitions;

  QueueSettings copyWith({
    int? topicPercent,
    int? itemRandomization,
    int? topicRandomization,
    bool? shouldSortAutomatically,
    bool? shouldRandomizeFinalDrill,
    bool? shouldConfirmStageTransitions,
  }) => QueueSettings(
    topicPercent: topicPercent ?? this.topicPercent,
    itemRandomization: itemRandomization ?? this.itemRandomization,
    topicRandomization: topicRandomization ?? this.topicRandomization,
    shouldSortAutomatically: shouldSortAutomatically ?? this.shouldSortAutomatically,
    shouldRandomizeFinalDrill: shouldRandomizeFinalDrill ?? this.shouldRandomizeFinalDrill,
    shouldConfirmStageTransitions:
        shouldConfirmStageTransitions ?? this.shouldConfirmStageTransitions,
  );

  @override
  bool operator ==(Object other) =>
      other is QueueSettings &&
      other.topicPercent == topicPercent &&
      other.itemRandomization == itemRandomization &&
      other.topicRandomization == topicRandomization &&
      other.shouldSortAutomatically == shouldSortAutomatically &&
      other.shouldRandomizeFinalDrill == shouldRandomizeFinalDrill &&
      other.shouldConfirmStageTransitions == shouldConfirmStageTransitions;

  @override
  int get hashCode => Object.hash(
    topicPercent,
    itemRandomization,
    topicRandomization,
    shouldSortAutomatically,
    shouldRandomizeFinalDrill,
    shouldConfirmStageTransitions,
  );
}
