/// Holds custom-study filters, matches, and current-session progress.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/custom_study/custom_study_providers.dart';
import 'package:incremental_reader/features/custom_study/custom_study_query.dart';
import 'package:incremental_reader/scheduling/element.dart';

@immutable
final class CustomStudyUiState {
  CustomStudyUiState({
    this.selectedTagIds = const <String>{},
    this.match = CustomStudyTagMatch.all,
    Set<ElementType>? types,
    this.shouldReschedule = true,
    this.entries = const <CustomStudyEntry>[],
    this.completedThisSession = 0,
    this.isLoading = false,
  }) : types = Set<ElementType>.unmodifiable(
         types ?? ElementType.values.toSet(),
       );

  final Set<String> selectedTagIds;
  final CustomStudyTagMatch match;
  final Set<ElementType> types;
  final bool shouldReschedule;
  final List<CustomStudyEntry> entries;
  final int completedThisSession;
  final bool isLoading;

  CustomStudyUiState copyWith({
    Set<String>? selectedTagIds,
    CustomStudyTagMatch? match,
    Set<ElementType>? types,
    bool? shouldReschedule,
    List<CustomStudyEntry>? entries,
    int? completedThisSession,
    bool? isLoading,
  }) => CustomStudyUiState(
    selectedTagIds: selectedTagIds ?? this.selectedTagIds,
    match: match ?? this.match,
    types: types ?? this.types,
    shouldReschedule: shouldReschedule ?? this.shouldReschedule,
    entries: entries ?? this.entries,
    completedThisSession: completedThisSession ?? this.completedThisSession,
    isLoading: isLoading ?? this.isLoading,
  );
}

final class CustomStudyViewModel extends AsyncNotifier<CustomStudyUiState> {
  var _filterRevision = 0;

  @override
  Future<CustomStudyUiState> build() async {
    final CustomStudyUiState initial = CustomStudyUiState();
    return initial.copyWith(entries: await _listEntries(initial));
  }

  Future<void> setSelectedTagIds(Set<String> tagIds) => _changeFilters(
    (CustomStudyUiState current) => current.copyWith(
      selectedTagIds: Set<String>.unmodifiable(tagIds),
      completedThisSession: 0,
    ),
  );

  Future<void> setMatch(CustomStudyTagMatch match) => _changeFilters(
    (CustomStudyUiState current) =>
        current.copyWith(match: match, completedThisSession: 0),
  );

  Future<void> toggleType(ElementType type) {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null || (!current.shouldReschedule && type.isTopic)) {
      return Future<void>.value();
    }
    final Set<ElementType> changed = <ElementType>{...current.types};
    changed.contains(type) ? changed.remove(type) : changed.add(type);
    return _changeFilters(
      (CustomStudyUiState latest) =>
          latest.copyWith(types: changed, completedThisSession: 0),
    );
  }

  Future<void> setShouldReschedule(bool shouldReschedule) => _changeFilters(
    (CustomStudyUiState current) => current.copyWith(
      shouldReschedule: shouldReschedule,
      types: shouldReschedule
          ? current.types
          : const <ElementType>{ElementType.card},
      completedThisSession: 0,
    ),
  );

  /// Freezes the current rows before routes begin changing schedules.
  List<CustomStudyEntry> beginSession() {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null || current.isLoading) return const <CustomStudyEntry>[];
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(completedThisSession: 0),
    );
    return List<CustomStudyEntry>.unmodifiable(current.entries);
  }

  void recordCompleted() {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue<CustomStudyUiState>.data(
      current.copyWith(completedThisSession: current.completedThisSession + 1),
    );
  }

  Future<void> _changeFilters(
    CustomStudyUiState Function(CustomStudyUiState current) change,
  ) async {
    final CustomStudyUiState? current = state.valueOrNull;
    if (current == null) return;
    final int revision = ++_filterRevision;
    final CustomStudyUiState changed = change(
      current,
    ).copyWith(isLoading: true);
    state = AsyncValue<CustomStudyUiState>.data(changed);
    final List<CustomStudyEntry> entries = await _listEntries(changed);
    if (revision != _filterRevision) return;
    state = AsyncValue<CustomStudyUiState>.data(
      changed.copyWith(entries: entries, isLoading: false),
    );
  }

  Future<List<CustomStudyEntry>> _listEntries(CustomStudyUiState filters) => ref
      .read(customStudyQueryProvider)
      .load(
        tagIds: filters.selectedTagIds,
        match: filters.match,
        types: filters.types,
      );
}

final AsyncNotifierProvider<CustomStudyViewModel, CustomStudyUiState>
customStudyViewModelProvider =
    AsyncNotifierProvider<CustomStudyViewModel, CustomStudyUiState>(
      CustomStudyViewModel.new,
    );
