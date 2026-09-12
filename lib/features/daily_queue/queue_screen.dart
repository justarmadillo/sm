/// The user's count-based study session, mixing cards and topics.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/browser/add_element_flow.dart';
import 'package:incremental_reader/features/browser/browser_screen.dart';
import 'package:incremental_reader/features/custom_study/custom_study_screen.dart';
import 'package:incremental_reader/features/daily_queue/open_study_element.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/daily_queue/queue_query.dart';
import 'package:incremental_reader/features/daily_queue/queue_view_model.dart';
import 'package:incremental_reader/features/daily_queue/smart_postpone_dialog.dart';
import 'package:incremental_reader/features/diagnostics/diagnostics_screen.dart';
import 'package:incremental_reader/features/priority/priority_browser_screen.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/settings/settings_screen.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/mercy/mercy.dart';
import 'package:incremental_reader/scheduling/mercy/mercy_workflow.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/colored_tag_list.dart';
import 'package:incremental_reader/shared/ui/element_type_badge.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  bool _isOpeningRoutes = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(queueViewModelProvider);
    final QueueViewModel model = ref.read(queueViewModelProvider.notifier);

    ref.listen<AsyncValue<QueueUiState>>(queueViewModelProvider, (
      AsyncValue<QueueUiState>? previous,
      AsyncValue<QueueUiState> next,
    ) {
      final message = next.valueOrNull?.message;
      if (message == null) return;
      showToast(context, message.text, isError: message.isError);
      model.shouldClearMessage();
    });

    return Focus(autofocus: true, child: _buildScaffold(context, state, model));
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<QueueUiState> state,
    QueueViewModel model,
  ) {
    return Scaffold(
      appBar: _appBar(context, model),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            _QueueError(error: error, onRetry: model.refresh),
        data: (QueueUiState queue) => queue.entries.isEmpty
            ? _QueueEmpty(state: queue, model: model)
            : _QueueBody(
                state: queue,
                model: model,
                isRunning: _isOpeningRoutes,
                onStart: _runQueue,
              ),
      ),
    );
  }

  /// This screen is the home, so the collection-wide destinations live here
  /// rather than on the screen that used to hold them.
  ///
  /// Everything is disabled while a route is opening, so a second tap cannot
  /// push the same screen twice.
  PreferredSizeWidget _appBar(BuildContext context, QueueViewModel model) {
    // Six destinations do not fit beside a title on a phone. The three the
    // session itself needs stay on the bar; the rest move into a menu, in the
    // same order they had, so the wide layout is still the readable one.
    final bool isNarrow = isCompactWidth(context);
    return AppBar(
      // No title. The page's own headline says what this screen is, and the
      // bar carries no colour or rule of its own any more, so a second word
      // above the headline read as a label for a strip that is not there.
      toolbarHeight: 52,
      actions: <Widget>[
        if (isNarrow)
          IconButton(
            onPressed: _isOpeningRoutes
                ? null
                : () => _openThenRefresh(
                    model,
                    () => showAddElementFlow(context, ref),
                  ),
            icon: const Icon(Icons.add),
            tooltip: 'Add',
          )
        else ...<Widget>[
          TextButton.icon(
            onPressed: _isOpeningRoutes
                ? null
                : () => _openThenRefresh(
                    model,
                    () => showAddElementFlow(context, ref),
                  ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
          const SizedBox(width: 4),
        ],
        if (isNarrow)
          IconButton(
            onPressed: _isOpeningRoutes
                ? null
                : () =>
                      _openThenRefresh(model, () => openBrowser(context, ref)),
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Browser',
          )
        else ...<Widget>[
          TextButton.icon(
            onPressed: _isOpeningRoutes
                ? null
                : () =>
                      _openThenRefresh(model, () => openBrowser(context, ref)),
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('Browser'),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          onPressed: _isOpeningRoutes
              ? null
              : () => _openThenRefresh(
                  model,
                  () => openCustomStudy(context, ref),
                ),
          icon: const Icon(Icons.school_outlined),
          tooltip: 'Custom study',
        ),
        // Deciding what matters is part of studying, not housekeeping, so
        // this one keeps its place on the bar at every width rather than
        // costing a menu tap on the screen it is used from most.
        IconButton(
          onPressed: _isOpeningRoutes
              ? null
              : () => _openThenRefresh(
                  model,
                  () => openPriorityBrowser(context, ref),
                ),
          icon: const Icon(Icons.low_priority),
          tooltip: 'Priority queue',
        ),
        if (isNarrow)
          _MoreDestinationsMenu(
            enabled: !_isOpeningRoutes,
            onRefresh: model.refresh,
            onDiagnostics: () => openDiagnostics(context, ref),
            onSettings: () =>
                _openThenRefresh(model, () => openSettings(context, ref)),
          )
        else ...<Widget>[
          IconButton(
            onPressed: _isOpeningRoutes ? null : model.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh queue',
          ),
          IconButton(
            onPressed: _isOpeningRoutes
                ? null
                : () => openDiagnostics(context, ref),
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Diagnostics',
          ),
          IconButton(
            onPressed: _isOpeningRoutes
                ? null
                : () =>
                      _openThenRefresh(model, () => openSettings(context, ref)),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  /// Reloads the queue after a screen that can change it closes, so coming
  /// back never shows a stale day.
  Future<void> _openThenRefresh(
    QueueViewModel model,
    Future<void> Function() open,
  ) async {
    await open();
    await model.refresh();
  }

  Future<void> _runQueue() async {
    if (_isOpeningRoutes) return;
    setState(() => _isOpeningRoutes = true);
    try {
      // The session advances only while each pass consumes an element. A
      // command can legitimately report "committed" while leaving the queue
      // exactly as it was — Later Today on an element that is already
      // Outstanding is a queue-only shift, and a topic already repeated today
      // makes no further progress. Without this guard the same element is
      // reopened forever, spinning the session counter and hammering the
      // database.
      ElementRef? previous;
      while (mounted) {
        final state = ref.read(queueViewModelProvider).valueOrNull;
        final entry = state?.next;
        if (entry == null) break;
        if (entry.ref == previous) break;
        previous = entry.ref;
        final result = await openStudyElement(
          context,
          ref,
          elementRef: entry.ref,
        );
        if (!mounted || !result.advancesSession) break;
        // Later Today and Dismiss end the visit without advancing a schedule,
        // so the session moves on but nothing is counted as completed.
        if (result.isRepetition) {
          await ref.read(queueViewModelProvider.notifier).refreshAfterCommit();
        } else {
          await ref.read(queueViewModelProvider.notifier).refresh();
        }
        if (!mounted) break;
        final refreshed = ref.read(queueViewModelProvider);
        if (refreshed.hasError || refreshed.valueOrNull?.next == null) break;
      }
    } finally {
      if (mounted) setState(() => _isOpeningRoutes = false);
    }
  }
}

class _QueueBody extends StatelessWidget {
  const _QueueBody({
    required this.state,
    required this.model,
    required this.isRunning,
    required this.onStart,
  });

  final QueueUiState state;
  final QueueViewModel model;
  final bool isRunning;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => ListView(
    // The scrollable fills the window so its desktop scrollbar belongs to the
    // window edge. Only the readable content column is centred and capped.
    padding: EdgeInsets.only(
      top: isCompactWidth(context) ? 16 : 24,
      bottom: 60,
    ),
    children: <Widget>[
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              // Tighter margins on a phone: 24 on each side of a 360-pixel
              // screen is a sixth of the width before the first word.
              padding: EdgeInsets.symmetric(
                horizontal: isCompactWidth(context) ? 14 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SessionHeader(
                    state: state,
                    isRunning: isRunning,
                    onStart: onStart,
                  ),
                  const SizedBox(height: AppSpacing.standard),
                  _LoadPanel(state: state, model: model, isRunning: isRunning),
                  const SizedBox(height: AppSpacing.standard),
                  for (var index = 0; index < state.entries.length; index++)
                    _QueueTile(
                      entry: state.entries[index],
                      isNext: index == 0,
                      onTap: index == 0 && !isRunning ? onStart : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// How much is waiting, one sentence about it, and the button that starts it.
///
/// The button drops to its own full-width row on a phone. Beside a sentence
/// that wraps it left the sentence a column two words wide, and the wrapped
/// line ran under the button — the header read as a collision rather than as
/// a heading with an action.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.state,
    required this.isRunning,
    required this.onStart,
  });

  final QueueUiState state;
  final bool isRunning;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final Widget headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${state.entries.length} ready to study',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.hair),
        Text(
          state.completedThisSession == 0
              ? 'Reviews and reading are mixed into one session.'
              : '${state.completedThisSession} completed this session',
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    );
    final Widget startButton = FilledButton.icon(
      onPressed: isRunning ? null : onStart,
      icon: const Icon(Icons.play_arrow, size: 18),
      label: Text(isRunning ? 'Studying…' : 'Start'),
    );
    if (isCompactWidth(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          headline,
          const SizedBox(height: AppSpacing.snug),
          SizedBox(height: 44, child: startButton),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: headline),
        const SizedBox(width: AppSpacing.loose),
        startButton,
      ],
    );
  }
}

/// The destinations that do not fit on a phone's app bar.
///
/// A menu rather than a second row of icons: the bar is already the only
/// place these live, and a row that wraps would push the queue itself down
/// the screen on every rebuild.
class _MoreDestinationsMenu extends StatelessWidget {
  const _MoreDestinationsMenu({
    required this.enabled,
    required this.onRefresh,
    required this.onDiagnostics,
    required this.onSettings,
  });

  final bool enabled;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onDiagnostics;
  final Future<void> Function() onSettings;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    enabled: enabled,
    tooltip: 'More',
    icon: const Icon(Icons.more_vert),
    onSelected: (String destination) {
      switch (destination) {
        case 'refresh':
          unawaited(onRefresh());
        case 'diagnostics':
          unawaited(onDiagnostics());
        case 'settings':
          unawaited(onSettings());
      }
    },
    itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'refresh',
        child: ListTile(
          leading: Icon(Icons.refresh),
          title: Text('Refresh queue'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'diagnostics',
        child: ListTile(
          leading: Icon(Icons.insights_outlined),
          title: Text('Diagnostics'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'settings',
        child: ListTile(
          leading: Icon(Icons.settings_outlined),
          title: Text('Settings'),
        ),
      ),
    ],
  );
}

/// SM20's current queue stage and its type counts.
class _LoadPanel extends StatelessWidget {
  const _LoadPanel({
    required this.state,
    required this.model,
    required this.isRunning,
  });

  final QueueUiState state;
  final QueueViewModel model;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final QueueCounters counters = state.counters;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.standard),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      // Counts above, actions below, a hairline between them. They used to sit
      // side by side wherever they fitted, which put a row of buttons and a
      // row of numbers on one baseline with nothing saying they were two
      // different things — and on a phone the buttons wrapped into a ragged
      // block under the counts anyway.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _counters(state, counters),
          const SizedBox(height: AppSpacing.snug),
          const Divider(),
          const SizedBox(height: AppSpacing.snug),
          _bulkActions(context),
        ],
      ),
    );
  }

  /// Which stage the queue is in, and how much of each kind is due.
  Widget _counters(QueueUiState state, QueueCounters counters) => Wrap(
    spacing: AppSpacing.standard,
    runSpacing: AppSpacing.tight,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      _StageBadge(lane: state.projection.lane),
      _CounterChip(label: 'due', value: '${counters.dueTotal}'),
      _CounterChip(label: 'cards', value: '${counters.dueCards}'),
      _CounterChip(label: 'topics', value: '${counters.dueTopics}'),
    ],
  );

  /// The commands that move a whole day's work at once.
  ///
  /// White utility buttons, not accented ones. Three orange labels beside an
  /// orange Start made four things claim to be the action of the screen; only
  /// Start is.
  Widget _bulkActions(BuildContext context) => Wrap(
    spacing: AppSpacing.tight,
    runSpacing: AppSpacing.tight,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      OutlinedButton.icon(
        onPressed: isRunning || state.isBusy
            ? null
            : () => _confirmSmartPostpone(context),
        icon: const Icon(Icons.update, size: 16),
        label: const Text('Smart Postpone'),
      ),
      OutlinedButton.icon(
        onPressed: isRunning || state.isBusy
            ? null
            : () => _confirmMercy(context),
        icon: const Icon(Icons.event_repeat, size: 16),
        label: const Text('Mercy'),
      ),
      // Always offered rather than hidden behind a query: a bulk calendar
      // move the user cannot find the reverse of is not really reversible.
      OutlinedButton.icon(
        onPressed: isRunning || state.isBusy ? null : model.undoMercy,
        icon: const Icon(Icons.undo, size: 16),
        label: const Text('Undo Mercy'),
      ),
      _LearnMenu(model: model, enabled: !(isRunning || state.isBusy)),
    ],
  );

  /// Mercy is a two-step conversation: propose, then confirm the proposal.
  ///
  /// The intermediate dialog exists because a bulk calendar move the user
  /// cannot inspect first is indistinguishable from data loss. What it shows
  /// is the plan that will be applied, not an estimate of one.
  Future<void> _confirmMercy(BuildContext context) async {
    if (!await _askToPreviewMercy(context)) return;

    final StoredMercyBatch? batch = await model.previewMercy();
    if (batch == null || !context.mounted) return;

    final MercyPreview preview = batch.preview;
    if (preview.selectedCount == 0) {
      await _showNothingToSpread(context, preview);
      return;
    }

    if (await _askToApplyMercy(context, preview)) {
      await model.applyMercy(batch);
    }
  }

  /// Step one: explain what Mercy does before computing anything.
  Future<bool> _askToPreviewMercy(BuildContext context) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Spread the backlog?'),
        content: const Text(
          'Mercy gathers scheduled work and redistributes it across its '
          'configured target horizon. It performs no repetitions and does '
          'not change priority or repetition history; it applies canonical '
          'low-level reschedules. You will see the exact plan before '
          'anything is written, and it can be undone as one batch.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Preview'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  /// Says why the plan is empty rather than closing silently, which would
  /// look like the command had failed.
  Future<void> _showNothingToSpread(
    BuildContext context,
    MercyPreview preview,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Nothing to spread'),
        content: Text(_planSummary(preview)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Step two: the exact plan, with the resulting load for every day it
  /// touches, so the user approves what will actually be written.
  Future<bool> _askToApplyMercy(
    BuildContext context,
    MercyPreview preview,
  ) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Apply this plan?'),
        content: SizedBox(
          width: dialogContentWidth(context, preferred: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_moveCountLine(preview)),
              const SizedBox(height: 8),
              Text(_planSummary(preview)),
              const SizedBox(height: 12),
              const Text('Proposed load per day:'),
              const SizedBox(height: 4),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (final MercyDailyLoad load in preview.afterLoad)
                        Text(
                          '${load.day}  —  ${load.cards} cards, '
                          '${load.topics} topics',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  /// How many elements move, split by kind.
  String _moveCountLine(MercyPreview preview) =>
      '${preview.selectedCount} element'
      '${preview.selectedCount == 1 ? '' : 's'} move: '
      '${preview.selectedCardCount} card'
      '${preview.selectedCardCount == 1 ? '' : 's'} and '
      '${preview.selectedTopicCount} topic'
      '${preview.selectedTopicCount == 1 ? '' : 's'}.';

  String _planSummary(MercyPreview preview) {
    if (preview.selectedCount == 0) {
      if (preview.deletedPlaceholderCount > 0) {
        final int missing = preview.deletedPlaceholderCount;
        final String subject = missing == 1
            ? 'reference no longer exists'
            : 'references no longer exist';
        return '$missing selected subset $subject, so there is nothing to '
            'reschedule.';
      }
      if (preview.gatherMode == Sm20MercyGatherMode.subset) {
        return 'The supplied subset is empty.';
      }
      return 'No scheduled elements fell inside the '
          '${preview.gatheringDays}-day gathering window.';
    }
    final int missing = preview.deletedPlaceholderCount;
    final String placeholders = missing == 0
        ? ''
        : ' $missing missing subset '
              '${missing == 1 ? 'reference remains' : 'references remain'} as '
              '${missing == 1 ? 'an empty ordering slot' : 'empty ordering slots'}.';
    final String source = preview.gatherMode == Sm20MercyGatherMode.subset
        ? 'from the supplied subset'
        : 'from the ${preview.gatheringDays}-day gathering window';
    return '${preview.selectedCount} scheduled '
        '${preview.selectedCount == 1 ? 'element was' : 'elements were'} '
        'redistributed $source across ${preview.reschedulingDays} target '
        '${preview.reschedulingDays == 1 ? 'day' : 'days'}.$placeholders';
  }

  Future<void> _confirmSmartPostpone(BuildContext context) =>
      runConfirmedSmartPostpone(
        context,
        (bool isSimulationOnly) =>
            model.smartPostpone(isSimulationOnly: isSimulationOnly),
      );
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
    return content;
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.entry, required this.isNext, this.onTap});

  final QueueEntry entry;
  final bool isNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({IconData icon, Color color, String label}) style = elementTypeStyle(
      entry.ref.type,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _typeIcon(style.icon, style.color),
              const SizedBox(width: AppSpacing.snug),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _metaRow(context: context, ref: ref, color: style.color),
                    const SizedBox(height: AppSpacing.hair + 2),
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title,
                    ),
                    if (entry.tagNames.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      ColoredTagList(
                        tagNames: entry.tagNames,
                        maximumVisibleTags: 3,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  /// The action to take, what the element is, and the flags that change how
  /// the user should treat it.
  ///
  /// The action says what to do; the badge says what the element is. A mixed
  /// queue needs both, because Read means something different for a topic
  /// than Review does for a card.
  ///
  /// These sit on their own line above the title rather than beside it. Five
  /// labels sharing one line with the title left the title about two words
  /// wide on a phone, and the title is the only part of the row that says
  /// which element this actually is.
  Widget _metaRow({
    required BuildContext context,
    required WidgetRef ref,
    required Color color,
  }) => Row(
    children: <Widget>[
      // Keep all left-side labels inside one Expanded child. A Flexible label
      // beside a Spacer splits the spare width between two flex children,
      // which stopped the trailing priority badge around the row's midpoint.
      Expanded(
        child: Row(
          children: <Widget>[
            ElementTypeBadge(type: entry.ref.type),
            const SizedBox(width: AppSpacing.tight),
            // On the narrowest screens this is the one label that can lose
            // its tail without the row losing its meaning.
            Flexible(
              child: Text(
                entry.actionLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.eyebrow.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
      if (entry.isLeech) ...<Widget>[
        const _LeechWarning(),
        const SizedBox(width: AppSpacing.tight),
      ],
      if (isNext) ...<Widget>[
        Text(
          'UP NEXT',
          style: AppTextStyles.eyebrow.copyWith(color: AppColors.faint),
        ),
        const SizedBox(width: AppSpacing.tight),
      ],
      // Last in the row on every tile, so the priorities read down the list as
      // one column. Anything allowed to follow it — UP NEXT on the first tile
      // — shunted that tile's badge left and broke the column at the top,
      // which is the one place the eye starts.
      if (entry.priorityPercent case final percent?)
        PriorityBadge(
          percent: percent,
          onTap: () async {
            final bool hasChanged = await showPriorityDialog(
              context,
              ref,
              elementRef: entry.ref,
            );
            if (hasChanged) {
              await ref.read(queueViewModelProvider.notifier).refresh();
            }
          },
        ),
    ],
  );
}

/// Marks a card that keeps failing, and says what to do about it.
class _LeechWarning extends StatelessWidget {
  const _LeechWarning();

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message:
          'This card keeps failing. It is usually the card that is wrong, '
          'not your memory — open its source passage and rewrite it.',
      child: Icon(
        Icons.warning_amber_rounded,
        size: 15,
        color: AppColors.softMarker,
      ),
    );
  }
}

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({required this.state, required this.model});

  final QueueUiState state;
  final QueueViewModel model;

  @override
  Widget build(BuildContext context) {
    final int completed = state.completedThisSession;
    return Center(
      child: Padding(
        // Room to breathe at the edges: on a phone the sentence below runs
        // the full width of the screen without it.
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline,
              size: 48,
              color: AppColors.accent,
            ),
            const SizedBox(height: 14),
            Text(
              completed == 0 ? 'Nothing is due right now' : 'Queue complete',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              completed == 0
                  ? 'New reading and reviews will appear when eligible.'
                  : '$completed item${completed == 1 ? '' : 's'} completed.',
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('Could not build the queue.\n$error', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

/// Which stage the queue is presenting.
///
/// Without this the three stages are indistinguishable on screen, and a user
/// whose Outstanding queue has emptied into the final drill has no way to tell
/// why work they already answered today has come back.
class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.lane});

  final QueueLane? lane;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (lane) {
      QueueLane.finalDrill => ('final drill', AppColors.accent),
      QueueLane.pending => ('pending', AppColors.softMarker),
      _ => ('outstanding', AppColors.muted),
    };
    // A pill, because this is a state the queue is in rather than a name for
    // what a row is — the square badges on the rows below mean the other
    // thing, and the two must not read as one kind of label.
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tight,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label, style: AppTextStyles.eyebrow.copyWith(color: color)),
    );
  }
}

/// The Learn menu's stage and randomization commands.
///
/// SM20 reaches the fallback stages automatically, but it also lets the user
/// enter them directly, so these are commands rather than states to wait for.
class _LearnMenu extends StatelessWidget {
  const _LearnMenu({required this.model, required this.enabled});

  final QueueViewModel model;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    enabled: enabled,
    tooltip: 'Choose a learning stage to execute',
    icon: const Icon(Icons.playlist_play, size: 18),
    // Squared off to the same height and hairline as the buttons it stands
    // beside, so a bare glyph does not read as a stray mark at the end of a
    // row of buttons.
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(40, 36)),
      side: const WidgetStatePropertyAll<BorderSide>(
        BorderSide(color: AppColors.border),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
    ),
    onSelected: (String value) async {
      switch (value) {
        case 'outstanding':
          await model.enterStage(Sm20StageRequest.outstanding);
        case 'final_drill':
          await model.enterStage(Sm20StageRequest.finalDrill);
        case 'new_material':
          await model.enterStage(Sm20StageRequest.newMaterial);
        case 'random_learning':
          await model.randomLearning();
        case 'cut_drills':
          if (!context.mounted) return;
          // Cutting the drill throws away a selection the user built by
          // hand, and nothing else restores it, so it is confirmed.
          final bool didConfirm =
              await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Cut drills?'),
                  content: const Text(
                    'This removes every element scheduled for the final '
                    'drill. Schedules, intervals, A-factors and priorities '
                    'are untouched: only drill membership is cleared.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Keep'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cut drills'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (didConfirm) await model.cutDrills();
        case 'randomize_outstanding':
          await model.randomizeQueue(Sm20RandomizableQueue.outstanding);
        case 'randomize_drill':
          await model.randomizeQueue(Sm20RandomizableQueue.finalDrill);
        case 'randomize_pending':
          await model.randomizeQueue(Sm20RandomizableQueue.pending);
      }
    },
    itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
      // Captions and tooltips are the executable's own, so the menu can be
      // matched against SuperMemo item by item.
      PopupMenuItem<String>(
        value: 'outstanding',
        child: Tooltip(
          message: "Repeat items that are scheduled for today's repetitions",
          child: Text('1. Outstanding material'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'new_material',
        child: Tooltip(
          message: 'Learn new material (i.e. commit it to your memory)',
          child: Text('2. New material'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'final_drill',
        child: Tooltip(
          message:
              'Go through the final revision of the material repeated '
              'recently (final drill stage)',
          child: Text('3. Final drill'),
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'random_learning',
        child: Tooltip(
          message:
              'Learn new elements by randomly reviewing pending elements '
              'in the collection',
          child: Text('Random learning'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'cut_drills',
        child: Tooltip(
          message: 'Eliminate items scheduled for final drill',
          child: Text('Cut drills'),
        ),
      ),
      PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'randomize_outstanding',
        child: Tooltip(
          message: 'Randomize the sequence of outstanding items',
          child: Text('Randomize repetitions'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'randomize_drill',
        child: Tooltip(
          message:
              'Mix randomly the queue of elements scheduled for final '
              'drill',
          child: Text('Randomize drill'),
        ),
      ),
      PopupMenuItem<String>(
        value: 'randomize_pending',
        child: Tooltip(
          message: 'Mix randomly the queue of pending elements',
          child: Text('Randomize pending'),
        ),
      ),
    ],
  );
}
