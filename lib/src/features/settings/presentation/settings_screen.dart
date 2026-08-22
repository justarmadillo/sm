/// Settings: every constant the schedulers run on.
///
/// The scheduling design's numbers are admitted starting points, not derived
/// values, so all of them are here rather than compiled in. That is also what
/// makes this a SuperMemo-shaped tool rather than an imitation of one: the
/// proportion of topics, the degree of randomization, the caps, the A-factor's
/// modulation, and the postponement formulas are exactly the knobs SuperMemo
/// exposes, and none of them can be tuned honestly without being visible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/toast.dart';
import '../../../data/platform/time_zones.dart';
import '../../../domain/settings/app_settings.dart';
import 'settings_controls.dart';
import 'settings_view_model.dart';

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

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        children: <Widget>[
          _studyDay(),
          _queue(),
          _topics(),
          _profiles(),
          _cards(),
          _postpone(),
          _reader(),
          _diagnostics(),
        ],
      ),
    ),
  );

  // ---------------------------------------------------------------- study day

  Widget _studyDay() => SettingsSection(
    title: 'Study day',
    description:
        'A study day ends at the rollover, not at midnight, so a session that '
        'runs past 1am still counts as the same day.',
    children: <Widget>[
      SettingsRow(
        label: 'Home timezone',
        hint:
            'A named home timezone keeps the StudyDay stable while travelling '
            'and applies its daylight-saving rules automatically.',
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
            (AppSettings s) =>
                s.copyWith(studyDay: s.studyDay.copyWith(zoneId: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Day rollover',
        hint: 'Minutes after local midnight at which a new study day begins.',
        control: IntField(
          value: draft.studyDay.rolloverMinutes,
          suffix: 'min',
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              studyDay: s.studyDay.copyWith(rolloverMinutes: value),
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
      // Keep malformed legacy data visible. Scheduling fails closed until the
      // user explicitly replaces it with a supported named zone.
      return storedId;
    }
  }

  // -------------------------------------------------------------------- queue

  Widget _queue() => SettingsSection(
    title: 'Daily queue',
    description:
        'Caps are maxima, not quotas: the queue is worked until you stop. '
        'What does not fit is deferred by priority rather than left to rot, '
        'which is what keeps an oversubscribed collection survivable.',
    children: <Widget>[
      SettingsRow(
        label: 'Maximum cards',
        hint: 'Most unique cards admitted in one study day.',
        control: IntField(
          value: draft.queue.maxCards,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(maxCards: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Maximum new cards',
        hint:
            'A subset of the card cap. New cards are cheap to make and '
            'expensive to keep, so they get their own limit.',
        control: IntField(
          value: draft.queue.maxNewCards,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(maxNewCards: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Maximum topics',
        hint: 'Sources and extracts together.',
        control: IntField(
          value: draft.queue.maxTopics,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(maxTopics: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Cards per topic',
        hint:
            'The proportion of topics in learning. Too few and you gain no '
            'new knowledge; too many and you forget what you already '
            'invested in. Four or more items per topic is the healthy range.',
        control: IntField(
          value: draft.queue.cardsPerTopic,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(cardsPerTopic: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Topic interleave floor',
        hint:
            'A hard guard: never more than this many elements in a row '
            'without a topic while topics are due. Items outnumber topics '
            'within months, and reading is what generates future items.',
        control: IntField(
          value: draft.queue.minTopicEvery,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(minTopicEvery: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Randomization',
        hint:
            'Zero gives strict priority order. A little shuffle fights the '
            'priority bias — today’s imports always feel more important '
            'than last year’s investment — and lets displaced material '
            'resurface. Too much and prioritization unravels entirely.',
        control: DoubleSliderField(
          value: draft.queue.randomization,
          min: 0,
          max: 0.5,
          divisions: 50,
          format: (double v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (double value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(randomization: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Protected top percentile',
        hint:
            'This share of the collection is never auto-postponed. Without '
            'the floor the valve eventually pushes everything out and the '
            'collection schedules nothing. Protected elements stay due and '
            'force a decision: do it, or demote it by hand.',
        control: DoubleSliderField(
          value: draft.queue.protectedPercentile,
          min: 0,
          max: 0.25,
          divisions: 25,
          format: (double v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (double value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(protectedPercentile: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Auto-postpone overflow',
        hint:
            'Off means the whole backlog stays due every day. Overload is '
            'normal in incremental reading; deferring the lowest-priority '
            'excess is how it stays workable.',
        control: SwitchField(
          value: draft.queue.autoPostpone,
          onChanged: (bool value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(autoPostpone: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Study More step',
        hint: 'How many deferred elements one Study More press takes back.',
        control: IntField(
          value: draft.queue.studyMoreStep,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(queue: s.queue.copyWith(studyMoreStep: value)),
          ),
        ),
      ),
    ],
  );

  // ------------------------------------------------------------------- topics

  Widget _topics() => SettingsSection(
    title: 'Topic scheduling',
    description:
        'Topics — articles and extracts — are never graded and never go '
        'through FSRS. There is no concept of failing a paragraph; you simply '
        'see it again and do more work on it. The A-factor decides how fast '
        'each one recedes.',
    children: <Widget>[
      SettingsRow(
        label: 'Base A-factor',
        hint: 'The multiplier before any modulation.',
        control: DoubleSliderField(
          value: draft.topics.baseAFactor,
          min: 1,
          max: 5,
          divisions: 40,
          onChanged: (double value) => model.edit(
            (AppSettings s) =>
                s.copyWith(topics: s.topics.copyWith(baseAFactor: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Priority floor / span',
        hint:
            'A is multiplied by (floor + span × pressure). Top-priority '
            'material grows slowly and returns often; the bottom recedes '
            'fast. Note that low priority is penalised twice — pushed '
            'further by the valve and grown faster here — which is intended, '
            'but worth watching if material vanishes sooner than you expect.',
        control: Row(
          children: <Widget>[
            Expanded(
              child: DoubleSliderField(
                value: draft.topics.priorityFloor,
                min: 0.2,
                max: 1.5,
                divisions: 26,
                onChanged: (double value) => model.edit(
                  (AppSettings s) => s.copyWith(
                    topics: s.topics.copyWith(priorityFloor: value),
                  ),
                ),
              ),
            ),
            Expanded(
              child: DoubleSliderField(
                value: draft.topics.prioritySpan,
                min: 0,
                max: 2,
                divisions: 20,
                onChanged: (double value) => model.edit(
                  (AppSettings s) => s.copyWith(
                    topics: s.topics.copyWith(prioritySpan: value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SettingsRow(
        label: 'A-factor clamps',
        hint:
            'A is clamped between these. A floor of 1.0 means a repetition '
            'never shortens an interval by itself — only you can do that.',
        control: Row(
          children: <Widget>[
            Expanded(
              child: DoubleSliderField(
                value: draft.topics.minAFactor,
                min: 0.5,
                max: 2,
                divisions: 15,
                onChanged: (double value) => model.edit(
                  (AppSettings s) =>
                      s.copyWith(topics: s.topics.copyWith(minAFactor: value)),
                ),
              ),
            ),
            Expanded(
              child: DoubleSliderField(
                value: draft.topics.maxAFactor,
                min: 2,
                max: 12,
                divisions: 20,
                onChanged: (double value) => model.edit(
                  (AppSettings s) =>
                      s.copyWith(topics: s.topics.copyWith(maxAFactor: value)),
                ),
              ),
            ),
          ],
        ),
      ),
      SettingsRow(
        label: 'First interval span — articles',
        hint:
            'first = 1 + span × pressure², capped. Squared, not linear: it '
            'keeps the top of the collection tight and lets the bottom '
            'spread out fast.',
        control: IntField(
          value: draft.topics.sourceFirstIntervalSpan,
          suffix: 'd',
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              topics: s.topics.copyWith(sourceFirstIntervalSpan: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'First interval span — extracts',
        hint:
            'Extracts start shorter than articles: an unconverted extract is '
            'a debt, material you have committed to but not yet turned into '
            'anything durable.',
        control: IntField(
          value: draft.topics.extractFirstIntervalSpan,
          suffix: 'd',
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              topics: s.topics.copyWith(extractFirstIntervalSpan: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Offer to finish an extract after',
        hint:
            'Encounters since its last card before the extract is offered '
            'Finish. Without a nudge, a collection fills with extracts you '
            'mentally finished months ago but never closed.',
        control: IntField(
          value: draft.topics.extractFinishPromptAfter,
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              topics: s.topics.copyWith(extractFinishPromptAfter: value),
            ),
          ),
        ),
      ),
    ],
  );

  // ----------------------------------------------------------------- profiles

  Widget _profiles() => SettingsSection(
    title: 'Interval sequences',
    description:
        'Used when the interval model is set to fixed sequences. Days between '
        'encounters; the final value repeats forever, so a long-lived topic '
        'settles into a steady rhythm instead of disappearing for years.',
    children: <Widget>[
      for (final MapEntry<String, List<int>> entry
          in draft.intervalProfiles.entries)
        SettingsRow(
          label: entry.key,
          hint: switch (entry.key) {
            'focused' => 'Material being worked through now.',
            'normal' => 'The default pace for an article.',
            'slow' => 'Background material.',
            'extract' => 'Extracts, which start shorter than articles.',
            _ => 'A custom sequence.',
          },
          control: IntListField(
            values: entry.value,
            onChanged: (List<int> values) => model.edit(
              (AppSettings s) => s.copyWith(
                intervalProfiles: <String, List<int>>{
                  ...s.intervalProfiles,
                  entry.key: values,
                },
              ),
            ),
          ),
        ),
    ],
  );

  // -------------------------------------------------------------------- cards

  Widget _cards() => SettingsSection(
    title: 'Cards (FSRS)',
    description:
        'The parameter vector itself stays pinned and versioned: a hand-edited '
        'weight would silently reinterpret every review already in the log. '
        'Retention, steps, and the interval cap are safe to change at any time.',
    children: <Widget>[
      SettingsRow(
        label: 'Desired retention',
        hint: 'Probability of recall FSRS aims for at the scheduled instant.',
        control: DoubleSliderField(
          value: draft.cards.desiredRetention,
          min: 0.70,
          max: 0.99,
          divisions: 29,
          format: (double v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (double value) => model.edit(
            (AppSettings s) =>
                s.copyWith(cards: s.cards.copyWith(desiredRetention: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Learning steps',
        hint: 'Minutes, comma separated.',
        control: IntListField(
          values: draft.cards.learningStepMinutes,
          onChanged: (List<int> values) => model.edit(
            (AppSettings s) => s.copyWith(
              cards: s.cards.copyWith(learningStepMinutes: values),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Relearning steps',
        hint: 'Minutes, comma separated.',
        control: IntListField(
          values: draft.cards.relearningStepMinutes,
          onChanged: (List<int> values) => model.edit(
            (AppSettings s) => s.copyWith(
              cards: s.cards.copyWith(relearningStepMinutes: values),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Maximum interval',
        hint: 'Upper clamp on any scheduled interval.',
        control: IntField(
          value: draft.cards.maximumIntervalDays,
          suffix: 'd',
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(cards: s.cards.copyWith(maximumIntervalDays: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Fuzzing',
        hint: 'Spreads due dates so reviews do not clump on one day.',
        control: SwitchField(
          value: draft.cards.enableFuzzing,
          onChanged: (bool value) => model.edit(
            (AppSettings s) =>
                s.copyWith(cards: s.cards.copyWith(enableFuzzing: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Leech threshold',
        hint:
            'Lapses after which a card is flagged and its source passage '
            'offered. Flagged, never auto-suspended: most repeated failures '
            'are badly written cards rather than hard facts, and suspending '
            'hides the evidence instead of fixing the cause.',
        control: IntField(
          value: draft.cards.leechLapses,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(cards: s.cards.copyWith(leechLapses: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Bury siblings',
        hint:
            'Answering a card pushes same-parent cards to tomorrow. Three '
            'clozes cut from one sentence give each other away, so seeing '
            'them together measures almost nothing.',
        control: SwitchField(
          value: draft.cards.burySiblings,
          onChanged: (bool value) => model.edit(
            (AppSettings s) =>
                s.copyWith(cards: s.cards.copyWith(burySiblings: value)),
          ),
        ),
      ),
    ],
  );

  // ----------------------------------------------------------------- postpone

  Widget _postpone() => SettingsSection(
    title: 'Postponement',
    description:
        'Three separate mechanisms. A manual Later is you saying "wrong task '
        'right now"; auto-postpone is the day’s capacity valve; Mercy '
        'resolves a backlog after an absence. None of them is a review, and '
        'none touches memory state or the algorithmic due date.',
    children: <Widget>[
      SettingsRow(
        label: 'Later delay range',
        hint:
            'A fraction of the element’s own interval. A fixed +1 day is '
            'useless — the element returns tomorrow into an equally full '
            'queue.',
        control: Row(
          children: <Widget>[
            Expanded(
              child: DoubleSliderField(
                value: draft.postpone.laterMinFraction,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: (double value) => model.edit(
                  (AppSettings s) => s.copyWith(
                    postpone: s.postpone.copyWith(laterMinFraction: value),
                  ),
                ),
              ),
            ),
            Expanded(
              child: DoubleSliderField(
                value: draft.postpone.laterMaxFraction,
                min: 0,
                max: 1.5,
                divisions: 30,
                onChanged: (double value) => model.edit(
                  (AppSettings s) => s.copyWith(
                    postpone: s.postpone.copyWith(laterMaxFraction: value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SettingsRow(
        label: 'Auto-postpone base',
        hint:
            'Fraction of the interval used as the base delay. Proportional, '
            'so young elements are not lost to the void while mature ones '
            'recede far.',
        control: DoubleSliderField(
          value: draft.postpone.autoBaseFraction,
          min: 0,
          max: 1,
          divisions: 20,
          onChanged: (double value) => model.edit(
            (AppSettings s) => s.copyWith(
              postpone: s.postpone.copyWith(autoBaseFraction: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Priority multiplier',
        hint:
            'How much further bottom-priority material is pushed than top. '
            'At 4, the bottom of the collection goes roughly five times as '
            'far as the top.',
        control: DoubleSliderField(
          value: draft.postpone.autoPriorityMultiplier,
          min: 0,
          max: 12,
          divisions: 24,
          format: (double v) => '×${v.toStringAsFixed(1)}',
          onChanged: (double value) => model.edit(
            (AppSettings s) => s.copyWith(
              postpone: s.postpone.copyWith(autoPriorityMultiplier: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Dispersal',
        hint:
            'Random ± spread on each delay, so a day’s overflow does not '
            'land together on one future day and recreate the same overload.',
        control: DoubleSliderField(
          value: draft.postpone.autoDispersal,
          min: 0,
          max: 0.6,
          divisions: 24,
          format: (double v) => '±${(v * 100).toStringAsFixed(0)}%',
          onChanged: (double value) => model.edit(
            (AppSettings s) =>
                s.copyWith(postpone: s.postpone.copyWith(autoDispersal: value)),
          ),
        ),
      ),
      SettingsRow(
        label: 'Mercy horizon',
        hint:
            'Days a backlog is spread across. The top of it lands within '
            'days and the tail lands months out — that distribution is the '
            'correct outcome, not damage control.',
        control: IntField(
          value: draft.postpone.mercyHorizonDays,
          suffix: 'd',
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              postpone: s.postpone.copyWith(mercyHorizonDays: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Mercy daily cap',
        hint: 'How many elements Mercy places on each day of the horizon.',
        control: IntField(
          value: draft.postpone.mercyDailyCap,
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(postpone: s.postpone.copyWith(mercyDailyCap: value)),
          ),
        ),
      ),
    ],
  );

  // ------------------------------------------------------------------- reader

  Widget _reader() => SettingsSection(
    title: 'Reader',
    description: 'Preferences rather than scheduling rules.',
    children: <Widget>[
      SettingsRow(
        label: 'Reminder after',
        hint:
            'Words past the session’s opening position before the '
            'nonblocking reminder line appears.',
        control: IntField(
          value: draft.reader.reminderWords,
          suffix: 'words',
          onChanged: (int value) => model.edit(
            (AppSettings s) =>
                s.copyWith(reader: s.reader.copyWith(reminderWords: value)),
          ),
        ),
      ),
    ],
  );

  // -------------------------------------------------------------- diagnostics

  Widget _diagnostics() => SettingsSection(
    title: 'Diagnostics',
    description:
        'A local rotating log of operation metadata, failures, and versions. '
        'It never records what you are studying.',
    children: <Widget>[
      SettingsRow(
        label: 'Write a log file',
        hint: 'Kept beside the database, never in a synced folder.',
        control: SwitchField(
          value: draft.diagnostics.logEnabled,
          onChanged: (bool value) => model.edit(
            (AppSettings s) => s.copyWith(
              diagnostics: s.diagnostics.copyWith(logEnabled: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Rotate at',
        hint: 'Size at which the active log file rolls over.',
        control: IntField(
          value: draft.diagnostics.logMaxBytes ~/ 1024,
          suffix: 'KB',
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              diagnostics: s.diagnostics.copyWith(logMaxBytes: value * 1024),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Files kept',
        hint: 'How many rotated logs to retain.',
        control: IntField(
          value: draft.diagnostics.logRetainedFiles,
          onChanged: (int value) => model.edit(
            (AppSettings s) => s.copyWith(
              diagnostics: s.diagnostics.copyWith(logRetainedFiles: value),
            ),
          ),
        ),
      ),
      SettingsRow(
        label: 'Show element text in the panel',
        hint:
            'Off by default. A panel meant for scheduling bugs should not '
            'spill your collection into a screenshot.',
        control: SwitchField(
          value: draft.diagnostics.showContentInPanel,
          onChanged: (bool value) => model.edit(
            (AppSettings s) => s.copyWith(
              diagnostics: s.diagnostics.copyWith(showContentInPanel: value),
            ),
          ),
        ),
      ),
    ],
  );
}
