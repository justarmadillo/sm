/// The priority browser: the whole collection in one ordered list.
///
/// The bulk counterpart to the slider. Setting one element's percent is a
/// judgement about that element; dragging a run of them past each other is how
/// a collection actually gets rebalanced, and it is the only place the user
/// can see the shape of their own priorities — which is usually the moment
/// they discover that four hundred things are all "urgent".
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/browser/open_element.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/daily_queue/smart_postpone_dialog.dart';
import 'package:incremental_reader/features/priority/learning_command_menu.dart';
import 'package:incremental_reader/features/priority/learning_commands.dart';
import 'package:incremental_reader/features/priority/priority_commands.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

/// Opens the browser.
Future<void> openPriorityBrowser(BuildContext context, WidgetRef ref) async {
  ref.invalidate(priorityBrowserViewModelProvider);
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
      priorityBrowserViewModelProvider,
    );
    final PriorityBrowserViewModel model = ref.read(
      priorityBrowserViewModelProvider.notifier,
    );

    ref.listen<AsyncValue<PriorityBrowserState>>(
      priorityBrowserViewModelProvider,
      (
        AsyncValue<PriorityBrowserState>? previous,
        AsyncValue<PriorityBrowserState> next,
      ) {
        final message = next.valueOrNull?.message;
        if (message == null) return;
        showToast(context, message.text, isError: message.isError);
        model.shouldClearMessage();
      },
    );

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
        // The empty state is rendered inside the body, never instead of it:
        // replacing the whole body would take the filter bar with it, and a
        // filter that returns nothing would then have no way back.
        data: (PriorityBrowserState browser) =>
            _BrowserBody(state: browser, model: model),
      ),
    );
  }
}

class _BrowserBody extends ConsumerWidget {
  const _BrowserBody({required this.state, required this.model});

  final PriorityBrowserState state;
  final PriorityBrowserViewModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        children: <Widget>[
          _FilterBar(state: state, model: model),
          _HeaderRow(state: state, model: model),
          if (state.entries.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Nothing matches this filter.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            Expanded(
              child: !state.isReorderable
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                      itemCount: state.entries.length,
                      itemBuilder: (BuildContext context, int index) =>
                          _ElementRow(
                            key: ValueKey<String>(
                              '${state.entries[index].ref}',
                            ),
                            entry: state.entries[index],
                            index: index,
                            isDraggable: false,
                            onBatchPriority: () => _promptBatchPriority(
                              context,
                              ref,
                              state.entries[index],
                            ),
                            onSmartPostpone: () => _confirmSmartPostpone(
                              context,
                              state.entries[index],
                            ),
                            onLearningCommand: (LearningCommand command) =>
                                _runLearningCommand(
                                  context,
                                  state.entries[index],
                                  command,
                                ),
                          ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                      itemCount: state.entries.length,
                      buildDefaultDragHandles: false,
                      // onReorderItem already accounts for the dragged row having
                      // been removed, so the index needs no adjustment here.
                      onReorderItem: model.reorder,
                      itemBuilder: (BuildContext context, int index) =>
                          _ElementRow(
                            key: ValueKey<String>(
                              '${state.entries[index].ref}',
                            ),
                            entry: state.entries[index],
                            index: index,
                            onBatchPriority: () => _promptBatchPriority(
                              context,
                              ref,
                              state.entries[index],
                            ),
                            onSmartPostpone: () => _confirmSmartPostpone(
                              context,
                              state.entries[index],
                            ),
                            onLearningCommand: (LearningCommand command) =>
                                _runLearningCommand(
                                  context,
                                  state.entries[index],
                                  command,
                                ),
                          ),
                    ),
            ),
        ],
      ),
    ),
  );

  /// Runs one Learning command against a single element.
  ///
  /// The confirmation and the follow-up questions are the shared ones the
  /// Browser rows use too: a command that discards work must say the same
  /// thing wherever the user reached it from.
  Future<void> _runLearningCommand(
    BuildContext context,
    PriorityEntry entry,
    LearningCommand command,
  ) async {
    final LearningCommandAnswers? answers = await askForLearningCommand(
      context,
      command,
    );
    if (answers == null) return;
    await model.applyLearningCommand(command, <ElementRef>[
      entry.ref,
    ], answers: answers);
  }

  /// Simulates Smart Postpone over one branch, then applies what was shown.
  ///
  /// A branch run reaches elements the Outstanding queue never offers, so it
  /// is confirmed against the same decision list the queue's own run shows.
  Future<void> _confirmSmartPostpone(
    BuildContext context,
    PriorityEntry entry,
  ) async {
    final String? sourceId = entry.schedule.rootId;
    if (sourceId == null) {
      showToast(context, 'That element has no article branch', isError: true);
      return;
    }
    final AppliedSmartPostpone? simulated = await model.smartPostpone(
      isSimulationOnly: true,
      branchSourceId: sourceId,
    );
    if (simulated == null || !context.mounted) return;
    if (!await confirmSmartPostpone(context, simulated.result)) return;
    await model.smartPostpone(
      isSimulationOnly: false,
      branchSourceId: sourceId,
    );
  }

  Future<void> _promptBatchPriority(
    BuildContext context,
    WidgetRef ref,
    PriorityEntry entry,
  ) async {
    final String? sourceId = entry.schedule.rootId;
    if (sourceId == null) {
      showToast(context, 'That element has no article branch', isError: true);
      return;
    }
    final _PriorityBatchDraft? draft = await showDialog<_PriorityBatchDraft>(
      context: context,
      builder: (BuildContext context) => const _PriorityBatchDialog(),
    );
    if (draft == null) return;
    await model.batchBranch(
      sourceId: sourceId,
      mode: draft.mode,
      lowPercent: draft.low,
      highPercent: draft.high,
      changePercent: draft.change,
      shouldLimitChanges: draft.shouldLimitChanges,
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
    // Two labelled buttons and three chips need more than a phone's width
    // beside a count, so there they wrap onto their own lines underneath it.
    child: isCompactWidth(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _countLine(),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[..._bulkActions(context), ..._typeChips()],
              ),
            ],
          )
        : Row(
            children: <Widget>[
              _countLine(),
              const Spacer(),
              ..._bulkActions(context),
              for (final Widget chip in _typeChips())
                Padding(padding: const EdgeInsets.only(left: 6), child: chip),
            ],
          ),
  );

  /// How many rows the current filter is showing.
  Widget _countLine() => Text(
    '${state.entries.length} elements',
    style: const TextStyle(fontSize: 13, color: AppColors.muted),
  );

  /// The two commands that act on every row on screen at once.
  ///
  /// Both move elements through time, so the pair has to read as opposites:
  /// a clock turning forward for Postpone, and the transport control for
  /// Advance. The old `schedule_send` was a clock with a paper plane, which
  /// at sixteen pixels is a play triangle and says "run this" rather than
  /// "move this later".
  List<Widget> _bulkActions(BuildContext context) => <Widget>[
    TextButton.icon(
      onPressed: state.isBusy || state.entries.isEmpty
          ? null
          : () => _confirmSmartPostpone(context),
      icon: const Icon(Icons.update, size: 16),
      label: const Text('Smart Postpone these'),
    ),
    TextButton.icon(
      onPressed: state.isBusy || state.entries.isEmpty
          ? null
          : () => _promptAdvance(context),
      icon: const Icon(Icons.fast_forward, size: 16),
      label: const Text('Advance these'),
    ),
  ];

  /// Which kinds of element the list is narrowed to.
  List<Widget> _typeChips() => <Widget>[
    for (final (String label, Set<ElementType> types)
        in <(String, Set<ElementType>)>[
          ('All', <ElementType>{}),
          (
            'Topics',
            <ElementType>{
              ElementType.source,
              ElementType.extract,
              ElementType.video,
            },
          ),
          ('Cards', <ElementType>{ElementType.card}),
        ])
      FilterChip(
        label: Text(label),
        selected: _areSetsEqual(state.types, types),
        onSelected: (_) => model.filterTo(types),
      ),
  ];

  /// Advance over exactly the rows the browser is showing.
  Future<void> _promptAdvance(BuildContext context) async {
    final _AdvanceDraft? draft = await showDialog<_AdvanceDraft>(
      context: context,
      builder: (BuildContext context) => const _AdvanceDialog(),
    );
    if (draft == null) return;
    await model.advance(
      <ElementRef>[for (final PriorityEntry entry in state.entries) entry.ref],
      scope: draft.scope,
      horizonDays: draft.horizonDays,
    );
  }

  /// Runs the browser scope over exactly the filtered rows on screen.
  Future<void> _confirmSmartPostpone(BuildContext context) async {
    final AppliedSmartPostpone? simulated = await model.smartPostpone(
      isSimulationOnly: true,
    );
    if (simulated == null || !context.mounted) return;
    if (!await confirmSmartPostpone(context, simulated.result)) return;
    await model.smartPostpone(isSimulationOnly: false);
  }

  bool _areSetsEqual(Set<ElementType> a, Set<ElementType> b) =>
      a.length == b.length && a.containsAll(b);
}

class _ElementRow extends ConsumerWidget {
  const _ElementRow({
    required this.entry,
    required this.index,
    required this.onBatchPriority,
    required this.onSmartPostpone,
    required this.onLearningCommand,
    this.isDraggable = true,
    super.key,
  });

  final PriorityEntry entry;
  final int index;

  /// Whether this row offers a drag handle. Only the priority order can be
  /// dragged, because only there does "the row above" mean "the rank above".
  final bool isDraggable;
  final VoidCallback onBatchPriority;
  final VoidCallback onSmartPostpone;
  final ValueChanged<LearningCommand> onLearningCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      // Tapping a row opens the element, the same as in the Browser: a queue
      // of titles is where a badly written extract is noticed, and having to
      // find it again somewhere else to fix it is how it stays badly written.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => unawaited(_open(context, ref)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: isCompactWidth(context)
                ? _stackedRow(context, ref)
                : _columnedRow(context, ref),
          ),
        ),
      ),
    );
  }

  /// Opens the element for reading or editing, then reloads the list: an edit
  /// changes the preview this row shows.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    await openElement(context, ref, elementRef: entry.ref);
    await ref.read(priorityBrowserViewModelProvider.notifier).refresh();
  }

  /// The desktop shape: every measurement gets a column of its own, under the
  /// heading that sorts by it.
  Widget _columnedRow(BuildContext context, WidgetRef ref) => Row(
    children: <Widget>[
      _dragHandle(),
      _percentCell(),
      _typeBadgeCell(shouldShowLabel: true),
      const SizedBox(width: 8),
      Expanded(child: _titleAndPreview()),
      _Cell(width: _kIntervalWidth, text: '${entry.intervalDays}'),
      _Cell(width: _kCountWidth, text: '${entry.repetitions}'),
      _Cell(width: _kCountWidth, text: '${entry.lapses}'),
      _Cell(width: _kDateWidth, text: entry.lastRepetition?.toString() ?? '—'),
      _Cell(width: _kDateWidth, text: entry.nextRepetition.toString()),
      SizedBox(
        width: _kActionsWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _actionButtons(context, ref),
        ),
      ),
    ],
  );

  /// The phone shape. The five measurements written out as a sentence took a
  /// whole line and still pushed the title into an ellipsis; the title is the
  /// one thing that says which element this is, so it gets the width and the
  /// measurements move behind the info button on the line below.
  Widget _stackedRow(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          _dragHandle(),
          _percentCell(),
          _typeBadgeCell(shouldShowLabel: false),
          const SizedBox(width: 6),
          Expanded(child: _titleAndPreview()),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          _MeasurementsButton(entry: entry),
          ..._actionButtons(context, ref),
        ],
      ),
    ],
  );

  /// A blank of the same width when the row cannot be dragged, so every row
  /// stays aligned whichever sort is active.
  Widget _dragHandle() {
    if (!isDraggable) return const SizedBox(width: _kHandleWidth);
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.drag_indicator, size: 18, color: AppColors.muted),
      ),
    );
  }

  Widget _percentCell() {
    return SizedBox(
      width: _kPercentWidth,
      child: Text(
        '${entry.percent.toStringAsFixed(1)}%',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }

  /// The word beside the icon is what keeps the desktop columns aligned; on a
  /// phone it costs sixty pixels of title to say something the icon and its
  /// colour already say.
  Widget _typeBadgeCell({required bool shouldShowLabel}) {
    return SizedBox(
      width: shouldShowLabel ? _kBadgeWidth : _kBadgeIconWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElementTypeBadge(
          type: entry.ref.type,
          shouldShowLabel: shouldShowLabel,
        ),
      ),
    );
  }

  /// The element's title, with the first line of its text beneath when there
  /// is one: two elements can share a title but rarely a first line.
  Widget _titleAndPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        if (entry.preview.isNotEmpty)
          Text(
            entry.preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }

  /// The four per-row commands: set priority, batch priority, smart postpone,
  /// and the learning menu.
  ///
  /// Set and batch are the same operation at two scales, which is exactly why
  /// they may not look alike: one slider icon and one outlined slider icon
  /// were indistinguishable at seventeen pixels, and getting them the wrong
  /// way round rewrites a whole article's priorities.
  List<Widget> _actionButtons(BuildContext context, WidgetRef ref) {
    return <Widget>[
      IconButton(
        tooltip: 'Set priority (Alt+P)',
        onPressed: () async {
          final bool hasChanged = await showPriorityDialog(
            context,
            ref,
            elementRef: entry.ref,
          );
          if (hasChanged) {
            await ref.read(priorityBrowserViewModelProvider.notifier).refresh();
          }
        },
        constraints: _kActionConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.tune, size: 17),
      ),
      IconButton(
        tooltip: 'Batch priority for this article',
        onPressed: onBatchPriority,
        constraints: _kActionConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.account_tree_outlined, size: 17),
      ),
      IconButton(
        tooltip: 'Smart Postpone this article',
        onPressed: onSmartPostpone,
        constraints: _kActionConstraints,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.update, size: 17),
      ),
      LearningCommandMenu(
        onSelected: onLearningCommand,
        size: _kActionConstraints.maxWidth,
      ),
    ];
  }
}

/// The five scheduling measurements, behind a button.
///
/// They are columns on a desktop window, where the headings say which number
/// is which. A phone has no room for either, and a row of unlabelled numbers
/// is worse than no numbers at all, so on a phone they are asked for.
class _MeasurementsButton extends StatelessWidget {
  const _MeasurementsButton({required this.entry});

  final PriorityEntry entry;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _kActionConstraints.maxWidth,
    height: _kActionConstraints.maxHeight,
    child: PopupMenuButton<void>(
      tooltip: 'Scheduling details',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.info_outline, size: 17),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          // Nothing here is a command, so nothing here is selectable. It is
          // still a menu because that is the shape the row has room for.
          enabled: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final (String name, String value) in <(String, String)>[
                ('Interval', '${entry.intervalDays} d'),
                ('Repetitions', '${entry.repetitions}'),
                ('Lapses', '${entry.lapses}'),
                ('Last', entry.lastRepetition?.toString() ?? '—'),
                ('Next', entry.nextRepetition.toString()),
              ])
                _measurementLine(name, value),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _measurementLine(String name, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 86,
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    ),
  );
}

final class _PriorityBatchDraft {
  const _PriorityBatchDraft({
    required this.mode,
    required this.low,
    required this.high,
    required this.change,
    required this.shouldLimitChanges,
  });

  final Sm20BatchPriorityMode mode;
  final double low;
  final double high;
  final double change;
  final bool shouldLimitChanges;
}

class _PriorityBatchDialog extends StatefulWidget {
  const _PriorityBatchDialog();

  @override
  State<_PriorityBatchDialog> createState() => _PriorityBatchDialogState();
}

class _PriorityBatchDialogState extends State<_PriorityBatchDialog> {
  Sm20BatchPriorityMode _mode = Sm20BatchPriorityMode.spread;
  final TextEditingController _low = TextEditingController(text: '20');
  final TextEditingController _high = TextEditingController(text: '80');
  final TextEditingController _change = TextEditingController(text: '0');
  bool _shouldLimitChanges = true;
  String? _error;

  @override
  void dispose() {
    _low.dispose();
    _high.dispose();
    _change.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Batch priority'),
    content: SizedBox(
      width: dialogContentWidth(context, preferred: 460),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'The operation follows the branch’s stored order. Each element is '
            'removed and reinserted immediately, so earlier changes can shift '
            'the live percentage used by later elements.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Sm20BatchPriorityMode>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Operation'),
            items: <DropdownMenuItem<Sm20BatchPriorityMode>>[
              for (final Sm20BatchPriorityMode mode
                  in Sm20BatchPriorityMode.values)
                DropdownMenuItem<Sm20BatchPriorityMode>(
                  value: mode,
                  child: Text(
                    '${mode.name[0].toUpperCase()}${mode.name.substring(1)}',
                  ),
                ),
            ],
            onChanged: (Sm20BatchPriorityMode? value) {
              if (value == null) return;
              setState(() {
                _mode = value;
                _change.text = switch (value) {
                  Sm20BatchPriorityMode.shouldIncrease => '50',
                  Sm20BatchPriorityMode.decrease => '150',
                  Sm20BatchPriorityMode.spread ||
                  Sm20BatchPriorityMode.adjust => '0',
                };
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _low,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Low priority %',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _high,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'High priority %',
                  ),
                ),
              ),
            ],
          ),
          if (_mode == Sm20BatchPriorityMode.shouldIncrease ||
              _mode == Sm20BatchPriorityMode.decrease) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _change,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Change %',
                helperText: 'Increase starts at 50; Decrease starts at 150.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Limit changes to the selected range'),
              value: _shouldLimitChanges,
              onChanged: (bool value) =>
                  setState(() => _shouldLimitChanges = value),
            ),
          ],
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Apply')),
    ],
  );

  void _submit() {
    final double? low = double.tryParse(_low.text.trim());
    final double? high = double.tryParse(_high.text.trim());
    final double? change = double.tryParse(_change.text.trim());
    if (low == null || high == null || change == null) {
      setState(() => _error = 'Enter valid numeric values.');
      return;
    }
    Navigator.of(context).pop(
      _PriorityBatchDraft(
        mode: _mode,
        low: low,
        high: high,
        change: change,
        shouldLimitChanges: _shouldLimitChanges,
      ),
    );
  }
}

/// The Advance dialog: scope plus a horizon in days.
class _AdvanceDialog extends StatefulWidget {
  const _AdvanceDialog();

  @override
  State<_AdvanceDialog> createState() => _AdvanceDialogState();
}

class _AdvanceDraft {
  const _AdvanceDraft({required this.scope, required this.horizonDays});

  final Sm20AdvanceScope scope;
  final int horizonDays;
}

class _AdvanceDialogState extends State<_AdvanceDialog> {
  Sm20AdvanceScope _scope = Sm20AdvanceScope.topics;
  late final TextEditingController _days = TextEditingController(
    text: '$kSm20AdvanceDefaultDays',
  );

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  int? get _horizon {
    final int? value = int.tryParse(_days.text.trim());
    if (value == null) return null;
    return value < _scope.minimumDays || value > kSm20AdvanceMaximumDays
        ? null
        : value;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Advance'),
    content: SizedBox(
      width: dialogContentWidth(context, preferred: 380),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Advance pulls future work closer to today. For a topic it is a '
            'real forced repetition, so the A-factor and priority adapt; for '
            'a card it only moves the due date. Elements whose interval is '
            'already inside the horizon are left alone.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Sm20AdvanceScope>(
            initialValue: _scope,
            decoration: const InputDecoration(
              labelText: 'Elements',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const <DropdownMenuItem<Sm20AdvanceScope>>[
              DropdownMenuItem<Sm20AdvanceScope>(
                value: Sm20AdvanceScope.topics,
                child: Text('Topics'),
              ),
              DropdownMenuItem<Sm20AdvanceScope>(
                value: Sm20AdvanceScope.items,
                child: Text('Items'),
              ),
              DropdownMenuItem<Sm20AdvanceScope>(
                value: Sm20AdvanceScope.all,
                child: Text('All elements'),
              ),
            ],
            onChanged: (Sm20AdvanceScope? value) {
              if (value == null) return;
              setState(() => _scope = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _days,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Days',
              helperText:
                  '${_scope.minimumDays}–$kSm20AdvanceMaximumDays; '
                  'items need at least two.',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
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
        onPressed: _horizon == null
            ? null
            : () => Navigator.of(
                context,
              ).pop(_AdvanceDraft(scope: _scope, horizonDays: _horizon!)),
        child: const Text('Advance'),
      ),
    ],
  );
}

/// Column widths shared by the header and every row.
///
/// The header used to guess the width of the type badge and the action
/// cluster, both of which vary with their content, so the headings drifted out
/// of line with the numbers beneath them. Both are pinned here instead, and
/// both layouts read the same constants.
const double _kBadgeWidth = 84;
const double _kActionsWidth = 132;
const double _kHandleWidth = 30;

/// The badge without its word, on a phone.
const double _kBadgeIconWidth = 22;

/// Four of these fill [_kActionsWidth] exactly.
const BoxConstraints _kActionConstraints = BoxConstraints.tightFor(
  width: 33,
  height: 33,
);
const double _kIntervalWidth = 52;
const double _kCountWidth = 44;
const double _kDateWidth = 92;
const double _kPercentWidth = 52;

/// One right-aligned numeric or date cell.
class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.text});

  final double width;
  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    ),
  );
}

/// Column headers. Clicking one sorts by it; clicking it again reverses.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.state, required this.model});

  final PriorityBrowserState state;
  final PriorityBrowserViewModel model;

  @override
  Widget build(BuildContext context) {
    // Headings sit over columns, and the narrow layout has no columns to sit
    // over, so there the same sorts are offered as a menu instead.
    if (isCompactWidth(context)) {
      return _CompactSortBar(state: state, model: model);
    }
    return Padding(
      // 16 for the list's padding, 6 for the row card's own padding, plus the
      // one-pixel border the card draws.
      padding: const EdgeInsets.fromLTRB(23, 6, 23, 2),
      child: Row(
        children: <Widget>[
          // Every spacer below is the same constant the row uses, so the
          // headings sit over the columns they name by construction rather than
          // by two layouts happening to agree.
          const SizedBox(width: _kHandleWidth),
          _ColumnHeader(
            state: state,
            model: model,
            sort: PriorityBrowserSort.priority,
            width: _kPercentWidth,
            align: TextAlign.left,
          ),
          const SizedBox(width: _kBadgeWidth + 8),
          Expanded(
            child: _ColumnHeader(
              state: state,
              model: model,
              sort: PriorityBrowserSort.title,
              align: TextAlign.left,
            ),
          ),
          _ColumnHeader(
            state: state,
            model: model,
            sort: PriorityBrowserSort.interval,
            width: _kIntervalWidth,
          ),
          _ColumnHeader(
            state: state,
            model: model,
            sort: PriorityBrowserSort.repetitions,
            width: _kCountWidth,
          ),
          _ColumnHeader(
            state: state,
            model: model,
            sort: PriorityBrowserSort.lapses,
            width: _kCountWidth,
          ),
          _ColumnHeader(
            state: state,
            model: model,
            sort: PriorityBrowserSort.lastRepetition,
            width: _kDateWidth,
          ),
          _ColumnHeader(
            state: state,
            model: model,
            sort: PriorityBrowserSort.nextRepetition,
            width: _kDateWidth,
          ),
          const SizedBox(width: _kActionsWidth),
        ],
      ),
    );
  }
}

/// The sort controls when there is no room for a row of column headings.
///
/// It names the sort in full rather than showing an icon: with the columns
/// gone, the only way to tell what the list is ordered by is to say so.
class _CompactSortBar extends StatelessWidget {
  const _CompactSortBar({required this.state, required this.model});

  final PriorityBrowserState state;
  final PriorityBrowserViewModel model;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
    child: Row(
      children: <Widget>[
        const Text(
          'Sorted by',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<PriorityBrowserSort>(
          tooltip: 'Sort by',
          // Choosing the sort already in use reverses it, exactly as clicking
          // an active column heading does on a wide window.
          onSelected: model.sortBy,
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<PriorityBrowserSort>>[
                for (final PriorityBrowserSort sort
                    in PriorityBrowserSort.values)
                  PopupMenuItem<PriorityBrowserSort>(
                    value: sort,
                    child: Text(sort.label),
                  ),
              ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                state.sort.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              Icon(
                state.isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 18,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.state,
    required this.model,
    required this.sort,
    this.width,
    this.align = TextAlign.right,
  });

  final PriorityBrowserState state;
  final PriorityBrowserViewModel model;
  final PriorityBrowserSort sort;
  final double? width;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final bool isActive = state.sort == sort;
    final Widget label = InkWell(
      onTap: () => model.sortBy(sort),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: align == TextAlign.right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: <Widget>[
            Text(
              sort.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.accent : AppColors.muted,
              ),
            ),
            if (isActive)
              Icon(
                state.isAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 15,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
    return width == null ? label : SizedBox(width: width, child: label);
  }
}
