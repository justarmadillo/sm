/// The user's count-based study session, mixing cards and topics.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/toast.dart';
import '../../../application/queue/queue_commands.dart';
import '../../../application/queue/queue_query.dart';
import '../../../application/scheduling/mercy_workflow.dart';
import '../../../domain/scheduling/element.dart';
import '../../../domain/scheduling/mercy.dart';
import '../../../domain/scheduling/queue_policy.dart';
import '../../contents/presentation/contents_screen.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../extract/presentation/extract_screen.dart';
import '../../extract/presentation/extract_view_model.dart';
import '../../priority/presentation/priority_browser_screen.dart';
import '../../priority/presentation/priority_dialog.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/presentation/reader_view_model.dart';
import '../../review/presentation/review_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shared/element_type_badge.dart';
import 'queue_view_model.dart';
import 'smart_postpone_dialog.dart';
import 'study_route_result.dart';

Future<void> openStudyQueue(BuildContext context, WidgetRef ref) async {
  ref.invalidate(queueViewModelProvider);
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const QueueScreen(),
    ),
  );
}

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  bool _openingRoutes = false;

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
      model.clearMessage();
    });

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            model.undoLastGrade,
      },
      child: Focus(
        autofocus: true,
        child: _buildScaffold(context, state, model),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    AsyncValue<QueueUiState> state,
    QueueViewModel model,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study'),
        actions: <Widget>[
          // This screen is now the home, so the collection-wide destinations
          // live here rather than on the screen that used to hold them.
          TextButton.icon(
            onPressed: _openingRoutes
                ? null
                : () async {
                    await openContents(context, ref);
                    await model.refresh();
                  },
            icon: const Icon(Icons.account_tree_outlined, size: 18),
            label: const Text('Contents'),
          ),
          const SizedBox(width: 4),
          IconButton(
            // Undo lives here rather than on the review screen: that screen
            // closes the moment a grade commits, and the session is what the
            // user is actually in the middle of.
            onPressed: _openingRoutes ? null : model.undoLastGrade,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last grade (Ctrl+Z)',
          ),
          IconButton(
            onPressed: _openingRoutes ? null : model.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh queue',
          ),
          IconButton(
            onPressed: _openingRoutes
                ? null
                : () async {
                    await openPriorityBrowser(context, ref);
                    await model.refresh();
                  },
            icon: const Icon(Icons.low_priority),
            tooltip: 'Priority queue',
          ),
          IconButton(
            onPressed: _openingRoutes
                ? null
                : () => openDiagnostics(context, ref),
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Diagnostics',
          ),
          IconButton(
            onPressed: _openingRoutes
                ? null
                : () async {
                    await openSettings(context, ref);
                    await model.refresh();
                  },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            _QueueError(error: error, onRetry: model.refresh),
        data: (QueueUiState data) => data.entries.isEmpty
            ? _QueueEmpty(state: data, model: model)
            : _QueueBody(
                state: data,
                model: model,
                isRunning: _openingRoutes,
                onStart: _runQueue,
              ),
      ),
    );
  }

  Future<void> _runQueue() async {
    if (_openingRoutes) return;
    setState(() => _openingRoutes = true);
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
        final result = await _openEntry(entry);
        if (!mounted || result != StudyRouteResult.committed) break;
        await ref.read(queueViewModelProvider.notifier).refreshAfterCommit();
        if (!mounted) break;
        final refreshed = ref.read(queueViewModelProvider);
        if (refreshed.hasError || refreshed.valueOrNull?.next == null) break;
      }
    } finally {
      if (mounted) setState(() => _openingRoutes = false);
    }
  }

  Future<StudyRouteResult> _openEntry(QueueEntry entry) =>
      switch (entry.ref.type) {
        ElementType.source => openReaderForStudy(
          context,
          ref,
          sourceId: entry.ref.id,
          mode: ReaderMode.scheduled,
        ),
        ElementType.extract => openExtract(
          context,
          ref,
          extractId: entry.ref.id,
          mode: ExtractMode.scheduled,
        ),
        ElementType.card => openReview(context, ref, cardId: entry.ref.id),
      };
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
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 60),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${state.entries.length} item'
                      '${state.entries.length == 1 ? '' : 's'} ready',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.completedThisSession == 0
                          ? 'Reviews and reading are mixed into one session.'
                          : '${state.completedThisSession} completed this session',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: isRunning ? null : onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(isRunning ? 'Studying…' : 'Start'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LoadPanel(state: state, model: model, isRunning: isRunning),
          const SizedBox(height: 18),
          for (var index = 0; index < state.entries.length; index++)
            _QueueTile(
              entry: state.entries[index],
              isNext: index == 0,
              onTap: index == 0 && !isRunning ? onStart : null,
            ),
        ],
      ),
    ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: 20,
              runSpacing: 6,
              children: <Widget>[
                _StageBadge(lane: state.projection.lane),
                _Metric(label: 'due', value: '${counters.dueTotal}'),
                _Metric(label: 'items', value: '${counters.dueCards}'),
                _Metric(label: 'topics', value: '${counters.dueTopics}'),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isRunning || state.isBusy
                ? null
                : () => _confirmSmartPostpone(context),
            icon: const Icon(Icons.schedule_send, size: 16),
            label: const Text('Smart Postpone'),
          ),
          TextButton.icon(
            onPressed: isRunning || state.isBusy
                ? null
                : () => _confirmMercy(context),
            icon: const Icon(Icons.event_repeat, size: 16),
            label: const Text('Mercy'),
          ),
          // Always offered rather than hidden behind a query: a bulk calendar
          // move the user cannot find the reverse of is not really reversible.
          TextButton.icon(
            onPressed: isRunning || state.isBusy ? null : model.undoMercy,
            icon: const Icon(Icons.undo, size: 16),
            label: const Text('Undo Mercy'),
          ),
          _LearnMenu(model: model, enabled: !(isRunning || state.isBusy)),
        ],
      ),
    );
  }

  /// Mercy is a two-step conversation: propose, then confirm the proposal.
  ///
  /// The intermediate dialog exists because a bulk calendar move the user
  /// cannot inspect first is indistinguishable from data loss. What it shows
  /// is the plan that will be applied, not an estimate of one.
  Future<void> _confirmMercy(BuildContext context) async {
    final bool wanted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Spread the backlog?'),
            content: const Text(
              'Mercy gathers scheduled work and redistributes it across its '
              'configured target horizon. It performs no repetitions and '
              'does not change priority or repetition history; it applies '
              'canonical low-level reschedules. You will see the exact plan '
              'before anything is written, and it can be undone as one batch.',
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
        ) ??
        false;
    if (!wanted) return;

    final StoredMercyBatch? batch = await model.previewMercy();
    if (batch == null || !context.mounted) return;

    final MercyPreview preview = batch.preview;
    if (preview.selectedCount == 0) {
      await showDialog<void>(
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
      return;
    }

    final bool apply =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Apply this plan?'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${preview.selectedCount} element'
                    '${preview.selectedCount == 1 ? '' : 's'} move: '
                    '${preview.selectedCardCount} card'
                    '${preview.selectedCardCount == 1 ? '' : 's'} and '
                    '${preview.selectedTopicCount} topic'
                    '${preview.selectedTopicCount == 1 ? '' : 's'}.',
                  ),
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
        ) ??
        false;
    if (apply) await model.applyMercy(batch);
  }

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

  /// Smart Postpone is simulated first, always.
  ///
  /// The simulation consumes no randomness and writes nothing, so the list the
  /// user approves is the engine's own decision set rather than a preview
  /// built by different code. The real run re-evaluates against live state.
  Future<void> _confirmSmartPostpone(BuildContext context) async {
    final AppliedSmartPostpone? simulated = await model.smartPostpone(
      simulate: true,
    );
    if (simulated == null || !context.mounted) return;
    if (!await confirmSmartPostpone(context, simulated.result)) return;
    await model.smartPostpone(simulate: false);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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
    final IconData icon = style.icon;
    final Color color = style.color;
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        // The action says what to do; the badge says what the
                        // element is. A mixed queue needs both, because Read
                        // means something different for a topic than Review
                        // does for a card.
                        ElementTypeBadge(type: entry.ref.type),
                        const SizedBox(width: 6),
                        Text(
                          entry.actionLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (entry.isLeech) ...<Widget>[
                          const Tooltip(
                            message:
                                'This card keeps failing. It is usually the '
                                'card that is wrong, not your memory — open '
                                'its source passage and rewrite it.',
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 15,
                              color: AppColors.softMarker,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (entry.priorityPercent
                            case final percent?) ...<Widget>[
                          PriorityBadge(
                            percent: percent,
                            onTap: () async {
                              final bool changed = await showPriorityDialog(
                                context,
                                ref,
                                elementRef: entry.ref,
                              );
                              if (changed) {
                                await ref
                                    .read(queueViewModelProvider.notifier)
                                    .refresh();
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (isNext)
                          const Text(
                            'UP NEXT',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
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
}

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({required this.state, required this.model});

  final QueueUiState state;
  final QueueViewModel model;

  @override
  Widget build(BuildContext context) {
    final int completed = state.completedThisSession;
    return Center(
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
          ),
          const SizedBox(height: 6),
          Text(
            completed == 0
                ? 'New reading and reviews will appear when eligible.'
                : '$completed item${completed == 1 ? '' : 's'} completed.',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
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
          final bool wanted =
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
          if (wanted) await model.cutDrills();
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
