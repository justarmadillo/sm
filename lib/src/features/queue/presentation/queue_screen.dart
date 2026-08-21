/// The user's count-based study session, mixing cards and topics.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/toast.dart';
import '../../../application/queue/queue_query.dart';
import '../../../domain/scheduling/element.dart';
import '../../../domain/scheduling/queue_policy.dart';
import '../../diagnostics/presentation/diagnostics_screen.dart';
import '../../extract/presentation/extract_screen.dart';
import '../../extract/presentation/extract_view_model.dart';
import '../../priority/presentation/priority_dialog.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/presentation/reader_view_model.dart';
import '../../review/presentation/review_screen.dart';
import 'queue_view_model.dart';
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
        title: const Text('Study queue'),
        actions: <Widget>[
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
                : () => openDiagnostics(context, ref),
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Diagnostics',
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
      while (mounted) {
        final state = ref.read(queueViewModelProvider).valueOrNull;
        final entry = state?.next;
        if (entry == null) break;
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

/// Today's capacity, and the two ways to change it.
///
/// Shown rather than hidden because an oversubscribed collection is the normal
/// state of incremental reading, and the user can only prioritize honestly if
/// they can see how much the valve is shedding on their behalf.
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
                _Metric(label: 'due', value: '${counters.dueTotal}'),
                _Metric(label: 'admitted', value: '${counters.admittedTotal}'),
                _Metric(
                  label: 'new cards',
                  value: '${counters.admittedNewCards}',
                ),
                if (counters.overflowTotal > 0)
                  _Metric(
                    label: 'deferred',
                    value: '${counters.overflowTotal}',
                    hint:
                        'Lowest-priority excess, pushed out to protect the '
                        'day. The top ${counters.protectedElements} '
                        'protected elements were never eligible for this.',
                  ),
                _Metric(
                  label: 'protection',
                  value: '${counters.protectionPercent.toStringAsFixed(0)}%',
                  hint:
                      'How deep into the collection today reached. Nothing '
                      'below this percentile is safe from being forgotten.',
                ),
              ],
            ),
          ),
          if (state.hasDeferrals)
            TextButton.icon(
              onPressed: isRunning || state.isBusy ? null : model.studyMore,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Study more'),
            ),
          TextButton.icon(
            onPressed: isRunning || state.isBusy
                ? null
                : () => _confirmMercy(context),
            icon: const Icon(Icons.event_repeat, size: 16),
            label: const Text('Mercy'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMercy(BuildContext context) async {
    final bool ok =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Spread the backlog?'),
            content: const Text(
              'Everything overdue is redistributed across the next few weeks '
              'in one operation, best priority first. Nothing is reviewed and '
              'no interval changes — only the dates you become eligible move.\n\n'
              'Worth doing after an absence, when auto-postpone would chew '
              'through the backlog one day at a time.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Spread'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) await model.runMercy();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

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
    return hint == null ? content : Tooltip(message: hint!, child: content);
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.entry, required this.isNext, this.onTap});

  final QueueEntry entry;
  final bool isNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (IconData icon, Color color) = switch (entry.ref.type) {
      ElementType.source => (Icons.menu_book_outlined, AppColors.accent),
      ElementType.extract => (Icons.content_cut, AppColors.softMarker),
      ElementType.card => (Icons.quiz_outlined, Colors.teal),
    };
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
          if (state.hasDeferrals) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              '${state.counters.overflowTotal} lower-priority '
              'element${state.counters.overflowTotal == 1 ? '' : 's'} were '
              'deferred to protect today.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.isBusy ? null : model.studyMore,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Study more'),
            ),
          ],
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
