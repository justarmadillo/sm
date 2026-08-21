/// Commands and immutable drafts for turning an element into recall cards.
library;

import '../../domain/content/card.dart';
import '../app_command.dart';

/// One card-making intention inside a batch formulation operation.
sealed class CardDraft {
  const CardDraft();
}

/// One explicit question and answer.
final class QaCardDraft extends CardDraft {
  const QaCardDraft({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// Canonical Anki cloze text.
///
/// One submitted draft creates one card for every distinct `cN` ordinal.
final class ClozeCardDraft extends CardDraft {
  const ClozeCardDraft(this.text);

  final String text;
}

/// Creates one or more independently scheduled cards from an element.
///
/// [parent] is an extract, a source, or null for a standalone item. The
/// parent is intentionally absent from the output transition: it stays
/// scheduled exactly as it was before formulation.
final class FormulateCards extends AppCommand {
  FormulateCards(
    super.operationId, {
    required this.parent,
    required this.drafts,
    super.timestampUtc,
  });

  final CardParent? parent;
  final List<CardDraft> drafts;
}
