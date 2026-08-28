/// What the app promises about saving and loading the things you read.
///
/// Sources, their text, the blocks parsed out of it, extracts, and cards.
/// Nothing here mentions Drift, SQL, or Flutter, so a screen can be tested
/// against a hand-written stand-in.
library;

import 'package:incremental_reader/documents/apply_source_edit.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/source_edit.dart';
import 'package:incremental_reader/documents/text_splice.dart';

/// Sources, their parsed documents, extracts, and cards.
abstract interface class ContentRepository {
  /// Stores a newly imported source together with its derived blocks.
  Future<void> insertSource(Source source, Document document);

  /// The source with [id], or null.
  Future<Source?> findSource(String id);

  /// The parsed document for [sourceId], or null.
  Future<Document?> findDocument(String sourceId);

  /// Every source, newest import first.
  Future<List<Source>> listSources();

  /// Replaces mutable source fields: title, pace, resume position, folder.
  Future<void> updateSource(Source source);

  /// Updates only the authoritative marker and returns the stored source.
  Future<Source?> setResumeMarker(String sourceId, ReaderAnchor anchor);

  /// Updates only the scratch scroll position and returns the stored source.
  Future<Source?> setSoftPosition(String sourceId, ReaderAnchor anchor);

  /// Atomically promotes the stored soft position to the marker.
  Future<Source?> confirmSoftPosition(String sourceId);

  /// Applies one splice to a source's text, in a single transaction.
  ///
  /// Everything that points into the text moves with it: both reading
  /// positions, and every direct child's recorded range. Nothing
  /// scheduling-related is read or written — editing text is not a repetition
  /// and must never disturb a due date.
  ///
  /// [baseContentRevision] is the revision the caller believed it was editing.
  /// A mismatch yields [SourceEditConflict] and writes nothing, so two windows
  /// editing the same source cannot silently overwrite one another.
  Future<SourceEditResult> applySourceEdit({
    required String sourceId,
    required TextSplice splice,
    required int baseContentRevision,
    required String operationId,
    required DateTime nowUtc,
    bool isUndo = false,
    SourceEditRestore? restore,
  });

  /// The edit journal for [sourceId], oldest first.
  Future<List<SourceEdit>> listSourceEdits(String sourceId);

  /// The most recent edit applied to [sourceId], or null.
  Future<SourceEdit?> latestSourceEdit(String sourceId);

  /// Stores a new extract.
  Future<void> insertExtract(Extract extract);

  /// The extract with [id], or null.
  Future<Extract?> findExtract(String id);

  /// Extracts whose provenance names [parentId], in creation order.
  Future<List<Extract>> listExtractsOfParent(String parentId);

  /// Every extract taken from [sourceId], including nested ones.
  Future<List<Extract>> listExtractsOfSource(String sourceId);

  /// How many extracts each of [sourceIds] has produced.
  Future<Map<String, int>> countExtractsBySource(List<String> sourceIds);

  /// Replaces an extract's editable text.
  Future<void> updateExtract(Extract extract);

  /// Removes an extract outright. Used by Undo, which must leave no trace.
  Future<void> deleteExtract(String id);

  /// Stores newly formulated cards.
  Future<void> insertCards(List<Card> cards);

  /// The card with [id], or null.
  Future<Card?> findCard(String id);

  /// Cards formulated from [extractId].
  Future<List<Card>> listCardsOfExtract(String extractId);

  /// Cards formulated directly from [sourceId], without an extract between.
  Future<List<Card>> listCardsOfSource(String sourceId);

  /// Replaces a card's text, including edits made during review.
  Future<void> updateCard(Card card);

  /// Cards formulated from the same parent as [cardId], excluding it.
  ///
  /// Sibling burying needs exactly this: three clozes cut from one sentence
  /// give each other away, so answering one pushes the rest off today.
  Future<List<Card>> listSiblingCards(String cardId);
}
