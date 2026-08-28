/// The Smart Postpone simulation report and its confirmation.
///
/// Every entry point simulates first and shows this dialog, so the list the
/// user approves is the engine's own decision set rather than a second
/// estimate that could disagree with what the real run writes.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/scheduling/postpone/sm20_postpone.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Shows [result] and answers whether the user wants it applied.
///
/// An empty decision set is reported rather than silently doing nothing: a
/// profile whose cutoffs rejected the whole population is a configuration
/// answer, not a failure.
Future<bool> confirmSmartPostpone(
  BuildContext context,
  SmartPostponeResult result,
) async {
  if (result.decisions.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Nothing to postpone'),
        content: Text(
          'None of the ${result.sourceOrder.length} source element'
          '${result.sourceOrder.length == 1 ? '' : 's'} passed the '
          '${result.profile.profileName} profile’s cutoffs.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    return false;
  }

  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => _SmartPostponeDialog(result: result),
      ) ??
      false;
}

class _SmartPostponeDialog extends StatelessWidget {
  const _SmartPostponeDialog({required this.result});

  final SmartPostponeResult result;

  @override
  Widget build(BuildContext context) {
    final int warnings = result.warningCount;
    return AlertDialog(
      title: const Text('Apply Smart Postpone?'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${result.postponed.length} of ${result.sourceOrder.length} '
              'element${result.sourceOrder.length == 1 ? '' : 's'} move; '
              '${result.unpostponed.length} stay.',
            ),
            const SizedBox(height: 6),
            Text(
              'Profile ${result.profile.profileName}, scope '
              '${result.profile.scope.name}. '
              '${result.wasStoppedAtProtectedCount ? 'The protected count stopped the pass. ' : ''}'
              '${result.didForcedPassRun ? 'A forced pass ran to reach the requested count. ' : ''}'
              'This performs no repetitions: A-factors, priority, repetition '
              'counts, and lapses are left untouched.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (warnings > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '$warnings element${warnings == 1 ? ' moves' : 's move'} more '
                'than 200 days away.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Proposed moves:'),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final SmartPostponeDecision decision
                        in result.decisions)
                      Text(
                        '${decision.ref.type.name} ${decision.ref.id}  —  '
                        '+${decision.delayDays}d to ${decision.targetDay}'
                        '${decision.warnsAboveTwoHundredDays ? '  (long)' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Postpone'),
        ),
      ],
    );
  }
}
