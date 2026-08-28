/// The Learn menu on the priority browser, as explicit commands.
///
/// SM20 calls this screen "the browser"; here it is the priority browser, the
/// one list that shows the whole collection in order.
///
/// These are the bulk operations the executable dispatches from a subset:
/// Learn/Review, Remember, Forget, Dismiss, Undismiss, Done, the two queue
/// insertions, Reset history, the two A-factor edits, and Advance. Each is one
/// command over an explicit ordered selection, because SM20's own semantics
/// are order-sensitive — Add to outstanding walks the selection counting
/// insertions, and Advance draws once per draw-eligible record in order.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_advance.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/command_base.dart';

/// Base for every command that acts on an ordered browser selection.
abstract base class PriorityBrowserSelectionCommand extends AppCommand {
  PriorityBrowserSelectionCommand(
    super.operationId, {
    required this.refs,
    required this.day,
    super.timestampUtc,
  });

  /// The selection, in the browser's own order.
  final List<ElementRef> refs;

  final StudyDay day;
}

/// Build a review source and enter a browser learning mode (4, 5, or 6).
final class StartBrowserReview extends PriorityBrowserSelectionCommand {
  StartBrowserReview(
    super.operationId, {
    required super.refs,
    required super.day,
    required this.mode,
    super.timestampUtc,
  });

  final Sm20ReviewMode mode;
}

/// Remember: memorize a pending or dismissed record with a first interval.
final class RememberElements extends PriorityBrowserSelectionCommand {
  RememberElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Forget: return a memorized record to the pending store, clearing history.
final class ForgetElements extends PriorityBrowserSelectionCommand {
  ForgetElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Dismiss: stop scheduling, clear repetition state, and send priority to 100.
final class DismissElements extends PriorityBrowserSelectionCommand {
  DismissElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Undismiss: status only. The schedule and priority Dismiss cleared stay gone.
final class UndismissElements extends PriorityBrowserSelectionCommand {
  UndismissElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Done: the scheduler-visible half of deletion.
final class DoneElements extends PriorityBrowserSelectionCommand {
  DoneElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Add to drill: queue membership only, no record field changes at all.
final class AddToFinalDrill extends PriorityBrowserSelectionCommand {
  AddToFinalDrill(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Add to outstanding, or Add all.
///
/// [everyWhich] is SM20's `Every which element?` spacing, default 5 and bounds
/// 1..100. Both variants raise importance by multiplying the priority target
/// by `0.9`; only [shouldRescheduleSameDay] (Add all) additionally reschedules a
/// record already reviewed today onto today.
final class AddToOutstanding extends PriorityBrowserSelectionCommand {
  AddToOutstanding(
    super.operationId, {
    required super.refs,
    required super.day,
    this.everyWhich = 5,
    this.shouldRescheduleSameDay = false,
    super.timestampUtc,
  });

  final int everyWhich;
  final bool shouldRescheduleSameDay;
}

/// Reset history: drop the external history block and nothing else.
final class ResetElementHistory extends PriorityBrowserSelectionCommand {
  ResetElementHistory(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Set A: store an A-factor directly, for normal topics only (1.01..3.00).
final class SetTopicAFactor extends PriorityBrowserSelectionCommand {
  SetTopicAFactor(
    super.operationId, {
    required super.refs,
    required super.day,
    required this.value,
    super.timestampUtc,
  });

  final double value;
}

/// Modify A: `A = 1.01 + m * (A - 1.01)`, for normal topics only (0.20..2.00).
final class ModifyTopicAFactor extends PriorityBrowserSelectionCommand {
  ModifyTopicAFactor(
    super.operationId, {
    required super.refs,
    required super.day,
    required this.multiplier,
    super.timestampUtc,
  });

  final double multiplier;
}

/// Advance Topics, Items, or All elements across a horizon of D days.
final class AdvanceElements extends PriorityBrowserSelectionCommand {
  AdvanceElements(
    super.operationId, {
    required super.refs,
    required super.day,
    required this.scope,
    this.horizonDays = kSm20AdvanceDefaultDays,
    super.timestampUtc,
  });

  final Sm20AdvanceScope scope;
  final int horizonDays;
}

/// What one browser command did.
///
/// SM20's commands are filters as much as actions — most of a selection is
/// routinely ineligible — so the skipped count is reported rather than hidden,
/// and the changed refs are returned in the order they were written.
final class PriorityBrowserCommandOutcome {
  const PriorityBrowserCommandOutcome({
    required this.changedRefs,
    required this.skipped,
    this.randomDraws = 0,
  });

  const PriorityBrowserCommandOutcome.empty()
    : changedRefs = const <ElementRef>[],
      skipped = 0,
      randomDraws = 0;

  final List<ElementRef> changedRefs;

  /// Selected records the command's own eligibility rules refused.
  final int skipped;

  /// PRNG values this run consumed from the one global stream.
  final int randomDraws;

  int get changedRefCount => changedRefs.length;
}
