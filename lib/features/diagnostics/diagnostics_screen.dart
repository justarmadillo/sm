/// The development diagnostics panel.
///
/// Built to answer one question — *why did the scheduler do that?* — and
/// deliberately not built to browse a collection. It shows the day's admission
/// queue counts, the most recent commands, and, for one element, its schedule and
/// the before-and-after of every transition it has been through.
///
/// Element text is withheld unless Settings turns it on, so the panel stays
/// safe to screenshot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/diagnostics/diagnostics_query.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/history/revlog.dart';
import 'package:incremental_reader/scheduling/metrics/scheduler_metrics.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/storage/contracts/repositories.dart';

/// Opens the panel, optionally focused on one element.
Future<void> openDiagnostics(
  BuildContext context,
  WidgetRef ref, {
  ElementRef? focus,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => DiagnosticsScreen(focus: focus),
    ),
  );
}

/// The collection-wide snapshot.
final FutureProvider<CollectionDiagnostics> collectionDiagnosticsProvider =
    FutureProvider<CollectionDiagnostics>((Ref ref) async {
      final DiagnosticsQuery query = ref.watch(diagnosticsQueryProvider);
      return query.forCollection(
        await ref.watch(queueQueryProvider).counters(),
      );
    });

/// Scheduler pacing, retention, and future-load metrics.
final FutureProvider<SchedulerMetricsSnapshot> schedulerMetricsProvider =
    FutureProvider<SchedulerMetricsSnapshot>(
      (Ref ref) => ref.watch(schedulerMetricsQueryProvider).collect(),
    );

/// Recent commands, newest first.
final FutureProvider<List<ActivityRecord>> recentCommandsProvider =
    FutureProvider<List<ActivityRecord>>(
      (Ref ref) => ref.watch(diagnosticsQueryProvider).recentCommands(),
    );

/// One element's full scheduling history.
final FutureProviderFamily<ElementDiagnostics?, ElementRef>
elementDiagnosticsProvider =
    FutureProvider.family<ElementDiagnostics?, ElementRef>(
      (Ref ref, ElementRef element) =>
          ref.watch(diagnosticsQueryProvider).forElement(element),
    );

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key, this.focus});

  final ElementRef? focus;

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  late ElementRef? _focus = widget.focus;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Diagnostics'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(collectionDiagnosticsProvider);
            ref.invalidate(schedulerMetricsProvider);
            ref.invalidate(recentCommandsProvider);
            final ElementRef? focus = _focus;
            if (focus != null) {
              ref.invalidate(elementDiagnosticsProvider(focus));
            }
          },
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
          children: <Widget>[
            const _CollectionPanel(),
            const SizedBox(height: 16),
            const _SchedulerMetricsPanel(),
            const SizedBox(height: 16),
            _CommandsPanel(
              onSelect: (ElementRef ref_) {
                setState(() => _focus = ref_);
              },
            ),
            if (_focus case final ElementRef focus) ...<Widget>[
              const SizedBox(height: 16),
              _ElementPanel(elementRef: focus),
            ],
          ],
        ),
      ),
    ),
  );
}

class _CollectionPanel extends ConsumerWidget {
  const _CollectionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CollectionDiagnostics> state = ref.watch(
      collectionDiagnosticsProvider,
    );
    return _Panel(
      title: 'Today',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object error, StackTrace stack) => Text('$error'),
        data: (CollectionDiagnostics data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 26,
              runSpacing: 12,
              children: <Widget>[
                _Stat(label: 'Study day', value: data.today.toString()),
                _Stat(label: 'Elements', value: '${data.totalElements}'),
                _Stat(
                  label: 'Outstanding items',
                  value: '${data.counters.dueCards}',
                ),
                _Stat(
                  label: 'Outstanding topics',
                  value: '${data.counters.dueTopics}',
                ),
                _Stat(
                  label: 'Indexed',
                  value: '${data.indexedDocuments}',
                  hint: data.searchIndexValid
                      ? 'Search index consistent'
                      : 'Search index needs a rebuild',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Repetition log today',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 6),
            if (data.eventsToday.isEmpty)
              const Text(
                'Nothing recorded yet.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              )
            else
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: <Widget>[
                  for (final MapEntry<RevlogEventType, int> entry
                      in data.eventsToday.entries)
                    _Stat(
                      label: entry.key.storageName,
                      value: '${entry.value}',
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Collection-level pacing and retention metrics.
class _SchedulerMetricsPanel extends ConsumerWidget {
  const _SchedulerMetricsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SchedulerMetricsSnapshot> state = ref.watch(
      schedulerMetricsProvider,
    );
    return _Panel(
      title: 'Scheduler metrics',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        ),
        error: (Object error, StackTrace _) => Text('$error'),
        data: _MetricsBody.new,
      ),
    );
  }
}

class _MetricsBody extends StatelessWidget {
  const _MetricsBody(this.metrics);

  final SchedulerMetricsSnapshot metrics;

  int _cards(int days) => metrics.next30Days
      .take(days)
      .fold(0, (int total, DueLoadMetric day) => total + day.cards);

  int _topics(int days) => metrics.next30Days
      .take(days)
      .fold(0, (int total, DueLoadMetric day) => total + day.topics);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 26,
          runSpacing: 14,
          children: <Widget>[
            _Stat(
              label: 'Overdue now',
              value:
                  '${metrics.overdueCards} cards, '
                  '${metrics.overdueTopics} topics',
            ),
            _Stat(
              label: 'Next 7 days',
              value: '${_cards(7)} cards, ${_topics(7)} topics',
            ),
            _Stat(
              label: 'Next 30 days',
              value: '${_cards(30)} cards, ${_topics(30)} topics',
            ),
            _Stat(label: 'Manual Later', value: '${metrics.manualLaterCount}'),
            _Stat(
              label: 'Mercy',
              value: metrics.mercyCount == 0
                  ? 'none'
                  : '${metrics.mercyCount} batches',
              hint: metrics.mercyBatchSizes.isEmpty
                  ? null
                  : 'Sizes: ${metrics.mercyBatchSizes.join(', ')}.',
            ),
            _Stat(
              label: 'Reviews / encounters',
              value:
                  '${metrics.actualCardReviews} / ${metrics.topicsCompleted}',
              hint: 'Genuine only: practice and undone events are excluded.',
            ),
            _Stat(
              label: 'Card/topic mix',
              value: metrics.cardTopicOpportunityRatio.value == null
                  ? 'none'
                  : '${metrics.cardTopicOpportunityRatio.value!.toStringAsFixed(1)} to 1',
              hint:
                  'Opportunities actually taken, not slots offered. The target '
                  'is four to one.',
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _MetricHeading('Lateness and retention by priority decile'),
        for (final PriorityDecileMetric decile in metrics.priorityDeciles)
          if (decile.allLateness.count > 0)
            Text(
              'D${decile.decile}: median '
              '${_days(decile.allLateness.median)} late, p95 '
              '${_days(decile.allLateness.p95)}'
              '${_retention(decile)}',
              style: const TextStyle(fontSize: 12),
            ),
        const SizedBox(height: 14),
        const _MetricHeading('Topic policies in use'),
        for (final TopicPolicyMetric policy in metrics.topicPolicies)
          Text(
            '${policy.policyVersion}: ${policy.intervals.count} topics, median '
            'interval ${_days(policy.intervals.median)}, median A '
            '${policy.aFactors.median?.toStringAsFixed(2) ?? 'none'}',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
  }

  String _days(double? value) =>
      value == null ? 'none' : '${value.toStringAsFixed(1)}d';

  String _retention(PriorityDecileMetric decile) {
    final double? retention = decile.measuredCardRetention;
    if (retention == null) return '';
    return ', retention ${(retention * 100).toStringAsFixed(0)}%';
  }
}

class _MetricHeading extends StatelessWidget {
  const _MetricHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _CommandsPanel extends ConsumerWidget {
  const _CommandsPanel({required this.onSelect});

  final ValueChanged<ElementRef> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ActivityRecord>> state = ref.watch(
      recentCommandsProvider,
    );
    return _Panel(
      title: 'Recent commands',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object error, StackTrace stack) => Text('$error'),
        data: (List<ActivityRecord> records) => Column(
          children: <Widget>[
            for (final ActivityRecord record in records.take(40))
              InkWell(
                onTap: record.ref == null ? null : () => onSelect(record.ref!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 132,
                        child: Text(
                          record.atUtc
                              .toIso8601String()
                              .substring(0, 19)
                              .replaceFirst('T', ' '),
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: Text(
                          record.kind,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          <String>[
                            if (record.ref != null) '${record.ref}',
                            if (record.durationMs != null)
                              '${record.durationMs}ms',
                            if (record.metadata != null)
                              record.metadata.toString(),
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Consolas',
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ElementPanel extends ConsumerWidget {
  const _ElementPanel({required this.elementRef});

  final ElementRef elementRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ElementDiagnostics?> state = ref.watch(
      elementDiagnosticsProvider(elementRef),
    );
    return _Panel(
      title: 'Element  $elementRef',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object error, StackTrace stack) => Text('$error'),
        data: (ElementDiagnostics? data) {
          if (data == null) {
            return const Text('That element has no schedule.');
          }
          final TopicState? topic = data.topic;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (data.title != null) ...<Widget>[
                Text(
                  data.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 26,
                runSpacing: 12,
                children: <Widget>[
                  _Stat(
                    label: 'Lifecycle',
                    value: data.schedule.lifecycle.name,
                  ),
                  _Stat(
                    label: 'Priority',
                    value: data.position == null
                        ? data.schedule.priority.orderKey
                        : '${data.position!.percent.toStringAsFixed(1)}%',
                  ),
                  _Stat(
                    label: 'Due',
                    value: data.schedule.algorithmicDueDay.toString(),
                  ),
                  _Stat(
                    label: 'Original due',
                    value: data.schedule.originalDueDay.toString(),
                  ),
                  if (topic != null) ...<Widget>[
                    _Stat(
                      label: 'Interval',
                      value: '${topic.intervalDays.toStringAsFixed(2)}d',
                    ),
                    _Stat(
                      label: 'A-factor',
                      value: topic.aFactor.toStringAsFixed(3),
                    ),
                    _Stat(label: 'Encounters', value: '${topic.encounters}'),
                    _Stat(label: 'Postponed', value: '${topic.postponeCount}'),
                  ],
                  if (data.card case final card?) ...<Widget>[
                    _Stat(label: 'State', value: card.memory.state.name),
                    _Stat(label: 'Reps', value: '${card.memory.reps}'),
                    _Stat(label: 'Lapses', value: '${card.memory.lapses}'),
                    _Stat(
                      label: 'Stability',
                      value: card.memory.stability?.toStringAsFixed(2) ?? '—',
                    ),
                    _Stat(
                      label: 'Difficulty',
                      value: card.memory.difficulty?.toStringAsFixed(2) ?? '—',
                    ),
                  ],
                ],
              ),
              if (data.nextIntervalPreview case final preview?) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Next SM20 topic interval: $preview days. '
                    'The preview uses a copy of the persisted Delphi PRNG; '
                    'it does not advance collection state.',
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'History',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 6),
              if (data.history.isEmpty)
                const Text(
                  'Nothing recorded yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                )
              else
                for (final RevlogEntry entry in data.history.take(60))
                  _HistoryRow(entry: entry),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final RevlogEntry entry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 112,
          child: Text(
            entry.atUtc
                .toIso8601String()
                .substring(0, 16)
                .replaceFirst('T', ' '),
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ),
        SizedBox(
          width: 130,
          child: Text(
            entry.eventType.storageName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: entry.feedsOptimizer ? AppColors.accent : AppColors.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            <String>[
              if (entry.grade != null) 'grade ${entry.grade}',
              if (entry.elapsedDays != null)
                'elapsed ${entry.elapsedDays!.toStringAsFixed(1)}d',
              if (entry.scheduledDays != null)
                'scheduled ${entry.scheduledDays!.toStringAsFixed(1)}d',
              if (entry.before.dueAtUtc != null && entry.after.dueAtUtc != null)
                'due ${entry.before.dueAtUtc!.toIso8601String().substring(0, 10)}'
                    ' → '
                    '${entry.after.dueAtUtc!.toIso8601String().substring(0, 10)}',
              if (entry.metadata != null) '${entry.metadata}',
            ].join('  ·  '),
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
    return hint == null ? content : Tooltip(message: hint!, child: content);
  }
}
