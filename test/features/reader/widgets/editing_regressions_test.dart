/// Two faults reported from a real session, pinned down.
///
/// Both are about what happens *after* an edit rather than during it, which is
/// exactly the seam a unit test does not cover: the domain was right both
/// times, and the screen around it was holding something stale.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/reader/widgets/block_editor.dart';
import 'package:incremental_reader/features/reader/widgets/reader_selection.dart';
import 'package:incremental_reader/features/reader/widgets/reader_view.dart';

import '../../../support/anchors.dart';

const String _before = '''
# A Chapter

The first paragraph is the one that gets edited.

The second paragraph is plain and easy to select from end to end.
''';

const String _after = '''
# A Chapter

Rewritten, and shorter.

The second paragraph is plain and easy to select from end to end.
''';

void main() {
  group('a selection made after an edit addresses the new text', () {
    test('a controller left on the old document produces a stale hash', () {
      // What the bug looked like from the domain's side: the offsets are
      // resolved against text that is no longer stored, so the hash pins a
      // passage the source can no longer produce, and extraction refuses it.
      final stale = Document.parse(sourceId: 's', markdown: _before);
      final current = Document.parse(
        sourceId: 's',
        markdown: _after,
        contentRevision: 2,
      );

      final block = stale.blocks[2];
      final start = anchorIn(block, 0);
      final end = anchorIn(block, block.lengthUtf8);
      final range = SelectionRange.of(
        startAnchor: start,
        endAnchor: end,
        markdown: stale.markdownBetween(start, end),
      );

      expect(
        range.matches(current.markdownForRange(range)),
        isFalse,
        reason: 'this is the mismatch the user was shown',
      );
    });

    testWidgets('the reader re-points its controller at the new document', (
      WidgetTester tester,
    ) async {
      final first = Document.parse(sourceId: 's', markdown: _before);
      final second = Document.parse(
        sourceId: 's',
        markdown: _after,
        contentRevision: 2,
      );
      final controller = ReaderSelectionController(first);

      Future<void> pump(Document document) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: ReaderView(document: document, controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(first);
      expect(controller.document.markdown, first.markdown);

      await pump(second);
      expect(
        controller.document.markdown,
        second.markdown,
        reason:
            'a selection resolved after an edit must address the stored text, '
            'or its hash pins a passage the source can no longer produce',
      );
      expect(controller.document.contentRevision, 2);
    });

    testWidgets('changing document clears a selection made against the old', (
      WidgetTester tester,
    ) async {
      final first = Document.parse(sourceId: 's', markdown: _before);
      final second = Document.parse(
        sourceId: 's',
        markdown: _after,
        contentRevision: 2,
      );
      final controller = ReaderSelectionController(first);

      Future<void> pump(Document document) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: ReaderView(document: document, controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(first);
      final Rect box = tester.getRect(
        find.text(
          'The second paragraph is plain and easy to select from end to end.',
          findRichText: true,
        ),
      );
      await tester.dragFrom(
        Offset(box.left + 4, box.center.dy),
        Offset(box.width - 12, 0),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isTrue);

      await pump(second);
      expect(
        controller.hasSelection,
        isFalse,
        reason: 'a selection measured against replaced text cannot survive it',
      );
    });
  });

  group('typing in the editor', () {
    Future<void> pumpEditing(
      WidgetTester tester,
      Document document,
      ReaderSelectionController controller,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ReaderView(
                document: document,
                controller: controller,
                editingBlockId: document.blocks[1].id,
                onEditCommit: (_, _) {},
                onEditCancel: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('space reaches the field instead of paging the reader', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _before);
      final controller = ReaderSelectionController(document);
      await pumpEditing(tester, document, controller);

      final Finder field = find.descendant(
        of: find.byType(BlockEditor),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.pumpAndSettle();

      // A space is an ordinary character here. The reading surface binds it to
      // page-down, and that binding must not outrank the field the caret is
      // sitting in.
      final KeyEventResult result = await _sendSpace(tester);
      expect(
        result,
        isNot(KeyEventResult.handled),
        reason: 'the reader must not swallow a space typed into the editor',
      );
    });

    testWidgets('space typed in the editor does not page the article', (
      WidgetTester tester,
    ) async {
      // The user-visible form of the fault: the caret stayed put and the
      // article jumped, because the reading surface's page-down binding fired
      // for a key that belonged to the field nested inside it.
      final document = Document.parse(
        sourceId: 's',
        markdown: List<String>.generate(
          60,
          (int i) => 'Paragraph number $i, long enough to need scrolling.',
        ).join('\n\n'),
      );
      final controller = ReaderSelectionController(document);
      final key = GlobalKey<ReaderViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: ReaderView(
                key: key,
                document: document,
                controller: controller,
                editingBlockId: document.blocks[1].id,
                onEditCommit: (_, _) {},
                onEditCancel: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(BlockEditor),
          matching: find.byType(TextField),
        ),
      );
      await tester.pumpAndSettle();

      final ReaderAnchor? before = key.currentState!.topVisibleAnchor;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(
        key.currentState!.topVisibleAnchor,
        before,
        reason: 'a space typed into the editor must not move the article',
      );
    });

    testWidgets('the field holds focus once the editor opens', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _before);
      final controller = ReaderSelectionController(document);
      await pumpEditing(tester, document, controller);

      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(BlockEditor),
          matching: find.byType(TextField),
        ),
      );
      expect(
        field.focusNode!.hasFocus,
        isTrue,
        reason: 'opening the editor puts the caret in it',
      );
    });
  });
}

/// Sends one space key down and reports whether anything claimed it.
Future<KeyEventResult> _sendSpace(WidgetTester tester) async {
  final bool handled = await tester.sendKeyDownEvent(
    LogicalKeyboardKey.space,
  );
  await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
  await tester.pumpAndSettle();
  return handled ? KeyEventResult.handled : KeyEventResult.ignored;
}
