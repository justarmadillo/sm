/// Reopening a card must present a fresh recall, not the last one's leftovers.
///
/// The queue hands the same card back within a session — a learning step, a
/// second Study run — and every opening has to ask before it answers and grade
/// when graded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart' as documents;
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/extract_providers.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/review/review_screen.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProviderContainer container;
  late String cardId;
  late FakeClock clock;
  late List<StudyRouteResult> outcomes;

  setUp(() async {
    database = openInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 3, 5));
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );
    outcomes = <StudyRouteResult>[];
    await container.read(browserViewModelProvider.future);
    final String sourceId = (await container
        .read(browserViewModelProvider.notifier)
        .importMarkdown(
          title: 'Encoding',
          markdown: '# Encoding\n\nWorking memory holds four items.',
        ))!;
    final List<documents.Card> cards = (await container
            .read(formulationCommandRunnerProvider)
            .formulate(
              FormulateCards(
                const OperationId('formulate-1'),
                parent: documents.CardParent.source(sourceId),
                drafts: const <CardDraft>[
                  QaCardDraft(
                    question: 'How many items does working memory hold?',
                    answer: 'Four.',
                  ),
                ],
              ),
            ))
        .unwrap();
    cardId = cards.single.id;
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  /// A stand-in for the queue: a screen that opens the same card on demand.
  Future<void> pumpQueue(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  Center(
                    child: FilledButton(
                      onPressed: () async => outcomes.add(
                        await openReview(context, ref, cardId: cardId),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pumpAndSettle();
  }

  testWidgets('a card reopened after grading asks before it answers', (
    WidgetTester tester,
  ) async {
    await pumpQueue(tester);

    await start(tester);
    expect(find.text('Show answer  (Space)'), findsOneWidget);
    expect(find.text('Four.'), findsNothing);
    await tester.tap(find.text('Show answer  (Space)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3  Good'));
    await tester.pumpAndSettle();
    expect(outcomes, <StudyRouteResult>[StudyRouteResult.committed]);

    // The card comes due again and the queue serves it a second time.
    clock.advance(const Duration(days: 1));
    await start(tester);

    expect(
      find.text('Show answer  (Space)'),
      findsOneWidget,
      reason: 'the second opening must hide the answer again',
    );
    expect(
      find.text('New card'),
      findsNothing,
      reason: 'the memory state is re-read, not carried over from before',
    );

    await tester.tap(find.text('Show answer  (Space)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3  Good'));
    await tester.pumpAndSettle();

    expect(
      outcomes,
      <StudyRouteResult>[
        StudyRouteResult.committed,
        StudyRouteResult.committed,
      ],
      reason: 'the second grade must commit and leave the screen',
    );
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('an abandoned reveal does not leak into the next opening', (
    WidgetTester tester,
  ) async {
    await pumpQueue(tester);

    await start(tester);
    await tester.tap(find.text('Show answer  (Space)'));
    await tester.pumpAndSettle();
    expect(find.text('Four.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(outcomes, <StudyRouteResult>[StudyRouteResult.canceled]);

    await start(tester);

    expect(find.text('Show answer  (Space)'), findsOneWidget);
    expect(find.text('Four.'), findsNothing);
  });
}
