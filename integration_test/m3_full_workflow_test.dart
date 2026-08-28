import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/incremental_reader_app.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/storage/database/connection.dart';
import 'package:incremental_reader/storage/drift/drift_repositories.dart';
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

  testWidgets(
    'native Windows import to extract, formulation, and FSRS review loop',
    (WidgetTester tester) async {
      final database = openInMemoryDatabase();
      // Sibling burying arrives in M4 and would push two of the three cards
      // off today. This test is about the M3 loop reaching every card it
      // formulated; burying has its own coverage.
      await DriftSettingsRepository(database).write(
        'card.bury_siblings',
        'false',
      );
      final clock = FakeClock(DateTime.utc(2026, 3, 5, 12));
      final container = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(clock),
        ],
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
        '# M3 workflow\n\nWorking memory holds four items while attention remains limited.',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      final paragraph = find.textContaining(
        'Working memory holds four items',
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
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Extract'),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Extracted'), findsOneWidget);

      // Remove the root topic from learning so tomorrow's queue opens the
      // independently scheduled extract first.
      final finishSource = find.widgetWithText(TextButton, 'Finish source');
      final finishAction = tester.widget<TextButton>(finishSource).onPressed;
      expect(finishAction, isNotNull);
      finishAction!();
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);

      clock.advance(const Duration(days: 1));
      await tester.tap(find.textContaining('Study').first);
      await tester.pumpAndSettle();
      expect(find.text('1 item ready'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Start'));
      await tester.pumpAndSettle();
      expect(find.text('Process extract'), findsOneWidget);

      await tester.tap(find.text('Formulate'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('formulation-question')),
        'How many items does working memory hold?',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('formulation-answer')),
        'Four items.',
      );
      await tester.tap(find.text('Add another'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cloze'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('formulation-cloze')),
        'Working memory holds {{c1::four items}} while '
        '{{c2::attention}} remains limited.',
      );
      await tester.pump();
      await tester.tap(find.text('Create 3 cards'));
      await tester.pumpAndSettle();
      expect(find.text('Process extract'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Dismiss'));
      await tester.pumpAndSettle();

      // The queue automatically advances through all three newly formulated
      // cards. Reveal-before-grade is enforced on each screen.
      for (var index = 0; index < 3; index++) {
        expect(find.text('Review'), findsOneWidget);
        expect(find.text('Show answer  (Space)'), findsOneWidget);
        await tester.tap(find.text('Show answer  (Space)'));
        await tester.pump();
        await tester.tap(find.text('3  Good'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Queue complete'), findsOneWidget);
      final cards = await database
          .customSelect('SELECT COUNT(*) AS n FROM cards')
          .getSingle();
      final reviews = await database
          .customSelect('SELECT COUNT(*) AS n FROM review_events')
          .getSingle();
      expect(cards.read<int>('n'), 3);
      expect(reviews.read<int>('n'), 3);
    },
  );
}
