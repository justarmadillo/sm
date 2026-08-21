/// Full-text search across sources, extracts, and cards.
library;

import 'package:incremental_reader/src/application/formulation/formulation_commands.dart';
import 'package:incremental_reader/src/application/reader/reader_commands.dart';
import 'package:incremental_reader/src/application/search/search_query.dart';
import 'package:incremental_reader/src/core/clock.dart';
import 'package:incremental_reader/src/core/result.dart';
import 'package:incremental_reader/src/domain/content/card.dart';
import 'package:incremental_reader/src/domain/content/source.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:test/test.dart';

import '../support/app_harness.dart';

const String _pulmonology = '''
# Pulmonary surfactant

Surfactant lowers alveolar surface tension and prevents collapse at the end of
expiration. It is produced by type II pneumocytes.
''';

const String _cardiology = '''
# Preload and afterload

Preload is the ventricular wall stress at the end of diastole. Afterload is the
resistance the ventricle must overcome to eject blood.
''';

extension _Fixtures on AppHarness {
  Future<Source> import(String title, String markdown) async {
    final Result<Source> result = await reader.importSource(
      ImportSource(
        operation(),
        title: title,
        markdown: markdown,
        timestampUtc: clock.nowUtc(),
      ),
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.unwrap();
  }
}

void main() {
  late AppHarness harness;
  late FakeClock clock;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 3, 5, 10));
    harness = AppHarness(clock: clock);
  });

  tearDown(() => harness.close());

  group('query preparation', () {
    test('quotes every token so prose cannot become query syntax', () {
      expect(prepareQuery('surfactant'), '"surfactant"*');
      expect(prepareQuery('type II'), '"type" AND "ii"*');
      expect(
        prepareQuery('NEAR OR "quoted" -minus *star'),
        '"near" AND "or" AND "quoted" AND "minus" AND "star"*',
      );
    });

    test('an empty or punctuation-only query matches nothing', () {
      expect(prepareQuery(''), isEmpty);
      expect(prepareQuery('   '), isEmpty);
      expect(prepareQuery('--- *** ???'), isEmpty);
    });

    test('keeps letters and digits from any script', () {
      expect(prepareQuery('日本語 42'), '"日本語" AND "42"*');
    });
  });

  group('indexing', () {
    test('an imported article is findable by its body, not only its title',
        () async {
      final Source source = await harness.import('Pulmonology', _pulmonology);

      final List<SearchResult> hits = await harness.searchQuery.run(
        'pneumocytes',
      );
      expect(hits, hasLength(1));
      expect(hits.single.ref, ElementRef(id: source.id, type: ElementType.source));
      expect(hits.single.typeLabel, 'Article');
      expect(hits.single.snippet, contains('pneumocytes'));
      expect(
        hits.single.schedule,
        isNotNull,
        reason: 'a result shows when the element is next due',
      );
    });

    test('a card is findable by its answer as well as its question', () async {
      final Source source = await harness.import('Cardiology', _cardiology);
      await harness.formulation.formulate(
        FormulateCards(
          harness.operation(),
          parent: CardParent.source(source.id),
          drafts: const <CardDraft>[
            QaCardDraft(
              question: 'What is preload?',
              answer: 'Ventricular wall stress at end diastole.',
            ),
          ],
          timestampUtc: clock.nowUtc(),
        ),
      );

      final List<SearchResult> hits = await harness.searchQuery.run(
        'diastole',
        types: <ElementType>{ElementType.card},
      );
      expect(hits, hasLength(1));
      expect(hits.single.typeLabel, 'Card');
      expect(hits.single.hit.sourceId, source.id);
    });

    test('results can be restricted by element type', () async {
      await harness.import('Pulmonology', _pulmonology);
      final List<SearchResult> articles = await harness.searchQuery.run(
        'surfactant',
        types: <ElementType>{ElementType.source},
      );
      final List<SearchResult> cards = await harness.searchQuery.run(
        'surfactant',
        types: <ElementType>{ElementType.card},
      );
      expect(articles, hasLength(1));
      expect(cards, isEmpty);
    });

    test('renaming an article updates its indexed title', () async {
      final Source source = await harness.import('Pulmonology', _pulmonology);
      await harness.reader.renameSource(
        RenameSource(
          harness.operation(),
          sourceId: source.id,
          title: 'Alveolar mechanics',
          timestampUtc: clock.nowUtc(),
        ),
      );

      final List<SearchResult> hits = await harness.searchQuery.run('alveolar');
      expect(hits.map((SearchResult r) => r.title), contains('Alveolar mechanics'));
    });

    test('a prefix matches while the user is still typing', () async {
      await harness.import('Pulmonology', _pulmonology);
      expect(await harness.searchQuery.run('surfac'), hasLength(1));
      expect(await harness.searchQuery.run('surf'), hasLength(1));
    });

    test('unrelated articles do not match', () async {
      await harness.import('Pulmonology', _pulmonology);
      await harness.import('Cardiology', _cardiology);
      expect(await harness.searchQuery.run('afterload'), hasLength(1));
      expect(await harness.searchQuery.run('nephron'), isEmpty);
    });
  });

  group('the index itself', () {
    test('reports consistent and countable', () async {
      await harness.import('Pulmonology', _pulmonology);
      await harness.import('Cardiology', _cardiology);

      expect(await harness.searchQuery.indexedCount(), 2);
      expect(await harness.searchQuery.indexIsValid(), isTrue);
    });

    test('rebuilds from the materialized rows without losing anything',
        () async {
      await harness.import('Pulmonology', _pulmonology);
      await harness.search.rebuildIndex();

      expect(await harness.searchQuery.indexIsValid(), isTrue);
      expect(await harness.searchQuery.run('surfactant'), hasLength(1));
    });

    test('a removed document leaves no hit behind', () async {
      final Source source = await harness.import('Pulmonology', _pulmonology);
      await harness.search.deleteDocument(
        ElementRef(id: source.id, type: ElementType.source),
      );

      expect(await harness.searchQuery.run('surfactant'), isEmpty);
      expect(await harness.searchQuery.indexIsValid(), isTrue);
    });

    test('a malformed query yields no results rather than an error', () async {
      await harness.import('Pulmonology', _pulmonology);
      expect(
        await harness.search.search('"unbalanced AND (', limit: 10),
        isEmpty,
      );
    });
  });
}
