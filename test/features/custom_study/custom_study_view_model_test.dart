/// The custom-study view model: cycling tags, saving and reverting decks,
/// and how a started session decides each element's scheduling.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/features/custom_study/custom_study_view_model.dart';
import 'package:incremental_reader/features/daily_queue/study_scheduling.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

import '../../support/app_harness.dart';
import '../../support/harness_fixtures.dart';

void main() {
  late AppHarness harness;
  late ProviderContainer container;
  late Source source;
  late Card card;
  late Tag biology;

  CustomStudyViewModel model() =>
      container.read(customStudyViewModelProvider.notifier);

  Future<CustomStudyUiState> current() =>
      container.read(customStudyViewModelProvider.future);

  setUp(() async {
    final FakeClock clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(harness.database),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator(prefix: 'vm')),
      ],
    );
    source = (await harness.importSources(1)).single;
    card = (await harness.formulation.formulate(
      FormulateCards(
        harness.operation(),
        parent: CardParent.source(source.id),
        drafts: const <CardDraft>[
          QaCardDraft(question: 'Question?', answer: 'Answer.'),
        ],
      ),
    )).unwrap().single;
    biology = (await harness.tagCommands.create(
      CreateTag(harness.operation(), name: 'biology'),
    )).unwrap().tag;
    await harness.tagCommands.save(
      SaveTagsOfElement(
        harness.operation(),
        ref: harness.refOf(source),
        tagIds: <String>{biology.id},
      ),
    );
  });

  tearDown(() async {
    container.dispose();
    await harness.close();
  });

  test('a tag cycles off, included, excluded, and off again', () async {
    await current();

    await model().cycleTag(biology.id);
    expect((await current()).filter.includeTagIds, <String>{biology.id});

    await model().cycleTag(biology.id);
    expect((await current()).filter.includeTagIds, isEmpty);
    expect((await current()).filter.excludeTagIds, <String>{biology.id});

    await model().cycleTag(biology.id);
    expect((await current()).filter.excludeTagIds, isEmpty);
  });

  test('a saved deck is selected, tracks changes, and reverts', () async {
    await current();
    await model().cycleTag(biology.id);

    expect(await model().saveAsNewDeck('Biology'), isTrue);
    CustomStudyUiState state = await current();
    expect(state.selectedDeck!.name, 'Biology');
    expect(state.isDirty, isFalse);

    await model().setSessionLimit(10);
    expect((await current()).isDirty, isTrue);

    await model().revert();
    state = await current();
    expect(state.isDirty, isFalse);
    expect(state.filter.sessionLimit, isNull);
  });

  test('a rescheduling deck reviews cards early and reads topics', () async {
    await current();

    final Map<ElementRef, StudyScheduling> steps =
        <ElementRef, StudyScheduling>{
          for (final CustomStudyStep step in model().beginSession())
            step.ref: step.scheduling,
        };

    expect(steps, <ElementRef, StudyScheduling>{
      harness.refOf(source): StudyScheduling.scheduled,
      ElementRef(id: card.id, type: ElementType.card):
          StudyScheduling.earlyReview,
    });
  });

  test('cram-only elements and non-rescheduling decks are practiced', () async {
    await harness.tagCommands.markCramOnly(
      MarkCramOnly(
        harness.operation(),
        refs: <ElementRef>[ElementRef(id: card.id, type: ElementType.card)],
        isCramOnly: true,
      ),
    );
    await current();

    final Map<ElementRef, StudyScheduling> rescheduling =
        <ElementRef, StudyScheduling>{
          for (final CustomStudyStep step in model().beginSession())
            step.ref: step.scheduling,
        };
    expect(
      rescheduling[ElementRef(id: card.id, type: ElementType.card)],
      StudyScheduling.practice,
    );

    await model().setShouldReschedule(false);
    expect(
      model().beginSession().map((CustomStudyStep step) => step.scheduling),
      everyElement(StudyScheduling.practice),
    );
  });

  test('a session stops at the deck limit', () async {
    await current();
    await model().setSessionLimit(1);

    expect(model().beginSession(), hasLength(1));
    expect((await current()).filter.order, CustomDeckOrder.priority);
  });
}
