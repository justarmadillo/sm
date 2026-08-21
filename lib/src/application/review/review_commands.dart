/// Commands for recall reviews.
library;

import '../../domain/scheduling/card_scheduler.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/study_day.dart';
import '../app_command.dart';

/// Grade one scheduled recall.
final class ReviewCard extends AppCommand {
  ReviewCard(
    super.operationId, {
    required this.cardId,
    required this.rating,
    this.elapsedMs,
    this.isPractice = false,
    super.timestampUtc,
  });

  final String cardId;
  final CardRating rating;
  final int? elapsedMs;

  /// A subset-review grade.
  ///
  /// Logged and flagged, but never allowed to touch FSRS state, due dates, or
  /// daily admission, and excluded from any future parameter optimization —
  /// nothing about the schedule changed, so it was not a measurement of a
  /// scheduled recall.
  final bool isPractice;
}

/// Take back the most recent grade.
///
/// A state restore, not an inverse calculation: FSRS is not invertible, so the
/// only trustworthy way back is the pre-review snapshot the review event
/// carries. The event is removed in the same transaction, which is the one
/// place the append-only log is allowed to shrink.
final class UndoLastReview extends AppCommand {
  UndoLastReview(super.operationId, {this.cardId, super.timestampUtc});

  /// Restrict the undo to one card, or null for whatever was graded last.
  final String? cardId;
}

/// Fix a card's wording without leaving the review flow.
///
/// Never reschedules. A typo found mid-review is not new evidence about
/// memory, and rescheduling on an edit would punish the user for improving
/// their own material.
final class EditCard extends AppCommand {
  EditCard(
    super.operationId, {
    required this.cardId,
    this.front,
    this.back,
    super.timestampUtc,
  });

  final String cardId;

  /// New question, or cloze text in canonical `{{c1::answer}}` form.
  final String? front;

  /// New answer. Ignored for cloze cards, whose answer is derived.
  final String? back;
}

/// Move a card's eligibility without reviewing it.
final class PostponeCard extends AppCommand {
  PostponeCard(
    super.operationId, {
    required this.cardId,
    this.until,
    this.kind = DeferralKind.manual,
    super.timestampUtc,
  });

  final String cardId;

  /// Explicit target day, or null to scale the delay by the card's own
  /// interval — a fixed +1 day just returns it tomorrow into the same queue.
  final StudyDay? until;

  final DeferralKind kind;
}
