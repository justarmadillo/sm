/// ViewModels for the priority slider and the priority browser.
///
/// Both work exclusively in percent and in neighbours. A raw order key means
/// nothing to a human, and an absolute score would inflate until it stopped
/// discriminating between anything — the point of a relative queue is that
/// promoting one element necessarily demotes another.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/daily_queue/daily_queue_providers.dart';
import 'package:incremental_reader/features/daily_queue/queue_commands.dart';
import 'package:incremental_reader/features/library/library_view_model.dart';
import 'package:incremental_reader/features/priority/browser_command_runner.dart';
import 'package:incremental_reader/features/priority/browser_commands.dart';
import 'package:incremental_reader/features/priority/priority_commands.dart';
import 'package:incremental_reader/features/priority/priority_providers.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/postpone_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// State of the Alt+P dialog for one element.
@immutable
final class PrioritySliderState {
  const PrioritySliderState({
    required this.context,
    required this.draftPercent,
    this.isBusy = false,
    this.message,
    this.draftAbove,
    this.draftBelow,
  });

  /// Where the element currently sits, and what surrounds it.
  final PriorityContext context;

  /// The value the slider is showing, before it is committed.
  final double draftPercent;

  final bool isBusy;
  final UiMessage? message;

  /// Neighbours for the drafted percent, not for the stored rank.
  final PriorityEntry? draftAbove;
  final PriorityEntry? draftBelow;

  /// Whether the draft differs from what is stored.
  bool get isDirty => (draftPercent - context.percent).abs() >= 0.5;

  PrioritySliderState copyWith({
    PriorityContext? context,
    double? draftPercent,
    bool? isBusy,
    UiMessage? message,
    bool shouldClearMessage = false,
    PriorityEntry? draftAbove,
    PriorityEntry? draftBelow,
    bool shouldClearDraftNeighbours = false,
  }) => PrioritySliderState(
    context: context ?? this.context,
    draftPercent: draftPercent ?? this.draftPercent,
    isBusy: isBusy ?? this.isBusy,
    message: shouldClearMessage ? null : (message ?? this.message),
    draftAbove: shouldClearDraftNeighbours ? null : (draftAbove ?? this.draftAbove),
    draftBelow: shouldClearDraftNeighbours ? null : (draftBelow ?? this.draftBelow),
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
      draftAbove: context.above,
      draftBelow: context.below,
    );
  }

  /// Moves the slider without committing.
  void draft(double percent) {
    final PrioritySliderState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    final double clamped = percent.clamp(0, 100);
    state = AsyncValue<PrioritySliderState>.data(
      current.copyWith(draftPercent: clamped),
    );
    unawaited(_refreshNeighbours(clamped));
  }

  /// Resolves the neighbours for [percent] and applies them if still current.
  ///
  /// The slider emits faster than the query returns, so a late answer for a
  /// percent the user has already moved past is dropped rather than shown.
  Future<void> _refreshNeighbours(double percent) async {
    final ({PriorityEntry? above, PriorityEntry? below}) neighbours = await ref
        .read(priorityQueryProvider)
        .neighboursAt(ref: arg, percent: percent);
    final PrioritySliderState? latest = state.valueOrNull;
    if (latest == null || latest.draftPercent != percent) return;
    state = AsyncValue<PrioritySliderState>.data(
      latest.copyWith(
        shouldClearDraftNeighbours: true,
        draftAbove: neighbours.above,
        draftBelow: neighbours.below,
      ),
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
        .read(priorityCommandRunnerProvider)
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
  Future<void> step({required bool shouldIncrease}) async {
    final PrioritySliderState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<PrioritySliderState>.data(
      current.copyWith(isBusy: true),
    );

    await ref
        .read(priorityCommandRunnerProvider)
        .step(
          StepPriority(
            OperationId(ref.read(idGeneratorProvider).newId()),
            ref: arg,
            shouldIncrease: shouldIncrease,
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
    this.sort = PriorityBrowserSort.priority,
    this.isAscending = true,
  });

  /// Every element in the order the browser is currently showing.
  final List<PriorityEntry> entries;

  /// Type filter. Empty means everything.
  final Set<ElementType> types;

  final UiMessage? message;
  final bool isBusy;

  final PriorityBrowserSort sort;
  final bool isAscending;

  /// Whether the rows are in collection priority order.
  ///
  /// Dragging rewrites one order key against its neighbours, so it is only
  /// meaningful while the list *is* that order. Under any other sort the row
  /// above is not the rank above, and a drag would move the element somewhere
  /// the user did not point at.
  bool get isReorderable => sort == PriorityBrowserSort.priority && isAscending;

  PriorityBrowserState copyWith({
    List<PriorityEntry>? entries,
    Set<ElementType>? types,
    UiMessage? message,
    bool shouldClearMessage = false,
    bool? isBusy,
    PriorityBrowserSort? sort,
    bool? isAscending,
  }) => PriorityBrowserState(
    entries: entries ?? this.entries,
    types: types ?? this.types,
    message: shouldClearMessage ? null : (message ?? this.message),
    isBusy: isBusy ?? this.isBusy,
    sort: sort ?? this.sort,
    isAscending: isAscending ?? this.isAscending,
  );
}

/// Which column the browser is ordered by.
enum PriorityBrowserSort {
  priority('Prior'),
  title('Title'),
  interval('Intrv'),
  repetitions('Reps'),
  lapses('Laps'),
  lastRepetition('LastRep'),
  nextRepetition('NextRep');

  const PriorityBrowserSort(this.label);

  final String label;
}

/// Orders [entries] by [sort], with a stable tie-break on priority.
///
/// The tie-break matters: most of these columns repeat heavily — every new
/// element has zero repetitions — and without it equal rows would shuffle on
/// every rebuild.
List<PriorityEntry> sortPriorityEntries(
  List<PriorityEntry> entries,
  PriorityBrowserSort sort,
  bool isAscending,
) {
  int byPriority(PriorityEntry a, PriorityEntry b) =>
      a.schedule.priority.compareTo(b.schedule.priority);
  int compare(PriorityEntry a, PriorityEntry b) {
    // Never-repeated elements are placed before the direction is applied, so
    // reversing the column cannot pull them to the front: an absent
    // repetition is not an early one, and it is not a late one either.
    if (sort == PriorityBrowserSort.lastRepetition) {
      final bool aMissing = a.lastRepetition == null;
      final bool bMissing = b.lastRepetition == null;
      if (aMissing || bMissing) {
        if (aMissing && bMissing) return byPriority(a, b);
        return aMissing ? 1 : -1;
      }
    }
    final int primary = switch (sort) {
      PriorityBrowserSort.priority => byPriority(a, b),
      PriorityBrowserSort.title => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      PriorityBrowserSort.interval => a.intervalDays.compareTo(b.intervalDays),
      PriorityBrowserSort.repetitions => a.repetitions.compareTo(b.repetitions),
      PriorityBrowserSort.lapses => a.lapses.compareTo(b.lapses),
      PriorityBrowserSort.lastRepetition => a.lastRepetition!.compareTo(
        b.lastRepetition!,
      ),
      PriorityBrowserSort.nextRepetition => a.nextRepetition.compareTo(
        b.nextRepetition,
      ),
    };
    if (primary != 0) return isAscending ? primary : -primary;
    return byPriority(a, b);
  }

  return List<PriorityEntry>.unmodifiable(
    <PriorityEntry>[...entries]..sort(compare),
  );
}

/// The whole collection in priority order, with drag-to-rebalance.
final class PriorityBrowserViewModel
    extends AsyncNotifier<PriorityBrowserState> {
  @override
  Future<PriorityBrowserState> build() async => PriorityBrowserState(
    entries: await ref.read(priorityQueryProvider).browse(),
  );

  /// Sorts by [sort], flipping direction when the same column is chosen twice.
  Future<void> sortBy(PriorityBrowserSort sort) async {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    final bool isAscending = current.sort == sort ? !current.isAscending : true;
    state = AsyncValue<PriorityBrowserState>.data(
      current.copyWith(
        sort: sort,
        isAscending: isAscending,
        entries: sortPriorityEntries(current.entries, sort, isAscending),
      ),
    );
  }

  /// Restricts the list to certain element types.
  Future<void> filterTo(Set<ElementType> types) async {
    state = const AsyncLoading<PriorityBrowserState>();
    final PriorityBrowserSort sort =
        state.valueOrNull?.sort ?? PriorityBrowserSort.priority;
    final bool isAscending = state.valueOrNull?.isAscending ?? true;
    state = await AsyncValue.guard(
      () async => PriorityBrowserState(
        entries: sortPriorityEntries(
          await ref
              .read(priorityQueryProvider)
              .browse(types: types.isEmpty ? null : types),
          sort,
          isAscending,
        ),
        types: types,
        sort: sort,
        isAscending: isAscending,
      ),
    );
  }

  /// Reloads the projection.
  Future<void> refresh() async {
    final PriorityBrowserState? current = state.valueOrNull;
    final Set<ElementType> types = current?.types ?? const <ElementType>{};
    final PriorityBrowserSort sort =
        current?.sort ?? PriorityBrowserSort.priority;
    final bool isAscending = current?.isAscending ?? true;
    state = AsyncValue<PriorityBrowserState>.data(
      PriorityBrowserState(
        entries: sortPriorityEntries(
          await ref
              .read(priorityQueryProvider)
              .browse(types: types.isEmpty ? null : types),
          sort,
          isAscending,
        ),
        types: types,
        sort: sort,
        isAscending: isAscending,
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
        .read(priorityCommandRunnerProvider)
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
      final PriorityBrowserState latest = state.valueOrNull ?? current;
      state = AsyncValue<PriorityBrowserState>.data(
        latest.copyWith(
          message: UiMessage(result.failureOrNull!.message, isError: true),
        ),
      );
    }
  }

  /// Applies an executable browser priority operation to one branch.
  Future<void> batchBranch({
    required String sourceId,
    required Sm20BatchPriorityMode mode,
    required double lowPercent,
    required double highPercent,
    required double changePercent,
    required bool shouldLimitChanges,
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
        .read(priorityCommandRunnerProvider)
        .batch(
          BatchPriority(
            OperationId(ref.read(idGeneratorProvider).newId()),
            refs: <ElementRef>[
              for (final PriorityEntry entry in branch) entry.ref,
            ],
            mode: mode,
            lowPercent: lowPercent,
            highPercent: highPercent,
            changePercent: changePercent,
            shouldLimitChanges: shouldLimitChanges,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );
    await refresh();
    final PriorityBrowserState latest = state.valueOrNull ?? current;
    state = AsyncValue<PriorityBrowserState>.data(
      latest.copyWith(
        message: result.fold(
          (int count) => UiMessage(
            '${mode.name[0].toUpperCase()}${mode.name.substring(1)} changed '
            '$count elements',
          ),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Runs Smart Postpone over a branch, or over what the browser is showing.
  ///
  /// The browser population is the visible, filtered order rather than the
  /// Outstanding queue, which is the whole reason SM20 offers a browser scope:
  /// it can reach elements that are not due at all.
  Future<AppliedSmartPostpone?> smartPostpone({
    required bool isSimulationOnly,
    String? branchSourceId,
  }) async {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current == null || current.isBusy) return null;
    state = AsyncValue<PriorityBrowserState>.data(
      current.copyWith(isBusy: true),
    );

    final AppSettings settings = await ref
        .read(schedulingContextProvider)
        .settings();
    final List<PriorityEntry> population = branchSourceId == null
        ? current.entries
        : await ref.read(priorityQueryProvider).branchOf(branchSourceId);
    final SmartPostponeSettings profile = settings.postpone.defaultProfile
        .copyWith(
          scope: branchSourceId == null
              ? SmartPostponeScope.browser
              : SmartPostponeScope.branch,
          rootElementId: int.tryParse(branchSourceId ?? '') ?? 0,
          isSimulationOnly: isSimulationOnly,
        );

    final Result<AppliedSmartPostpone> result = await ref
        .read(queueCommandRunnerProvider)
        .runSmartPostpone(
          RunSmartPostpone(
            OperationId(ref.read(idGeneratorProvider).newId()),
            day: await ref.read(schedulingContextProvider).today(),
            profile: profile,
            sourcePopulation: <ElementRef>[
              for (final PriorityEntry entry in population) entry.ref,
            ],
            applicableSubbranchProfiles: _applicableBranchProfiles(
              settings.postpone,
              population,
            ),
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        );

    // A simulation wrote nothing, so the rows on screen are still accurate.
    if (!isSimulationOnly && result.isOk) {
      await refresh();
    } else {
      state = AsyncValue<PriorityBrowserState>.data(
        (state.valueOrNull ?? current).copyWith(isBusy: false),
      );
    }
    final PriorityBrowserState latest = state.valueOrNull ?? current;
    return result.fold(
      (AppliedSmartPostpone applied) {
        if (!isSimulationOnly) {
          state = AsyncValue<PriorityBrowserState>.data(
            latest.copyWith(
              message: UiMessage(
                applied.written == 0
                    ? 'Nothing was eligible for postponement'
                    : 'Smart Postpone moved ${applied.written} element'
                          '${applied.written == 1 ? '' : 's'}',
              ),
            ),
          );
        }
        return applied;
      },
      (AppFailure failure) {
        state = AsyncValue<PriorityBrowserState>.data(
          latest.copyWith(message: UiMessage(failure.message, isError: true)),
        );
        return null;
      },
    );
  }

  /// Branch profiles that apply to [population], outermost first.
  ///
  /// The merge SM20 performs is order-sensitive, so roots are contributed
  /// before parents and parents before the elements themselves; the innermost
  /// assignment is therefore the last word under Respect.
  List<SmartPostponeSettings> _applicableBranchProfiles(
    PostponeSettings postpone,
    Iterable<PriorityEntry> population,
  ) {
    if (postpone.branchProfileAssignments.isEmpty) {
      return const <SmartPostponeSettings>[];
    }
    final List<String> ordered = <String>[];
    void add(String? id) {
      if (id != null && !ordered.contains(id)) ordered.add(id);
    }

    for (final PriorityEntry entry in population) {
      add(entry.schedule.rootId);
    }
    for (final PriorityEntry entry in population) {
      add(entry.schedule.parentElementId);
    }
    for (final PriorityEntry entry in population) {
      add(entry.ref.id);
    }
    final List<SmartPostponeSettings> profiles = <SmartPostponeSettings>[];
    for (final String id in ordered) {
      final int? root = int.tryParse(id);
      if (root == null) continue;
      final String? name = postpone.branchProfileAssignments[root];
      if (name == null) continue;
      final SmartPostponeSettings? profile = postpone.profileNamed(name);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  /// Remember: memorize pending or dismissed topics.
  /// Learn, Review all, Review topics: section 9.7's review modes 4, 5, 6.
  ///
  /// Opening a review sets the learning mode and stores the subset queue; it
  /// does not touch A, because merely opening a review is not a repetition.
  Future<void> startReview(List<ElementRef> refs, Sm20ReviewMode mode) =>
      _browserCommand(
        switch (mode) {
          Sm20ReviewMode.learn => 'Learning',
          Sm20ReviewMode.reviewAll => 'Reviewing all',
          Sm20ReviewMode.reviewTopics => 'Reviewing topics',
        },
        (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
            commandRunner.startReview(
              StartBrowserReview(
                operation,
                refs: refs,
                day: day,
                mode: mode,
                timestampUtc: ref.read(clockProvider).nowUtc(),
              ),
            ),
      );

  Future<void> remember(List<ElementRef> refs) => _browserCommand(
    'Remembered',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.remember(
          RememberElements(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Forget: return memorized records to the pending store.
  Future<void> forget(List<ElementRef> refs) => _browserCommand(
    'Forgotten',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.forget(
          ForgetElements(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Dismiss: stop scheduling and send priority to the bottom.
  Future<void> dismiss(List<ElementRef> refs) => _browserCommand(
    'Dismissed',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.dismiss(
          DismissElements(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Undismiss: restore the status only.
  Future<void> undismiss(List<ElementRef> refs) => _browserCommand(
    'Undismissed',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.undismiss(
          UndismissElements(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Done: remove from scheduling entirely.
  Future<void> done(List<ElementRef> refs) => _browserCommand(
    'Done',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.done(
          DoneElements(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Add to drill: Final Drill membership only.
  Future<void> addToFinalDrill(List<ElementRef> refs) => _browserCommand(
    'Added to Final Drill',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.addToFinalDrill(
          AddToFinalDrill(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Add to outstanding, or Add all.
  Future<void> addToOutstanding(
    List<ElementRef> refs, {
    int everyWhich = 5,
    bool shouldRescheduleSameDay = false,
  }) => _browserCommand(
    'Added to Outstanding',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.addToOutstanding(
          AddToOutstanding(
            operation,
            refs: refs,
            day: day,
            everyWhich: everyWhich,
            shouldRescheduleSameDay: shouldRescheduleSameDay,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Reset history: drop the external history block and nothing else.
  Future<void> resetHistory(List<ElementRef> refs) => _browserCommand(
    'History reset',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.resetHistory(
          ResetElementHistory(
            operation,
            refs: refs,
            day: day,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Set A directly, for normal topics.
  Future<void> setAFactor(List<ElementRef> refs, double value) =>
      _browserCommand(
        'A-factor set',
        (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
            commandRunner.setAFactor(
              SetTopicAFactor(
                operation,
                refs: refs,
                day: day,
                value: value,
                timestampUtc: ref.read(clockProvider).nowUtc(),
              ),
            ),
      );

  /// Modify A by a multiplier, for normal topics.
  Future<void> modifyAFactor(List<ElementRef> refs, double multiplier) =>
      _browserCommand(
        'A-factor modified',
        (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
            commandRunner.modifyAFactor(
              ModifyTopicAFactor(
                operation,
                refs: refs,
                day: day,
                multiplier: multiplier,
                timestampUtc: ref.read(clockProvider).nowUtc(),
              ),
            ),
      );

  /// Advance: pull future work closer to today across a horizon.
  Future<void> advance(
    List<ElementRef> refs, {
    required Sm20AdvanceScope scope,
    required int horizonDays,
  }) => _browserCommand(
    'Advanced',
    (BrowserCommandRunner commandRunner, OperationId operation, StudyDay day) =>
        commandRunner.advance(
          AdvanceElements(
            operation,
            refs: refs,
            day: day,
            scope: scope,
            horizonDays: horizonDays,
            timestampUtc: ref.read(clockProvider).nowUtc(),
          ),
        ),
  );

  /// Runs one browser command and reports what it actually changed.
  ///
  /// SM20's commands are filters as much as actions, so the skipped count is
  /// surfaced: a command that legitimately refused the whole selection must
  /// not look like one that silently failed.
  Future<void> _browserCommand(
    String verb,
    Future<Result<BrowserCommandOutcome>> Function(
      BrowserCommandRunner commandRunner,
      OperationId operation,
      StudyDay day,
    )
    run,
  ) async {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current == null || current.isBusy) return;
    state = AsyncValue<PriorityBrowserState>.data(
      current.copyWith(isBusy: true),
    );

    final Result<BrowserCommandOutcome> result = await run(
      ref.read(browserCommandRunnerProvider),
      OperationId(ref.read(idGeneratorProvider).newId()),
      await ref.read(schedulingContextProvider).today(),
    );
    await refresh();
    final PriorityBrowserState latest = state.valueOrNull ?? current;
    state = AsyncValue<PriorityBrowserState>.data(
      latest.copyWith(
        message: result.fold(
          (BrowserCommandOutcome outcome) => UiMessage(
            outcome.changedRefCount == 0
                ? 'Nothing was eligible'
                : '$verb ${outcome.changedRefCount} element'
                      '${outcome.changedRefCount == 1 ? '' : 's'}'
                      '${outcome.skipped == 0 ? '' : ', ${outcome.skipped} skipped'}',
          ),
          (AppFailure failure) => UiMessage(failure.message, isError: true),
        ),
      ),
    );
  }

  /// Clears the one-shot message after the view has shown it.
  void shouldClearMessage() {
    final PriorityBrowserState? current = state.valueOrNull;
    if (current?.message == null) return;
    state = AsyncValue<PriorityBrowserState>.data(
      current!.copyWith(shouldClearMessage: true),
    );
  }
}

final AsyncNotifierProvider<PriorityBrowserViewModel, PriorityBrowserState>
priorityBrowserProvider =
    AsyncNotifierProvider<PriorityBrowserViewModel, PriorityBrowserState>(
      PriorityBrowserViewModel.new,
    );
