/// Verifies the Reader's space-saving phone chrome and system UI lifecycle.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProviderContainer container;
  late List<MethodCall> platformCalls;

  setUp(() {
    database = openInMemoryDatabase();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 3, 5))),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    container.dispose();
    await database.close();
  });

  Future<ReaderRequest> importReaderRequest() async {
    final browser = container.read(browserViewModelProvider.notifier);
    await container.read(browserViewModelProvider.future);
    final String? sourceId = await browser.importMarkdown(
      title: 'Phone reading',
      markdown: '# Heading\n\nA paragraph for reading.',
    );
    return ReaderRequest(sourceId: sourceId!, mode: ReaderMode.scheduled);
  }

  Future<void> pumpReader(WidgetTester tester, ReaderRequest request) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReaderScreen(request: request)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone status starts collapsed and expands accessibly', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await pumpReader(tester, await importReaderRequest());

      expect(find.text('Reading status'), findsOneWidget);
      expect(find.text('No marker placed yet'), findsNothing);
      expect(find.bySemanticsLabel('Expand reading status'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Expand reading status'));
      await tester.pump();

      expect(find.text('No marker placed yet'), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse reading status'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('phone actions occupy one compact row', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      await pumpReader(tester, await importReaderRequest());

      final Finder actions = find.byKey(const Key('compact-reader-actions'));
      expect(actions, findsOneWidget);
      expect(tester.getSize(actions).height, lessThanOrEqualTo(43));
      for (final String label in <String>[
        'Formulate',
        'Dismiss',
        'Later',
        'Postpone',
        'Done',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('mobile status bar is restored after leaving Reader', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester, await importReaderRequest());

    expect(
      platformCalls,
      contains(
        isA<MethodCall>()
            .having(
              (MethodCall call) => call.method,
              'method',
              'SystemChrome.setEnabledSystemUIOverlays',
            )
            .having((MethodCall call) => call.arguments, 'arguments', <String>[
              'SystemUiOverlay.bottom',
            ]),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(
      platformCalls,
      contains(
        isA<MethodCall>()
            .having(
              (MethodCall call) => call.method,
              'method',
              'SystemChrome.setEnabledSystemUIMode',
            )
            .having(
              (MethodCall call) => call.arguments,
              'arguments',
              'SystemUiMode.edgeToEdge',
            ),
      ),
    );
  });
}
