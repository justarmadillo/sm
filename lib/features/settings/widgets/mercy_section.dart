/// The Mercy section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';

/// How Mercy chooses what to move, and how far.
class MercySection extends StatelessWidget {
  const MercySection({required this.state, required this.model, super.key});

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Mercy',
    description:
        'Mercy is the larger rescue. Where Smart Postpone shifts part of a '
        'heavy day, Mercy takes everything that has piled up, scores it, and '
        'spreads it evenly across the days ahead — keeping the highest '
        'priority and the most heavily invested nearest to now.',
    children: <Widget>[
      ..._mercyRangeRows(),
      ..._mercyCapacityRows(),
      ..._mercyWeightRows(),
    ],
  );

  List<Widget> _mercyRangeRows() => <Widget>[
    SettingsRow(
      label: 'Candidate order',
      hint:
          'Mercy scores every candidate out of the five weights below. '
          'This is the order it then works through them in, and so which '
          'of them land on the nearest days.',
      control: ChoiceField<MercyMode>(
        value: draft.mercy.mode,
        options: const <MercyMode, String>{
          MercyMode.highScoreFirst: 'High score first',
          MercyMode.lowScoreFirst: 'Low score first',
          MercyMode.sourceOrder: 'Source order',
          MercyMode.random: 'Fixed-size random',
        },
        onChanged: (MercyMode value) => model.edit(
          (AppSettings settings) =>
              settings.copyWith(mercy: settings.mercy.copyWith(mode: value)),
        ),
      ),
    ),
    SettingsRow(
      label: 'Rescheduling horizon',
      hint: 'How many days ahead the backlog is spread across.',
      control: IntField(
        value: draft.mercy.reschedulingDays,
        min: 1,
        max: 3650,
        suffix: 'd',
        onChanged: (int value) => model.edit((AppSettings settings) {
          final MercySettings mercy = settings.mercy;
          return settings.copyWith(
            mercy: mercy.copyWith(
              reschedulingDays: value,
              gatheringDays: mercy.shouldIncludeFuture
                  ? mercy.gatheringDays.clamp(value, 3650)
                  : value,
            ),
          );
        }),
      ),
    ),
    SettingsRow(
      label: 'Gathering horizon',
      hint:
          'How far ahead to look for candidates to include. Never smaller '
          'than the rescheduling horizon.',
      control: IntField(
        value: draft.mercy.gatheringDays,
        min: 1,
        max: 3650,
        suffix: 'd',
        onChanged: (int value) => model.edit((AppSettings settings) {
          final MercySettings mercy = settings.mercy;
          return settings.copyWith(
            mercy: mercy.copyWith(
              gatheringDays: mercy.shouldIncludeFuture
                  ? value.clamp(mercy.reschedulingDays, 3650)
                  : mercy.reschedulingDays,
            ),
          );
        }),
      ),
    ),
  ];

  List<Widget> _mercyCapacityRows() => <Widget>[
    SettingsRow(
      label: 'Elements per day',
      hint:
          'The most Mercy will place on any one day while it spreads the '
          'backlog out.',
      control: IntField(
        value: draft.mercy.dailyCap,
        min: 1,
        max: 5000,
        onChanged: (int value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            mercy: settings.mercy.copyWith(dailyCap: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Include future schedule',
      hint:
          'Turning this off keeps Mercy to what is already overdue, and it '
          'then gathers from exactly the days it reschedules across.',
      control: SwitchField(
        value: draft.mercy.shouldIncludeFuture,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            mercy: settings.mercy.copyWith(
              shouldIncludeFuture: value,
              gatheringDays: value
                  ? settings.mercy.gatheringDays.clamp(
                      settings.mercy.reschedulingDays,
                      3650,
                    )
                  : settings.mercy.reschedulingDays,
            ),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _mercyWeightRows() => <Widget>[
    _mercyWeight(
      label: 'Importance weight',
      hint:
          'How much an element\'s priority pulls it towards the nearest '
          'days. The heaviest of the five by default, at 10 against the '
          'others’ 1 to 4.',
      value: draft.mercy.importanceWeight,
      change: (MercySettings mercy, double value) =>
          mercy.copyWith(importanceWeight: value),
    ),
    _mercyWeight(
      label: 'Lateness weight',
      hint:
          'How much being overdue counts, judged against how long the '
          'element was meant to wait. Default 3.',
      value: draft.mercy.latenessWeight,
      change: (MercySettings mercy, double value) =>
          mercy.copyWith(latenessWeight: value),
    ),
    _mercyWeight(
      label: 'Investment weight',
      hint:
          'How much the repetitions already done count, so that what you '
          'have nearly learnt is not what slips. Default 4.',
      value: draft.mercy.investmentWeight,
      change: (MercySettings mercy, double value) =>
          mercy.copyWith(investmentWeight: value),
    ),
    _mercyWeight(
      label: 'Easiness weight',
      hint:
          'How much an element being easy for you counts, read off its '
          'lapses. Default 1.',
      value: draft.mercy.easinessWeight,
      change: (MercySettings mercy, double value) =>
          mercy.copyWith(easinessWeight: value),
    ),
    _mercyWeight(
      label: 'Recency weight',
      hint: 'How much having seen the element lately counts. Default 1.',
      value: draft.mercy.recencyWeight,
      change: (MercySettings mercy, double value) =>
          mercy.copyWith(recencyWeight: value),
    ),
  ];

  Widget _mercyWeight({
    required String label,
    required String hint,
    required double value,
    required MercySettings Function(MercySettings mercy, double value) change,
  }) => SettingsRow(
    label: label,
    hint: hint,
    control: DoubleField(
      value: value,
      min: 0,
      max: 1000000,
      onChanged: (double next) => model.edit(
        (AppSettings settings) =>
            settings.copyWith(mercy: change(settings.mercy, next)),
      ),
    ),
  );
}
