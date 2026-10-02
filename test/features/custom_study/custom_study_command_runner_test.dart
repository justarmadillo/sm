/// Saving, changing, and deleting custom decks, the refusals that keep a
/// deck readable, and what tag deletes and merges do to saved decks.
library;

import 'package:incremental_reader/features/custom_study/custom_study_commands.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:test/test.dart';

import '../../support/app_harness.dart';

void main() {
  late AppHarness harness;
  late Tag pharmacology;
  late Tag done;

  Future<Tag> createTag(String name) async => (await harness.tagCommands.create(
    CreateTag(harness.operation(), name: name),
  )).unwrap().tag;

  Future<Result<CustomDeckOutcome>> createDeck(
    String name,
    CustomDeckFilter filter,
  ) => harness.deckCommands.create(
    CreateCustomDeck(harness.operation(), name: name, filter: filter),
  );

  setUp(() async {
    harness = AppHarness();
    pharmacology = await createTag('pharmacology');
    done = await createTag('done');
  });
  tearDown(() => harness.close());

  test('a saved deck reads back exactly as it was saved', () async {
    final CustomDeckFilter filter = CustomDeckFilter(
      includeTagIds: <String>{pharmacology.id},
      excludeTagIds: <String>{done.id},
      match: CustomDeckTagMatch.any,
      types: const <ElementType>{ElementType.card, ElementType.extract},
      shouldReschedule: false,
      sessionLimit: 50,
      order: CustomDeckOrder.random,
      isDueOnly: true,
    );

    final CustomDeck created = (await createDeck(
      '  Pharm   cram ',
      filter,
    )).unwrap().deck;

    final CustomDeck stored = (await harness.decks.findDeck(created.id))!;
    expect(stored.name, 'Pharm cram');
    expect(stored.filter, filter);
  });

  test(
    'refuses a duplicate name, an empty type set, and a tag in both lists',
    () async {
      await createDeck('Pharm', CustomDeckFilter());

      expect(
        (await createDeck('PHARM', CustomDeckFilter())).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await createDeck(
          'No types',
          CustomDeckFilter(types: const <ElementType>{}),
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await createDeck(
          'Both',
          CustomDeckFilter(
            includeTagIds: <String>{pharmacology.id},
            excludeTagIds: <String>{pharmacology.id},
          ),
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await createDeck(
          'Zero',
          CustomDeckFilter(sessionLimit: 0),
        )).failureOrNull,
        isA<ValidationFailure>(),
      );
    },
  );

  test('renames, replaces the filter, and deletes for good', () async {
    final CustomDeck deck = (await createDeck(
      'Pharm',
      CustomDeckFilter(),
    )).unwrap().deck;

    await harness.deckCommands.update(
      UpdateCustomDeck(
        harness.operation(),
        deckId: deck.id,
        name: 'Pharmacology',
        filter: CustomDeckFilter(sessionLimit: 20),
      ),
    );
    final CustomDeck renamed = (await harness.decks.findDeck(deck.id))!;
    expect(renamed.name, 'Pharmacology');
    expect(renamed.filter.sessionLimit, 20);

    await harness.deckCommands.delete(
      DeleteCustomDeck(harness.operation(), deckId: deck.id),
    );
    expect(await harness.decks.listDecks(), isEmpty);
  });

  test('a replayed create applies once', () async {
    final command = CreateCustomDeck(
      harness.operation(),
      name: 'Pharm',
      filter: CustomDeckFilter(),
    );
    expect((await harness.deckCommands.create(command)).isOk, isTrue);
    expect((await harness.deckCommands.create(command)).isErr, isTrue);
    expect(await harness.decks.listDecks(), hasLength(1));
  });

  test('deleting a tag drops it from a deck that named it', () async {
    final CustomDeck deck = (await createDeck(
      'Pharm',
      CustomDeckFilter(
        includeTagIds: <String>{pharmacology.id},
        excludeTagIds: <String>{done.id},
      ),
    )).unwrap().deck;

    await harness.tagCommands.delete(
      DeleteTag(harness.operation(), tagId: done.id),
    );

    final CustomDeck stored = (await harness.decks.findDeck(deck.id))!;
    expect(stored.filter.includeTagIds, <String>{pharmacology.id});
    expect(stored.filter.excludeTagIds, isEmpty);
  });

  test('merging tags moves deck references to the surviving tag', () async {
    final Tag pharm = await createTag('pharm');
    final CustomDeck deck = (await createDeck(
      'Pharm',
      CustomDeckFilter(includeTagIds: <String>{pharm.id}),
    )).unwrap().deck;

    await harness.tagCommands.merge(
      MergeTags(
        harness.operation(),
        sourceTagIds: <String>{pharm.id},
        intoTagId: pharmacology.id,
      ),
    );

    final CustomDeck stored = (await harness.decks.findDeck(deck.id))!;
    expect(stored.filter.includeTagIds, <String>{pharmacology.id});
  });

  test(
    'a merge keeps the role a deck already gave the surviving tag',
    () async {
      final Tag pharm = await createTag('pharm');
      final CustomDeck deck = (await createDeck(
        'Pharm',
        CustomDeckFilter(
          includeTagIds: <String>{pharm.id},
          excludeTagIds: <String>{pharmacology.id},
        ),
      )).unwrap().deck;

      await harness.tagCommands.merge(
        MergeTags(
          harness.operation(),
          sourceTagIds: <String>{pharm.id},
          intoTagId: pharmacology.id,
        ),
      );

      final CustomDeck stored = (await harness.decks.findDeck(deck.id))!;
      expect(stored.filter.includeTagIds, isEmpty);
      expect(stored.filter.excludeTagIds, <String>{pharmacology.id});
    },
  );
}
