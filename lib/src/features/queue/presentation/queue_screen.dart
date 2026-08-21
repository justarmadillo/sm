/// The user's count-based study session, mixing cards and topics.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../application/queue/queue_query.dart';
import '../../../domain/scheduling/element.dart';
import '../../extract/presentation/extract_screen.dart';
import '../../extract/presentation/extract_view_model.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study queue'),
        actions: <Widget>[
          IconButton(
            onPressed: _openingRoutes
                ? null
                : () => ref.read(queueViewModelProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh queue',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) => _QueueError(
          error: error,
          onRetry: () => ref.read(queueViewModelProvider.notifier).refresh(),
        ),
        data: (QueueUiState data) => data.entries.isEmpty
            ? _QueueEmpty(completed: data.completedThisSession)
            : _QueueBody(
                state: data,
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
    required this.isRunning,
    required this.onStart,
  });

  final QueueUiState state;
  final bool isRunning;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
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
          const SizedBox(height: 22),
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

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.entry, required this.isNext, this.onTap});

  final QueueEntry entry;
  final bool isNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
  const _QueueEmpty({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) => Center(
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
