/// Verifies minimal full-document rewrites and the anchors they leave intact.
library;

import 'package:incremental_reader/documents/apply_source_edit.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/document_edit.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/shared/utf8_offsets.dart';
import 'package:test/test.dart';

void main() {
  test('a paragraph rewrite splices only the changed text', () {
    const String markdown =
        'First paragraph.\n\nSecond old paragraph.\n\nThird.';
    final Document document = Document.parse(
      sourceId: 'source-1',
      markdown: markdown,
    );

    final splice = spliceForDocumentRewrite(
      document,
      'First paragraph.\n\nSecond new paragraph.\n\nThird.',
    );
    final Utf8OffsetIndex offsets = Utf8OffsetIndex(markdown);
    final int changedStart = markdown.indexOf('old');

    expect(splice.startUtf8, offsets.toUtf8(changedStart));
    expect(splice.endUtf8, offsets.toUtf8(changedStart + 3));
    expect(splice.inserted, 'new');
    expect(splice.applyTo(markdown), contains('Second new paragraph'));
  });

  test('identical normalized text is a no-op', () {
    final Document document = Document.parse(
      sourceId: 'source-1',
      markdown: 'First.\n\nSecond.',
    );

    final splice = spliceForDocumentRewrite(document, 'First.\r\n\r\nSecond.');

    expect(splice.isNoop, isTrue);
  });

  test('an astral-plane boundary never splits a surrogate pair', () {
    final Document document = Document.parse(
      sourceId: 'source-1',
      markdown: 'A😀B',
    );

    final splice = spliceForDocumentRewrite(document, 'A😃B');

    expect(splice.startUtf8, 1);
    expect(splice.endUtf8, 5);
    expect(splice.inserted, '😃');
    expect(splice.applyTo(document.markdown), 'A😃B');
  });

  test('the common suffix never crosses the common prefix', () {
    final Document document = Document.parse(
      sourceId: 'source-1',
      markdown: 'aaaa',
    );

    final splice = spliceForDocumentRewrite(document, 'aa');

    expect(splice.startUtf8, 2);
    expect(splice.endUtf8, 4);
    expect(splice.inserted, isEmpty);
  });

  test('an extract outside the rewritten span stays intact', () {
    const String markdown = 'First.\n\nRewrite this.\n\nKeep this extract.';
    final Document document = Document.parse(
      sourceId: 'source-1',
      markdown: markdown,
      contentRevision: 4,
    );
    final Utf8OffsetIndex offsets = Utf8OffsetIndex(markdown);
    final int selectionStart = markdown.indexOf('Keep this extract.');
    final int selectionEnd = selectionStart + 'Keep this extract.'.length;
    final provenance = Provenance(
      sourceId: 'source-1',
      parentId: 'source-1',
      hasSourceAsParent: true,
      startAnchor: ReaderAnchor(
        utf8Offset: offsets.toUtf8(selectionStart),
        contentRevision: 4,
      ),
      endAnchor: ReaderAnchor(
        utf8Offset: offsets.toUtf8(selectionEnd),
        contentRevision: 4,
      ),
      selectedTextHash: hashSelection('Keep this extract.'),
    );
    final splice = spliceForDocumentRewrite(
      document,
      'First.\n\nRewrite only this paragraph.\n\nKeep this extract.',
    );

    final outcome = applySourceEditToText(
      markdown: document.markdown,
      contentRevision: document.contentRevision,
      splice: splice,
      children: <ChildProvenance>[
        ChildProvenance(extractId: 'extract-1', provenance: provenance),
      ],
    );
    final updated = outcome.provenanceUpdates.single.provenance;

    expect(updated.state, ProvenanceState.verbatim);
    expect(
      Utf8OffsetIndex(outcome.markdown).toUtf16(updated.startUtf8),
      outcome.markdown.indexOf('Keep this extract.'),
    );
  });
}
