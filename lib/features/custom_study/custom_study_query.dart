/// Reads which elements a custom deck studies, in the order it studies them.
///
/// Reads only. Nothing here admits a queue, moves a schedule, or draws from
/// the collection's shared random-number stream: a Random deck shuffles with
/// a seed the session owns.
library;

import 'package:incremental_reader/features/browser/browser_tree_query.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/cram_scope_query.dart';
import 'package:incremental_reader/scheduling/daily_queue/queue_policy.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/sm20_numeric.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:meta/meta.dart';

/// One element a deck can study.
@immutable
final class CustomStudyEntry {
  const CustomStudyEntry({
    required this.ref,
    required this.title,
    required this.tagNames,
    required this.effectiveTagIds,
    required this.priorityPercent,
    required this.dueDay,
    required this.addedAtUtc,
    this.isCramOnly = false,
  });

  final ElementRef ref;
  final String title;

  /// Direct and inherited tag names, alphabetically.
  final List<String> tagNames;

  /// Direct and inherited tag ids, the set every filter is matched against.
  final Set<String> effectiveTagIds;
  final double priorityPercent;
  final StudyDay dueDay;
  final DateTime addedAtUtc;

  /// Whether this element is always practiced, never rescheduled.
  final bool isCramOnly;
}

/// What a filter matches right now.
@immutable
final class CustomStudyMatches {
  const CustomStudyMatches({
    required this.entries,
    required this.tagCounts,
    this.sessionLimit,
  });

  static const CustomStudyMatches empty = CustomStudyMatches(
    entries: <CustomStudyEntry>[],
    tagCounts: <String, int>{},
  );

  /// Every match, in the deck's order.
  final List<CustomStudyEntry> entries;

  /// How many active elements of the chosen types carry each tag, directly
  /// or through a parent: the numbers shown beside the tag list.
  final Map<String, int> tagCounts;
  final int? sessionLimit;

  /// The matches one session studies: the first [sessionLimit] of them.
  List<CustomStudyEntry> get sessionEntries => sessionLimit == null
      ? entries
      : entries.take(sessionLimit!).toList(growable: false);
}

/// Projects a deck's matches from the Browser's tree, so a tag inherits here
/// exactly as the Browser shows it inheriting.
final class CustomStudyQuery {
  const CustomStudyQuery({
    required BrowserTreeQuery tree,
    required LearningRepository learning,
    required CramScopeQuery cramScope,
    required SchedulingContext context,
    required Clock clock,
  }) : _tree = tree,
       _learning = learning,
       _cramScope = cramScope,
       _context = context,
       _clock = clock;

  final BrowserTreeQuery _tree;
  final LearningRepository _learning;
  final CramScopeQuery _cramScope;
  final SchedulingContext _context;
  final Clock _clock;

  /// [shuffleSeed] decides a Random deck's order and nothing else, so the
  /// preview a user looks at is exactly what Start then studies.
  Future<CustomStudyMatches> load({
    required CustomDeckFilter filter,
    required int shuffleSeed,
  }) async {
    final Map<ElementRef, ElementSchedule> schedules = await _activeSchedules();
    final List<BrowserTreeNode> eligible = <BrowserTreeNode>[
      for (final BrowserTreeNode node in _flatten(await _tree.load()))
        if (node.lifecycle == ElementLifecycle.active &&
            schedules.containsKey(node.ref) &&
            filter.types.contains(node.ref.type))
          node,
    ];
    final Set<ElementRef> cramOnly = await _cramScope.listCramOnlyRefs();
    final Set<ElementRef> dueRefs = filter.isDueOnly
        ? await _listDueRefs(<ElementRef>[
            for (final BrowserTreeNode node in eligible) node.ref,
          ])
        : const <ElementRef>{};
    final PriorityScale scale = PriorityScale(
      schedules.values.map((ElementSchedule schedule) => schedule.priority),
    );
    final List<_RankedEntry> matches = <_RankedEntry>[
      for (final BrowserTreeNode node in eligible)
        if (_matchesTags(node.effectiveTagIds, filter) &&
            (!filter.isDueOnly ||
                (dueRefs.contains(node.ref) && !cramOnly.contains(node.ref))))
          _rank(
            node,
            schedule: schedules[node.ref]!,
            scale: scale,
            isCramOnly: cramOnly.contains(node.ref),
          ),
    ];
    return CustomStudyMatches(
      entries: List<CustomStudyEntry>.unmodifiable(
        _ordered(matches, order: filter.order, shuffleSeed: shuffleSeed),
      ),
      tagCounts: _countTags(eligible),
      sessionLimit: filter.sessionLimit,
    );
  }

  Future<Map<ElementRef, ElementSchedule>> _activeSchedules() async =>
      <ElementRef, ElementSchedule>{
        for (final ElementSchedule schedule in await _learning.listSchedules(
          types: ElementType.values.toSet(),
          lifecycles: const <ElementLifecycle>{ElementLifecycle.active},
        ))
          schedule.ref: schedule,
      };

  /// Elements due today or overdue, by the same rule the daily queue admits
  /// with — so a new card or a pending topic is not "due" here either.
  Future<Set<ElementRef>> _listDueRefs(List<ElementRef> refs) async {
    final DateTime nowUtc = _clock.nowUtc();
    final StudyDay today = await _context.today();
    final Map<ElementRef, TopicState> topics = await _learning.findTopics(
      <ElementRef>[
        for (final ElementRef ref in refs)
          if (ref.type.isTopic) ref,
      ],
    );
    final Map<String, CardState> cards = await _learning.findCardStates(
      <String>[
        for (final ElementRef ref in refs)
          if (!ref.type.isTopic) ref.id,
      ],
    );
    final List<QueueCandidate> candidates = <QueueCandidate>[
      for (final TopicState topic in topics.values)
        if (topic.status != Sm20ElementStatus.dismissed &&
            topic.status != Sm20ElementStatus.deleted)
          QueueCandidate.topic(topic),
      for (final CardState card in cards.values) QueueCandidate.card(card),
    ];
    return <ElementRef>{
      for (final QueueCandidate candidate in candidates)
        if (!candidate.isPending &&
            candidate.isDue(nowUtc: nowUtc, today: today))
          candidate.ref,
    };
  }

  _RankedEntry _rank(
    BrowserTreeNode node, {
    required ElementSchedule schedule,
    required PriorityScale scale,
    required bool isCramOnly,
  }) => _RankedEntry(
    rank: schedule.priority,
    entry: CustomStudyEntry(
      ref: node.ref,
      title: node.title,
      tagNames: node.tagNames,
      effectiveTagIds: node.effectiveTagIds,
      priorityPercent: scale.positionOf(schedule.priority)?.percent ?? 100,
      dueDay: schedule.dueDay,
      addedAtUtc: node.addedAtUtc,
      isCramOnly: isCramOnly,
    ),
  );
}

Iterable<BrowserTreeNode> _flatten(List<BrowserTreeNode> nodes) sync* {
  for (final BrowserTreeNode node in nodes) {
    yield node;
    yield* _flatten(node.children);
  }
}

/// An empty include list means no tag restriction; an exclude tag wins over
/// any include, and both are matched through inheritance.
bool _matchesTags(Set<String> effectiveTagIds, CustomDeckFilter filter) {
  if (filter.excludeTagIds.any(effectiveTagIds.contains)) return false;
  if (filter.includeTagIds.isEmpty) return true;
  return switch (filter.match) {
    CustomDeckTagMatch.all => effectiveTagIds.containsAll(filter.includeTagIds),
    CustomDeckTagMatch.any => filter.includeTagIds.any(
      effectiveTagIds.contains,
    ),
  };
}

Map<String, int> _countTags(List<BrowserTreeNode> nodes) {
  final Map<String, int> counts = <String, int>{};
  for (final BrowserTreeNode node in nodes) {
    for (final String tagId in node.effectiveTagIds) {
      counts[tagId] = (counts[tagId] ?? 0) + 1;
    }
  }
  return counts;
}

/// Random starts from priority order before shuffling, so one seed always
/// gives one order whatever order the tree happened to list things in.
List<CustomStudyEntry> _ordered(
  List<_RankedEntry> matches, {
  required CustomDeckOrder order,
  required int shuffleSeed,
}) {
  final List<_RankedEntry> sorted = <_RankedEntry>[...matches]
    ..sort(switch (order) {
      CustomDeckOrder.priority || CustomDeckOrder.random => _byPriority,
      CustomDeckOrder.dueDate => _byDueDay,
      CustomDeckOrder.newestAdded => _byNewest,
    });
  if (order == CustomDeckOrder.random) {
    QueuePolicy.randomizeFixedSize(
      sorted,
      Sm20RandomNumberGenerator(seed: shuffleSeed),
    );
  }
  return <CustomStudyEntry>[
    for (final _RankedEntry ranked in sorted) ranked.entry,
  ];
}

final class _RankedEntry {
  const _RankedEntry({required this.rank, required this.entry});

  final PriorityRank rank;
  final CustomStudyEntry entry;
}

int _byPriority(_RankedEntry first, _RankedEntry second) {
  final int byRank = first.rank.compareTo(second.rank);
  if (byRank != 0) return byRank;
  final int byDueDay = first.entry.dueDay.compareTo(second.entry.dueDay);
  if (byDueDay != 0) return byDueDay;
  return _byTitle(first, second);
}

int _byDueDay(_RankedEntry first, _RankedEntry second) {
  final int byDueDay = first.entry.dueDay.compareTo(second.entry.dueDay);
  if (byDueDay != 0) return byDueDay;
  return _byPriority(first, second);
}

int _byNewest(_RankedEntry first, _RankedEntry second) {
  final int byAdded = second.entry.addedAtUtc.compareTo(first.entry.addedAtUtc);
  if (byAdded != 0) return byAdded;
  return _byPriority(first, second);
}

int _byTitle(_RankedEntry first, _RankedEntry second) {
  final int byTitle = first.entry.title.compareTo(second.entry.title);
  if (byTitle != 0) return byTitle;
  return first.entry.ref.compareTo(second.entry.ref);
}
