/// Automatic backup folder and cadence controls.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/backup_settings.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Where and how often the app mirrors its recovery backup.
class BackupSection extends StatelessWidget {
  const BackupSection({required this.state, required this.model, super.key});

  final SettingsUiState state;
  final SettingsViewModel model;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Backup',
    description:
        'The app keeps its recovery copy in private storage. Automatic backup '
        'also copies that complete collection package to the folder you '
        'choose on Windows or Android.',
    children: <Widget>[
      SettingsRow(
        label: 'Automatic backup interval',
        hint:
            'A backup is due the next time the app starts after this many '
            'study days.',
        control: ChoiceField<AutomaticBackupInterval>(
          value: state.draft.backup.interval,
          options: const <AutomaticBackupInterval, String>{
            AutomaticBackupInterval.daily: 'Each day',
            AutomaticBackupInterval.everyThreeDays: 'Each 3 days',
            AutomaticBackupInterval.weekly: 'Once per week',
          },
          onChanged: (AutomaticBackupInterval interval) => model.edit(
            (AppSettings settings) => settings.copyWith(
              backup: settings.backup.copyWith(interval: interval),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Automatic backup folder',
        hint:
            'Choose a normal folder on Windows or a document folder on '
            'Android. Android keeps permission to that folder after restart.',
        controlWidth: 360,
        control: _FolderControl(state: state, model: model),
      ),
    ],
  );
}

class _FolderControl extends StatelessWidget {
  const _FolderControl({required this.state, required this.model});

  final SettingsUiState state;
  final SettingsViewModel model;

  @override
  Widget build(BuildContext context) {
    final BackupSettings backup = state.draft.backup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          backup.hasSelectedDirectory
              ? backup.directoryLabel
              : 'App storage only',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 6,
          children: <Widget>[
            if (backup.hasSelectedDirectory)
              TextButton(
                onPressed: state.isBusy
                    ? null
                    : model.useApplicationBackupFolder,
                child: const Text('Use app storage'),
              ),
            OutlinedButton.icon(
              onPressed: state.isBusy
                  ? null
                  : model.chooseAutomaticBackupFolder,
              icon: const Icon(Icons.folder_open, size: 17),
              label: const Text('Choose folder'),
            ),
          ],
        ),
      ],
    );
  }
}
