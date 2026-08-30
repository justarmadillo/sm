/// The Learning commands offered on one element, and the code that runs them.
///
/// Two screens offer this menu — the Priority queue and the Browser — so the
/// list of commands, what each one is called, what it warns about, and which
/// command object it builds all live here rather than in whichever screen was
/// written first.
///
/// It sits in `features/priority/` rather than `shared/` because running one
/// means reaching the priority browser's command runner, and `shared/` is not
/// allowed to know that exists.
library;

import 'package:flutter/foundation.dart';
import 'package:incremental_reader/features/priority/priority_browser_command_runner.dart';
import 'package:incremental_reader/features/priority/priority_browser_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';

/// One element command from SM20's browser Learning menu.
enum LearningCommand {
  learn('Learn', 'Learning'),
  reviewAll('Review all', 'Reviewing all'),
  reviewTopics('Review topics', 'Reviewing topics'),
  remember('Remember', 'Remembered'),
  forget('Forget', 'Forgotten'),
  dismiss('Dismiss', 'Dismissed'),
  undismiss('Undismiss', 'Undismissed'),
  done('Done', 'Done with'),
  addToFinalDrill('Add to drill', 'Added to the drill'),
  addToOutstanding('Add to outstanding', 'Added to Outstanding'),
  addAll('Add all', 'Added to Outstanding'),
  resetHistory('Reset history', 'History reset for'),
  setAFactor('Set A…', 'A set on'),
  modifyAFactor('Modify A…', 'A modified on');

  const LearningCommand(this.label, this.successVerb);

  /// What the menu calls it.
  final String label;

  /// How the toast opens when the command succeeded, before the count.
  final String successVerb;

  /// Whether the command destroys scheduling state and deserves a prompt.
  bool get isDestructive =>
      this == LearningCommand.forget ||
      this == LearningCommand.dismiss ||
      this == LearningCommand.done;

  /// Whether the command cannot run until the user has typed something.
  bool get needsAnAnswer =>
      this == LearningCommand.addToOutstanding ||
      this == LearningCommand.addAll ||
      this == LearningCommand.setAFactor ||
      this == LearningCommand.modifyAFactor;

  String get warning => switch (this) {
    LearningCommand.forget =>
      'Forget clears the repetition count, interval, and postponement '
          'counters and returns the element to the pending store. The '
          'A-factor and priority survive; the schedule does not.',
    LearningCommand.dismiss =>
      'Dismiss stops scheduling, clears the repetition state, and sets '
          'priority to 100%. Undismiss later restores the status only — not '
          'the schedule or the priority.',
    LearningCommand.done =>
      'Done removes the element from scheduling, every queue, and the '
          'priority population.',
    _ => '',
  };
}

/// The values a command needed the user to type before it could run.
///
/// One object rather than three optional parameters threaded through every
/// caller: only one field is ever filled, and which one is decided by the
/// command the user picked.
@immutable
final class LearningCommandAnswers {
  const LearningCommandAnswers({
    this.everyWhich = 5,
    this.aFactor = 1.10,
    this.aFactorMultiplier = 1,
  });

  /// SM20's `Every which element?` spacing for the two queue insertions.
  final int everyWhich;

  /// The A-factor Set A stores directly.
  final double aFactor;

  /// The multiplier Modify A rescales A by.
  final double aFactorMultiplier;
}

/// Carries out one Learning command over [refs].
///
/// A plain function rather than a method on a ViewModel, because both screens
/// that offer these commands already have their own busy flag and their own
/// way of showing a message; the only part they share is which command object
/// each menu entry builds.
Future<Result<PriorityBrowserCommandOutcome>> runLearningCommand(
  LearningCommand command, {
  required PriorityBrowserCommandRunner commandRunner,
  required OperationId operation,
  required List<ElementRef> refs,
  required StudyDay day,
  required DateTime timestampUtc,
  LearningCommandAnswers answers = const LearningCommandAnswers(),
}) {
  switch (command) {
    case LearningCommand.learn:
      return commandRunner.startReview(
        StartBrowserReview(
          operation,
          refs: refs,
          day: day,
          mode: Sm20ReviewMode.learn,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.reviewAll:
      return commandRunner.startReview(
        StartBrowserReview(
          operation,
          refs: refs,
          day: day,
          mode: Sm20ReviewMode.reviewAll,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.reviewTopics:
      return commandRunner.startReview(
        StartBrowserReview(
          operation,
          refs: refs,
          day: day,
          mode: Sm20ReviewMode.reviewTopics,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.remember:
      return commandRunner.remember(
        RememberElements(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.forget:
      return commandRunner.forget(
        ForgetElements(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.dismiss:
      return commandRunner.dismiss(
        DismissElements(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.undismiss:
      return commandRunner.undismiss(
        UndismissElements(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.done:
      return commandRunner.done(
        DoneElements(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.addToFinalDrill:
      return commandRunner.addToFinalDrill(
        AddToFinalDrill(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.addToOutstanding:
      return commandRunner.addToOutstanding(
        AddToOutstanding(
          operation,
          refs: refs,
          day: day,
          everyWhich: answers.everyWhich,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.addAll:
      return commandRunner.addToOutstanding(
        AddToOutstanding(
          operation,
          refs: refs,
          day: day,
          everyWhich: answers.everyWhich,
          shouldRescheduleSameDay: true,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.resetHistory:
      return commandRunner.resetHistory(
        ResetElementHistory(
          operation,
          refs: refs,
          day: day,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.setAFactor:
      return commandRunner.setAFactor(
        SetTopicAFactor(
          operation,
          refs: refs,
          day: day,
          value: answers.aFactor,
          timestampUtc: timestampUtc,
        ),
      );
    case LearningCommand.modifyAFactor:
      return commandRunner.modifyAFactor(
        ModifyTopicAFactor(
          operation,
          refs: refs,
          day: day,
          multiplier: answers.aFactorMultiplier,
          timestampUtc: timestampUtc,
        ),
      );
  }
}
