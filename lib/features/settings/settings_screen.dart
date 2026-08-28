/// Settings for the SM20 scheduler and application-local preferences.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/mercy_settings.dart';
import 'package:incremental_reader/settings/postpone_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
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
      model.clearMessage();
    });

    final SettingsUiState? data = state.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: <Widget>[
          TextButton(
            onPressed: data == null || data.isBusy ? null : model.loadDefaults,
            child: const Text('Restore defaults'),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: data == null || !data.isDirty ? null : model.revert,
            child: const Text('Discard'),
          ),
          const SizedBox(width: 6),
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
        data: (SettingsUiState data) => _Body(state: data, model: model),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.model});

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;
  SmartPostponeSettings get smart => draft.postpone.defaultProfile;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: ListView(
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
          _reader(),
          _diagnostics(),
        ],
      ),
    ),
  );

  void _editSmart(
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
        'The scheduler works in collection-relative days. The local rollover '
        'keeps a late-night session on one study day.',
    children: <Widget>[
      SettingsRow(
        label: 'Home timezone',
        hint: 'Used to translate instants into stable study-day numbers.',
        control: ChoiceField<String>(
          value: _displayZoneId(draft.studyDay.zoneId),
          options: <String, String>{
            if (!selectableZoneIds.contains(
              _displayZoneId(draft.studyDay.zoneId),
            ))
              _displayZoneId(draft.studyDay.zoneId):
                  'Unsupported: ${draft.studyDay.zoneId}',
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
        hint: 'Minutes after local midnight at which Today advances.',
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
    title: 'Daily Outstanding queue',
    description:
        'SM20 priority-sorts items and topics independently, applies each '
        'randomization curve, then merges the two outputs at the selected '
        'topic percentage. There are no capacity caps or Study More overlay.',
    children: <Widget>[
      SettingsRow(
        label: 'Topics in merged queue',
        hint:
            'Target topic-family share. When one family runs out, SM20 uses '
            'the other while preserving its exact merge counters.',
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
        label: 'Item randomization',
        hint:
            'The item-family slider value used by SM20’s nonlinear '
            'randomization curve (0–100).',
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
            'The topic-family slider value. Topic extraction starts only '
            'after every item extraction has consumed its random draws.',
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
            'Sort once when Today changes and Outstanding is nonempty. '
            'Sorting does not reseed the collection PRNG.',
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
            'Use SM20’s fixed-size full-range swap routine before the Final '
            'Drill stage. It consumes one global PRNG value per entry.',
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
            'When enabled, collections over 100 elements ask before moving '
            'from Outstanding into Final Drill or Pending.',
        control: SwitchField(
          value: draft.queue.shouldConfirmStageTransitions,
          onChanged: (bool value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              queue: settings.queue.copyWith(shouldConfirmStageTransitions: value),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _remember() => SettingsSection(
    title: 'Remember',
    description:
        'The browser Remember command chooses the first interval from these '
        'collection words. Equal endpoints are explicit and consume no '
        'random draw; a high endpoint of zero uses the generated path.',
    children: <Widget>[
      SettingsRow(
        label: 'First interval — low',
        hint: 'Inclusive lower endpoint for a randomized first interval.',
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
            'Inclusive upper endpoint (1–365). Set to 0 to ask the topic '
            'scheduler to generate the first interval.',
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
        'The supplied SM20 source does not reconstruct item memory. Cards '
        'retain FSRS memory while still participating in SM20 priority, '
        'Outstanding, Smart Postpone, and Mercy.',
    children: <Widget>[
      SettingsRow(
        label: 'Desired retention',
        hint: 'Target recall probability used by the card scheduler.',
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
        hint: 'Comma-separated minute steps used only by card memory.',
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
        hint: 'Minute steps after a card lapse.',
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
        hint: 'Upper bound used by FSRS card scheduling.',
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
        hint: 'Apply the card scheduler’s interval fuzzing.',
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
        hint: 'Number of card lapses before the card is marked as a leech.',
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
        hint: 'Keep related cards from appearing in the same study day.',
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
        'These are the actual profile-record controls used by Smart Postpone. '
        'Automatic postponement runs the Default profile at most once per day '
        'and only after SM20’s strict Outstanding and overdue count gates.',
    children: <Widget>[
      SettingsRow(
        label: 'Automatic postponement',
        hint: 'Allow the once-per-day Default-profile automatic path.',
        control: SwitchField(
          value: draft.postpone.isAutomaticPostponeEnabled,
          onChanged: (bool value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              postpone: settings.postpone.copyWith(isAutomaticPostponeEnabled: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Profile name',
        hint: 'Managed profile name. The automatic path loads “Default”.',
        control: StringField(
          value: smart.profileName,
          onChanged: (String value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(profileName: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Scope',
        hint:
            'All Outstanding, a selected branch/concept, or the current '
            'browser population.',
        control: ChoiceField<SmartPostponeScope>(
          value: smart.scope,
          options: const <SmartPostponeScope, String>{
            SmartPostponeScope.global: 'All Outstanding',
            SmartPostponeScope.branch: 'Branch or concept',
            SmartPostponeScope.browser: 'Current browser',
          },
          onChanged: (SmartPostponeScope value) =>
              _editSmart((SmartPostponeSettings s) => s.copyWith(scope: value)),
        ),
      ),
      SettingsRow(
        label: 'Branch root element',
        hint: 'Unsigned element ID used when scope is Branch or concept.',
        control: IntField(
          value: smart.rootElementId,
          min: 0,
          max: 0xFFFFFFFF,
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(rootElementId: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Selection method',
        hint:
            'Protect a fixed top-priority count, including the forced second '
            'pass, or rely only on the parameter eligibility gates.',
        control: ChoiceField<SmartPostponeMethod>(
          value: smart.method,
          options: const <SmartPostponeMethod, String>{
            SmartPostponeMethod.topCount: 'Protect top count',
            SmartPostponeMethod.parameters: 'Parameters only',
          },
          onChanged: (SmartPostponeMethod value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(method: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Protected top count',
        hint:
            'Number of highest-importance source entries left unpostponed '
            'when the top-count method is active.',
        control: IntField(
          value: smart.protectedCount,
          min: 1,
          max: 20000,
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(protectedCount: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Simulate',
        hint:
            'Calculate and report candidates without dispersion, record '
            'writes, or PRNG consumption.',
        control: SwitchField(
          value: smart.isSimulationOnly,
          onChanged: (bool value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(isSimulationOnly: value),
          ),
        ),
      ),
    ],
  );

  Widget _smartPostponeParameters() => SettingsSection(
    title: 'Smart Postpone — parameters',
    description:
        'Delay percentages are stored behind the displayed factor '
        '(factor = 1 + percent/100). Minimum and maximum values clamp days '
        'added before random dispersion, not the final interval.',
    children: <Widget>[
      SettingsRow(
        label: 'Item delay factor',
        hint: 'Stored 1–400%; 20% is displayed by SM20 as factor 1.20.',
        control: IntField(
          value: smart.itemDelayPercent,
          min: 1,
          max: 400,
          suffix: '%',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(itemDelayPercent: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic delay factor',
        hint: 'Stored 1–1900%; 50% is displayed as factor 1.50.',
        control: IntField(
          value: smart.topicDelayPercent,
          min: 1,
          max: 1900,
          suffix: '%',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(topicDelayPercent: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Item maximum added delay',
        hint: 'Pre-dispersion clamp for item delay days.',
        control: IntField(
          value: smart.itemMaximumDelayDays,
          min: 1,
          max: 300,
          suffix: 'd',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(itemMaximumDelayDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic maximum added delay',
        hint: 'Pre-dispersion clamp for topic-family delay days.',
        control: IntField(
          value: smart.topicMaximumDelayDays,
          min: 1,
          max: 500,
          suffix: 'd',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(topicMaximumDelayDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Item minimum added delay',
        hint: 'Pre-dispersion minimum, and forced-pass item minimum.',
        control: IntField(
          value: smart.itemMinimumDelayDays,
          min: 1,
          max: 30,
          suffix: 'd',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(itemMinimumDelayDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic minimum added delay',
        hint: 'Pre-dispersion minimum, and forced-pass topic minimum.',
        control: IntField(
          value: smart.topicMinimumDelayDays,
          min: 1,
          max: 100,
          suffix: 'd',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(topicMinimumDelayDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Skip all items',
        hint: 'Reject the item family in a normal parameter pass.',
        control: SwitchField(
          value: smart.shouldSkipItems,
          onChanged: (bool value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(shouldSkipItems: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Skip all topics',
        hint: 'Reject topics and extracts in a normal parameter pass.',
        control: SwitchField(
          value: smart.shouldSkipTopics,
          onChanged: (bool value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(shouldSkipTopics: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Item interval cutoff',
        hint: 'Reject an item when age is greater than or equal to this.',
        control: IntField(
          value: smart.itemAgeCutoffDays,
          min: 2,
          max: 4000,
          suffix: 'd',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(itemAgeCutoffDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic interval cutoff',
        hint: 'Reject a topic-family element when age reaches this value.',
        control: IntField(
          value: smart.topicAgeCutoffDays,
          min: 2,
          max: 4000,
          suffix: 'd',
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(topicAgeCutoffDays: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Skip cards you still recall',
        hint:
            'Cards easier than this are left alone. The number is a '
            'forgetting index — the chance of failing a card, read off FSRS '
            'retrievability as 100 × (1 − R). At 6, a card you would recall '
            'better than 94% of the time is not postponed.',
        control: IntField(
          value: smart.itemForgettingIndexCutoff,
          min: 3,
          max: 20,
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(itemForgettingIndexCutoff: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic A-factor floor',
        hint: 'Reject when A is less than or equal to this strict cutoff.',
        control: DoubleField(
          value: smart.topicAFactorCutoff,
          min: 1.01,
          max: 6,
          onChanged: (double value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(topicAFactorCutoff: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Item postponement-count cutoff',
        hint: 'Reject when total item postponements reach this count.',
        control: IntField(
          value: smart.itemPostponeCountCutoff,
          min: 1,
          max: 255,
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(itemPostponeCountCutoff: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic postponement-count cutoff',
        hint: 'Reject when total topic postponements reach this count.',
        control: IntField(
          value: smart.topicPostponeCountCutoff,
          min: 1,
          max: 255,
          onChanged: (int value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(topicPostponeCountCutoff: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Item priority threshold',
        hint: 'Reject an item when rank-derived priority P is below this.',
        control: DoubleField(
          value: smart.itemPriorityThreshold,
          min: 0.01,
          max: 100,
          suffix: '%',
          onChanged: (double value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(itemPriorityThreshold: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic priority threshold',
        hint: 'Reject a topic when rank-derived P is below this.',
        control: DoubleField(
          value: smart.topicPriorityThreshold,
          min: 0.0001,
          max: 100,
          suffix: '%',
          onChanged: (double value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(topicPriorityThreshold: value),
          ),
        ),
      ),
    ],
  );

  Widget _smartPostponeAdjust() => SettingsSection(
    title: 'Smart Postpone — adjust',
    description:
        'Nested branch profiles can be copied or merged. The two modifier '
        'flags below are preserved exactly as profile data even though the '
        'SM20 evaluator never reads them.',
    children: <Widget>[
      SettingsRow(
        label: 'Sub-branch profiles',
        hint:
            'Respect the exact nested profile, ignore it, or merge profiles '
            'using SM20’s conservative/liberal field directions.',
        control: ChoiceField<SmartPostponeSubbranchMode>(
          value: smart.subbranchMode,
          options: const <SmartPostponeSubbranchMode, String>{
            SmartPostponeSubbranchMode.respect: 'Respect',
            SmartPostponeSubbranchMode.ignore: 'Ignore',
            SmartPostponeSubbranchMode.conservative: 'Most conservative',
            SmartPostponeSubbranchMode.liberal: 'Most liberal',
          },
          onChanged: (SmartPostponeSubbranchMode value) => _editSmart(
            (SmartPostponeSettings s) => s.copyWith(subbranchMode: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Include non-Outstanding elements',
        hint:
            'Bypass only the Outstanding-membership exclusion. Pending '
            'elements can consequently be admitted by a manual run.',
        control: SwitchField(
          value: smart.shouldIncludeNonOutstanding,
          onChanged: (bool value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(shouldIncludeNonOutstanding: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Modify item delay by FI',
        hint:
            'Preserved inert SM20 checkbox. Changing it does not alter the '
            'evaluator’s delay calculation.',
        control: SwitchField(
          value: smart.shouldModifyItemByForgettingIndex,
          onChanged: (bool value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(shouldModifyItemByForgettingIndex: value),
          ),
        ),
      ),
      SettingsRow(
        label: 'Modify topic delay by A-factor',
        hint: 'Preserved inert SM20 checkbox. The evaluator does not read it.',
        control: SwitchField(
          value: smart.shouldModifyTopicByAFactor,
          onChanged: (bool value) => _editSmart(
            (SmartPostponeSettings s) =>
                s.copyWith(shouldModifyTopicByAFactor: value),
          ),
        ),
      ),
    ],
  );

  Widget _mercy() => SettingsSection(
    title: 'Mercy',
    description:
        'Mercy scores scheduled items and topic-family elements, orders them, '
        'then redistributes actual due dates. Its investment estimate uses '
        'the live collection-specific 20×20 interval-factor matrix.',
    children: <Widget>[
      SettingsRow(
        label: 'Candidate order',
        hint: 'Select one of SM20’s four exact Mercy ordering modes.',
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
        hint: 'R: days across which selected candidates are assigned.',
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
            'G: scheduled candidates are gathered through Today + G − 1. '
            'Future mode keeps G at least as large as R.',
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
        hint: 'C: planner cap, from 1 through the executable maximum 5,000.',
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
            'Use future-mode horizon behavior. Turning this off makes G '
            'equal R, matching SM20’s nonfuture planner.',
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
        hint: 'Default 10; uses 1 − rank-derived priority/100.',
        value: draft.mercy.importanceWeight,
        change: (MercySettings mercy, double value) =>
            mercy.copyWith(importanceWeight: value),
      ),
      _mercyWeight(
        label: 'Lateness weight',
        hint: 'Default 3; combines interval ratio and age.',
        value: draft.mercy.latenessWeight,
        change: (MercySettings mercy, double value) =>
            mercy.copyWith(latenessWeight: value),
      ),
      _mercyWeight(
        label: 'Investment weight',
        hint: 'Default 4; uses repetition count and matrix investment.',
        value: draft.mercy.investmentWeight,
        change: (MercySettings mercy, double value) =>
            mercy.copyWith(investmentWeight: value),
      ),
      _mercyWeight(
        label: 'Easiness weight',
        hint: 'Default 1; combines lapse order and lateness.',
        value: draft.mercy.easinessWeight,
        change: (MercySettings mercy, double value) =>
            mercy.copyWith(easinessWeight: value),
      ),
      _mercyWeight(
        label: 'Recency weight',
        hint: 'Default 1; combines inverse age and inverse lapse order.',
        value: draft.mercy.recencyWeight,
        change: (MercySettings mercy, double value) =>
            mercy.copyWith(recencyWeight: value),
      ),
      SettingsRow(
        label: 'Interval-factor matrix',
        hint:
            'Optional row-major 20×20 UInt16 matrix scaled by 1,000. Empty '
            'means this collection has no imported live matrix.',
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

  Widget _reader() => SettingsSection(
    title: 'Reader',
    description: 'Reader-only preferences; these do not alter SM20 records.',
    children: <Widget>[
      SettingsRow(
        label: 'Reminder after',
        hint:
            'Words past the opening position before the nonblocking reader '
            'reminder appears.',
        control: IntField(
          value: draft.reader.reminderWords,
          min: 0,
          max: 100000,
          suffix: 'words',
          onChanged: (int value) => model.edit(
            (AppSettings settings) => settings.copyWith(
              reader: settings.reader.copyWith(reminderWords: value),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _diagnostics() => SettingsSection(
    title: 'Diagnostics',
    description:
        'Local scheduler diagnostics. Content remains hidden unless explicitly '
        'enabled for the developer panel.',
    children: <Widget>[
      SettingsRow(
        label: 'Write a log file',
        hint: 'Enable the local rotating diagnostic log.',
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
        hint: 'Maximum active log size before rotation.',
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
        hint: 'Number of rotated log files retained.',
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
            'Off by default so diagnostics screenshots do not reveal study content.',
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

/// Save/List/Delete/Assign controls for SM20's managed profile registry.
///
/// The fields edited above are one working record. This section is what gives
/// that record a name, hands it to a branch, or promotes it back into the
/// permanent Default slot the automatic run loads.
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
    final String selected = _liveName(_selected);
    final String branchProfile = _liveName(_branchProfile);
    final Map<String, String> options = <String, String>{
      for (final String name in _postpone.profileNames) name: name,
    };
    final List<int> roots = _postpone.branchProfileAssignments.keys.toList()
      ..sort();

    return SettingsSection(
      title: 'Smart Postpone — profiles',
      description:
          'Default is permanent: it is the record automatic postponement '
          'runs and the one the fields above edit. Saving under another name '
          'stores a copy that a branch can use instead.',
      children: <Widget>[
        SettingsRow(
          label: 'Save the edited record as',
          hint:
              'Stores every field above, including the two inert modifier '
              'flags. Saving over an existing name replaces it.',
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
                onPressed:
                    _name.trim().isEmpty ||
                        _name.trim() == PostponeSettings.defaultProfileName
                    ? null
                    : _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
        SettingsRow(
          label: 'Managed profile',
          hint:
              'Load copies the stored record into Default, which is what the '
              'automatic run and the fields above use. Delete also removes '
              'every branch assignment that named it.',
          controlWidth: 300,
          control: Row(
            children: <Widget>[
              Expanded(
                child: ChoiceField<String>(
                  value: selected,
                  options: options,
                  onChanged: (String value) =>
                      setState(() => _selected = value),
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
        ),
        SettingsRow(
          label: 'Reset Default to the shipped record',
          hint:
              'Restores the binary-derived Default profile without touching '
              'any other setting or saved profile.',
          control: OutlinedButton(
            onPressed: () => _editPostpone(
              (PostponeSettings current) =>
                  current.replaceDefault(const SmartPostponeSettings()),
            ),
            child: const Text('Reset Default'),
          ),
        ),
        SettingsRow(
          label: 'Assign a profile to a branch',
          hint:
              'Branch runs merge the profiles of every enclosing branch, '
              'outer to inner, using the sub-branch mode above.',
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
                  value: branchProfile,
                  options: options,
                  onChanged: (String value) =>
                      setState(() => _branchProfile = value),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: _assign, child: const Text('Assign')),
            ],
          ),
        ),
        if (roots.isEmpty)
          const SettingsRow(
            label: 'Branch assignments',
            hint: 'No branch overrides the Default profile.',
            control: SizedBox.shrink(),
          )
        else
          for (final int root in roots)
            SettingsRow(
              label: 'Branch $root',
              hint:
                  'Uses ${_postpone.branchProfileAssignments[root]} when a '
                  'run reaches this branch.',
              control: OutlinedButton(
                onPressed: () => _editPostpone(
                  (PostponeSettings current) =>
                      current.unassignBranchProfile(root),
                ),
                child: const Text('Unassign'),
              ),
            ),
      ],
    );
  }
}
