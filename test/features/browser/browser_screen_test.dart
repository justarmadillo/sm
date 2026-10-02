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
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
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

  testWidgets('the row menu ticks Cram only and creates #cram', (
    WidgetTester tester,
  ) async {
    browserRoots = <BrowserTreeNode>[
      _node(id: 'topic', title: 'Pharmacology', day: 1),
    ];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Element actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cram only'));
    await tester.pumpAndSettle();

    final TagRepository tags = container.read(tagRepositoryProvider);
    final Tag? cram = await tester.runAsync<Tag?>(
      () => tags.findTagByLowercaseName(Tag.cramLowercaseName),
    );
    expect(cram, isNotNull);
    expect(
      await tester.runAsync(() => tags.listElementsWithTag(cram!.id)),
      <ElementRef>{const ElementRef(id: 'topic', type: ElementType.source)},
    );
  });

  testWidgets('a row cram-only through its parent cannot be unticked', (
    WidgetTester tester,
  ) async {
    final Tag cram = Tag(
      id: 'cram-tag',
      name: 'cram',
      createdAtUtc: DateTime.utc(2026),
      updatedAtUtc: DateTime.utc(2026),
    );
    await tester.runAsync(
      () => container.read(tagRepositoryProvider).insertTag(cram),
    );
    browserRoots = <BrowserTreeNode>[
      BrowserTreeNode(
        ref: const ElementRef(id: 'card', type: ElementType.card),
        title: 'Inherited card',
        addedAtUtc: DateTime.utc(2026),
        children: const <BrowserTreeNode>[],
        directTagIds: const <String>{},
        effectiveTagIds: const <String>{'cram-tag'},
      ),
    ];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BrowserScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Element actions'));
    await tester.pumpAndSettle();

    final CheckedPopupMenuItem<String> item = tester.widget(
      find.byType(CheckedPopupMenuItem<String>),
    );
    expect(item.checked, isTrue);
    expect(item.enabled, isFalse);
    expect(find.text('Cram only (from a parent)'), findsOneWidget);
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
