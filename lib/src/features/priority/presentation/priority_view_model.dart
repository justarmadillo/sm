/// ViewModels for the priority slider and the priority browser.
///
/// Both work exclusively in percent and in neighbours. A raw order key means
/// nothing to a human, and an absolute score would inflate until it stopped
/// discriminating between anything — the point of a relative queue is that
/// promoting one element necessarily demotes another.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../application/priority/priority_commands.dart';
import '../../../application/priority/priority_query.dart';
import '../../../core/result.dart';
import '../../../core/tracing.dart';
import '../../../domain/scheduling/element.dart';
import '../../library/presentation/library_view_model.dart';

/// State of the Alt+P dialog for one element.
@immutable
final class PrioritySliderState {
  const PrioritySliderState({
    required this.context,
    required this.draftPercent,
    this.isBusy = false,
    this.message,
  });

  /// Where the element currently sits, and what surrounds it.
  final PriorityContext context;

  /// The value the slider is showing, before it is committed.
  final double draftPercent;

  final bool isBusy;
  final UiMessage? message;

  /// Whether the draft differs from what is stored.
  bool get isDirty => (draftPercent - context.percent).abs() >= 0.5;

  PrioritySliderState copyWith({
    PriorityContext? context,
    double? draftPercent,
    bool? isBusy,
    UiMessage? message,
    bool clearMessage = false,
  }) => PrioritySliderState(
    context: context ?? this.context,
    draftPercent: draftPercent ?? this.draftPercent,
    isBusy: isBusy ?? this.isBusy,
    message: clearMessage ? null : (message ?? this.message),
  );
}

/// One element's priority, editable.
final class PrioritySliderViewModel
    extends FamilyAsyncNotifier<PrioritySliderState, ElementRef> {
  @override
  Future<PrioritySliderState> build(ElementRef arg) async {
    final PriorityContext? context = await ref
        .read(priorityQueryProvider)
        .contextFor(arg);
    if (context == null) {
      throw StateError('$arg has no schedule, so it has no priority');
    }
    return PrioritySliderState(
      context: context,
      draftPercent: context.percent,
    );
  }

  /// Moves the slider without committing.
  void draft(double percent) {
    final PrioritySliderState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<PrioritySliderState>.data(
      current.copyWith(draftPercent: percent.clamp(0, 100)),
    );
  }

  /// Writes the drafted percent.
  Future<bool> commit() async {
    final PrioritySliderState? current = state.valueOrNull;
    if (current == null || current.isBusy) return false;
    state = AsyncValue<PrioritySliderState>.data(
      current.copyWith(isBusy: true),
    );

    final Result<ElementSchedule> result = await ref
        .read(priorityHandlersProvider)
        .setPercent(
          SetPriorityPercent(
            OperationId(ref.read(idGeneratorProvider).newId()),
            ref: arg,
            percent: current.draftPercent,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    if (result.isErr) {
      state = AsyncValue<PrioritySliderState>.data(
        current.copyWith(
          isBusy: false,
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
      return false;
    }

    final PriorityContext? reloaded = await ref
        .read(priorityQueryProvider)
        .contextFor(arg);
    state = AsyncValue<PrioritySliderState>.data(
      PrioritySliderState(
        context: reloaded ?? current.context,
        draftPercent: reloaded?.percent ?? current.draftPercent,
      ),
    );
    return true;
  }

  /// Nudges the element one place up or down the queue.
  Future<void> step({required bool increase}) async {
    final PrioritySliderState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<PrioritySliderState>.data(
      current.copyWith(isBusy: true),
    );

    await ref
        .read(priorityHandlersProvider)
        .step(
          StepPriority(
            OperationId(ref.read(idGeneratorProvider).newId()),
            ref: arg,
            increase: increase,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    final PriorityContext? reloaded = await ref
        .read(priorityQueryProvider)
        .contextFor(arg);
    state = AsyncValue<PrioritySliderState>.data(
      PrioritySliderState(
        context: reloaded ?? current.context,
        draftPercent: reloaded?.percent ?? current.draftPercent,
      ),
    );
  }
}

final AsyncNotifierProviderFamily<
  PrioritySliderViewModel,
  PrioritySliderState,
  ElementRef
>
prioritySliderProvider =
    AsyncNotifierProvider.family<
      PrioritySliderViewModel,
      PrioritySliderState,
      ElementRef
    >(PrioritySliderViewModel.new);

/// State of the priority browser.
@immutable
final class PriorityBrowserState {
  const PriorityBrowserState({
    required this.entries,
    this.types = const <ElementType>{},
    this.message,
    this.isBusy = false,
  });

  /// Every element, most important first.
  final List<PriorityEntry> entries;

  /// Type filter. Empty means everything.
  final Set<ElementType> types;

  final UiMessage? message;
  final bool isBusy;

  PriorityBrowserState copyWith({
    List<PriorityEntry>? entries,
    Set<ElementType>? types,
    UiMessage? message,
    bool clearMessage = false,
    bool? isBusy,
  }) => PriorityBrowserState(
    entries: entries ?? this.entries,
    types: types ?? this.types,
    message: clearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
  );
}

/// The whole collection in priority order, with drag-to-rebalance.
final class PriorityBrowserViewModel
    extends AsyncNotifier<PriorityBrowserState> {
  @override
  Future<PriorityBrowserState> build() async => PriorityBrowserState(
    entries: await ref.read(priorityQueryProvider).browse(),
  );

  /// Restricts the list to certain element types.
  Future<void> filterTo(Set<ElementType> types) async {
    state = const AsyncLoading<PriorityBrowserState>();
    state = await AsyncValue.guard(
      () async => PriorityBrowserState(
        entries: await ref
            .read(priorityQueryProvider)
            .browse(types: types.isEmpty ? null : types),
        types: types,
      ),
    );
  }

  /// Reloads the projection.
  Future<void> refresh() async {
    final PriorityBrowserState? current = state.valueOrNull;
    final Set<ElementType> types = current?.types ?? const <ElementType>{};
    state = AsyncValue<PriorityBrowserState>.data(
      PriorityBrowserState(
        entries: await ref
            .read(priorityQueryProvider)
            .browse(types: types.isEmpty ? null : types),
        types: types,
      ),
    );
  }

  /// Moves the element at [from] to sit at [to], as a drag does.
  ///
  /// Only the dragged element's key is rewritten; the rest of the collection
  /// keeps the keys it had, which is the whole reason for fractional ordering.
  Future<void> reorder(int from, int to) async {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    if (from < 0 || from >= current.entries.length) return;

    final List<PriorityEntry> reordered = <PriorityEntry>[...current.entries];
    final PriorityEntry moved = reordered.removeAt(from);
    final int target = to.clamp(0, reordered.length);
    reordered.insert(target, moved);

    state = AsyncValue<PriorityBrowserState>.data(
      current.copyWith(entries: reordered, isBusy: true),
    );

    final Result<ElementSchedule> result = await ref
        .read(priorityHandlersProvider)
        .reorder(
          ReorderPriority(
            OperationId(ref.read(idGeneratorProvider).newId()),
            ref: moved.ref,
            after: target == 0 ? null : reordered[target - 1].schedule.priority,
            before: target >= reordered.length - 1
                ? null
                : reordered[target + 1].schedule.priority,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    await refresh();
    if (result.isErr) {
      final PriorityBrowserState latest =
          state.valueOrNull ?? current;
      state = AsyncValue<PriorityBrowserState>.data(
        latest.copyWith(
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
    }
  }

  /// Spreads a percent range across every element under one article.
  ///
  /// The operation that makes exact inheritance survivable: an article given a
  /// high priority hands it to every extract and card it produces, which is
  /// right at creation and wrong once the reading is done.
  Future<void> spreadBranch({
    required String sourceId,
    required double fromPercent,
    required double toPercent,
  }) async {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<PriorityBrowserState>.data(
      current.copyWith(isBusy: true),
    );

    final List<PriorityEntry> branch = await ref
        .read(priorityQueryProvider)
        .branchOf(sourceId);
    final Result<int> result = await ref
        .read(priorityHandlersProvider)
        .spread(
          SpreadPriority(
            OperationId(ref.read(idGeneratorProvider).newId()),
            refs: <ElementRef>[
              for (final PriorityEntry entry in branch) entry.ref,
            ],
            fromPercent: fromPercent,
            toPercent: toPercent,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    await refresh();
    final PriorityBrowserState latest = state.valueOrNull ?? current;
    state = AsyncValue<PriorityBrowserState>.data(
      latest.copyWith(
        message: result.fold(
          (int count) => UiMessage('Spread $count elements'),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Clears the one-shot message after the view has shown it.
  void clearMessage() {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<PriorityBrowserState>.data(
      current!.copyWith(clearMessage: true),
    );
  }
}

final AsyncNotifierProvider<PriorityBrowserViewModel, PriorityBrowserState>
priorityBrowserProvider =
    AsyncNotifierProvider<PriorityBrowserViewModel, PriorityBrowserState>(
      PriorityBrowserViewModel.new,
    );
