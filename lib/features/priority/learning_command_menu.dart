/// The Learning menu, and the questions a command asks before it runs.
///
/// Drawn identically on the Priority queue and on every Browser row, so the
/// same element offers the same commands wherever the user found it.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/priority/learning_commands.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

/// The Learning commands for one element, behind a button.
class LearningCommandMenu extends StatelessWidget {
  const LearningCommandMenu({
    required this.onSelected,
    this.isEnabled = true,
    this.size = 34,
    this.iconSize = 17,
    super.key,
  });

  final ValueChanged<LearningCommand> onSelected;

  /// False while a command is already running, so a second tap cannot start
  /// one on top of it.
  final bool isEnabled;

  /// The button's slot, tighter than Material's 48-pixel tap target: a row
  /// carries three of these beside a title.
  final double size;

  final double iconSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: PopupMenuButton<LearningCommand>(
      enabled: isEnabled,
      tooltip: 'Learning commands',
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<LearningCommand>>[
        for (final LearningCommand command in LearningCommand.values)
          PopupMenuItem<LearningCommand>(
            value: command,
            child: Text(command.label),
          ),
      ],
      // No `constraints` here. On PopupMenuButton that property sizes the
      // *menu*, not the button, so the tight box used for the icon buttons
      // beside it would shrink the menu itself. The button is sized by the
      // SizedBox around it instead.
      padding: EdgeInsets.zero,
      icon: Icon(Icons.school_outlined, size: iconSize),
    ),
  );
}

/// Confirms a destructive command and collects whatever it still needs.
///
/// Returns null when the user backed out of either question, and the answers
/// otherwise — the defaults for the commands that ask nothing at all.
Future<LearningCommandAnswers?> askForLearningCommand(
  BuildContext context,
  LearningCommand command,
) async {
  if (command.isDestructive) {
    if (!await _confirmDestructive(context, command)) return null;
    if (!context.mounted) return null;
  }
  switch (command) {
    case LearningCommand.addToOutstanding:
    case LearningCommand.addAll:
      final int? everyWhich = await _promptForSpacing(context);
      return everyWhich == null
          ? null
          : LearningCommandAnswers(everyWhich: everyWhich);
    case LearningCommand.setAFactor:
      final double? value = await _promptForDouble(
        context,
        title: 'Set A',
        hint:
            'Stores the A-factor directly. It changes no interval, due '
            'date, priority, or repetition count.',
        initial: 1.10,
        min: 1.01,
        max: 3,
      );
      return value == null ? null : LearningCommandAnswers(aFactor: value);
    case LearningCommand.modifyAFactor:
      final double? multiplier = await _promptForDouble(
        context,
        title: 'Modify A',
        hint: 'Rescales A around 1.01: A = 1.01 + m × (A − 1.01).',
        initial: 1,
        min: 0.20,
        max: 2,
      );
      return multiplier == null
          ? null
          : LearningCommandAnswers(aFactorMultiplier: multiplier);
    case LearningCommand.learn:
    case LearningCommand.reviewAll:
    case LearningCommand.reviewTopics:
    case LearningCommand.remember:
    case LearningCommand.forget:
    case LearningCommand.dismiss:
    case LearningCommand.undismiss:
    case LearningCommand.done:
    case LearningCommand.addToFinalDrill:
    case LearningCommand.resetHistory:
      return const LearningCommandAnswers();
  }
}

/// Each destructive command carries its own warning, so the dialog can say
/// what this particular one discards rather than a generic "are you sure".
Future<bool> _confirmDestructive(
  BuildContext context,
  LearningCommand command,
) async {
  final bool? didConfirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('${command.label}?'),
      content: Text(command.warning),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(command.label),
        ),
      ],
    ),
  );
  return didConfirm ?? false;
}

Future<double?> _promptForDouble(
  BuildContext context, {
  required String title,
  required String hint,
  required double initial,
  required double min,
  required double max,
}) async {
  final TextEditingController controller = TextEditingController(
    text: '$initial',
  );
  try {
    return await showDialog<double>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final double? value = double.tryParse(controller.text.trim());
          final bool isValid = value != null && value >= min && value <= max;
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: dialogContentWidth(context, preferred: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      helperText: '$min–$max',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isValid
                    ? () => Navigator.of(context).pop(value)
                    : null,
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}

/// SM20's `Every which element?` prompt for batch Add to Outstanding.
///
/// The spacing is not cosmetic: section 9.7 seeds the first insertion at
/// `min(3, s)` and advances the target by `s` after each success, so it
/// decides where in the queue the selection lands. Defaulting it silently
/// would hide a choice the executable always asks for.
Future<int?> _promptForSpacing(BuildContext context) async {
  final TextEditingController controller = TextEditingController(text: '5');
  try {
    return await showDialog<int>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final int? value = int.tryParse(controller.text.trim());
          final bool isValid = value != null && value >= 1 && value <= 100;
          return AlertDialog(
            title: const Text('Every which element?'),
            content: SizedBox(
              width: dialogContentWidth(context, preferred: 340),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Spacing between insertions in the Outstanding queue. '
                    'The first lands at position min(3, s), and each further '
                    'element is placed s positions later. Every successful '
                    'insertion also multiplies that priority target by 0.9.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      helperText: '1–100',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isValid
                    ? () => Navigator.of(context).pop(value)
                    : null,
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  } finally {
    controller.dispose();
  }
}
