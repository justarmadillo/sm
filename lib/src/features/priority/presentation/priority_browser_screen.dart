/// The priority browser: the whole collection in one ordered list.
///
/// The bulk counterpart to the slider. Setting one element's percent is a
/// judgement about that element; dragging a run of them past each other is how
/// a collection actually gets rebalanced, and it is the only place the user
/// can see the shape of their own priorities — which is usually the moment
/// they discover that four hundred things are all "urgent".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/toast.dart';
import '../../../application/priority/priority_query.dart';
import '../../../domain/scheduling/element.dart';
import 'priority_dialog.dart';
import 'priority_view_model.dart';

/// Opens the browser.
Future<void> openPriorityBrowser(BuildContext context, WidgetRef ref) async {
  ref.invalidate(priorityBrowserProvider);
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const PriorityBrowserScreen(),
    ),
  );
}

class PriorityBrowserScreen extends ConsumerWidget {
  const PriorityBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PriorityBrowserState> state = ref.watch(
      priorityBrowserProvider,
    );
    final PriorityBrowserViewModel model = ref.read(
      priorityBrowserProvider.notifier,
    );

    ref.listen<AsyncValue<PriorityBrowserState>>(priorityBrowserProvider, (
      AsyncValue<PriorityBrowserState>? previous,
      AsyncValue<PriorityBrowserState> next,
    ) {
      final message = next.valueOrNull?.message;
      if (message == null) return;
      showToast(context, message.text, isError: message.isError);
      model.clearMessage();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Priority queue'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: model.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not load priorities.\n$error')),
        data: (PriorityBrowserState data) => data.entries.isEmpty
            ? const Center(
                child: Text(
                  'Nothing is scheduled yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            : _Body(state: data, model: model),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state, required this.model});

  final PriorityBrowserState state;
  final PriorityBrowserViewModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        children: <Widget>[
          _FilterBar(state: state, model: model),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
              itemCount: state.entries.length,
              buildDefaultDragHandles: false,
              // onReorderItem already accounts for the dragged row having
              // been removed, so the index needs no adjustment here.
              onReorderItem: model.reorder,
              itemBuilder: (BuildContext context, int index) => _Row(
                key: ValueKey<String>('${state.entries[index].ref}'),
                entry: state.entries[index],
                index: index,
                onSpread: () =>
                    _promptSpread(context, ref, state.entries[index]),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _promptSpread(
    BuildContext context,
    WidgetRef ref,
    PriorityEntry entry,
  ) async {
    final String? sourceId = entry.schedule.rootId;
    if (sourceId == null) {
      showToast(
        context,
        'That element has no article to spread',
        isError: true,
      );
      return;
    }
    final (double, double)? range = await showDialog<(double, double)>(
      context: context,
      builder: (BuildContext context) => const _SpreadDialog(),
    );
    if (range == null) return;
    await model.spreadBranch(
      sourceId: sourceId,
      fromPercent: range.$1,
      toPercent: range.$2,
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state, required this.model});

  final PriorityBrowserState state;
  final PriorityBrowserViewModel model;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: Row(
      children: <Widget>[
        Text(
          '${state.entries.length} elements',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const Spacer(),
        for (final (String label, Set<ElementType> types)
            in <(String, Set<ElementType>)>[
              ('All', <ElementType>{}),
              (
                'Topics',
                <ElementType>{ElementType.source, ElementType.extract},
              ),
              ('Cards', <ElementType>{ElementType.card}),
            ])
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: FilterChip(
              label: Text(label),
              selected: _sameSet(state.types, types),
              onSelected: (_) => model.filterTo(types),
            ),
          ),
      ],
    ),
  );

  bool _sameSet(Set<ElementType> a, Set<ElementType> b) =>
      a.length == b.length && a.containsAll(b);
}

class _Row extends ConsumerWidget {
  const _Row({
    required this.entry,
    required this.index,
    required this.onSpread,
    super.key,
  });

  final PriorityEntry entry;
  final int index;
  final VoidCallback onSpread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (IconData icon, Color color) = switch (entry.ref.type) {
      ElementType.source => (Icons.menu_book_outlined, AppColors.accent),
      ElementType.extract => (Icons.content_cut, AppColors.extractInk),
      ElementType.card => (Icons.quiz_outlined, Colors.teal),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          children: <Widget>[
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.drag_indicator,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${entry.percent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (entry.preview.isNotEmpty)
                    Text(
                      entry.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Set priority (Alt+P)',
              onPressed: () async {
                final bool changed = await showPriorityDialog(
                  context,
                  ref,
                  elementRef: entry.ref,
                );
                if (changed) {
                  await ref.read(priorityBrowserProvider.notifier).refresh();
                }
              },
              icon: const Icon(Icons.tune, size: 17),
            ),
            IconButton(
              tooltip: 'Spread this article’s elements',
              onPressed: onSpread,
              icon: const Icon(Icons.linear_scale, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpreadDialog extends StatefulWidget {
  const _SpreadDialog();

  @override
  State<_SpreadDialog> createState() => _SpreadDialogState();
}

class _SpreadDialogState extends State<_SpreadDialog> {
  RangeValues _range = const RangeValues(20, 80);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Spread priorities'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Every element under this article is spread evenly across the '
            'chosen range, keeping its current order. Worth doing once an '
            'article is finished: its extracts and cards inherited the '
            'article’s priority, which is almost always higher than they '
            'deserve on their own.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          RangeSlider(
            values: _range,
            max: 100,
            divisions: 100,
            labels: RangeLabels(
              '${_range.start.round()}%',
              '${_range.end.round()}%',
            ),
            onChanged: (RangeValues value) => setState(() => _range = value),
          ),
          Text(
            '${_range.start.round()}% to ${_range.end.round()}%',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop((_range.start, _range.end)),
        child: const Text('Spread'),
      ),
    ],
  );
}
