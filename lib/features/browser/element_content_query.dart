/// Reads the body of any one element, whatever kind it is.
///
/// The Browser tree lists sources, extracts, and cards side by side, so
/// inspecting a row cannot mean "open the screen that owns this type" — the
/// point of a browser is to see the content without leaving the list. This
/// query is the one place that knows where each kind keeps its text.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:meta/meta.dart';

/// One element's text, in a shape the detail pane can render for any type.
@immutable
final class ElementContent {
  const ElementContent({
    required this.ref,
    required this.title,
    required this.body,
    this.back,
    this.isEditable = false,
    this.notEditableReason,
  });

  final ElementRef ref;

  /// The element's own name: a source's title, or the leading words of a body
  /// that has no name of its own.
  final String title;

  /// The editable text. A card's question, an extract's markdown, a source's
  /// whole document.
  final String body;

  /// A card's answer, absent for every other kind and for cloze cards, whose
  /// answer is derived from the question.
  final String? back;

  /// Whether this pane may write the text back.
  final bool isEditable;

  /// Why it may not, shown in place of the editor's actions.
  final String? notEditableReason;
}

/// Loads the body of one element by reference.
final class ElementContentQuery {
  ElementContentQuery({required ContentRepository content})
    : _content = content;

  final ContentRepository _content;

  /// The content behind [ref], or null when it no longer exists.
  Future<ElementContent?> load(ElementRef ref) async {
    switch (ref.type) {
      case ElementType.source:
        final Source? source = await _content.findSource(ref.id);
        if (source == null) return null;
        return ElementContent(
          ref: ref,
          title: source.title,
          body: source.markdown,
          // A source is edited a block at a time in the Reader, because an
          // edit has to splice into known bounds for every anchor taken from
          // it to survive. Rewriting the whole document from here has no such
          // bounds, so the pane shows it and sends the user to the Reader.
          notEditableReason: 'Open the reader to edit this article’s text.',
        );

      case ElementType.extract:
        final Extract? extract = await _content.findExtract(ref.id);
        if (extract == null) return null;
        final List<Extract> children = await _content.listExtractsOfParent(
          extract.id,
        );
        return ElementContent(
          ref: ref,
          title: _leadingWords(extract.markdown),
          body: extract.markdown,
          isEditable: children.isEmpty,
          notEditableReason: children.isEmpty
              ? null
              : 'Nested extracts point into this text, so it stays fixed.',
        );

      case ElementType.card:
        final Card? card = await _content.findCard(ref.id);
        if (card == null) return null;
        return ElementContent(
          ref: ref,
          title: _leadingWords(card.front),
          body: card.front,
          // A cloze card's answer is the question with the deletion revealed,
          // so offering it as a second field would invite editing a value
          // nothing reads.
          back: card.type == CardType.cloze ? null : card.back,
          isEditable: true,
        );
    }
  }

  static String _leadingWords(String body) {
    final String flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 70) return flat;
    return '${flat.substring(0, 70)}…';
  }
}
