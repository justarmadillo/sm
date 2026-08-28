/// Persisted collection-wide state required by the SM20 scheduler.
library;

import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';
import 'package:meta/meta.dart';

@immutable
final class Sm20CollectionState {
  const Sm20CollectionState({
    this.prngSeed = 0,
    this.learningStartDay,
    this.lastAutomaticSortDay,
    this.lastAutomaticPostponeDay,
    this.lastCollectionUseUtc,
    this.learningMode = 0,
    this.outstanding = const <ElementRef>[],
    this.outstandingItems = const <ElementRef>[],
    this.outstandingTopics = const <ElementRef>[],
    this.pending = const <ElementRef>[],
    this.finalDrill = const <ElementRef>[],
    this.subsetQueues = const <String, List<ElementRef>>{},
  });

  final int prngSeed;
  final StudyDay? learningStartDay;
  final StudyDay? lastAutomaticSortDay;
  final StudyDay? lastAutomaticPostponeDay;
  final DateTime? lastCollectionUseUtc;
  final int learningMode;

  /// Combined daily Outstanding order.
  final List<ElementRef> outstanding;

  /// Priority-sorted type stores saved by the daily sort.
  final List<ElementRef> outstandingItems;
  final List<ElementRef> outstandingTopics;

  /// Separate fallback learning stages.
  final List<ElementRef> pending;
  final List<ElementRef> finalDrill;
  final Map<String, List<ElementRef>> subsetQueues;

  Sm20CollectionState copyWith({
    int? prngSeed,
    Object? learningStartDay = _keep,
    Object? lastAutomaticSortDay = _keep,
    Object? lastAutomaticPostponeDay = _keep,
    Object? lastCollectionUseUtc = _keep,
    int? learningMode,
    List<ElementRef>? outstanding,
    List<ElementRef>? outstandingItems,
    List<ElementRef>? outstandingTopics,
    List<ElementRef>? pending,
    List<ElementRef>? finalDrill,
    Map<String, List<ElementRef>>? subsetQueues,
  }) => Sm20CollectionState(
    prngSeed: prngSeed ?? this.prngSeed,
    learningStartDay: identical(learningStartDay, _keep)
        ? this.learningStartDay
        : learningStartDay as StudyDay?,
    lastAutomaticSortDay: identical(lastAutomaticSortDay, _keep)
        ? this.lastAutomaticSortDay
        : lastAutomaticSortDay as StudyDay?,
    lastAutomaticPostponeDay: identical(lastAutomaticPostponeDay, _keep)
        ? this.lastAutomaticPostponeDay
        : lastAutomaticPostponeDay as StudyDay?,
    lastCollectionUseUtc: identical(lastCollectionUseUtc, _keep)
        ? this.lastCollectionUseUtc
        : lastCollectionUseUtc as DateTime?,
    learningMode: learningMode ?? this.learningMode,
    outstanding: List<ElementRef>.unmodifiable(outstanding ?? this.outstanding),
    outstandingItems: List<ElementRef>.unmodifiable(
      outstandingItems ?? this.outstandingItems,
    ),
    outstandingTopics: List<ElementRef>.unmodifiable(
      outstandingTopics ?? this.outstandingTopics,
    ),
    pending: List<ElementRef>.unmodifiable(pending ?? this.pending),
    finalDrill: List<ElementRef>.unmodifiable(finalDrill ?? this.finalDrill),
    subsetQueues:
        Map<String, List<ElementRef>>.unmodifiable(<String, List<ElementRef>>{
          for (final MapEntry<String, List<ElementRef>> entry
              in (subsetQueues ?? this.subsetQueues).entries)
            entry.key: List<ElementRef>.unmodifiable(entry.value),
        }),
  );

  bool get anythingOutstanding =>
      outstanding.isNotEmpty || finalDrill.isNotEmpty || pending.isNotEmpty;
}

const Object _keep = Object();
