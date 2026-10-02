/// The custom-study screen in both shapes: tags with counts beside the
/// matches on a wide window, folded sections on a phone, and Save as deck.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/custom_study/custom_study_screen.dart';
import 'package:incremental_reader/features/custom_study/widgets/tag_filter_list.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

import '../../support/app_harness.dart';
import '../../support/harness_fixtures.dart';

void main() {
  late AppHarness harness;
  late ProviderContainer container;

  setUp(() async {
    final FakeClock clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(harness.database),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator(prefix: 'ui')),
      ],
    );
    final List<Source> sources = await harness.importSources(2);
    final Tag biology = (await harness.tagCommands.create(
      CreateTag(harness.operation(), name: 'biology'),
    )).unwrap().tag;
    await harness.tagCommands.save(
      SaveTagsOfElement(
        harness.operation(),
        ref: harness.refOf(sources.first),
        tagIds: <String>{biology.id},
      ),
    );
  });

  tearDown(() async {
    container.dispose();
    await harness.close();
  });

  final Finder biologyInTagList = find.descendant(
    of: find.byType(TagFilterList),
    matching: find.text('#biology'),
  );

  Future<void> pumpScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CustomStudyScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a tag filters the matches and saves as a deck', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, const Size(1200, 900));

    expect(find.text('Decks'), findsOneWidget);
    expect(biologyInTagList, findsOneWidget);
    expect(find.text('Article 00'), findsOneWidget);
    expect(find.text('Article 01'), findsOneWidget);

    await tester.tap(biologyInTagList);
    await tester.pumpAndSettle();
    expect(find.text('Article 00'), findsOneWidget);
    expect(find.text('Article 01'), findsNothing);

    await tester.tap(find.text('Save as deck…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Biology');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final List<CustomDeck> decks = (await tester.runAsync(
      harness.decks.listDecks,
    ))!;
    expect(decks.single.name, 'Biology');
    expect(decks.single.filter.includeTagIds, hasLength(1));
    expect(find.text('Biology'), findsWidgets);
    // Lets the "Deck saved" toast time out before the tree is torn down.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a phone folds decks and tags above the matches', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, const Size(400, 900));

    expect(find.byType(ExpansionTile), findsNWidgets(2));
    expect(find.text('Tags'), findsOneWidget);
    expect(biologyInTagList, findsNothing);

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(biologyInTagList, findsOneWidget);
  });
}
