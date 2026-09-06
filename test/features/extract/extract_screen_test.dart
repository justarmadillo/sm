/// Reopening an extract must present today's sitting, not the last one's.
///
/// The ViewModel is a keyed family and is not autoDispose, so a finished
/// sitting leaves `isDone` set behind it. Carried into the next opening, the
/// first thing that changes the state — any toast — fires the screen's
/// completion listener and closes the extract, counting a repetition the user
/// never made.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

import '../../support/anchors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProviderContainer container;
  late FakeClock clock;
  late String extractId;
  late List<StudyRouteResult> outcomes;

  setUp(() async {
    database = openInMemoryDatabase();
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
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
          markdown: '# Encoding\n\nThe idea worth keeping, and some padding.',
        ))!;

    final ReaderRequest request = ReaderRequest(
      sourceId: sourceId,
      mode: ReaderMode.scheduled,
    );
    final ReaderUiState reader = await container.read(
      readerViewModelProvider(request).future,
    );
    final Block block = reader.document.blocks[1];
    const String needle = 'The idea worth keeping';
    final (int startUtf8, int endUtf8) = block.sourceRangeForRendered(
      block.renderedText.indexOf(needle),
      block.renderedText.indexOf(needle) + needle.length,
    );
    final ReaderAnchor start = anchorIn(block, startUtf8);
    final ReaderAnchor end = anchorIn(block, endUtf8);
    final Extract? created = await container
        .read(readerViewModelProvider(request).notifier)
        .extractSelection(
          SelectionRange.of(
            startAnchor: start,
            endAnchor: end,
            markdown: reader.document.markdownBetween(start, end),
          ),
        );
    extractId = created!.id;
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  ExtractRequest request() =>
      ExtractRequest(extractId: extractId, mode: ExtractMode.scheduled);

  /// A stand-in for the queue: a screen that opens the same extract on demand.
  Future<void> pumpQueue(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                        await openExtract(
                          context,
                          ref,
                          extractId: extractId,
                          mode: ExtractMode.scheduled,
                        ),
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

  testWidgets('a finished extract reopens as an unfinished sitting', (
    WidgetTester tester,
  ) async {
    await pumpQueue(tester);

    await start(tester);
    expect(find.text('Process extract'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(outcomes, <StudyRouteResult>[StudyRouteResult.committed]);

    clock.advance(const Duration(days: 2));
    await start(tester);

    expect(
      find.text('Process extract'),
      findsOneWidget,
      reason: 'the extract must stay open until this sitting ends',
    );
    expect(
      container.read(extractViewModelProvider(request())).requireValue.isDone,
      isFalse,
      reason: 'a carried-over isDone closes the screen on the next toast',
    );
  });
}
