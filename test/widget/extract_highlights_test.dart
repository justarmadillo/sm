/// Extracted text has to stay visible in the source it came from.
///
/// The gutter alone could only say "something was taken from this block"; it
/// could never say *which words*. These tests pin the mapping from provenance
/// to painted ranges, and that choosing an extract in the panel marks it
/// rather than merely scrolling near it.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/src/app/theme.dart';
import 'package:incremental_reader/src/domain/content/block.dart';
import 'package:incremental_reader/src/domain/content/document.dart';
import 'package:incremental_reader/src/domain/content/extract.dart';
import 'package:incremental_reader/src/domain/content/inline_markup.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/features/reader/presentation/extract_highlights.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_selection.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_view.dart';

const String _markdown = '''
# Chapter One

The first paragraph contains **bold text** and a [link](https://example.com).

The second paragraph is plain and easy to select from end to end.
''';

/// An extract of [text] taken from [block], with real anchors.
Extract _extractOf(Block block, String text, {String id = 'x1'}) {
  final renderedStart = block.renderedText.indexOf(text);
  expect(renderedStart, isNonNegative, reason: '"$text" is not in the block');
  final startAnchor = ReaderAnchor(
    blockId: block.id,
    utf8Offset: block.renderedToUtf8(renderedStart),
  );
  final endAnchor = ReaderAnchor(
    blockId: block.id,
    utf8Offset: block.renderedToUtf8(
      renderedStart + text.length,
      edge: RenderedEdge.trailing,
    ),
  );
  return Extract(
    id: id,
    markdown: text,
    provenance: Provenance(
      sourceId: 's',
      parentId: 's',
      parentIsSource: true,
      startAnchor: startAnchor,
      endAnchor: endAnchor,
      selectedTextHash: hashSelection(text),
    ),
    createdAtUtc: DateTime.utc(2026, 8, 20),
  );
}

void main() {
  group('buildExtractHighlights', () {
    test('paints exactly the characters the extract covers', () {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final block = document.blocks[2];
      final extract = _extractOf(block, 'plain and easy');

      final highlights = buildExtractHighlights(document, <Extract>[extract]);

      expect(highlights.keys, <String>[block.id]);
      final mark = highlights[block.id]!.single;
      expect(
        block.renderedText.substring(mark.start, mark.end),
        'plain and easy',
      );
      expect(mark.color, AppColors.extractWash);
      expect(mark.underlineColor, isNotNull);
    });

    test('the focused extract gets the stronger wash and comes first', () {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final block = document.blocks[2];
      final wide = _extractOf(block, 'The second paragraph is plain', id: 'a');
      final inner = _extractOf(block, 'second paragraph', id: 'b');

      final highlights = buildExtractHighlights(document, <Extract>[
        wide,
        inner,
      ], focusedExtractId: 'b');

      final marks = highlights[block.id]!;
      expect(marks.first.color, AppColors.extractFocusWash);
      expect(
        block.renderedText.substring(marks.first.start, marks.first.end),
        'second paragraph',
      );
    });

    test('an extract of an extract paints nothing in this document', () {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final foreign = Extract(
        id: 'child',
        markdown: 'anything',
        provenance: const Provenance(
          sourceId: 's',
          parentId: 'other-extract',
          parentIsSource: false,
          startAnchor: ReaderAnchor(blockId: 'not-here', utf8Offset: 0),
          endAnchor: ReaderAnchor(blockId: 'not-here', utf8Offset: 3),
          selectedTextHash: 'deadbeef',
        ),
        createdAtUtc: DateTime.utc(2026, 8, 20),
      );

      expect(buildExtractHighlights(document, <Extract>[foreign]), isEmpty);
    });

    test('marks every block an extract covers, not only its first', () {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final spanning = Extract(
        id: 'wide',
        markdown: 'spanning',
        provenance: Provenance(
          sourceId: 's',
          parentId: 's',
          parentIsSource: true,
          startAnchor: ReaderAnchor(
            blockId: document.blocks[1].id,
            utf8Offset: 0,
          ),
          endAnchor: ReaderAnchor(
            blockId: document.blocks[2].id,
            utf8Offset: 5,
          ),
          selectedTextHash: 'irrelevant',
        ),
        createdAtUtc: DateTime.utc(2026, 8, 20),
      );

      final marks = extractMarksByCoveredBlock(document, <Extract>[spanning]);
      expect(marks[document.blocks[1].id], 1);
      expect(marks[document.blocks[2].id], 1);
    });
  });

  group('ReaderView', () {
    testWidgets('renders the extract wash behind extracted text', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final block = document.blocks[2];
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      final extract = _extractOf(block, 'plain and easy');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ReaderView(
              document: document,
              controller: controller,
              extractHighlights: buildExtractHighlights(document, <Extract>[
                extract,
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final washed = <String>[];
      for (final richText in tester.widgetList<RichText>(
        find.byType(RichText),
      )) {
        richText.text.visitChildren((InlineSpan span) {
          if (span is TextSpan &&
              span.style?.backgroundColor == AppColors.extractWash) {
            washed.add(span.text ?? '');
          }
          return true;
        });
      }
      expect(washed.join(), contains('plain and easy'));
    });

    testWidgets('a drag that starts in the gutter selects nothing', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ReaderView(document: document, controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.getRect(
        find.text(
          'The second paragraph is plain and easy to select from end to end.',
          findRichText: true,
        ),
      );
      // Left of the text column: the marker gutter.
      final gesture = await tester.startGesture(
        Offset(paragraph.left - 12, paragraph.top + 6),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.hasSelection, isFalse);
    });

    testWidgets('a small tremor during a click does not select', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _markdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ReaderView(document: document, controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.getRect(
        find.text(
          'The second paragraph is plain and easy to select from end to end.',
          findRichText: true,
        ),
      );
      final gesture = await tester.startGesture(
        Offset(paragraph.left + 20, paragraph.top + 6),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(2, 1));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.hasSelection, isFalse);
    });
  });
}
