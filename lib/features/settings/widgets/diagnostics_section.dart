/// The diagnostics section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';

/// What the app records about its own behaviour.
class DiagnosticsSection extends StatelessWidget {
  const DiagnosticsSection({
    required this.state,
    required this.model,
    super.key,
  });

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Diagnostics',
    description:
        'A record of what the scheduler did, for working out why something '
        'came back when it did. It never leaves this device, and nothing '
        'here changes your schedule.',
    children: <Widget>[
      SettingsRow(
        label: 'Write a log file',
        hint:
            'Records each scheduling decision to a rotating log file on this '
            'device.',
        control: SwitchField(
          value: draft.diagnostics.isLogEnabled,
          onChanged: (bool value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              diagnostics: settings.diagnostics.copyWith(isLogEnabled: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Rotate at',
        hint: 'How large the active log may get before a fresh one is started.',
        control: IntField(
          value: draft.diagnostics.logMaxBytes ~/ 1024,
          min: 4,
          max: 524288,
          suffix: 'KB',
          onChanged: (int value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              diagnostics: settings.diagnostics.copyWith(
                logMaxBytes: value * 1024,
              ),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Files kept',
        hint: 'How many rotated logs to keep. Older ones are deleted.',
        control: IntField(
          value: draft.diagnostics.logRetainedFiles,
          min: 1,
          max: 100,
          onChanged: (int value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              diagnostics: settings.diagnostics.copyWith(
                logRetainedFiles: value,
              ),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Show element text in panel',
        hint:
            'Off by default, so a screenshot of the diagnostics panel does '
            'not give away what you are studying.',
        control: SwitchField(
          value: draft.diagnostics.shouldShowContentInPanel,
          onChanged: (bool value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              diagnostics: settings.diagnostics.copyWith(
                shouldShowContentInPanel: value,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
