/// M4 end to end on native Windows: priority, caps, the overload valve,
/// Study More, undo-last-grade, and search.
///
/// Everything below is driven through the real widgets, because the point of
/// this milestone is that the scheduling machinery is *reachable* — a cap the
/// user cannot change and a deferral they cannot see would be no better than
/// hard-coded constants.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/incremental_reader_app.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
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

  Future<(AppDatabase, ProviderContainer, FakeClock)> boot(
    WidgetTester tester,
  ) async {
    final AppDatabase database = openInMemoryDatabase();
    final FakeClock clock = FakeClock(DateTime.utc(2026, 3, 5, 12));
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
      ],
    );
    await warmSettings(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const IncrementalReaderApp(),
      ),
    );
    await tester.pumpAndSettle();
    return (database, container, clock);
  }

  Future<void> importArticle(
    WidgetTester tester,
    String title,
    String body,
  ) async {
    await _openContents(tester);
    await tester.tap(find.text('Import markdown').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, title);
    await tester.enterText(find.byType(TextField).last, '# $title\n\n$body');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
    // Importing opens the Reader on the new article; go back to the Library.
    if (find.byTooltip('Back').evaluate().isNotEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  }

  testWidgets('priority, caps, the valve, Study More, undo, and search', (
    WidgetTester tester,
  ) async {
    final (AppDatabase database, ProviderContainer container, _) = await boot(
      tester,
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    await importArticle(
      tester,
      'Surfactant',
      'Surfactant lowers alveolar surface tension and is made by type II '
          'pneumocytes.',
    );
    await importArticle(
      tester,
      'Preload',
      'Preload is ventricular wall stress at the end of diastole.',
    );
    await importArticle(
      tester,
      'Nephron',
      'The nephron is the functional unit of the kidney.',
    );

    // ---------------------------------------------------------------- search
    await tester.tap(find.byTooltip('Search (Ctrl+F)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'pneumocytes');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Surfactant'),
      findsWidgets,
      reason: 'articles are indexed whole, not only by their titles',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ------------------------------------------------------- priority browser
    await tester.tap(find.byTooltip('Priority queue'));
    await tester.pumpAndSettle();
    expect(find.text('Priority queue'), findsOneWidget);
    expect(find.text('3 elements'), findsOneWidget);
    expect(
      find.textContaining('%'),
      findsWidgets,
      reason: 'every row shows its derived percentile',
    );

    // The Alt+P slider, opened from a browser row.
    await tester.tap(find.byTooltip('Set priority (Alt+P)').first);
    await tester.pumpAndSettle();
    expect(find.text('Element priority'), findsOneWidget);
    expect(find.textContaining('position 1 of 3'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // -------------------------------------------------------------- settings
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Daily queue'), findsOneWidget);

    final Finder maxTopics = find.ancestor(
      of: find.text('Maximum topics'),
      matching: find.byType(Row),
    );
    await tester.enterText(
      find.descendant(of: maxTopics.first, matching: find.byType(TextField)),
      '1',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ------------------------------------------------- the valve, then more
    await tester.tap(find.textContaining('Study').first);
    await tester.pumpAndSettle();

    expect(
      find.text('1 item ready'),
      findsOneWidget,
      reason: 'the cap the user just set applies to today',
    );
    expect(
      find.text('Study more'),
      findsWidgets,
      reason: 'what the valve shed has to be visible and recoverable',
    );

    final int deferred = (await database
            .customSelect(
              'SELECT COUNT(*) AS n FROM revlog_entries '
              'WHERE event_type = 4',
            )
            .getSingle())
        .read<int>('n');
    expect(deferred, 2, reason: 'two articles were deferred, and logged as it');

    final int encounters = (await database
            .customSelect(
              'SELECT COUNT(*) AS n FROM revlog_entries '
              'WHERE event_type = 2',
            )
            .getSingle())
        .read<int>('n');
    expect(
      encounters,
      0,
      reason: 'the valve must never record an encounter that did not happen',
    );

    await tester.tap(find.text('Study more').first);
    await tester.pumpAndSettle();
    expect(find.text('3 items ready'), findsOneWidget);
  });

  testWidgets('a grade can be taken back and the card graded again', (
    WidgetTester tester,
  ) async {
    final (AppDatabase database, ProviderContainer container, _) = await boot(
      tester,
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    // Importing leaves the Reader open in scheduled mode, which is where
    // SuperMemo's Alt+Z lives: a card straight from the article, no extract
    // in between.
    await _openContents(tester);
    await tester.tap(find.text('Import markdown').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Recall');
    await tester.enterText(
      find.byType(TextField).last,
      '''
# Recall

Working memory holds about four items.''',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Formulate'));
    await tester.pumpAndSettle();

    // Fill the dialog's own fields, found through the dialog rather than by
    // key, so this stays valid if the form is rearranged.
    final Finder dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(
      dialogFields.at(0),
      'How many items does working memory hold?',
    );
    await tester.pump();
    await tester.enterText(dialogFields.at(1), 'About four.');
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    // Take the article itself out of the queue so the card is the only thing
    // due, and the queue opens straight onto the review screen.
    await tester.tap(find.widgetWithText(TextButton, 'Finish source'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Study').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsOneWidget);
    await tester.tap(find.text('Show answer  (Space)'));
    await tester.pump();

    final String beforeState = (await database
            .customSelect(
              'SELECT state, reps, due_at_utc FROM card_memories LIMIT 1',
            )
            .getSingle())
        .data
        .toString();

    await tester.tap(find.text('3  Good'));
    await tester.pumpAndSettle();

    expect(
      (await database
              .customSelect('SELECT COUNT(*) AS n FROM review_events')
              .getSingle())
          .read<int>('n'),
      1,
    );

    // The review screen closes the moment a grade commits, so undo lives on
    // the queue — which is where the session actually is.
    expect(find.text('Queue complete'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo last grade (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(
      find.text('1 item ready'),
      findsOneWidget,
      reason: 'the restored card is due again immediately',
    );

    final String afterState = (await database
            .customSelect(
              'SELECT state, reps, due_at_utc FROM card_memories LIMIT 1',
            )
            .getSingle())
        .data
        .toString();
    expect(
      afterState,
      beforeState,
      reason: 'undo restores the pre-review snapshot exactly',
    );
    expect(
      (await database
              .customSelect('SELECT COUNT(*) AS n FROM review_events')
              .getSingle())
          .read<int>('n'),
      0,
      reason: 'the grade whose effect no longer exists must not linger',
    );
  });
}
