/// The Alt+P dialog's neighbours, which are the whole point of the slider.
///
/// "More important than this, less important than that" is a judgement a
/// person can make; an abstract 42% is not. So the two named neighbours have
/// to follow the slider, and they have to survive a commit — a dialog that
/// blanks them the moment anything is written stops answering the only
/// question it was opened to answer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late List<ElementRef> sources;

  setUp(() async {
    database = openInMemoryDatabase();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(
          FakeClock(DateTime.utc(2026, 3, 5, 10)),
        ),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator()),
      ],
    );

    final BrowserViewModel library = container.read(
      browserViewModelProvider.notifier,
    );
    await container.read(browserViewModelProvider.future);
    sources = <ElementRef>[];
    for (final String title in <String>['First', 'Second', 'Third', 'Fourth']) {
      final String? id = await library.importMarkdown(
        title: title,
        markdown: '# $title\n\nA paragraph belonging to $title.\n',
      );
      sources.add(ElementRef(id: id!, type: ElementType.source));
    }
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  PrioritySliderViewModel modelFor(ElementRef ref) =>
      container.read(prioritySliderViewModelProvider(ref).notifier);

  Future<PrioritySliderState> stateFor(ElementRef ref) =>
      container.read(prioritySliderViewModelProvider(ref).future);

  test('the neighbours are named as soon as the dialog opens', () async {
    final PrioritySliderState opened = await stateFor(sources.last);

    expect(opened.draftAbove ?? opened.draftBelow, isNotNull);
  });

  test('dragging the slider names the neighbours at the new place', () async {
    final ElementRef ref = sources.last;
    await stateFor(ref);
    final PrioritySliderViewModel model = modelFor(ref);

    model.draft(0);
    // The neighbour query is resolved off the slider's own notification, so
    // the answer arrives on a later microtask than the drag.
    await Future<void>.delayed(Duration.zero);

    final PrioritySliderState atTop = container
        .read(prioritySliderViewModelProvider(ref))
        .value!;
    expect(atTop.draftPercent, 0);
    expect(
      atTop.draftAbove,
      isNull,
      reason: 'nothing is more important than the top of the queue',
    );
    expect(atTop.draftBelow, isNotNull, reason: 'the rest of the collection');
  });

  test('moving back down names a different neighbour again', () async {
    final ElementRef ref = sources.last;
    await stateFor(ref);
    final PrioritySliderViewModel model = modelFor(ref);

    model.draft(0);
    await Future<void>.delayed(Duration.zero);
    final String? atTop = container
        .read(prioritySliderViewModelProvider(ref))
        .value!
        .draftBelow
        ?.title;

    model.draft(100);
    await Future<void>.delayed(Duration.zero);
    final PrioritySliderState atBottom = container
        .read(prioritySliderViewModelProvider(ref))
        .value!;

    expect(atBottom.draftBelow, isNull, reason: 'nothing is less important');
    expect(atBottom.draftAbove, isNotNull);
    expect(atBottom.draftAbove!.title, isNot(atTop));
  });

  test('committing keeps the neighbours on screen', () async {
    final ElementRef ref = sources.last;
    await stateFor(ref);
    final PrioritySliderViewModel model = modelFor(ref);

    model.draft(0);
    await Future<void>.delayed(Duration.zero);
    expect(await model.commit(), isTrue);

    final PrioritySliderState committed = container
        .read(prioritySliderViewModelProvider(ref))
        .value!;
    expect(committed.draftBelow, isNotNull);
  });

  test('stepping one place keeps the neighbours on screen', () async {
    final ElementRef ref = sources.last;
    await stateFor(ref);
    final PrioritySliderViewModel model = modelFor(ref);

    await model.step(shouldIncrease: true);

    final PrioritySliderState stepped = container
        .read(prioritySliderViewModelProvider(ref))
        .value!;
    expect(stepped.draftAbove ?? stepped.draftBelow, isNotNull);
  });
}
