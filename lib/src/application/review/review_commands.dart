/// Commands for recall reviews.
library;

import '../../domain/scheduling/card_scheduler.dart';
import '../app_command.dart';

final class ReviewCard extends AppCommand {
  ReviewCard(
    super.operationId, {
    required this.cardId,
    required this.rating,
    this.elapsedMs,
    super.timestampUtc,
  });

  final String cardId;
  final CardRating rating;
  final int? elapsedMs;
}
