/// What the app promises about saved custom-study decks.
///
/// A deck is a saved filter, not a list of elements: it is evaluated again
/// every time it is opened, so it always reflects the collection's current
/// tags.
library;

import 'package:collection/collection.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:meta/meta.dart';

/// Whether an element must inherit every include tag, or any one of them.
enum CustomDeckTagMatch {
  all(0),
  any(1);

  const CustomDeckTagMatch(this.storedValue);

  /// The number in `custom_decks.tag_match`. Frozen once shipped.
  final int storedValue;

  static CustomDeckTagMatch fromStoredValue(int value) => values.firstWhere(
    (CustomDeckTagMatch match) => match.storedValue == value,
  );
}

/// The order a session studies its elements in.
enum CustomDeckOrder {
  /// Most important first, as the daily queue would put them.
  priority(0),

  /// Shuffled once per session from a seed the session owns.
  random(1),

  /// Earliest due date first.
  dueDate(2),

  /// Most recently added first.
  newestAdded(3);

  const CustomDeckOrder(this.storedValue);

  /// The number in `custom_decks.study_order`. Frozen once shipped.
  final int storedValue;

  static CustomDeckOrder fromStoredValue(int value) =>
      values.firstWhere((CustomDeckOrder order) => order.storedValue == value);
}

/// Whether a deck's tag draws elements in or keeps them out.
enum CustomDeckTagRole {
  include(0),
  exclude(1);

  const CustomDeckTagRole(this.storedValue);

  /// The number in `custom_deck_tags.role`. Frozen once shipped.
  final int storedValue;

  static CustomDeckTagRole fromStoredValue(int value) =>
      values.firstWhere((CustomDeckTagRole role) => role.storedValue == value);
}

/// Everything that decides which elements a deck studies, and how.
@immutable
final class CustomDeckFilter {
  CustomDeckFilter({
    Set<String> includeTagIds = const <String>{},
    Set<String> excludeTagIds = const <String>{},
    this.match = CustomDeckTagMatch.all,
    Set<ElementType>? types,
    this.shouldReschedule = true,
    this.sessionLimit,
    this.order = CustomDeckOrder.priority,
    this.isDueOnly = false,
  }) : includeTagIds = Set<String>.unmodifiable(includeTagIds),
       excludeTagIds = Set<String>.unmodifiable(excludeTagIds),
       types = Set<ElementType>.unmodifiable(
         types ?? ElementType.values.toSet(),
       );

  /// Tags an element must inherit. Empty means no tag restriction at all.
  final Set<String> includeTagIds;

  /// Tags that keep an element out, directly or through a filed parent.
  final Set<String> excludeTagIds;
  final CustomDeckTagMatch match;
  final Set<ElementType> types;

  /// Whether grades and Done move schedules. Cram-only elements are always
  /// practiced, whatever this says.
  final bool shouldReschedule;

  /// The most elements one session studies, or null for no cap.
  final int? sessionLimit;
  final CustomDeckOrder order;

  /// Whether only elements due today or overdue are studied.
  final bool isDueOnly;

  CustomDeckFilter copyWith({
    Set<String>? includeTagIds,
    Set<String>? excludeTagIds,
    CustomDeckTagMatch? match,
    Set<ElementType>? types,
    bool? shouldReschedule,
    int? sessionLimit,
    bool shouldClearSessionLimit = false,
    CustomDeckOrder? order,
    bool? isDueOnly,
  }) => CustomDeckFilter(
    includeTagIds: includeTagIds ?? this.includeTagIds,
    excludeTagIds: excludeTagIds ?? this.excludeTagIds,
    match: match ?? this.match,
    types: types ?? this.types,
    shouldReschedule: shouldReschedule ?? this.shouldReschedule,
    sessionLimit: shouldClearSessionLimit
        ? null
        : (sessionLimit ?? this.sessionLimit),
    order: order ?? this.order,
    isDueOnly: isDueOnly ?? this.isDueOnly,
  );

  static const SetEquality<Object> _sets = SetEquality<Object>();

  @override
  bool operator ==(Object other) =>
      other is CustomDeckFilter &&
      _sets.equals(other.includeTagIds, includeTagIds) &&
      _sets.equals(other.excludeTagIds, excludeTagIds) &&
      other.match == match &&
      _sets.equals(other.types, types) &&
      other.shouldReschedule == shouldReschedule &&
      other.sessionLimit == sessionLimit &&
      other.order == order &&
      other.isDueOnly == isDueOnly;

  @override
  int get hashCode => Object.hash(
    _sets.hash(includeTagIds),
    _sets.hash(excludeTagIds),
    match,
    _sets.hash(types),
    shouldReschedule,
    sessionLimit,
    order,
    isDueOnly,
  );
}

/// A named, saved [CustomDeckFilter].
@immutable
final class CustomDeck {
  const CustomDeck({
    required this.id,
    required this.name,
    required this.filter,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String name;
  final CustomDeckFilter filter;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Trims and collapses whitespace so equivalent input has one spelling.
  static String normalizeName(String typed) =>
      typed.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// The case-insensitive identity persisted in the unique column.
  static String toLowercaseName(String typed) =>
      normalizeName(typed).toLowerCase();

  CustomDeck copyWith({
    String? name,
    CustomDeckFilter? filter,
    DateTime? updatedAtUtc,
  }) => CustomDeck(
    id: id,
    name: name ?? this.name,
    filter: filter ?? this.filter,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
}

/// Persists saved decks and the tags they include or exclude.
abstract interface class CustomDeckRepository {
  /// Every deck, alphabetically.
  Future<List<CustomDeck>> listDecks();
  Future<CustomDeck?> findDeck(String id);
  Future<CustomDeck?> findDeckByLowercaseName(String lowercaseName);
  Future<void> insertDeck(CustomDeck deck);

  /// Replaces the deck row and its tag links together.
  Future<void> updateDeck(CustomDeck deck);
  Future<void> deleteDeck(String id);

  /// Points every deck that names one of [fromTagIds] at [toTagId] instead,
  /// for a tag merge. A deck that already names [toTagId] keeps its role.
  Future<void> updateDeckTagReferences({
    required Set<String> fromTagIds,
    required String toTagId,
  });
}
