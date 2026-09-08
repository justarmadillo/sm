/// Verifies collection transfer controls on the Settings screen.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/app/providers.dart';
import 'package:incremental_reader/features/settings/collection_file_dialogs.dart';
import 'package:incremental_reader/features/settings/settings_providers.dart';
import 'package:incremental_reader/features/settings/settings_screen.dart';
import 'package:incremental_reader/features/settings/settings_view_model.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/storage/database/app_database.dart';
import 'package:incremental_reader/storage/database/connection.dart';

void main() {
  testWidgets('shows full collection import and export actions', (
    WidgetTester tester,
  ) async {
    _useCompactTestWindow(tester);
    final AppDatabase database = openInMemoryDatabase();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(settingsViewModelProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Collection data'),
      600,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Export collection'), findsOneWidget);
    expect(find.text('Import collection'), findsOneWidget);
    expect(
      find.textContaining('This does not merge collections.'),
      findsOneWidget,
    );
  });

  testWidgets('disables collection transfer while settings are unsaved', (
    WidgetTester tester,
  ) async {
    _useCompactTestWindow(tester);
    final AppDatabase database = openInMemoryDatabase();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    await container.read(settingsViewModelProvider.future);
    container
        .read(settingsViewModelProvider.notifier)
        .edit(
          (AppSettings settings) => settings.copyWith(
            diagnostics: settings.diagnostics.copyWith(
              isLogEnabled: !settings.diagnostics.isLogEnabled,
            ),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Collection data'),
      600,
      scrollable: find.byType(Scrollable).last,
    );

    final FilledButton exportButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Export…'),
    );
    final FilledButton importButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Import…'),
    );
    expect(exportButton.onPressed, isNull);
    expect(importButton.onPressed, isNull);
    expect(
      find.text('Save or discard your settings edits before exporting.'),
      findsOneWidget,
    );
  });

  testWidgets('import confirmation defaults to cancel and cleans picker copy', (
    WidgetTester tester,
  ) async {
    _useCompactTestWindow(tester);
    final Directory workspace = Directory.systemTemp.createTempSync(
      'ir_settings_import_test_',
    );
    final File selectedFile = File('${workspace.path}/chosen.irbackup')
      ..writeAsBytesSync(<int>[1]);
    final AppDatabase database = openInMemoryDatabase();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(database),
        collectionFileDialogsProvider.overrideWithValue(
          _SelectedPackageDialogs(selectedFile),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    });
    await container.read(settingsViewModelProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Collection data'),
      600,
      scrollable: find.byType(Scrollable).last,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Import…'));
    await tester.pumpAndSettle();

    expect(find.text('Replace this collection?'), findsOneWidget);
    final TextButton cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    expect(cancelButton.autofocus, isTrue);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(selectedFile.existsSync(), isFalse);
  });
}

void _useCompactTestWindow(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 1000);
  addTearDown(tester.view.reset);
}

final class _SelectedPackageDialogs extends CollectionFileDialogs {
  const _SelectedPackageDialogs(this.file);

  final File file;

  @override
  Future<SelectedCollectionPackage?> pickPackage() async =>
      SelectedCollectionPackage(file: file, shouldDeleteAfterUse: true);
}
