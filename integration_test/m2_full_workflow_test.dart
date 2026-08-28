import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/incremental_reader_app.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:integration_test/integration_test.dart';

/// Opens the Contents tab when it is showing.
///
/// The home screen leads with the study queue, so the import affordance lives
/// one tab across. Tolerating its absence keeps this usable from a screen that
/// is already past the tab bar.
Future<void> _openContents(WidgetTester tester) async {
  final Finder tab = find.text('Contents');
  if (tab.evaluate().isEmpty) return;
  await tester.tap(tab.first);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import, read, extract, undo, and continue', (tester) async {
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

    await _openContents(tester);
    await tester.tap(find.text('Import markdown').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '# M2 workflow\n\nSelect this exact passage and keep reading afterward.',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    final paragraph = find.text(
      'Select this exact passage and keep reading afterward.',
      findRichText: true,
    );
    expect(paragraph, findsOneWidget);
    final box = tester.getRect(paragraph);
    final gesture = await tester.startGesture(
      Offset(box.left + 1, box.top + 8),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(6, 0));
    await gesture.moveTo(Offset(box.right - 1, box.top + 8));
    await gesture.up();
    await tester.pumpAndSettle();

    final extractButton = find.widgetWithText(OutlinedButton, 'Extract');
    tester.widget<OutlinedButton>(extractButton).onPressed!();
    await tester.pump();
    expect(find.text('Extracted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    final undoButton = find.widgetWithText(TextButton, 'Undo');
    tester.widget<TextButton>(undoButton).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Extract removed'), findsOneWidget);
    expect(paragraph, findsOneWidget, reason: 'the reader must stay in place');
  });
}
