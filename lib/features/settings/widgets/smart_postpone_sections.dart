/// The three Smart Postpone sections of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';

/// What the three Smart Postpone sections have in common.
///
/// They edit one profile between them, so the getter that reaches it and the
/// helper that writes it back belong in one place: three copies of
/// [editSmartPostpone] is three chances for one of them to write to a
/// different profile than the row above it.
abstract class _SmartPostponeSection extends StatelessWidget {
  const _SmartPostponeSection({
    required this.state,
    required this.model,
    super.key,
  });

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;
  SmartPostponeSettings get smart => draft.postpone.defaultProfile;

  /// Replaces the default profile with [change] applied to it.
  void editSmartPostpone(
    SmartPostponeSettings Function(SmartPostponeSettings current) change,
  ) {
    model.edit(
      (AppSettings settings) => settings.copyWith(
        postpone: settings.postpone.copyWith(
          defaultProfile: change(settings.postpone.defaultProfile),
        ),
      ),
    );
  }
}

/// Which elements a postpone pass may touch.
class SmartPostponeScopeSection extends _SmartPostponeSection {
  const SmartPostponeScopeSection({
    required super.state,
    required super.model,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Smart Postpone — scope',
    description:
        'When a day is bigger than you can finish, Smart Postpone pushes '
        'part of it into the future — lowest priority and easiest first, so '
        'what you have invested most in stays where it is. This panel says '
        'which elements a run is allowed to look at. The automatic run '
        'happens at most once a day, and only when you really are behind.',
    children: <Widget>[
      ..._automaticPostponeRows(),
      ..._smartPostponeTargetRows(),
      ..._smartPostponeSelectionRows(),
    ],
  );

  List<Widget> _automaticPostponeRows() => <Widget>[
    SettingsRow(
      label: 'Automatic postponement',
      hint:
          'Allows the once-a-day automatic run, which always uses the '
          'profile named Default.',
      control: SwitchField(
        value: draft.postpone.isAutomaticPostponeEnabled,
        onChanged: (bool value) => model.edit(
          (AppSettings settings) => settings.copyWith(
            postpone: settings.postpone.copyWith(
              isAutomaticPostponeEnabled: value,
            ),
          ),
        ),
      ),
    ),
    SettingsRow(
      label: 'Profile name',
      hint:
          'A name for the profile these fields are editing. The automatic '
          'run always loads the one called Default.',
      control: StringField(
        value: smart.profileName,
        onChanged: (String value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(profileName: value),
        ),
      ),
    ),
  ];

  List<Widget> _smartPostponeTargetRows() => <Widget>[
    SettingsRow(
      label: 'Scope',
      hint:
          'All Outstanding is everything due today. A branch is one '
          'article together with every extract and card that came out of '
          'it. Current browser is whatever the priority queue happens to '
          'be showing right now.',
      control: ChoiceField<SmartPostponeScope>(
        value: smart.scope,
        options: const <SmartPostponeScope, String>{
          SmartPostponeScope.global: 'All Outstanding',
          SmartPostponeScope.branch: 'Branch or concept',
          SmartPostponeScope.browser: 'Current browser',
        },
        onChanged: (SmartPostponeScope value) => editSmartPostpone(
          (SmartPostponeSettings settings) => settings.copyWith(scope: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Branch root element',
      hint:
          'The element id of the article at the top of the branch. Used '
          'only when Scope is set to a branch.',
      control: IntField(
        value: smart.rootElementId,
        min: 0,
        max: 0xFFFFFFFF,
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(rootElementId: value),
        ),
      ),
    ),
  ];

  List<Widget> _smartPostponeSelectionRows() => <Widget>[
    SettingsRow(
      label: 'Selection method',
      hint:
          'Protect top count keeps a fixed number of your highest-priority '
          'elements untouched whatever else happens. Parameters only '
          'decides purely from the cutoffs on the next panel.',
      control: ChoiceField<SmartPostponeMethod>(
        value: smart.method,
        options: const <SmartPostponeMethod, String>{
          SmartPostponeMethod.topCount: 'Protect top count',
          SmartPostponeMethod.parameters: 'Parameters only',
        },
        onChanged: (SmartPostponeMethod value) => editSmartPostpone(
          (SmartPostponeSettings settings) => settings.copyWith(method: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Protected top count',
      hint:
          'How many of the highest-priority elements are left exactly '
          'where they are. Used only when the method above protects them.',
      control: IntField(
        value: smart.protectedCount,
        min: 1,
        max: 20000,
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(protectedCount: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Simulate',
      hint:
          'Works the whole run out and reports what it would move, without '
          'changing a single due date.',
      control: SwitchField(
        value: smart.isSimulationOnly,
        onChanged: (bool value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(isSimulationOnly: value),
        ),
      ),
    ),
  ];
}

/// How far a postpone pass moves what it picks.
class SmartPostponeParametersSection extends _SmartPostponeSection {
  const SmartPostponeParametersSection({
    required super.state,
    required super.model,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Smart Postpone — parameters',
    description:
        'How much later an element goes when it is postponed, and which '
        'elements are spared entirely. A delay factor adds that share of the '
        'interval the element already had: at 20%, something due in ten days '
        'moves to twelve. The minimum and maximum clamp the days added, not '
        'the final interval.',
    children: <Widget>[
      ..._smartPostponeFactorRows(),
      ..._smartPostponeDelayLimitRows(),
      ..._smartPostponeTypeExclusionRows(),
      ..._smartPostponeRecallLimitRows(),
      ..._smartPostponeHistoryPriorityRows(),
    ],
  );

  List<Widget> _smartPostponeFactorRows() => <Widget>[
    SettingsRow(
      label: 'Card delay factor',
      hint:
          'A share of the interval the card already had. At 20%, a card on '
          'a ten-day interval moves two days later.',
      control: IntField(
        value: smart.itemDelayPercent,
        min: 1,
        max: 400,
        suffix: '%',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemDelayPercent: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic delay factor',
      hint:
          'The same, for topics and extracts. Reading tolerates a far '
          'larger delay than a card does, which is why it can go so high.',
      control: IntField(
        value: smart.topicDelayPercent,
        min: 1,
        max: 1900,
        suffix: '%',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicDelayPercent: value),
        ),
      ),
    ),
  ];

  List<Widget> _smartPostponeDelayLimitRows() => <Widget>[
    SettingsRow(
      label: 'Card maximum added delay',
      hint:
          'A ceiling on the days added, so no card vanishes for months in '
          'a single pass.',
      control: IntField(
        value: smart.itemMaximumDelayDays,
        min: 1,
        max: 300,
        suffix: 'd',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemMaximumDelayDays: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic maximum added delay',
      hint: 'The same ceiling, for topics and extracts.',
      control: IntField(
        value: smart.topicMaximumDelayDays,
        min: 1,
        max: 500,
        suffix: 'd',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicMaximumDelayDays: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Card minimum added delay',
      hint:
          'If a card is worth postponing at all, move it at least this far '
          '— otherwise it is back tomorrow and nothing was relieved.',
      control: IntField(
        value: smart.itemMinimumDelayDays,
        min: 1,
        max: 30,
        suffix: 'd',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemMinimumDelayDays: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic minimum added delay',
      hint: 'The same floor, for topics and extracts.',
      control: IntField(
        value: smart.topicMinimumDelayDays,
        min: 1,
        max: 100,
        suffix: 'd',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicMinimumDelayDays: value),
        ),
      ),
    ),
  ];

  List<Widget> _smartPostponeTypeExclusionRows() => <Widget>[
    SettingsRow(
      label: 'Skip all cards',
      hint: 'Leaves every card where it is, and postpones only topics.',
      control: SwitchField(
        value: smart.shouldSkipItems,
        onChanged: (bool value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(shouldSkipItems: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Skip all topics',
      hint:
          'Leaves every topic and extract where it is, and postpones only '
          'cards.',
      control: SwitchField(
        value: smart.shouldSkipTopics,
        onChanged: (bool value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(shouldSkipTopics: value),
        ),
      ),
    ),
  ];

  List<Widget> _smartPostponeRecallLimitRows() => <Widget>[
    SettingsRow(
      label: 'Card interval cutoff',
      hint:
          'A card already on an interval this long or longer is left '
          'alone: it is not what is making today heavy.',
      control: IntField(
        value: smart.itemAgeCutoffDays,
        min: 2,
        max: 4000,
        suffix: 'd',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemAgeCutoffDays: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic interval cutoff',
      hint: 'The same, for topics and extracts.',
      control: IntField(
        value: smart.topicAgeCutoffDays,
        min: 2,
        max: 4000,
        suffix: 'd',
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicAgeCutoffDays: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Skip cards you still recall',
      hint:
          'The number is a forgetting index: your chance of failing the '
          'card, out of a hundred, read off its FSRS retrievability. At 6, '
          'any card you would still recall more than 94 times in a hundred '
          'is left where it is.',
      control: IntField(
        value: smart.itemForgettingIndexCutoff,
        min: 3,
        max: 20,
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemForgettingIndexCutoff: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic A-factor floor',
      hint:
          'A topic\'s A-factor is how fast its intervals grow. Anything at '
          'or below this grows slowly already, so postponing it gains '
          'little. 1.01 is the slowest an A-factor goes.',
      control: DoubleField(
        value: smart.topicAFactorCutoff,
        min: 1.01,
        max: 6,
        onChanged: (double value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicAFactorCutoff: value),
        ),
      ),
    ),
  ];

  List<Widget> _smartPostponeHistoryPriorityRows() => <Widget>[
    SettingsRow(
      label: 'Card postponement-count cutoff',
      hint:
          'A card already postponed this many times in total is left alone '
          'from now on.',
      control: IntField(
        value: smart.itemPostponeCountCutoff,
        min: 1,
        max: 255,
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemPostponeCountCutoff: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic postponement-count cutoff',
      hint:
          'The same, for topics and extracts. It stops an article being '
          'quietly pushed out of your life a fortnight at a time.',
      control: IntField(
        value: smart.topicPostponeCountCutoff,
        min: 1,
        max: 255,
        onChanged: (int value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicPostponeCountCutoff: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Card priority threshold',
      hint:
          'Priority runs from 1%, the very top of your collection, down to '
          '100%. A card of higher priority than this is never postponed.',
      control: DoubleField(
        value: smart.itemPriorityThreshold,
        min: 0.01,
        max: 100,
        suffix: '%',
        onChanged: (double value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(itemPriorityThreshold: value),
        ),
      ),
    ),
    SettingsRow(
      label: 'Topic priority threshold',
      hint:
          'The same line, for topics and extracts. It can be set finer '
          'because there is usually far more reading than there are cards.',
      control: DoubleField(
        value: smart.topicPriorityThreshold,
        min: 0.0001,
        max: 100,
        suffix: '%',
        onChanged: (double value) => editSmartPostpone(
          (SmartPostponeSettings settings) =>
              settings.copyWith(topicPriorityThreshold: value),
        ),
      ),
    ),
  ];
}

/// The A-factor and forgetting-index nudges.
class SmartPostponeAdjustSection extends _SmartPostponeSection {
  const SmartPostponeAdjustSection({
    required super.state,
    required super.model,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Smart Postpone — adjust',
    description:
        'Settings you are unlikely to need. The last two are kept only so a '
        'collection brought in from SuperMemo goes back out unchanged; '
        'nothing here reads them.',
    children: <Widget>[
      SettingsRow(
        label: 'Sub-branch profiles',
        hint:
            'A branch can carry its own Smart Postpone profile. This decides '
            'what happens when one run covers several nested branches: obey '
            'each profile exactly, ignore them all, or merge them and take '
            'the setting that postpones the least — or the most.',
        control: ChoiceField<SmartPostponeSubbranchMode>(
          value: smart.subbranchMode,
          options: const <SmartPostponeSubbranchMode, String>{
            SmartPostponeSubbranchMode.respect: 'Respect',
            SmartPostponeSubbranchMode.ignore: 'Ignore',
            SmartPostponeSubbranchMode.conservative: 'Most conservative',
            SmartPostponeSubbranchMode.liberal: 'Most liberal',
          },
          onChanged: (SmartPostponeSubbranchMode value) => editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(subbranchMode: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Include non-Outstanding elements',
        hint:
            'Normally only elements in Outstanding can be postponed. This '
            'lets a run you start yourself reach further, pending material '
            'you have not begun included.',
        control: SwitchField(
          value: smart.shouldIncludeNonOutstanding,
          onChanged: (bool value) => editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(shouldIncludeNonOutstanding: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Modify card delay by forgetting index',
        hint:
            'Kept so an imported collection is preserved exactly. It changes '
            'no delay here.',
        control: SwitchField(
          value: smart.shouldModifyItemByForgettingIndex,
          onChanged: (bool value) => editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(shouldModifyItemByForgettingIndex: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Modify topic delay by A-factor',
        hint:
            'Kept so an imported collection is preserved exactly. It changes '
            'no delay here either.',
        control: SwitchField(
          value: smart.shouldModifyTopicByAFactor,
          onChanged: (bool value) => editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(shouldModifyTopicByAFactor: value),
          ),
        ),
      ),
    ],
  );
}
