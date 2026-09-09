/// The card-memory section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';

/// FSRS, and the safeguards around a card's memory.
class CardMemorySection extends StatelessWidget {
  const CardMemorySection({
    required this.state,
    required this.model,
    super.key,
  });

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Card memory',
    description:
        'Cards are the question-and-answer half of a collection, and their '
        'intervals come from FSRS: when a card returns is worked out from '
        'how well you have actually been recalling it. Everything else about '
        'a card — its priority, its place in Outstanding, Smart Postpone, '
        'Mercy — works exactly as it does for a topic.',
    children: <Widget>[
      ..._cardLearningRows(),
      ..._cardSchedulingRows(),
      ..._cardSafeguardRows(),
      ..._overlapContextRows(),
    ],
  );

  List<Widget> _cardLearningRows() => <Widget>[
    SettingsRow(
      label: 'Desired retention',
      hint:
          'The share of cards you want to get right when they come back. '
          '0.90 means aiming to recall nine in ten. Asking for more means '
          'shorter intervals and more reviews every day.',
      control: DoubleSliderField(
        value: draft.cards.desiredRetention,
        min: 0.70,
        max: 0.99,
        divisions: 29,
        onChanged: (double value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(desiredRetention: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Learning steps',
      hint:
          'The intervals, in minutes, a brand-new card goes through before '
          'it joins the normal FSRS schedule. "1, 10" shows it again after '
          'a minute, then after ten. Leave empty to use FSRS directly.',
      control: IntListField(
        values: draft.cards.learningStepMinutes,
        onChanged: (List<int> value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(learningStepMinutes: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Relearning steps',
      hint:
          'The intervals, in minutes, a card goes back through after a '
          'lapse. Leave empty to use FSRS directly.',
      control: IntListField(
        values: draft.cards.relearningStepMinutes,
        onChanged: (List<int> value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(relearningStepMinutes: value),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _cardSchedulingRows() => <Widget>[
    SettingsRow(
      label: 'Maximum card interval',
      hint:
          'However well you know a card, FSRS never schedules it further '
          'ahead than this.',
      control: IntField(
        value: draft.cards.maximumIntervalDays,
        min: 1,
        max: 36500,
        suffix: 'd',
        onChanged: (int value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(maximumIntervalDays: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Fuzz card intervals',
      hint:
          'Nudges each interval by a day or so at random, so cards you '
          'made on the same afternoon do not come back together for ever.',
      control: SwitchField(
        value: draft.cards.isFuzzingEnabled,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(isFuzzingEnabled: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Reschedule after FSRS changes',
      hint:
          'Immediately updates existing review-card due dates when desired '
          'retention, fuzzing, or the maximum interval changes. Overdue and '
          'in-progress learning cards are left where they are.',
      control: SwitchField(
        value: draft.cards.shouldRescheduleAfterSettingsChange,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(
              shouldRescheduleAfterSettingsChange: value,
            ),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _cardSafeguardRows() => <Widget>[
    SettingsRow(
      label: 'Leech lapse threshold',
      hint:
          'How many lapses before a card is flagged as a leech. A leech is '
          'surfaced for you to rewrite, never suspended: most cards that '
          'fail repeatedly are badly written rather than hard, and hiding '
          'one hides the evidence.',
      control: IntField(
        value: draft.cards.leechLapses,
        min: 1,
        max: 999,
        onChanged: (int value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(leechLapses: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Bury card siblings',
      hint:
          'Cards made from the same passage are not shown on the same '
          'study day, so one does not give away the answer to another.',
      control: SwitchField(
        value: draft.cards.shouldBurySiblings,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(shouldBurySiblings: value),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _overlapContextRows() => <Widget>[
    SettingsRow(
      label: 'Overlap context before',
      hint:
          'How many earlier list items a new Cloze Overlapper reveals. '
          'Use -1 to reveal every earlier item.',
      control: IntField(
        value: draft.cards.overlapContextBefore,
        min: -1,
        max: 99,
        onChanged: (int value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(overlapContextBefore: value),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Overlap context after',
      hint:
          'How many later list items a new Cloze Overlapper reveals. '
          'Use -1 to reveal every later item.',
      control: IntField(
        value: draft.cards.overlapContextAfter,
        min: -1,
        max: 99,
        onChanged: (int value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            cards: settings.cards.copyWith(overlapContextAfter: value),
          ),
        ),
      ),
    ),
  ];
}
