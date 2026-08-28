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
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/daily_queue/smart_postpone_dialog.dart';
import 'package:incremental_reader/features/priority/priority_commands.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
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
                            onLearningCommand: (_LearningCommand command) =>
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
                            onLearningCommand: (_LearningCommand command) =>
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

  /// Runs one browser Learning command against a single element.
  ///
  /// The three commands that destroy scheduling state confirm first, and the
  /// prompt says exactly what is cleared — Undismiss does not bring a schedule
  /// back, so a user who expected it to would otherwise lose one silently.
  /// Runs one learning command on one element, confirming first when the
  /// command throws work away.
  Future<void> _runLearningCommand(
    BuildContext context,
    PriorityEntry entry,
    _LearningCommand command,
  ) async {
    final List<ElementRef> refs = <ElementRef>[entry.ref];
    if (command.isDestructive) {
      if (!await _confirmDestructive(context, command)) return;
      if (!context.mounted) return;
    }

    switch (command) {
      case _LearningCommand.learn:
        await model.startReview(refs, Sm20ReviewMode.learn);
      case _LearningCommand.reviewAll:
        await model.startReview(refs, Sm20ReviewMode.reviewAll);
      case _LearningCommand.reviewTopics:
        await model.startReview(refs, Sm20ReviewMode.reviewTopics);
      case _LearningCommand.remember:
        await model.remember(refs);
      case _LearningCommand.forget:
        await model.forget(refs);
      case _LearningCommand.dismiss:
        await model.dismiss(refs);
      case _LearningCommand.undismiss:
        await model.undismiss(refs);
      case _LearningCommand.done:
        await model.done(refs);
      case _LearningCommand.addToFinalDrill:
        await model.addToFinalDrill(refs);
      case _LearningCommand.addToOutstanding:
        final int? every = await _promptForSpacing(context);
        if (every != null) {
          await model.addToOutstanding(refs, everyWhich: every);
        }
      case _LearningCommand.addAll:
        final int? everyAll = await _promptForSpacing(context);
        if (everyAll != null) {
          await model.addToOutstanding(
            refs,
            everyWhich: everyAll,
            shouldRescheduleSameDay: true,
          );
        }
      case _LearningCommand.resetHistory:
        await model.resetHistory(refs);
      case _LearningCommand.setAFactor:
        final double? value = await _promptForDouble(
          context,
          title: 'Set A',
          hint:
              'Stores the A-factor directly. It changes no interval, due '
              'date, priority, or repetition count.',
          initial: 1.10,
          min: 1.01,
          max: 3,
        );
        if (value != null) await model.setAFactor(refs, value);
      case _LearningCommand.modifyAFactor:
        final double? multiplier = await _promptForDouble(
          context,
          title: 'Modify A',
          hint: 'Rescales A around 1.01: A = 1.01 + m × (A − 1.01).',
          initial: 1,
          min: 0.20,
          max: 2,
        );
        if (multiplier != null) await model.modifyAFactor(refs, multiplier);
    }
  }

  /// Each destructive command carries its own warning, so the dialog can say
  /// what this particular one discards rather than a generic "are you sure".
  Future<bool> _confirmDestructive(
    BuildContext context,
    _LearningCommand command,
  ) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('${command.label}?'),
        content: Text(command.warning),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(command.label),
          ),
        ],
      ),
    );
    return answer ?? false;
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
    child: Row(
      children: <Widget>[
        Text(
          '${state.entries.length} elements',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: state.isBusy || state.entries.isEmpty
              ? null
              : () => _confirmSmartPostpone(context),
          icon: const Icon(Icons.schedule_send, size: 16),
          label: const Text('Smart Postpone these'),
        ),
        TextButton.icon(
          onPressed: state.isBusy || state.entries.isEmpty
              ? null
              : () => _promptAdvance(context),
          icon: const Icon(Icons.fast_forward, size: 16),
          label: const Text('Advance these'),
        ),
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
              selected: _areSetsEqual(state.types, types),
              onSelected: (_) => model.filterTo(types),
            ),
          ),
      ],
    ),
  );

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
  final ValueChanged<_LearningCommand> onLearningCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            _dragHandle(),
            _percentCell(),
            _typeBadgeCell(),
            const SizedBox(width: 8),
            Expanded(child: _titleAndPreview()),
            _Cell(width: _kIntervalWidth, text: '${entry.intervalDays}'),
            _Cell(width: _kCountWidth, text: '${entry.repetitions}'),
            _Cell(width: _kCountWidth, text: '${entry.lapses}'),
            _Cell(
              width: _kDateWidth,
              text: entry.lastRepetition?.toString() ?? '—',
            ),
            _Cell(width: _kDateWidth, text: entry.nextRepetition.toString()),
            SizedBox(
              width: _kActionsWidth,
              child: _actionButtons(context, ref),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _typeBadgeCell() {
    return SizedBox(
      width: _kBadgeWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ElementTypeBadge(type: entry.ref.type),
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
  Widget _actionButtons(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        IconButton(
          tooltip: 'Set priority (Alt+P)',
          onPressed: () async {
            final bool hasChanged = await showPriorityDialog(
              context,
              ref,
              elementRef: entry.ref,
            );
            if (hasChanged) {
              await ref
                  .read(priorityBrowserViewModelProvider.notifier)
                  .refresh();
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
          icon: const Icon(Icons.tune_outlined, size: 17),
        ),
        IconButton(
          tooltip: 'Smart Postpone this article',
          onPressed: onSmartPostpone,
          constraints: _kActionConstraints,
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.schedule_send_outlined, size: 17),
        ),
        SizedBox(
          width: _kActionConstraints.maxWidth,
          height: _kActionConstraints.maxHeight,
          child: PopupMenuButton<_LearningCommand>(
            tooltip: 'Learning commands',
            onSelected: onLearningCommand,
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_LearningCommand>>[
                  for (final _LearningCommand command
                      in _LearningCommand.values)
                    PopupMenuItem<_LearningCommand>(
                      value: command,
                      child: Text(command.label),
                    ),
                ],
            // No `constraints` here. On PopupMenuButton that property sizes
            // the *menu*, not the button, so the 33x33 box used for the icon
            // buttons would shrink the menu itself. The button is sized by
            // the SizedBox around it instead.
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, size: 17),
          ),
        ),
      ],
    );
  }
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
      width: 460,
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

/// SM20's browser Learning commands for one element.
enum _LearningCommand {
  learn('Learn'),
  reviewAll('Review all'),
  reviewTopics('Review topics'),
  remember('Remember'),
  forget('Forget'),
  dismiss('Dismiss'),
  undismiss('Undismiss'),
  done('Done'),
  addToFinalDrill('Add to drill'),
  addToOutstanding('Add to outstanding'),
  addAll('Add all'),
  resetHistory('Reset history'),
  setAFactor('Set A…'),
  modifyAFactor('Modify A…');

  const _LearningCommand(this.label);

  final String label;

  /// Whether the command destroys scheduling state and deserves a prompt.
  bool get isDestructive =>
      this == _LearningCommand.forget ||
      this == _LearningCommand.dismiss ||
      this == _LearningCommand.done;

  String get warning => switch (this) {
    _LearningCommand.forget =>
      'Forget clears the repetition count, interval, and postponement '
          'counters and returns the element to the pending store. The '
          'A-factor and priority survive; the schedule does not.',
    _LearningCommand.dismiss =>
      'Dismiss stops scheduling, clears the repetition state, and sets '
          'priority to 100%. Undismiss later restores the status only — not '
          'the schedule or the priority.',
    _LearningCommand.done =>
      'Done removes the element from scheduling, every queue, and the '
          'priority population.',
    _ => '',
  };
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
      width: 380,
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

/// A single numeric prompt, used by Set A and Modify A.
Future<double?> _promptForDouble(
  BuildContext context, {
  required String title,
  required String hint,
  required double initial,
  required double min,
  required double max,
}) async {
  final TextEditingController controller = TextEditingController(
    text: '$initial',
  );
  try {
    return await showDialog<double>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final double? value = double.tryParse(controller.text.trim());
          final bool isValid = value != null && value >= min && value <= max;
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      helperText: '$min–$max',
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
                onPressed: isValid
                    ? () => Navigator.of(context).pop(value)
                    : null,
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// SM20's `Every which element?` prompt for batch Add to Outstanding.
///
/// The spacing is not cosmetic: section 9.7 seeds the first insertion at
/// `min(3, s)` and advances the target by `s` after each success, so it
/// decides where in the queue the selection lands. Defaulting it silently
/// would hide a choice the executable always asks for.
Future<int?> _promptForSpacing(BuildContext context) async {
  final TextEditingController controller = TextEditingController(text: '5');
  try {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final int? value = int.tryParse(controller.text.trim());
          final bool isValid = value != null && value >= 1 && value <= 100;
          return AlertDialog(
            title: const Text('Every which element?'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Spacing between insertions in the Outstanding queue. '
                    'The first lands at position min(3, s), and each further '
                    'element is placed s positions later. Every successful '
                    'insertion also multiplies that priority target by 0.9.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      helperText: '1–100',
                      isDense: true,
                      border: OutlineInputBorder(),
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
                onPressed: isValid
                    ? () => Navigator.of(context).pop(value)
                    : null,
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
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
  Widget build(BuildContext context) => Padding(
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
