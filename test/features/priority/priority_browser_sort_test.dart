/// Sorting the priority browser.
///
/// The columns repeat heavily — most elements share a repetition count — so
/// the interesting behaviour is not the primary key but what happens when it
/// ties, and what happens to elements that have never been repeated.
library;

import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/priority_rank.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:test/test.dart';

StudyDay _day(String value) => StudyDay.parse(value, zoneId: 'UTC');

PriorityEntry _entry({
  required String id,
  required String key,
  String title = 'Element',
  int interval = 0,
  int repetitionCount = 0,
  int lapses = 0,
  String? lastRep,
  String next = '2026-03-05',
}) {
  final ElementRef ref = ElementRef(id: id, type: ElementType.source);
  return PriorityEntry(
    schedule: ElementSchedule(
      ref: ref,
      priority: PriorityRank(key),
      dueDay: _day(next),
      originalDueDay: _day(next),
      lifecycle: ElementLifecycle.active,
    ),
    position: const PriorityPosition(index: 0, total: 1),
    title: title,
    preview: '',
    intervalDays: interval,
    repetitions: repetitionCount,
    lapses: lapses,
    lastRepetition: lastRep == null ? null : _day(lastRep),
  );
}

List<String> _ids(List<PriorityEntry> entries) => <String>[
  for (final PriorityEntry e in entries) e.ref.id,
];

void main() {
  group('ordering by a column', () {
    final List<PriorityEntry> entries = <PriorityEntry>[
      _entry(
        id: 'a',
        key: 'V',
        title: 'Zebra',
        interval: 10,
        repetitionCount: 3,
      ),
      _entry(
        id: 'b',
        key: 'W',
        title: 'apple',
        interval: 2,
        repetitionCount: 1,
      ),
      _entry(
        id: 'c',
        key: 'X',
        title: 'Mango',
        interval: 30,
        repetitionCount: 7,
      ),
    ];

    test('interval ascending, then descending', () {
      expect(
        _ids(sortPriorityEntries(entries, PriorityBrowserSort.interval, true)),
        <String>['b', 'a', 'c'],
      );
      expect(
        _ids(sortPriorityEntries(entries, PriorityBrowserSort.interval, false)),
        <String>['c', 'a', 'b'],
      );
    });

    test('title sorts case-insensitively', () {
      // 'apple' before 'Mango' before 'Zebra': a raw string compare would put
      // every lowercase title after every uppercase one.
      expect(
        _ids(sortPriorityEntries(entries, PriorityBrowserSort.title, true)),
        <String>['b', 'c', 'a'],
      );
    });

    test('repetitions and lapses order numerically', () {
      expect(
        _ids(
          sortPriorityEntries(entries, PriorityBrowserSort.repetitions, true),
        ),
        <String>['b', 'a', 'c'],
      );
    });
  });

  test('equal values fall back to priority order', () {
    // Every element here has the same repetition count, which is the normal
    // case for a young collection. Without the tie-break the rows would
    // reshuffle on each rebuild.
    final List<PriorityEntry> tied = <PriorityEntry>[
      _entry(id: 'third', key: 'X'),
      _entry(id: 'first', key: 'V'),
      _entry(id: 'second', key: 'W'),
    ];
    expect(
      _ids(sortPriorityEntries(tied, PriorityBrowserSort.repetitions, true)),
      <String>['first', 'second', 'third'],
    );
    expect(
      _ids(sortPriorityEntries(tied, PriorityBrowserSort.repetitions, false)),
      <String>['first', 'second', 'third'],
      reason: 'the tie-break is not reversed with the column',
    );
  });

  test('a never-repeated element sorts last in both directions', () {
    final List<PriorityEntry> mixed = <PriorityEntry>[
      _entry(id: 'never', key: 'V'),
      _entry(id: 'old', key: 'W', lastRep: '2026-01-01'),
      _entry(id: 'recent', key: 'X', lastRep: '2026-03-01'),
    ];
    expect(
      _ids(
        sortPriorityEntries(mixed, PriorityBrowserSort.lastRepetition, true),
      ),
      <String>['old', 'recent', 'never'],
    );
    expect(
      _ids(
        sortPriorityEntries(mixed, PriorityBrowserSort.lastRepetition, false),
      ),
      <String>['recent', 'old', 'never'],
      reason: 'an absent repetition is not an early one',
    );
  });

  group('dragging', () {
    test('is offered only while the rows are in priority order', () {
      const PriorityBrowserState priority = PriorityBrowserState(
        entries: <PriorityEntry>[],
      );
      expect(priority.isReorderable, isTrue);

      // Under any other order the row above is not the rank above, so a drag
      // would move the element somewhere the user did not point at.
      expect(
        priority.copyWith(sort: PriorityBrowserSort.interval).isReorderable,
        isFalse,
      );
      expect(
        priority.copyWith(isAscending: false).isReorderable,
        isFalse,
        reason: 'reversed priority is still not the collection order',
      );
    });
  });
}
