/// The Browser's selection-mode navigation behavior.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_screen.dart';
import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late List<BrowserTreeNode> browserRoots;

  setUp(() {
    browserRoots = <BrowserTreeNode>[];
    database = openInMemoryDatabase();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        browserTreeProvider.overrideWith((Ref ref) async => browserRoots),
        clockProvider.overrideWithValue(FakeClock(DateTime.utc(2026, 8, 31))),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );
  });

  testWidgets('Added order composes with the Browser filters', (
    WidgetTester tester,
  ) async {
    browserRoots = <BrowserTreeNode>[
      _node(id: 'older', title: 'Older topic', day: 1),
      _node(id: 'newer', title: 'Newer topic', day: 2),
    ];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Topics'));
    await tester.tap(find.text('Filed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Added — newest first'));
    await tester.pumpAndSettle();

    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Added ↓'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newer topic')).dy,
      lessThan(tester.getTopLeft(find.text('Older topic')).dy),
    );
  });

  testWidgets('new-element menu offers one topic flow', (
    WidgetTester tester,
  ) async {
    browserRoots = <BrowserTreeNode>[
      _node(id: 'topic', title: 'Existing topic', day: 1),
    ];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New element here'));
    await tester.pumpAndSettle();

    expect(find.text('Topic'), findsOneWidget);
    expect(find.text('Topic from markdown'), findsNothing);
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

BrowserTreeNode _node({
  required String id,
  required String title,
  required int day,
}) => BrowserTreeNode(
  ref: ElementRef(id: id, type: ElementType.source),
  title: title,
  addedAtUtc: DateTime.utc(2026, 1, day),
  children: const <BrowserTreeNode>[],
  directTagIds: const <String>{},
  effectiveTagIds: const <String>{},
);
