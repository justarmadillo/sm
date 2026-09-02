/// The Browser's selection-mode navigation behavior.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_screen.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = openInMemoryDatabase();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 8, 31))),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  testWidgets('back clears selection before leaving the Browser', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const BrowserScreen()),
              ),
              child: const Text('Open Browser'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Browser'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Select elements'));
    await tester.pump();

    expect(find.text('0 selected'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Browser'), findsOneWidget);
    expect(find.text('0 selected'), findsNothing);
  });
}
