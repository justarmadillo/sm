/// The collection-data section of Settings.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/features/settings/collection_file_dialogs.dart';
import 'package:incremental_reader/features/settings/settings_controls.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:path/path.dart' as p;

/// Exporting and importing the whole collection.
class CollectionDataSection extends StatelessWidget {
  const CollectionDataSection({
    required this.state,
    required this.model,
    super.key,
  });

  final SettingsUiState state;
  final SettingsViewModel model;

  AppSettings get draft => state.draft;

  @override
  Widget build(BuildContext context) => SettingsSection(
    title: 'Collection data',
    description:
        'Move a complete collection between installations. Packages contain '
        'sources, cards, schedules, history, tags, settings, and available '
        'images.',
    children: <Widget>[
      SettingsRow(
        label: 'Export collection',
        hint: state.isDirty
            ? 'Save or discard your settings edits before exporting.'
            : 'Creates one portable .irbackup package without changing your '
                  'rolling backups.',
        control: FilledButton.tonal(
          onPressed: state.isBusy || state.isDirty
              ? null
              : model.exportCollection,
          child: Text(
            state.activeOperation == SettingsOperation.exportingCollection
                ? 'Exporting…'
                : 'Export…',
          ),
        ),
      ),
      SettingsRow(
        label: 'Import collection',
        hint: state.isDirty
            ? 'Save or discard your settings edits before importing.'
            : 'Replaces this collection after creating a safety backup. '
                  'This does not merge collections.',
        control: FilledButton.tonal(
          onPressed: state.isBusy || state.isDirty
              ? null
              : () => _chooseAndConfirmImport(context),
          child: Text(
            state.activeOperation == SettingsOperation.importingCollection
                ? 'Importing…'
                : 'Import…',
          ),
        ),
      ),
    ],
  );

  Future<void> _chooseAndConfirmImport(BuildContext context) async {
    final SelectedCollectionPackage? selected = await model
        .chooseCollectionPackage();
    if (selected == null) return;
    if (!context.mounted) {
      await model.discardSelectedCollectionPackage(selected);
      return;
    }
    final bool didConfirm =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Replace this collection?'),
            content: Text(
              '${p.basename(selected.file.path)} will replace every source, '
              'card, schedule, history entry, tag, setting, and image in the '
              'current collection. A safety backup is created first.',
            ),
            actions: <Widget>[
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Replace and import'),
              ),
            ],
          ),
        ) ??
        false;
    if (!didConfirm) {
      await model.discardSelectedCollectionPackage(selected);
      return;
    }
    await model.importCollection(selected);
  }
}
