/// Full-text search across the collection.
///
/// Once there are a few hundred extracts, "did I already make a card about
/// this?" and "where did I read that?" are the two questions asked most often,
/// and a tree answers neither. Articles are indexed whole, so a passage is
/// findable before it has ever been extracted.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:incremental_reader/src/app/providers.dart';
import 'package:incremental_reader/src/app/theme.dart';
import 'package:incremental_reader/src/application/search/search_query.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/features/extract/presentation/extract_screen.dart';
import 'package:incremental_reader/src/features/extract/presentation/extract_view_model.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_screen.dart';
import 'package:incremental_reader/src/features/reader/presentation/reader_view_model.dart';

/// The Windows shortcut that opens search.
const SingleActivator kSearchShortcut = SingleActivator(
  LogicalKeyboardKey.keyF,
  control: true,
);

/// Opens the search screen.
Future<void> openSearch(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const SearchScreen(),
    ),
  );
}

/// The current query text.
final StateProvider<String> searchTextProvider = StateProvider<String>(
  (Ref ref) => '',
);

/// The type filter, empty meaning everything.
final StateProvider<Set<ElementType>> searchTypesProvider =
    StateProvider<Set<ElementType>>((Ref ref) => const <ElementType>{});

/// Results for the current query.
final FutureProvider<List<SearchResult>> searchResultsProvider =
    FutureProvider<List<SearchResult>>((Ref ref) async {
      final String query = ref.watch(searchTextProvider);
      final Set<ElementType> types = ref.watch(searchTypesProvider);
      if (query.trim().length < 2) return const <SearchResult>[];
      return ref
          .watch(searchQueryProvider)
          .run(query, types: types.isEmpty ? null : types);
    });

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = ref.read(searchTextProvider);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<SearchResult>> results = ref.watch(
      searchResultsProvider,
    );
    final Set<ElementType> types = ref.watch(searchTypesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search articles, extracts, and cards',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (String value) =>
                      ref.read(searchTextProvider.notifier).state = value,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    for (final (String label, Set<ElementType> filter)
                        in <(String, Set<ElementType>)>[
                          ('Everything', <ElementType>{}),
                          ('Articles', <ElementType>{ElementType.source}),
                          ('Extracts', <ElementType>{ElementType.extract}),
                          ('Cards', <ElementType>{ElementType.card}),
                        ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(label),
                          selected:
                              types.length == filter.length &&
                              types.containsAll(filter),
                          onSelected: (_) =>
                              ref.read(searchTypesProvider.notifier).state =
                                  filter,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stack) =>
                      Center(child: Text('Search failed.\n$error')),
                  data: (List<SearchResult> data) => data.isEmpty
                      ? _Empty(query: _controller.text)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
                          itemCount: data.length,
                          itemBuilder: (BuildContext context, int index) =>
                              _ResultTile(result: data[index]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      query.trim().length < 2
          ? 'Type at least two characters.'
          : 'Nothing matched “$query”.',
      style: const TextStyle(color: AppColors.muted),
    ),
  );
}

class _ResultTile extends ConsumerWidget {
  const _ResultTile({required this.result});

  final SearchResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (IconData icon, Color color) = switch (result.ref.type) {
      ElementType.source => (Icons.menu_book_outlined, AppColors.accent),
      ElementType.extract => (Icons.content_cut, AppColors.extractInk),
      ElementType.card => (Icons.quiz_outlined, Colors.teal),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Every result opens in browse mode: looking something up must never
        // be mistaken by the scheduler for having processed it.
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          result.typeLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            result.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (result.schedule case final schedule?)
                          Text(
                            schedule.lifecycle.isSchedulable
                                ? 'due ${result.effectiveDueDay ?? schedule.algorithmicDueDay}'
                                : schedule.lifecycle.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.snippet.replaceAll(RegExp(r'\s+'), ' '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    switch (result.ref.type) {
      case ElementType.source:
        await openReader(
          context,
          ref,
          sourceId: result.ref.id,
          mode: ReaderMode.browse,
        );
      case ElementType.extract:
        await openExtract(
          context,
          ref,
          extractId: result.ref.id,
          mode: ExtractMode.browse,
        );
      case ElementType.card:
        // A card has no browse surface of its own; its article is the useful
        // destination, because that is where a badly written card gets fixed.
        final String? sourceId = result.hit.sourceId;
        if (sourceId == null) return;
        await openReader(
          context,
          ref,
          sourceId: sourceId,
          mode: ReaderMode.browse,
        );
    }
  }
}
