/// Reopening a video range must present today's sitting, not the last one's.
///
/// The ViewModel is a keyed family and is not autoDispose, so a finished
/// sitting leaves `isDone` set behind it. Carried into the next opening, the
/// first thing that changes the state — any toast — fires the screen's
/// completion listener and closes the range, counting a repetition the user
/// never made.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/video/video_commands.dart';
import 'package:incremental_reader/features/video/video_providers.dart';
import 'package:incremental_reader/features/video/video_screen.dart';
import 'package:incremental_reader/features/video/video_view_model.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProviderContainer container;
  late FakeClock clock;
  late String elementId;
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
    final VideoElement element = (await container
            .read(videoCommandRunnerProvider)
            .importVideo(
              ImportVideo(
                const OperationId('import-1'),
                url: 'https://www.youtube.com/watch?v=lecture1',
                title: 'Retinal detachment',
                startSeconds: 0,
                endSeconds: 1200,
                durationSeconds: 7200,
                timestampUtc: clock.nowUtc(),
              ),
            ))
        .unwrap();
    elementId = element.id;
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  VideoRequest request() =>
      VideoRequest(videoElementId: elementId, mode: VideoMode.scheduled);

  /// A stand-in for the queue: a screen that opens the same range on demand.
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
                        await openVideoForStudy(
                          context,
                          ref,
                          videoElementId: elementId,
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

  testWidgets('a finished range reopens as an unfinished sitting', (
    WidgetTester tester,
  ) async {
    await pumpQueue(tester);

    await start(tester);
    expect(find.text('Retinal detachment'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(outcomes, <StudyRouteResult>[StudyRouteResult.committed]);

    clock.advance(const Duration(days: 2));
    await start(tester);

    expect(
      find.text('Retinal detachment'),
      findsOneWidget,
      reason: 'the range must stay open until this sitting ends',
    );
    expect(
      container.read(videoViewModelProvider(request())).requireValue.isDone,
      isFalse,
      reason: 'a carried-over isDone closes the screen on the next toast',
    );
  });
}
