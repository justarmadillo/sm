/// Rebuilds card memory from genuine review history under a parameter vector.
library;

import 'package:fsrs_dart/fsrs.dart' as fsrs;
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/study_day.dart';

final class FsrsMemoryRecomputer {
  const FsrsMemoryRecomputer({required this.calendar});

  final StudyDayCalendar calendar;

  /// Replays every grade because changed parameters reinterpret the complete
  /// history; current due/lifecycle fields remain application-owned state.
  CardState recompute(
    CardState state, {
    required List<ReviewRecord> reviews,
    required List<double> parameters,
    required String parametersVersion,
  }) {
    if (reviews.isEmpty) return state;
    final ordered = List<ReviewRecord>.of(reviews)
      ..sort(
        (ReviewRecord first, ReviewRecord second) =>
            first.reviewedAtUtc.compareTo(second.reviewedAtUtc),
      );
    final algorithm = fsrs.FSRSAlgorithm(
      fsrs.generatorParameters(w: parameters),
    );
    fsrs.FSRSState? memory;
    DateTime? previousReview;
    for (final ReviewRecord review in ordered) {
      final int elapsedDays = previousReview == null
          ? 0
          : calendar
                .dayOf(previousReview)
                .daysUntil(calendar.dayOf(review.reviewedAtUtc));
      memory = algorithm.nextState(
        memory,
        elapsedDays.toDouble(),
        _rating(review.rating),
      );
      previousReview = review.reviewedAtUtc;
    }
    final before = state.memory;
    final recomputed = CardMemory(
      cardId: before.cardId,
      state: before.state,
      step: before.step,
      stability: memory!.stability,
      difficulty: memory.difficulty,
      repetitionCount: before.repetitionCount,
      lapses: before.lapses,
      lastReviewAtUtc: before.lastReviewAtUtc,
      dueAtUtc: before.dueAtUtc,
      originalDueAtUtc: before.originalDueAtUtc,
      schedulerVersion: before.schedulerVersion,
      parametersVersion: parametersVersion,
      postponeCount: before.postponeCount,
      scheduledDays: before.scheduledDays,
      schedulerName: before.schedulerName,
      revision: before.revision + 1,
    );
    return state.copyWith(memory: recomputed);
  }
}

fsrs.Rating _rating(CardRating rating) => switch (rating) {
  CardRating.again => fsrs.Rating.again,
  CardRating.hard => fsrs.Rating.hard,
  CardRating.good => fsrs.Rating.good,
  CardRating.easy => fsrs.Rating.easy,
};
