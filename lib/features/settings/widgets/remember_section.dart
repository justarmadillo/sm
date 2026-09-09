/// The Remember section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';

/// What a newly remembered element starts out with.
class RememberSection extends StatelessWidget {
  const RememberSection({required this.state, required this.model, super.key});

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Remember',
    description:
        'Remember is the command that starts scheduling a topic. It has to '
        'choose how long to wait before showing that topic to you again, and '
        'it picks that first interval from the range below.',
    children: <Widget>[
      SettingsRow(
        label: 'First interval — low',
        hint: 'The shortest first interval, in days.',
        control: IntField(
          value: draft.remember.firstIntervalLowDays,
          min: 1,
          max: 365,
          suffix: 'd',
          onChanged: (int value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              remember: settings.remember.copyWith(firstIntervalLowDays: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'First interval — high',
        hint:
            'The longest first interval, in days. Set it equal to the low '
            'value for a fixed interval, or to 0 to let the topic scheduler '
            'work the first interval out itself.',
        control: IntField(
          value: draft.remember.firstIntervalHighDays,
          min: 0,
          max: 365,
          suffix: 'd',
          onChanged: (int value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              remember: settings.remember.copyWith(
                firstIntervalHighDays: value,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
