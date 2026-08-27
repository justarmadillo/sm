/// Drives the real Windows app through an edit, end to end.
///
/// Everything below happens through the actual widget tree the user meets: the
/// import sheet, the reader, the selection toolbar, the in-place editor. The
/// point is to catch what unit tests structurally cannot — a control that is
/// never reachable, a gesture that never lands, a screen that does not rebuild
/// after the document underneath it is re-derived.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/src/app/app.dart';
import 'package:incremental_reader/src/app/providers.dart';
import 'package:incremental_reader/src/data/database/connection.dart';
import 'package:incremental_reader/src/domain/content/reader_anchor.dart';
import 'package:incremental_reader/src/features/reader/presentation/block_editor.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_view.dart';
import 'package:integration_test/integration_test.dart';

const String _markdown = '''
# Photosynthesis

Chlorophyll absorbs blue and red light most strongly.

A closing paragraph that stays exactly where it is.
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import, edit a paragraph in place, and undo it', (
    WidgetTester tester,
  ) async {
    final database = openInMemoryDatabase();
    final container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const IncrementalReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    // --- import -----------------------------------------------------------
    await tester.tap(find.text('Contents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import markdown').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, _markdown);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Chlorophyll absorbs blue and red light most strongly.',
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'the reader opened on the imported article',
    );

    // --- select the paragraph, then reach the editor through the toolbar ---
    final paragraph = find.text(
      'Chlorophyll absorbs blue and red light most strongly.',
      findRichText: true,
    );
    final Rect box = tester.getRect(paragraph);
    final gesture = await tester.startGesture(
      Offset(box.left + 4, box.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveTo(Offset(box.right - 4, box.center.dy));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.text('Edit'),
      findsOneWidget,
      reason: 'the selection toolbar offers the editor',
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // --- the editor is open on this block only, showing raw markdown -------
    expect(find.byType(BlockEditor), findsOneWidget);
    final TextField field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(BlockEditor),
        matching: find.byType(TextField),
      ),
    );
    expect(
      field.controller!.text,
      'Chlorophyll absorbs blue and red light most strongly.',
    );
    expect(
      find.text(
        'A closing paragraph that stays exactly where it is.',
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'every other block keeps rendering normally',
    );

    // --- typing: a space is a space, not a page-down ----------------------
    //
    // Reported from a real session: the space bar scrolled the article while
    // the caret sat in the editor. It only shows up on the whole screen —
    // the reading surface, its shortcut bindings, and the view model's
    // rebuilds all have to be present for focus to be stolen mid-word.
    final Finder editorField = find.descendant(
      of: find.byType(BlockEditor),
      matching: find.byType(TextField),
    );
    final TextEditingController fieldController = tester
        .widget<TextField>(editorField)
        .controller!;
    fieldController.selection = TextSelection.collapsed(
      offset: fieldController.text.length,
    );
    await tester.pump();

    final ReaderAnchor? topBefore = tester
        .state<ReaderViewState>(find.byType(ReaderView))
        .topVisibleAnchor;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(
      tester.state<ReaderViewState>(find.byType(ReaderView)).topVisibleAnchor,
      topBefore,
      reason: 'space typed into the editor must not move the article',
    );
    expect(
      tester.widget<TextField>(editorField).focusNode!.hasFocus,
      isTrue,
      reason: 'and it must not cost the editor its focus',
    );

    // --- edit and save ----------------------------------------------------
    await tester.enterText(
      find.descendant(
        of: find.byType(BlockEditor),
        matching: find.byType(TextField),
      ),
      'Chlorophyll **reflects** green light.',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockEditor), findsNothing);
    expect(
      find.text('Chlorophyll reflects green light.', findRichText: true),
      findsOneWidget,
      reason: 'the page shows the rendered result, not the raw markdown',
    );
    expect(
      find.text(
        'A closing paragraph that stays exactly where it is.',
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'the block after the edit is untouched',
    );

    // --- extract, from the text as it now stands --------------------------
    //
    // The reported fault: after an edit the reader was still resolving
    // selections against the document it had before, so the range it built
    // hashed a passage the source could no longer produce and extraction
    // refused it as no longer matching.
    final Rect edited = tester.getRect(
      find.text('Chlorophyll reflects green light.', findRichText: true),
    );
    final selectEdited = await tester.startGesture(
      Offset(edited.left + 4, edited.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 40));
    await selectEdited.moveTo(Offset(edited.right - 4, edited.center.dy));
    await tester.pump(const Duration(milliseconds: 40));
    await selectEdited.up();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Extract'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no longer matches'),
      findsNothing,
      reason: 'the selection was made against the text that is actually stored',
    );

    // --- undo -------------------------------------------------------------
    expect(find.text('Undo edit'), findsOneWidget);
    await tester.tap(find.text('Undo edit'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Chlorophyll absorbs blue and red light most strongly.',
        findRichText: true,
      ),
      findsOneWidget,
      reason: 'undo put the original text back on the page',
    );
  });
}
