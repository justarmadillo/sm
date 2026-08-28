/// SM20's browser Learning command group, as explicit commands.
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
abstract base class BrowserSelectionCommand extends AppCommand {
  BrowserSelectionCommand(
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
final class StartBrowserReview extends BrowserSelectionCommand {
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
final class RememberElements extends BrowserSelectionCommand {
  RememberElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Forget: return a memorized record to the pending store, clearing history.
final class ForgetElements extends BrowserSelectionCommand {
  ForgetElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Dismiss: stop scheduling, clear repetition state, and send priority to 100.
final class DismissElements extends BrowserSelectionCommand {
  DismissElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Undismiss: status only. The schedule and priority Dismiss cleared stay gone.
final class UndismissElements extends BrowserSelectionCommand {
  UndismissElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Done: the scheduler-visible half of deletion.
final class DoneElements extends BrowserSelectionCommand {
  DoneElements(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Add to drill: queue membership only, no record field changes at all.
final class AddToFinalDrill extends BrowserSelectionCommand {
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
/// by `0.9`; only [rescheduleSameDay] (Add all) additionally reschedules a
/// record already reviewed today onto today.
final class AddToOutstanding extends BrowserSelectionCommand {
  AddToOutstanding(
    super.operationId, {
    required super.refs,
    required super.day,
    this.everyWhich = 5,
    this.rescheduleSameDay = false,
    super.timestampUtc,
  });

  final int everyWhich;
  final bool rescheduleSameDay;
}

/// Reset history: drop the external history block and nothing else.
final class ResetElementHistory extends BrowserSelectionCommand {
  ResetElementHistory(
    super.operationId, {
    required super.refs,
    required super.day,
    super.timestampUtc,
  });
}

/// Set A: store an A-factor directly, for normal topics only (1.01..3.00).
final class SetTopicAFactor extends BrowserSelectionCommand {
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
final class ModifyTopicAFactor extends BrowserSelectionCommand {
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
final class AdvanceElements extends BrowserSelectionCommand {
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
final class BrowserCommandOutcome {
  const BrowserCommandOutcome({
    required this.changed,
    required this.skipped,
    this.randomDraws = 0,
  });

  const BrowserCommandOutcome.empty()
    : changed = const <ElementRef>[],
      skipped = 0,
      randomDraws = 0;

  final List<ElementRef> changed;

  /// Selected records the command's own eligibility rules refused.
  final int skipped;

  /// PRNG values this run consumed from the one global stream.
  final int randomDraws;

  int get changedCount => changed.length;
}
