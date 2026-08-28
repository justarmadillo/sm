import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/reader/widgets/block_view.dart';
import 'package:incremental_reader/features/reader/widgets/reader_selection.dart';
import 'package:incremental_reader/features/reader/widgets/reader_view.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

import '../../../support/anchors.dart';
import '../../../support/sample_document_generator.dart';

const String _shortMarkdown = '''
# Chapter One

The first paragraph contains **bold text** and a [link](https://example.com).

The second paragraph is plain and easy to select from end to end.

- A list item
- Another list item
''';

void main() {
  Future<GlobalKey<ReaderViewState>> pumpReader(
    WidgetTester tester,
    Document document,
    ReaderSelectionController controller, {
    ReaderAnchor? marker,
    ReaderAnchor? initialAnchor,
    void Function(ReaderAnchor)? onGutterTap,
  }) async {
    final key = GlobalKey<ReaderViewState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ReaderView(
            key: key,
            document: document,
            controller: controller,
            marker: marker,
            initialAnchor: initialAnchor,
            onGutterTap: onGutterTap,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  group('rendering', () {
    testWidgets('renders block text without its markdown syntax', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      expect(find.text('Chapter One', findRichText: true), findsOneWidget);
      expect(
        find.text(
          'The first paragraph contains bold text and a link.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      // The list marker is drawn beside the paragraph, not inside it, so it
      // cannot shift the character offsets selection depends on.
      expect(find.text('A list item', findRichText: true), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
    });

    testWidgets('the resume marker is drawn on its block', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(
        tester,
        document,
        controller,
        marker: anchorIn(document.blocks[1], 0),
      );

      final marked = tester
          .widgetList<BlockView>(find.byType(BlockView))
          .where((BlockView v) => v.isMarkerPainted)
          .toList();
      expect(marked, hasLength(1));
      expect(marked.single.block.id, document.blocks[1].id);
    });
  });

  group('virtualization', () {
    testWidgets('a 50k-word document mounts only what fits on screen', (
      WidgetTester tester,
    ) async {
      final markdown = generateSampleMarkdown(targetWords: 50000);
      final source = Source.import(
        id: 'big',
        title: 'Big',
        markdown: markdown,
        importedAtUtc: DateTime.utc(2026),
      );
      expect(source.wordCount, greaterThan(45000));

      final document = Document.parse(
        sourceId: 'big',
        markdown: source.markdown,
      );
      expect(document.blocks.length, greaterThan(500));

      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final mounted = find.byType(BlockView).evaluate().length;
      expect(
        mounted,
        lessThan(60),
        reason: 'the whole document must not be laid out at once',
      );
      expect(mounted, greaterThan(0));
    });

    testWidgets('anchors resolve for blocks that are not mounted', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(
        sourceId: 'big',
        markdown: generateSampleMarkdown(targetWords: 50000),
      );
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final last = document.blocks.last;
      final mountedIds = tester
          .widgetList<BlockView>(find.byType(BlockView))
          .map((BlockView v) => v.block.id)
          .toSet();
      expect(
        mountedIds.contains(last.id),
        isFalse,
        reason: 'the final block of a 50k-word document is far off screen',
      );

      // The coordinate system is data, not layout: it answers anyway.
      final anchor = anchorIn(last, 0);
      expect(document.documentOffsetOf(anchor), last.sourceStartUtf8);
      expect(document.indexOfBlock(last.id), document.blocks.length - 1);
      // Rendered coordinates answer too, without the block ever being laid out.
      expect(last.utf8ToRendered(last.renderedToUtf8(0)), 0);
      expect(last.rawSliceForRendered(0, last.renderedText.length), isNotEmpty);
    });

    testWidgets('jumping to an unmounted anchor mounts its block', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(
        sourceId: 'big',
        markdown: generateSampleMarkdown(targetWords: 50000),
      );
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      final key = await pumpReader(tester, document, controller);

      final target = document.blocks[document.blocks.length - 3];
      key.currentState!.jumpToAnchor(anchorIn(target, 0));
      await tester.pumpAndSettle();

      final mountedIds = tester
          .widgetList<BlockView>(find.byType(BlockView))
          .map((BlockView v) => v.block.id)
          .toSet();
      expect(mountedIds, contains(target.id));
    });

    testWidgets('opens at the initial anchor without scrolling there', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(
        sourceId: 'big',
        markdown: generateSampleMarkdown(targetWords: 50000),
      );
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      final target = document.blocks[400];
      await pumpReader(
        tester,
        document,
        controller,
        initialAnchor: anchorIn(target, 0),
      );

      final mountedIds = tester
          .widgetList<BlockView>(find.byType(BlockView))
          .map((BlockView v) => v.block.id)
          .toSet();
      expect(mountedIds, contains(target.id));
    });

    testWidgets('scrolling a long document keeps the mounted set bounded', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(
        sourceId: 'big',
        markdown: generateSampleMarkdown(targetWords: 50000),
      );
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      var worstMounted = 0;
      for (var i = 0; i < 15; i++) {
        await tester.drag(find.byType(ReaderView), const Offset(0, -1200));
        await tester.pumpAndSettle();
        worstMounted = <int>[
          worstMounted,
          find.byType(BlockView).evaluate().length,
        ].reduce((int a, int b) => a > b ? a : b);
      }
      expect(worstMounted, lessThan(80));
    });

    testWidgets('the scrollbar range stays fixed while travelling', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(
        sourceId: 'big',
        markdown: generateSampleMarkdown(targetWords: 50000),
      );
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final verticalScrollable = find
          .descendant(
            of: find.byType(ReaderView),
            matching: find.byType(Scrollable),
          )
          .first;
      final scrollableState = tester.state<ScrollableState>(verticalScrollable);
      final initialMaximum = scrollableState.position.maxScrollExtent;

      await tester.drag(find.byType(ReaderView), const Offset(0, -12000));
      await tester.pumpAndSettle();

      expect(scrollableState.position.maxScrollExtent, initialMaximum);
    });

    testWidgets('up and down arrow keys move the reading surface', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(
        sourceId: 'big',
        markdown: generateSampleMarkdown(targetWords: 5000),
      );
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final verticalScrollable = find
          .descendant(
            of: find.byType(ReaderView),
            matching: find.byType(Scrollable),
          )
          .first;
      final scrollableState = tester.state<ScrollableState>(verticalScrollable);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(scrollableState.position.pixels, 0);
    });
  });

  group('selection maps to exact source', () {
    testWidgets('a double click selects a word and resolves its markdown', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final paragraph = find.text(
        'The first paragraph contains bold text and a link.',
        findRichText: true,
      );
      final origin = tester.getTopLeft(paragraph);
      // A point inside the word "first": far enough in to be unambiguous.
      await tester.tapAt(origin + const Offset(40, 10));
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(origin + const Offset(40, 10));
      await tester.pumpAndSettle();

      final resolved = controller.resolveSelection();
      expect(resolved, isNotNull);
      // Whatever word was hit, the markdown must be a real word from the
      // source, never markup and never a stray delimiter.
      expect(resolved!.markdown, matches(RegExp(r'^[A-Za-z]+$')));
      expect(
        _shortMarkdown.contains(resolved.markdown),
        isTrue,
        reason: '"${resolved.markdown}" is not present in the source',
      );
      expect(resolved.range.matches(resolved.markdown), isTrue);
    });

    testWidgets('a mouse drag across a paragraph selects exact source', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final paragraph = find.text(
        'The second paragraph is plain and easy to select from end to end.',
        findRichText: true,
      );
      final box = tester.getRect(paragraph);
      final gesture = await tester.startGesture(
        Offset(box.left + 1, box.top + 8),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(6, 0));
      await gesture.moveTo(Offset(box.right - 1, box.bottom - 8));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final resolved = controller.resolveSelection();
      expect(resolved, isNotNull);
      expect(
        resolved!.markdown,
        'The second paragraph is plain and easy to select from end to end.',
      );
      expect(document.isSameBlock(resolved.range), isTrue);
      expect(resolved.range.matches(resolved.markdown), isTrue);
    });

    testWidgets('a drag across blocks keeps the separators in the source', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final first = tester.getRect(
        find.text(
          'The second paragraph is plain and easy to select from end to end.',
          findRichText: true,
        ),
      );
      final second = tester.getRect(
        find.text('A list item', findRichText: true),
      );

      final gesture = await tester.startGesture(
        Offset(first.left + 1, first.top + 8),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(6, 0));
      await gesture.moveTo(Offset(second.right - 1, second.top + 8));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final resolved = controller.resolveSelection();
      expect(resolved, isNotNull);
      expect(document.isSameBlock(resolved!.range), isFalse);
      expect(controller.canExtract, isFalse);
      expect(resolved.markdown, startsWith('The second paragraph'));
      expect(resolved.markdown, endsWith('- A list item'));
      // The raw slice is contiguous original markdown, blank lines included.
      expect(
        document.markdown.contains(resolved.markdown),
        isTrue,
        reason: 'a cross-block selection must quote the source verbatim',
      );
    });

    testWidgets('a gutter click resolves a precise in-block anchor', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      ReaderAnchor? tapped;
      await pumpReader(
        tester,
        document,
        controller,
        onGutterTap: (anchor) => tapped = anchor,
      );

      final target = document.blocks[2];
      final view = find.byWidgetPredicate(
        (widget) => widget is BlockView && widget.block.id == target.id,
      );
      final gutter = find.descendant(
        of: view,
        matching: find.byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onTapDown != null,
        ),
      );
      final rect = tester.getRect(gutter.first);
      tester.widget<GestureDetector>(gutter.first).onTapDown!(
        TapDownDetails(globalPosition: rect.center),
      );
      await tester.pump();

      expect(document.blockForAnchor(tapped!)?.id, target.id);
      expect(tapped!.utf8Offset, greaterThan(target.sourceStartUtf8));
      expect(tapped!.utf8Offset, lessThanOrEqualTo(target.sourceEndUtf8));
    });

    testWidgets('clicking clears the selection', (WidgetTester tester) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final controller = ReaderSelectionController(document);
      addTearDown(controller.dispose);
      await pumpReader(tester, document, controller);

      final box = tester.getRect(
        find.text(
          'The second paragraph is plain and easy to select from end to end.',
          findRichText: true,
        ),
      );
      final gesture = await tester.startGesture(
        Offset(box.left + 1, box.top + 8),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(6, 0));
      await gesture.moveTo(Offset(box.right - 1, box.top + 8));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.hasSelection, isTrue);

      await tester.tapAt(box.center);
      // A double-tap recognizer is also registered, so a single tap only
      // resolves once its timeout expires. That timer schedules no frame,
      // which pumpAndSettle would not wait for.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      expect(controller.hasSelection, isFalse);
    });
  });

  group('typography independence', () {
    testWidgets('the same selection resolves identically at any text size', (
      WidgetTester tester,
    ) async {
      final document = Document.parse(sourceId: 's', markdown: _shortMarkdown);
      final block = document.blocks[2];
      const start = 4;
      const end = 10;

      // The mapping is a property of the block, not of the layout, so it is
      // unchanged by font size, text scaling, or window width.
      final expected = block.rawSliceForRendered(start, end);
      expect(expected, 'second');

      for (final size in <double>[12, 18, 28]) {
        final controller = ReaderSelectionController(document);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: ReaderView(
                document: document,
                controller: controller,
                typography: ReaderTypography(fontSize: size),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(block.rawSliceForRendered(start, end), expected);
      }
    });
  });
}
