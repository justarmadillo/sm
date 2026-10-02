/// Holds the custom-study filter being edited, the saved decks, the current
/// matches, and this session's progress.
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/custom_study/custom_study_commands.dart';
import 'package:incremental_reader/features/custom_study/custom_study_providers.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';
import 'package:incremental_reader/features/daily_queue/study_scheduling.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/features/tags/tags_providers.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';

/// One element of a started session and how its screen treats its schedule.
@immutable
final class CustomStudyStep {
  const CustomStudyStep({required this.ref, required this.scheduling});

  final ElementRef ref;
  final StudyScheduling scheduling;
}

@immutable
final class CustomStudyUiState {
  CustomStudyUiState({
    this.decks = const <CustomDeck>[],
    this.selectedDeckId,
    CustomDeckFilter? filter,
    this.matches = CustomStudyMatches.empty,
    this.shuffleSeed = 0,
    this.completedThisSession = 0,
    this.isLoading = false,
    this.message,
  }) : filter = filter ?? CustomDeckFilter();

  final List<CustomDeck> decks;

  /// The saved deck being looked at, or null for an unsaved filter.
  final String? selectedDeckId;

  /// The filter on screen, which may differ from the saved deck's.
  final CustomDeckFilter filter;
  final CustomStudyMatches matches;

  /// The seed a Random order shuffles with, owned by this session.
  final int shuffleSeed;
  final int completedThisSession;
  final bool isLoading;
  final UiMessage? message;

  CustomDeck? get selectedDeck =>
      decks.firstWhereOrNull((CustomDeck deck) => deck.id == selectedDeckId);

  /// Whether the filter on screen differs from the saved deck it came from.
  bool get isDirty {
    final CustomDeck? deck = selectedDeck;
    return deck != null && deck.filter != filter;
  }

  CustomStudyUiState copyWith({
    List<CustomDeck>? decks,
    String? selectedDeckId,
    bool shouldClearSelectedDeck = false,
    CustomDeckFilter? filter,
    CustomStudyMatches? matches,
    int? shuffleSeed,
    int? completedThisSession,
    bool? isLoading,
    UiMessage? message,
    bool shouldClearMessage = false,
  }) => CustomStudyUiState(
    decks: decks ?? this.decks,
    selectedDeckId: shouldClearSelectedDeck
        ? null
        : (selectedDeckId ?? this.selectedDeckId),
    filter: filter ?? this.filter,
    matches: matches ?? this.matches,
    shuffleSeed: shuffleSeed ?? this.shuffleSeed,
    completedThisSession: completedThisSession ?? this.completedThisSession,
    isLoading: isLoading ?? this.isLoading,
    message: shouldClearMessage ? null : (message ?? this.message),
  );
}

final class CustomStudyViewModel extends AsyncNotifier<CustomStudyUiState> {
  var _filterRevision = 0;
  var _shuffleCount = 0;

  @override
  Future<CustomStudyUiState> build() async {
    final CustomStudyUiState initial = CustomStudyUiState(
      decks: await ref.read(customDeckRepositoryProvider).listDecks(),
      shuffleSeed: _newShuffleSeed(null),
    );
    return initial.copyWith(matches: await _listMatches(initial));
  }

  /// Opens a saved deck's filter, or keeps the current filter unsaved.
  Future<void> selectDeck(String? deckId) => _changeFilters(
    (CustomStudyUiState current) => current.copyWith(
      selectedDeckId: deckId,
      shouldClearSelectedDeck: deckId == null,
      filter: current.decks
          .firstWhereOrNull((CustomDeck deck) => deck.id == deckId)
          ?.filter,
      shuffleSeed: _newShuffleSeed(deckId),
    ),
  );

  /// Off, then included, then excluded, then off again: one tap per step, so
  /// the tag list needs no second control for exclusion.
  Future<void> cycleTag(String tagId) =>
      _changeFilter((CustomDeckFilter filter) {
        if (filter.includeTagIds.contains(tagId)) {
          return filter.copyWith(
            includeTagIds: <String>{...filter.includeTagIds}..remove(tagId),
            excludeTagIds: <String>{...filter.excludeTagIds, tagId},
          );
        }
        if (filter.excludeTagIds.contains(tagId)) {
          return filter.copyWith(
            excludeTagIds: <String>{...filter.excludeTagIds}..remove(tagId),
          );
        }
        return filter.copyWith(
          includeTagIds: <String>{...filter.includeTagIds, tagId},
        );
      });

  Future<void> setMatch(CustomDeckTagMatch match) =>
      _changeFilter((CustomDeckFilter filter) => filter.copyWith(match: match));

  /// Never empties the type set: the last chosen type stays chosen.
  Future<void> toggleType(ElementType type) =>
      _changeFilter((CustomDeckFilter filter) {
        final Set<ElementType> types = <ElementType>{...filter.types};
        if (!types.remove(type)) types.add(type);
        return types.isEmpty ? filter : filter.copyWith(types: types);
      });

  Future<void> setShouldReschedule(bool shouldReschedule) => _changeFilter(
    (CustomDeckFilter filter) =>
        filter.copyWith(shouldReschedule: shouldReschedule),
  );

  Future<void> setSessionLimit(int? sessionLimit) => _changeFilter(
    (CustomDeckFilter filter) => filter.copyWith(
      sessionLimit: sessionLimit,
      shouldClearSessionLimit: sessionLimit == null,
    ),
  );

  Future<void> setOrder(CustomDeckOrder order) =>
      _changeFilter((CustomDeckFilter filter) => filter.copyWith(order: order));

  Future<void> setDueOnly(bool isDueOnly) => _changeFilter(
    (CustomDeckFilter filter) => filter.copyWith(isDueOnly: isDueOnly),
  );

  /// A new Random order for the same filter.
  Future<void> reshuffle() => _changeFilters(
    (CustomStudyUiState current) =>
        current.copyWith(shuffleSeed: _newShuffleSeed(current.selectedDeckId)),
  );

  /// Puts the saved deck's filter back on screen.
  Future<void> revert() => _changeFilters(
    (CustomStudyUiState current) =>
        current.copyWith(filter: current.selectedDeck?.filter),
  );

  /// Saves the filter on screen as a new deck and selects it.
  Future<bool> saveAsNewDeck(String name) async {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return false;
    final Result<CustomDeckOutcome> result = await ref
        .read(customStudyCommandRunnerProvider)
        .create(
          CreateCustomDeck(_newOperation(), name: name, filter: current.filter),
        );
    return _afterDeckChange(result, success: 'Deck saved');
  }

  /// Writes the filter on screen over the selected deck's.
  Future<bool> saveDeck() async {
    final CustomStudyUiState? current = state.valueOrNull;
    final CustomDeck? deck = current?.selectedDeck;
    if (current == null || deck == null) return false;
    final Result<CustomDeckOutcome> result = await ref
        .read(customStudyCommandRunnerProvider)
        .update(
          UpdateCustomDeck(
            _newOperation(),
            deckId: deck.id,
            filter: current.filter,
          ),
        );
    return _afterDeckChange(result, success: 'Deck saved');
  }

  Future<bool> renameDeck(String deckId, String name) async {
    final Result<CustomDeckOutcome> result = await ref
        .read(customStudyCommandRunnerProvider)
        .update(UpdateCustomDeck(_newOperation(), deckId: deckId, name: name));
    return _afterDeckChange(result, success: 'Deck renamed');
  }

  /// Deletes the deck for good; the filter stays on screen, unsaved.
  Future<bool> deleteDeck(String deckId) async {
    final Result<CustomDeckOutcome> result = await ref
        .read(customStudyCommandRunnerProvider)
        .delete(DeleteCustomDeck(_newOperation(), deckId: deckId));
    return _afterDeckChange(result, success: 'Deck deleted');
  }

  /// Ticks or unticks "Cram only" on matched elements, then re-reads, since
  /// a cram-only element is practiced and may leave a Due only deck.
  Future<void> markCramOnly(
    List<ElementRef> refs, {
    required bool isCramOnly,
  }) async {
    final result = await ref
        .read(tagsCommandRunnerProvider)
        .markCramOnly(
          MarkCramOnly(_newOperation(), refs: refs, isCramOnly: isCramOnly),
        );
    if (result.isErr) {
      _showMessage(UiMessage(result.failureOrNull!.message, isError: true));
      return;
    }
    if (!isCramOnly && result.unwrap().changedRefCount == 0) {
      _showMessage(
        const UiMessage(
          'Cram only comes from a parent. Untick it on the parent instead.',
        ),
      );
    }
    await _changeFilters((CustomStudyUiState current) => current);
  }

  /// Freezes the session before any screen starts changing schedules, and
  /// decides once how each element is studied.
  ///
  /// Cram-only elements are practiced in every deck. Otherwise a deck that
  /// reschedules grades cards early through FSRS and reads topics normally,
  /// and one that does not practices everything.
  List<CustomStudyStep> beginSession() {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null || current.isLoading) return const <CustomStudyStep>[];
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(completedThisSession: 0),
    );
    return List<CustomStudyStep>.unmodifiable(<CustomStudyStep>[
      for (final CustomStudyEntry entry in current.matches.sessionEntries)
        CustomStudyStep(
          ref: entry.ref,
          scheduling: _schedulingFor(entry, filter: current.filter),
        ),
    ]);
  }

  void recordCompleted() {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(completedThisSession: current.completedThisSession + 1),
    );
  }

  void clearMessage() {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null || current.message == null) return;
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(shouldClearMessage: true),
    );
  }

  StudyScheduling _schedulingFor(
    CustomStudyEntry entry, {
    required CustomDeckFilter filter,
  }) {
    if (entry.isCramOnly || !filter.shouldReschedule) {
      return StudyScheduling.practice;
    }
    return entry.ref.type == ElementType.card
        ? StudyScheduling.earlyReview
        : StudyScheduling.scheduled;
  }

  Future<bool> _afterDeckChange(
    Result<CustomDeckOutcome> result, {
    required String success,
  }) async {
    if (result.isErr) {
      _showMessage(UiMessage(result.failureOrNull!.message, isError: true));
      return false;
    }
    final CustomDeck changed = result.unwrap().deck;
    final List<CustomDeck> decks = await ref
        .read(customDeckRepositoryProvider)
        .listDecks();
    final bool stillExists = decks.any(
      (CustomDeck deck) => deck.id == changed.id,
    );
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return true;
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(
        decks: decks,
        selectedDeckId: stillExists ? changed.id : null,
        shouldClearSelectedDeck: !stillExists,
        message: UiMessage(success),
      ),
    );
    return true;
  }

  Future<void> _changeFilter(
    CustomDeckFilter Function(CustomDeckFilter filter) change,
  ) => _changeFilters(
    (CustomStudyUiState current) =>
        current.copyWith(filter: change(current.filter)),
  );

  /// Drops a result that a later change has already superseded, so quick
  /// taps on the tag list never leave an older match list on screen.
  Future<void> _changeFilters(
    CustomStudyUiState Function(CustomStudyUiState current) change,
  ) async {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return;
    final int revision = ++_filterRevision;
    final CustomStudyUiState changed = change(
      current,
    ).copyWith(isLoading: true, completedThisSession: 0);
    state = AsyncValue<CustomStudyUiState>.data(changed);
    final CustomStudyMatches matches = await _listMatches(changed);
    if (revision != _filterRevision) return;
    final CustomStudyUiState latest = state.valueOrNull ?? changed;
    state = AsyncValue<CustomStudyUiState>.data(
      latest.copyWith(matches: matches, isLoading: false),
    );
  }

  Future<CustomStudyMatches> _listMatches(CustomStudyUiState filters) => ref
      .read(customStudyQueryProvider)
      .load(filter: filters.filter, shuffleSeed: filters.shuffleSeed);

  void _showMessage(UiMessage message) {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(message: message),
    );
  }

  OperationId _newOperation() =>
      OperationId(ref.read(idGeneratorProvider).newId());

  /// A 32-bit FNV-1a hash of the deck, the clock, and how many shuffles came
  /// before, so a session shuffles reproducibly under a fake clock without
  /// ever drawing from the collection's shared random-number stream.
  int _newShuffleSeed(String? deckId) {
    final String text =
        '${deckId ?? 'unsaved'}:'
        '${ref.read(clockProvider).nowUtc().microsecondsSinceEpoch}:'
        '${_shuffleCount++}';
    var hash = 0x811c9dc5;
    for (final int unit in text.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

final AsyncNotifierProvider<CustomStudyViewModel, CustomStudyUiState>
customStudyViewModelProvider =
    AsyncNotifierProvider<CustomStudyViewModel, CustomStudyUiState>(
      CustomStudyViewModel.new,
    );
