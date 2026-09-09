/// The daily-queue section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';

/// How much of the collection today's queue admits.
class QueueSection extends StatelessWidget {
  const QueueSection({required this.state, required this.model, super.key});

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Daily queue',
    description:
        'Outstanding is the day\'s work: everything that has come due. Cards '
        'and topics are each sorted by priority on their own, each shuffled '
        'by its own randomization setting, and the two are then merged at the '
        'topic percentage below. Nothing here caps the size of a day — the '
        'day is however much is genuinely due.',
    children: <Widget>[..._queueMixRows(), ..._queueBehaviorRows()],
  );

  List<Widget> _queueMixRows() => <Widget>[
    SettingsRow(
      label: 'Topics in merged queue',
      hint:
          'How much of the day is topics rather than cards. At 30%, '
          'roughly three in every ten elements you are shown is something '
          'to read. When one of the two runs out, the rest of the day is '
          'filled from the other.',
      control: DoubleSliderField(
        value: draft.queue.topicPercent.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        format: (double value) => '${value.round()}%',
        onChanged: (double value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            queue: settings.queue.copyWith(topicPercent: value.round()),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Card randomization',
      hint:
          'How far a card may drift from its place in the priority order. '
          '0 gives you the day strictly by priority; 100 is close to '
          'shuffled.',
      control: DoubleSliderField(
        value: draft.queue.itemRandomization.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        format: (double value) => '${value.round()}',
        onChanged: (double value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            queue: settings.queue.copyWith(itemRandomization: value.round()),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic randomization',
      hint:
          'The same, for topics and extracts. Some shuffling stops you '
          'meeting the same few articles in the same order every day.',
      control: DoubleSliderField(
        value: draft.queue.topicRandomization.toDouble(),
        min: 0,
        max: 100,
        divisions: 100,
        format: (double value) => '${value.round()}',
        onChanged: (double value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            queue: settings.queue.copyWith(topicRandomization: value.round()),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _queueBehaviorRows() => <Widget>[
    SettingsRow(
      label: 'Automatic daily sort',
      hint:
          'Re-sorts Outstanding by priority the first time you open the '
          'app on a new study day. Turn it off only if you would rather '
          'keep the order you left yesterday.',
      control: SwitchField(
        value: draft.queue.shouldSortAutomatically,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            queue: settings.queue.copyWith(shouldSortAutomatically: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Randomize Final Drill',
      hint:
          'The Final Drill is the short second pass over anything you '
          'failed today. Shuffling it stops you always meeting the same '
          'card first, when you are most awake.',
      control: SwitchField(
        value: draft.queue.shouldRandomizeFinalDrill,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            queue: settings.queue.copyWith(shouldRandomizeFinalDrill: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Confirm stage transitions',
      hint:
          'In a collection of more than a hundred elements, ask before the '
          'session leaves Outstanding for the Final Drill, or for pending '
          'material you have not started yet.',
      control: SwitchField(
        value: draft.queue.shouldConfirmStageTransitions,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            queue: settings.queue.copyWith(
              shouldConfirmStageTransitions: value,
            ),
          ),
        ),
      ),
    ),
  ];
}
