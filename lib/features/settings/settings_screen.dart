/// Settings for the scheduler and the application's own preferences.
///
/// Two different things were being confused here, so the rule is worth
/// stating. The **names** are the domain's own: A-factor, FSRS, priority,
/// Outstanding, Final Drill, Mercy, Smart Postpone, Optimize database. They
/// stay exactly as they are, because they are the names of real things and
/// renaming them would only leave the user unable to look anything up.
///
/// What does not belong on screen is the **implementation** behind them: the
/// PRNG, the evaluator, dispersion passes, record layouts, UInt16 widths,
/// section numbers, and formulas. Every explanation here says what the
/// setting does to the user's day, in a sentence they can act on, and names
/// the domain word while it does it. Keep both halves when adding a row.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:incremental_reader/settings/postpone_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/shared/ui/desktop_scroll_view.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';
import 'package:incremental_reader/storage/platform/time_zones.dart';

/// Opens Settings.
Future<void> openSettings(BuildContext context, WidgetRef ref) async {
  ref.invalidate(settingsViewModelProvider);
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const SettingsScreen(),
    ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SettingsUiState> state = ref.watch(
      settingsViewModelProvider,
    );
    final SettingsViewModel model = ref.read(
      settingsViewModelProvider.notifier,
    );

    ref.listen<AsyncValue<SettingsUiState>>(settingsViewModelProvider, (
      AsyncValue<SettingsUiState>? previous,
      AsyncValue<SettingsUiState> next,
    ) {
      final message = next.valueOrNull?.message;
      if (message == null) return;
      showToast(context, message.text, isError: message.isError);
      model.shouldClearMessage();
    });

    final SettingsUiState? data = state.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Save is the one that has to stay reachable; the two ways of throwing
        // an edit away move into a menu when the bar runs out of room.
        actions: <Widget>[
          if (isCompactWidth(context))
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onSelected: (String action) {
                switch (action) {
                  case 'defaults':
                    model.loadDefaults();
                  case 'discard':
                    model.revert();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'defaults',
                  enabled: data != null && !data.isBusy,
                  child: const Text('Restore defaults'),
                ),
                PopupMenuItem<String>(
                  value: 'discard',
                  enabled: data != null && data.isDirty,
                  child: const Text('Discard'),
                ),
              ],
            )
          else ...<Widget>[
            TextButton(
              onPressed: data == null || data.isBusy
                  ? null
                  : model.loadDefaults,
              child: const Text('Restore defaults'),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: data == null || !data.isDirty ? null : model.revert,
              child: const Text('Discard'),
            ),
            const SizedBox(width: 6),
          ],
          FilledButton(
            onPressed: data == null || !data.isDirty || data.isBusy
                ? null
                : model.save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text('Could not load settings.\n$error')),
        data: (SettingsUiState settings) =>
            _SettingsBody(state: settings, model: model),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.state, required this.model});

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;
  SmartPostponeSettings get smart => draft.postpone.defaultProfile;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: DesktopListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        children: <Widget>[
          _studyDay(),
          _queue(),
          _remember(),
          _cards(),
          _smartPostponeScope(),
          _smartPostponeParameters(),
          _smartPostponeAdjust(),
          _ProfileRegistry(draft: draft, model: model),
          _mercy(),
          _maintenance(),
          _diagnostics(),
        ],
      ),
    ),
  );

  void _editSmartPostpone(
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

  Widget _studyDay() => SettingsSection(
    title: 'Study day',
    description:
        'The scheduler counts in whole days. These two settings decide when '
        'one study day ends and the next begins, so a session that runs past '
        'midnight still counts as the day you started it.',
    children: <Widget>[
      SettingsRow(
        label: 'Home timezone',
        hint:
            'Where you normally study. It decides which study day a review '
            'counts towards, and keeps that count right when the clocks '
            'change.',
        control: ChoiceField<String>(
          value: _displayZoneId(draft.studyDay.zoneId),
          options: <String, String>{
            if (!selectableZoneIds.contains(
              _displayZoneId(draft.studyDay.zoneId),
            ))
              _displayZoneId(draft.studyDay.zoneId):
                  '${draft.studyDay.zoneId} (not offered here)',
            for (final String id in selectableZoneIds) id: id,
          },
          onChanged: (String value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              studyDay: settings.studyDay.copyWith(zoneId: value),
            ),
          ),
        ),
      ),
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

  String _displayZoneId(String storedId) {
    try {
      return canonicalTimeZoneId(storedId);
    } on UnknownTimeZoneException {
      return storedId;
    }
  }

  Widget _queue() => SettingsSection(
    title: 'Daily queue',
    description:
        'Outstanding is the day\'s work: everything that has come due. Cards '
        'and topics are each sorted by priority on their own, each shuffled '
        'by its own randomization setting, and the two are then merged at the '
        'topic percentage below. Nothing here caps the size of a day — the '
        'day is however much is genuinely due.',
    children: <Widget>[
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
    ],
  );

  Widget _remember() => SettingsSection(
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

  Widget _cards() => SettingsSection(
    title: 'Card memory',
    description:
        'Cards are the question-and-answer half of a collection, and their '
        'intervals come from FSRS: when a card returns is worked out from '
        'how well you have actually been recalling it. Everything else about '
        'a card — its priority, its place in Outstanding, Smart Postpone, '
        'Mercy — works exactly as it does for a topic.',
    children: <Widget>[
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
            'a minute, then after ten.',
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
            'lapse.',
        control: IntListField(
          values: draft.cards.relearningStepMinutes,
          onChanged: (List<int> value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              cards: settings.cards.copyWith(relearningStepMinutes: value),
            ),
          ),
        ),
      ),
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
    ],
  );

  Widget _smartPostponeScope() => SettingsSection(
    title: 'Smart Postpone — scope',
    description:
        'When a day is bigger than you can finish, Smart Postpone pushes '
        'part of it into the future — lowest priority and easiest first, so '
        'what you have invested most in stays where it is. This panel says '
        'which elements a run is allowed to look at. The automatic run '
        'happens at most once a day, and only when you really are behind.',
    children: <Widget>[
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
          onChanged: (String value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(profileName: value),
          ),
        ),
      ),
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
          onChanged: (SmartPostponeScope value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(rootElementId: value),
          ),
        ),
      ),
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
          onChanged: (SmartPostponeMethod value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(method: value),
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (bool value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(isSimulationOnly: value),
          ),
        ),
      ),
    ],
  );

  Widget _smartPostponeParameters() => SettingsSection(
    title: 'Smart Postpone — parameters',
    description:
        'How much later an element goes when it is postponed, and which '
        'elements are spared entirely. A delay factor adds that share of the '
        'interval the element already had: at 20%, something due in ten days '
        'moves to twelve. The minimum and maximum clamp the days added, not '
        'the final interval.',
    children: <Widget>[
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(topicDelayPercent: value),
          ),
        ),
      ),
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(topicMinimumDelayDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Skip all cards',
        hint: 'Leaves every card where it is, and postpones only topics.',
        control: SwitchField(
          value: smart.shouldSkipItems,
          onChanged: (bool value) => _editSmartPostpone(
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
          onChanged: (bool value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(shouldSkipTopics: value),
          ),
        ),
      ),
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (double value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(topicAFactorCutoff: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Card postponement-count cutoff',
        hint:
            'A card already postponed this many times in total is left alone '
            'from now on.',
        control: IntField(
          value: smart.itemPostponeCountCutoff,
          min: 1,
          max: 255,
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (int value) => _editSmartPostpone(
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
          onChanged: (double value) => _editSmartPostpone(
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
          onChanged: (double value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(topicPriorityThreshold: value),
          ),
        ),
      ),
    ],
  );

  Widget _smartPostponeAdjust() => SettingsSection(
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
          onChanged: (SmartPostponeSubbranchMode value) => _editSmartPostpone(
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
          onChanged: (bool value) => _editSmartPostpone(
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
          onChanged: (bool value) => _editSmartPostpone(
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
          onChanged: (bool value) => _editSmartPostpone(
            (SmartPostponeSettings settings) =>
                settings.copyWith(shouldModifyTopicByAFactor: value),
          ),
        ),
      ),
    ],
  );

  Widget _mercy() => SettingsSection(
    title: 'Mercy',
    description:
        'Mercy is the larger rescue. Where Smart Postpone shifts part of a '
        'heavy day, Mercy takes everything that has piled up, scores it, and '
        'spreads it evenly across the days ahead — keeping the highest '
        'priority and the most heavily invested nearest to now.',
    children: <Widget>[
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
      SettingsRow(
        label: 'Interval-factor matrix',
        hint:
            'An optional 20×20 table of interval factors imported from '
            'SuperMemo, describing how intervals grow in your own '
            'collection. Mercy reads it to judge how much work an element '
            'has had. Leave it empty unless you have one to paste in.',
        controlWidth: 390,
        control: UInt16MatrixField(
          value: draft.mercy.intervalFactorMatrix,
          onChanged: (List<int>? value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              mercy: settings.mercy.copyWith(intervalFactorMatrix: value),
            ),
          ),
        ),
      ),
    ],
  );

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

  Widget _maintenance() => SettingsSection(
    title: 'Maintenance',
    description:
        'Housekeeping on the database file your collection lives in. These '
        'change how it is stored, never what it holds, and never a schedule.',
    children: <Widget>[
      SettingsRow(
        label: 'Optimize database',
        hint:
            'Checks the collection for damage, rebuilds the search index if '
            'it has drifted, and hands back the space freed by anything you '
            'have deleted. Safe to run at any time; a large collection takes '
            'a moment.',
        control: _OptimizeButton(isBusy: state.isBusy, model: model),
      ),
    ],
  );

  Widget _diagnostics() => SettingsSection(
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

/// Save, load, delete, and assign controls for the managed profile registry.
///
/// The fields edited above are one working profile. This section is what
/// gives that profile a name, hands it to a branch, or puts it back into the
/// permanent Default slot the automatic run reads.
class _ProfileRegistry extends StatefulWidget {
  const _ProfileRegistry({required this.draft, required this.model});

  final AppSettings draft;
  final SettingsViewModel model;

  @override
  State<_ProfileRegistry> createState() => _ProfileRegistryState();
}

class _ProfileRegistryState extends State<_ProfileRegistry> {
  String _name = '';
  String _selected = PostponeSettings.defaultProfileName;
  int _branchRoot = 0;
  String _branchProfile = PostponeSettings.defaultProfileName;

  PostponeSettings get _postpone => widget.draft.postpone;

  /// Keeps the two selectors on a profile that still exists after a delete or
  /// a revert, so an assignment can never name a profile that is gone.
  String _liveName(String candidate) =>
      _postpone.profileNamed(candidate) == null
      ? PostponeSettings.defaultProfileName
      : candidate;

  void _editPostpone(
    PostponeSettings Function(PostponeSettings current) change,
  ) {
    widget.model.edit(
      (AppSettings settings) =>
          settings.copyWith(postpone: change(settings.postpone)),
    );
  }

  void _save() {
    final String name = _name.trim();
    if (name.isEmpty || name == PostponeSettings.defaultProfileName) return;
    _editPostpone(
      (PostponeSettings current) =>
          current.saveNamedProfile(name, current.defaultProfile),
    );
    setState(() => _selected = name);
  }

  void _load() {
    final SmartPostponeSettings? profile = _postpone.profileNamed(_selected);
    if (profile == null) return;
    _editPostpone(
      (PostponeSettings current) => current.replaceDefault(profile),
    );
  }

  void _delete() {
    if (_selected == PostponeSettings.defaultProfileName) return;
    final String removed = _selected;
    _editPostpone(
      (PostponeSettings current) => current.deleteNamedProfile(removed),
    );
    setState(() {
      _selected = PostponeSettings.defaultProfileName;
      if (_branchProfile == removed) {
        _branchProfile = PostponeSettings.defaultProfileName;
      }
    });
  }

  void _assign() {
    final String profile = _liveName(_branchProfile);
    if (_branchRoot < 0 || _branchRoot > 0xFFFFFFFF) return;
    _editPostpone(
      (PostponeSettings current) =>
          current.assignBranchProfile(_branchRoot, profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, String> options = <String, String>{
      for (final String name in _postpone.profileNames) name: name,
    };
    final List<int> assignedRoots =
        _postpone.branchProfileAssignments.keys.toList()..sort();

    return SettingsSection(
      title: 'Smart Postpone — profiles',
      description:
          'Default is the profile the automatic run uses, and the one the '
          'fields above edit. It is permanent and cannot be deleted. Save a '
          'copy under another name to give one branch different behaviour.',
      children: <Widget>[
        _saveAsRow(),
        _managedProfileRow(options),
        _resetDefaultRow(),
        _assignBranchRow(options),
        ..._branchAssignmentRows(assignedRoots),
      ],
    );
  }

  /// Names and stores a copy of whatever Default currently holds.
  Widget _saveAsRow() {
    final String trimmedName = _name.trim();
    return SettingsRow(
      label: 'Save this profile as',
      hint:
          'Stores a copy of every field above under a name of your own. '
          'Saving over a name you have already used replaces it.',
      controlWidth: 260,
      control: Row(
        children: <Widget>[
          Expanded(
            child: StringField(
              value: _name,
              onChanged: (String value) => setState(() => _name = value),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            // Default is permanent, so it cannot be saved over by name.
            onPressed:
                trimmedName.isEmpty ||
                    trimmedName == PostponeSettings.defaultProfileName
                ? null
                : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Loads a stored profile into Default, or deletes it.
  Widget _managedProfileRow(Map<String, String> options) {
    final String selected = _liveName(_selected);
    return SettingsRow(
      label: 'Managed profile',
      hint:
          'Load copies a stored profile into Default, which is what the '
          'automatic run and the fields above use. Delete also removes it '
          'from every branch it was assigned to.',
      controlWidth: 300,
      control: Row(
        children: <Widget>[
          Expanded(
            child: ChoiceField<String>(
              value: selected,
              options: options,
              onChanged: (String value) => setState(() => _selected = value),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _load, child: const Text('Load')),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: selected == PostponeSettings.defaultProfileName
                ? null
                : _delete,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _resetDefaultRow() {
    return SettingsRow(
      label: 'Reset Default to the shipped profile',
      hint:
          'Restores the Default profile the app came with, without touching '
          'any other setting or any profile you have saved.',
      control: OutlinedButton(
        onPressed: () => _editPostpone(
          (PostponeSettings current) =>
              current.replaceDefault(const SmartPostponeSettings()),
        ),
        child: const Text('Reset Default'),
      ),
    );
  }

  /// Points one branch of the tree at a profile other than Default.
  Widget _assignBranchRow(Map<String, String> options) {
    return SettingsRow(
      label: 'Assign a profile to a branch',
      hint:
          'Give the element id of a branch and the profile to use inside it. '
          'When branches are nested, the profiles around it are merged, '
          'outermost first, using the sub-branch mode above.',
      controlWidth: 320,
      control: Row(
        children: <Widget>[
          SizedBox(
            width: 96,
            child: IntField(
              value: _branchRoot,
              min: 0,
              max: 0xFFFFFFFF,
              onChanged: (int value) => setState(() => _branchRoot = value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceField<String>(
              value: _liveName(_branchProfile),
              options: options,
              onChanged: (String value) =>
                  setState(() => _branchProfile = value),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _assign, child: const Text('Assign')),
        ],
      ),
    );
  }

  /// One removable row per branch that overrides Default.
  List<Widget> _branchAssignmentRows(List<int> assignedRoots) {
    if (assignedRoots.isEmpty) {
      return const <Widget>[
        SettingsRow(
          label: 'Branch assignments',
          hint: 'Every branch currently uses the Default profile.',
          control: SizedBox.shrink(),
        ),
      ];
    }
    return <Widget>[
      for (final int root in assignedRoots)
        SettingsRow(
          label: 'Branch $root',
          hint:
              'Uses ${_postpone.branchProfileAssignments[root]} when a run '
              'reaches this branch.',
          control: OutlinedButton(
            onPressed: () => _editPostpone(
              (PostponeSettings current) => current.unassignBranchProfile(root),
            ),
            child: const Text('Unassign'),
          ),
        ),
    ];
  }
}

/// The Optimize control, which is a button until it is a progress indicator.
///
/// The pass rewrites the whole database file, so on a large collection it is
/// slow enough that a button which merely greyed out would read as broken.
class _OptimizeButton extends StatelessWidget {
  const _OptimizeButton({required this.isBusy, required this.model});

  final bool isBusy;
  final SettingsViewModel model;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      if (isBusy) ...<Widget>[
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
      ],
      FilledButton.tonal(
        onPressed: isBusy ? null : model.optimizeDatabase,
        child: Text(isBusy ? 'Optimizing…' : 'Optimize now'),
      ),
    ],
  );
}
