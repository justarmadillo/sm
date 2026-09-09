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
import 'package:incremental_reader/features/settings/widgets/card_memory_section.dart';
import 'package:incremental_reader/features/settings/widgets/collection_data_section.dart';
import 'package:incremental_reader/features/settings/widgets/diagnostics_section.dart';
import 'package:incremental_reader/features/settings/widgets/maintenance_section.dart';
import 'package:incremental_reader/features/settings/widgets/mercy_section.dart';
import 'package:incremental_reader/features/settings/widgets/queue_section.dart';
import 'package:incremental_reader/features/settings/widgets/remember_section.dart';
import 'package:incremental_reader/features/settings/widgets/smart_postpone_sections.dart';
import 'package:incremental_reader/features/settings/widgets/study_day_section.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/postpone_settings.dart';
import 'package:incremental_reader/settings/smart_postpone_settings.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/desktop_scroll_view.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

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

    final SettingsUiState? settingsState = state.valueOrNull;
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
                    model.restoreDefaults();
                  case 'discard':
                    model.revert();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'defaults',
                  enabled: settingsState != null && !settingsState.isBusy,
                  child: const Text('Restore defaults'),
                ),
                PopupMenuItem<String>(
                  value: 'discard',
                  enabled:
                      settingsState != null &&
                      settingsState.isDirty &&
                      !settingsState.isBusy,
                  child: const Text('Discard'),
                ),
              ],
            )
          else ...<Widget>[
            // Muted, because Save is the action of this screen. Three accented
            // labels in one bar make the user find the one that matters.
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              onPressed: settingsState == null || settingsState.isBusy
                  ? null
                  : model.restoreDefaults,
              child: const Text('Restore defaults'),
            ),
            const SizedBox(width: AppSpacing.hair),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              onPressed:
                  settingsState == null ||
                      !settingsState.isDirty ||
                      settingsState.isBusy
                  ? null
                  : model.revert,
              child: const Text('Discard'),
            ),
            const SizedBox(width: AppSpacing.tight),
          ],
          FilledButton(
            onPressed:
                settingsState == null ||
                    !settingsState.isDirty ||
                    settingsState.isBusy
                ? null
                : model.save,
            child: Text(
              settingsState?.activeOperation == SettingsOperation.saving
                  ? 'Saving…'
                  : 'Save',
            ),
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

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: DesktopListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        children: <Widget>[
          StudyDaySection(state: state, model: model),
          QueueSection(state: state, model: model),
          RememberSection(state: state, model: model),
          CardMemorySection(state: state, model: model),
          SmartPostponeScopeSection(state: state, model: model),
          SmartPostponeParametersSection(state: state, model: model),
          SmartPostponeAdjustSection(state: state, model: model),
          _ProfileRegistry(draft: state.draft, model: model),
          MercySection(state: state, model: model),
          CollectionDataSection(state: state, model: model),
          MaintenanceSection(state: state, model: model),
          DiagnosticsSection(state: state, model: model),
        ],
      ),
    ),
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
