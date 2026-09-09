/// The study-day section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';

/// When one study day ends and the next begins.
class StudyDaySection extends StatelessWidget {
  const StudyDaySection({required this.state, required this.model, super.key});

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Study day',
    description:
        'The scheduler follows this device\'s timezone. Day rollover decides '
        'when one study day ends and the next begins, so a late-night session '
        'can still count as the day you started it.',
    children: <Widget>[
      SettingsRow(
        label: 'Day rollover',
        hint:
            'How long after midnight Today moves on to the next study day. '
            'Set it to 180 if you often study until three in the morning and '
            'want that to still count as the night before.',
        control: IntField(
          value: draft.studyDay.rolloverMinutes,
          min: 0,
          max: 1439,
          suffix: 'min',
          onChanged: (int value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              studyDay: settings.studyDay.copyWith(rolloverMinutes: value),
            ),
          ),
        ),
      ),
    ],
  );
}
