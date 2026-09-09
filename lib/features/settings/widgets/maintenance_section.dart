/// The maintenance section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';

/// Repairing and compacting the collection.
class MaintenanceSection extends StatelessWidget {
  const MaintenanceSection({
    required this.state,
    required this.model,
    super.key,
  });

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Maintenance',
    description:
        'Housekeeping on the database file your collection lives in. These '
        'change how it is stored, never what it holds, and never a schedule.',
    children: <Widget>[
      SettingsRow(
        label: 'Check database',
        hint:
            'Checks physical integrity and repairs broken relationships in one '
            'transaction. Historical logs are reported but never deleted.',
        control: FilledButton.tonal(
          onPressed: state.isBusy ? null : model.checkDatabase,
          child: Text(
            state.activeOperation == SettingsOperation.checkingDatabase
                ? 'Checking…'
                : 'Check now',
          ),
        ),
      ),
      SettingsRow(
        label: 'Optimize database',
        hint:
            'Checks the collection for damage, rebuilds the search index if '
            'it has drifted, and hands back the space freed by anything you '
            'have deleted. Safe to run at any time; a large collection takes '
            'a moment.',
        control: _OptimizeButton(
          isDisabled: state.isBusy,
          isOptimizing:
              state.activeOperation == SettingsOperation.optimizingDatabase,
          model: model,
        ),
        controlWidth: 220,
      ),
    ],
  );
}

/// The Optimize control, which is a button until it is a progress indicator.
///
/// The pass rewrites the whole database file, so on a large collection it is
/// slow enough that a button which merely greyed out would read as broken.
class _OptimizeButton extends StatelessWidget {
  const _OptimizeButton({
    required this.isDisabled,
    required this.isOptimizing,
    required this.model,
  });

  final bool isDisabled;
  final bool isOptimizing;
  final SettingsViewModel model;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      if (isOptimizing) ...<Widget>[
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
      ],
      FilledButton.tonal(
        onPressed: isDisabled ? null : model.optimizeDatabase,
        child: Text(isOptimizing ? 'Optimizing…' : 'Optimize now'),
      ),
    ],
  );
}
