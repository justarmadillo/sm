/// Replaying a review history to produce the schedule the current parameters
/// would have produced.
///
/// Rescheduling never invents a review: it replays the grades that actually
/// happened and then records one explicit [Rating.manual] entry to move the
/// live card onto the replayed schedule, so the history stays honest about
/// what was recall and what was a calendar move.
library;

import 'convert.dart';
import 'default.dart';
import 'error.dart';
import 'fsrs.dart';
import 'help.dart';
import 'models.dart';

/// Replays review histories through an [FSRS] instance.
class Reschedule {
  /// Binds the rescheduler to the scheduler whose parameters should apply.
  Reschedule(this.fsrs);

  /// The scheduler used for the replay.
  final FSRS fsrs;

  /// Replays one graded review of [card] at [reviewed].
  RecordLogItem replay(Card card, DateTime reviewed, Rating rating) =>
      fsrs.next(card, reviewed, rating);

  /// Records a manual state change: a forced state, due date, or memory state.
  ///
  /// [state] of [State.newState] resets the card; any other state requires an
  /// explicit [due], because a manual move has no algorithmic interval to fall
  /// back on.
  RecordLogItem handleManualRating(
    Card card,
    State state,
    DateTime reviewed,
    int elapsedDays, {
    double? stability,
    double? difficulty,
    DateTime? due,
  }) {
    final ReviewLog log;
    final Card nextCard;
    if (state == State.newState) {
      log = ReviewLog(
        rating: Rating.manual,
        state: state,
        due: due ?? reviewed,
        stability: card.stability,
        difficulty: card.difficulty,
        elapsedDays: elapsedDays,
        lastElapsedDays: card.elapsedDays,
        scheduledDays: card.scheduledDays,
        learningSteps: card.learningSteps,
        review: reviewed,
      );
      nextCard = createEmptyCard(reviewed)..lastReview = reviewed;
    } else {
      if (due == null) {
        throw FSRSValidationError(
          'reschedule: due is required for manual rating',
        );
      }
      final scheduledDays = dateDiff(due, reviewed, DateDiffUnit.days);
      log = ReviewLog(
        rating: Rating.manual,
        state: card.state,
        due: card.lastReview ?? card.due,
        stability: card.stability,
        difficulty: card.difficulty,
        elapsedDays: elapsedDays,
        lastElapsedDays: card.elapsedDays,
        scheduledDays: card.scheduledDays,
        learningSteps: card.learningSteps,
        review: reviewed,
      );
      nextCard = card.copy()
        ..state = state
        ..due = due
        ..lastReview = reviewed
        ..stability =
            (stability == null || stability == 0) ? card.stability : stability
        ..difficulty = (difficulty == null || difficulty == 0)
            ? card.difficulty
            : difficulty
        ..elapsedDays = elapsedDays
        ..scheduledDays = scheduledDays
        ..reps = card.reps + 1;
    }

    return RecordLogItem(card: nextCard, log: log);
  }

  /// Replays [reviews] from an empty card due at [currentCard]'s due date.
  List<RecordLogItem> reschedule(Card currentCard, List<FSRSHistory> reviews) {
    final collections = <RecordLogItem>[];
    var curCard = createEmptyCard(currentCard.due);
    for (final review in reviews) {
      final reviewedAt = TypeConvert.time(review.review);
      review.review = reviewedAt;
      final RecordLogItem item;
      if (review.rating == Rating.manual) {
        // Mirrors the elapsed-day bookkeeping the scheduler does on init.
        var interval = 0;
        final lastReview = curCard.lastReview;
        if (curCard.state != State.newState && lastReview != null) {
          interval = dateDiff(reviewedAt, lastReview, DateDiffUnit.days);
        }
        final state = review.state;
        if (state == null) {
          throw FSRSValidationError(
            'reschedule: state is required for manual rating',
          );
        }
        item = handleManualRating(
          curCard,
          state,
          reviewedAt,
          interval,
          stability: review.stability,
          difficulty: review.difficulty,
          due: review.due == null ? null : TypeConvert.time(review.due),
        );
      } else {
        item = replay(curCard, reviewedAt, review.rating);
      }
      collections.add(item);
      curCard = item.card;
    }
    return collections;
  }

  /// The manual entry that moves [currentCard] onto the replayed schedule, or
  /// null when the two already agree.
  RecordLogItem? calculateManualRecord(
    Card currentCard,
    Object now,
    RecordLogItem? recordLogItem, {
    bool updateMemory = false,
  }) {
    if (recordLogItem == null) return null;
    final rescheduleCard = recordLogItem.card;
    final log = recordLogItem.log;
    final curCard = TypeConvert.card(currentCard);
    if (curCard.due.millisecondsSinceEpoch ==
        rescheduleCard.due.millisecondsSinceEpoch) {
      return null;
    }
    curCard.scheduledDays =
        dateDiff(rescheduleCard.due, curCard.due, DateDiffUnit.days);
    return handleManualRating(
      curCard,
      rescheduleCard.state,
      TypeConvert.time(now),
      log.elapsedDays,
      stability: updateMemory ? rescheduleCard.stability : null,
      difficulty: updateMemory ? rescheduleCard.difficulty : null,
      due: rescheduleCard.due,
    );
  }
}
