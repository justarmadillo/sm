/// The in-place block editor, as the reader actually mounts it.
///
/// The properties that matter here are structural rather than cosmetic: only
/// one block turns into a field, the paragraph it replaced stops being
/// hit-testable while it is gone, and cancelling writes nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/features/reader/widgets/block_editor.dart';
import 'package:incremental_reader/features/reader/widgets/block_view.dart';
import 'package:incremental_reader/features/reader/widgets/reader_selection.dart';
import 'package:incremental_reader/features/reader/widgets/reader_view.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

const String _markdown = '''
# A Chapter

The first paragraph contains **bold text** and plain words.

The second paragraph is plain and easy to select from end to end.
''';

void main() {
  Future<void> pumpReader(
    WidgetTester tester,
    Document document,
    ReaderSelectionController controller, {
    String? editingBlockId,
    void Function(Block block, String markdown)? onCommit,
    void Function(Block block)? onCancel,
    void Function(Block block)? onDelete,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ReaderView(
              document: document,
              controller: controller,
              editingBlockId: editingBlockId,
              onEditCommit: onCommit ?? (Block _, String _) {},
              onEditCancel: onCancel,
              onEditDelete: onDelete,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('only the named block becomes a field', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);
    final target = document.blocks[1];

    await pumpReader(
      tester,
      document,
      controller,
      editingBlockId: target.id,
    );

    expect(find.byType(BlockEditor), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // Every other block still renders normally.
    final rendered = tester
        .widgetList<BlockView>(find.byType(BlockView))
        .where((BlockView v) => !v.isEditing)
        .length;
    expect(rendered, greaterThan(1));
  });

  testWidgets('the field opens on the block raw markdown, not its text', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);
    final target = document.blocks[1];

    await pumpReader(
      tester,
      document,
      controller,
      editingBlockId: target.id,
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, target.raw);
    expect(
      field.controller!.text,
      contains('**bold text**'),
      reason: 'the editor shows markdown, so the syntax can be changed',
    );
  });

  testWidgets('an edited block stops being hit-testable', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);
    final target = document.blocks[1];

    await pumpReader(tester, document, controller);
    expect(controller.isParagraphMounted(target.id), isTrue);

    await pumpReader(
      tester,
      document,
      controller,
      editingBlockId: target.id,
    );

    // Its paragraph is gone, so nothing may resolve a selection against the
    // layout it used to have.
    expect(controller.isParagraphMounted(target.id), isFalse);
    expect(
      controller.isParagraphMounted(document.blocks[2].id),
      isTrue,
      reason: 'the rest of the page is untouched',
    );
  });

  testWidgets('Save reports the typed markdown, Cancel reports nothing', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);
    final target = document.blocks[1];
    String? committed;
    var cancelled = false;

    await pumpReader(
      tester,
      document,
      controller,
      editingBlockId: target.id,
      onCommit: (Block _, String markdown) => committed = markdown,
      onCancel: (Block _) => cancelled = true,
    );

    // Save is inert until something actually changes: re-saving unchanged text
    // must not advance the revision, and the cheapest way to guarantee that is
    // to not offer the button.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'Rewritten paragraph.');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(committed, 'Rewritten paragraph.');
    expect(cancelled, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, isTrue);
  });

  testWidgets('Delete block is offered separately from an empty save', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);
    Block? deleted;

    await pumpReader(
      tester,
      document,
      controller,
      editingBlockId: document.blocks[1].id,
      onDelete: (Block block) => deleted = block,
    );

    await tester.tap(find.text('Delete block'));
    await tester.pump();
    expect(deleted?.id, document.blocks[1].id);
  });

  testWidgets('a commit in flight disables the controls', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);

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
              isBusy: true,
              onEditCommit: (Block _, String _) {},
              onEditCancel: (Block _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancel')).onPressed,
      isNull,
    );
  });

  testWidgets('the editor uses the reading typography, at code width', (
    WidgetTester tester,
  ) async {
    final document = Document.parse(sourceId: 's', markdown: _markdown);
    final controller = ReaderSelectionController(document);
    const typography = ReaderTypography.standard;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: ReaderView(
              document: document,
              controller: controller,
              typography: typography,
              editingBlockId: document.blocks[1].id,
              onEditCommit: (Block _, String _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontFamily, typography.code.fontFamily);
  });
}
