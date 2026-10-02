/// Plain requests to save, change, and delete custom-study decks.
library;

import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';

/// Saves the current filter as a new named deck.
final class CreateCustomDeck extends AppCommand {
  CreateCustomDeck(
    super.operationId, {
    required this.name,
    required this.filter,
    super.timestampUtc,
  });
  final String name;
  final CustomDeckFilter filter;
}

/// Renames a deck, replaces its filter, or both.
final class UpdateCustomDeck extends AppCommand {
  UpdateCustomDeck(
    super.operationId, {
    required this.deckId,
    this.name,
    this.filter,
    super.timestampUtc,
  });
  final String deckId;
  final String? name;
  final CustomDeckFilter? filter;
}

/// Deletes a deck for good. The elements it drew from are not touched.
final class DeleteCustomDeck extends AppCommand {
  DeleteCustomDeck(
    super.operationId, {
    required this.deckId,
    super.timestampUtc,
  });
  final String deckId;
}

/// The deck a command created, changed, or deleted.
final class CustomDeckOutcome {
  const CustomDeckOutcome(this.deck);
  final CustomDeck deck;
}
