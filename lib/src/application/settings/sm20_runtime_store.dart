/// Durable collection-wide state for the executable-faithful scheduler.
///
/// It is stored as one versioned JSON settings row so queue order and the
/// global PRNG seed advance in the same database transaction as a command.
library;

import 'dart:convert';

import 'package:incremental_reader/src/application/ports/repositories.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';
import 'package:incremental_reader/src/domain/scheduling/sm20_collection_state.dart';
import 'package:incremental_reader/src/domain/scheduling/study_day.dart';

const String kSm20RuntimeSettingKey = 'sm20.runtime.v1';

final class Sm20RuntimeStore {
  Sm20RuntimeStore(this._repository);

  final SettingsRepository _repository;

  Future<Sm20CollectionState> load({required String zoneId}) async {
    final String? raw = await _repository.read(kSm20RuntimeSettingKey);
    if (raw == null || raw.isEmpty) return const Sm20CollectionState();
    try {
      final Map<String, Object?> map = jsonDecode(raw) as Map<String, Object?>;
      return Sm20CollectionState(
        prngSeed: _uint32(map['seed']),
        learningStartDay: _day(map['learning_start_day'], zoneId),
        lastAutomaticSortDay: _day(map['last_auto_sort_day'], zoneId),
        lastAutomaticPostponeDay: _day(map['last_auto_postpone_day'], zoneId),
        lastCollectionUseUtc: _instant(map['last_collection_use_utc']),
        learningMode: _integer(map['learning_mode'], 0).clamp(0, 255),
        outstanding: _refs(map['outstanding']),
        outstandingItems: _refs(map['outstanding_items']),
        outstandingTopics: _refs(map['outstanding_topics']),
        pending: _refs(map['pending']),
        finalDrill: _refs(map['final_drill']),
        subsetQueues: _subsets(map['subset_queues']),
      );
    } on Object {
      return const Sm20CollectionState();
    }
  }

  Future<void> save(Sm20CollectionState state) => _repository.write(
    kSm20RuntimeSettingKey,
    jsonEncode(<String, Object?>{
      'version': 1,
      'seed': state.prngSeed & 0xFFFFFFFF,
      'learning_start_day': state.learningStartDay?.epochDay,
      'last_auto_sort_day': state.lastAutomaticSortDay?.epochDay,
      'last_auto_postpone_day': state.lastAutomaticPostponeDay?.epochDay,
      'last_collection_use_utc':
          state.lastCollectionUseUtc?.millisecondsSinceEpoch,
      'learning_mode': state.learningMode,
      'outstanding': _encodeRefs(state.outstanding),
      'outstanding_items': _encodeRefs(state.outstandingItems),
      'outstanding_topics': _encodeRefs(state.outstandingTopics),
      'pending': _encodeRefs(state.pending),
      'final_drill': _encodeRefs(state.finalDrill),
      'subset_queues': <String, Object?>{
        for (final MapEntry<String, List<ElementRef>> entry
            in state.subsetQueues.entries)
          entry.key: _encodeRefs(entry.value),
      },
    }),
  );

  static int _uint32(Object? value) => _integer(value, 0).clamp(0, 0xFFFFFFFF);

  static int _integer(Object? value, int fallback) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? fallback,
    _ => fallback,
  };

  static StudyDay? _day(Object? value, String zoneId) {
    if (value == null) return null;
    final int epoch = _integer(value, -0x7FFFFFFF);
    if (epoch == -0x7FFFFFFF) return null;
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      epoch * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return StudyDay(
      year: date.year,
      month: date.month,
      day: date.day,
      zoneId: zoneId,
    );
  }

  static DateTime? _instant(Object? value) {
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(_integer(value, 0), isUtc: true);
  }

  static List<ElementRef> _refs(Object? value) {
    if (value is! List<Object?>) return const <ElementRef>[];
    final List<ElementRef> result = <ElementRef>[];
    for (final Object? raw in value) {
      if (raw is! Map<String, Object?>) continue;
      final String? id = raw['id'] as String?;
      final int type = _integer(raw['type'], -1);
      if (id == null || type < 0 || type >= ElementType.values.length) continue;
      result.add(ElementRef(id: id, type: ElementType.values[type]));
    }
    return List<ElementRef>.unmodifiable(result);
  }

  static Map<String, List<ElementRef>> _subsets(Object? value) {
    if (value is! Map<String, Object?>) {
      return const <String, List<ElementRef>>{};
    }
    return <String, List<ElementRef>>{
      for (final MapEntry<String, Object?> entry in value.entries)
        entry.key: _refs(entry.value),
    };
  }

  static List<Map<String, Object?>> _encodeRefs(Iterable<ElementRef> refs) =>
      <Map<String, Object?>>[
        for (final ElementRef ref in refs)
          <String, Object?>{'id': ref.id, 'type': ref.type.index},
      ];
}
