/// Fails the build when a folder imports something it is not allowed to.
///
/// A rule that only lives in a document erodes: one convenient
/// `import 'package:flutter/material.dart'` inside `lib/scheduling/`, and the
/// schedulers can no longer be tested without starting a widget binding. This
/// test is the rule with teeth.
///
/// The shape being protected, from the inside out:
///
///   shared/      knows nothing about anything
///   documents/   knows only shared/
///   scheduling/  knows shared/, settings/, and what storage promises
///   settings/    knows shared/ and what storage promises
///   storage/     knows documents/, scheduling/, shared/ -- never a screen
///   features/    knows everything except how rows are actually written
///   app/         wires it all together, so it may reach anywhere
library;

import 'dart:io';

import 'package:test/test.dart';

/// One folder and the things it is forbidden to import.
final class _FolderRule {
  const _FolderRule({
    required this.folderName,
    required this.folderPath,
    required this.forbiddenPackages,
    required this.forbiddenFolders,
    required this.reason,
    this.skippedSubfolders = const <String>[],
  });

  /// How the failure message names this folder.
  final String folderName;

  /// Path from the project root, e.g. `lib/scheduling`.
  final String folderPath;

  /// `package:` prefixes files in this folder must never import.
  final List<String> forbiddenPackages;

  /// Folders inside `lib/` this folder must never reach into.
  final List<String> forbiddenFolders;

  /// Plain-English explanation printed when the rule is broken.
  final String reason;

  /// Subfolders that have their own rule further down the list.
  final List<String> skippedSubfolders;
}

/// Flutter and every package that drags a Flutter binding or a real database
/// in with it. A folder that forbids all of these can be tested with plain
/// `dart test`, with no widget binding and no temporary file on disk.
const List<String> _flutterAndDatabasePackages = <String>[
  'package:flutter/',
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:drift/',
  'package:drift_flutter/',
  'package:sqlite3/',
  'package:path_provider/',
  'package:scrollable_positioned_list/',
];

const List<_FolderRule> _rules = <_FolderRule>[
  _FolderRule(
    folderName: 'shared',
    folderPath: 'lib/shared',
    skippedSubfolders: <String>['ui'],
    forbiddenPackages: _flutterAndDatabasePackages,
    forbiddenFolders: <String>[
      'app/',
      'features/',
      'storage/',
      'documents/',
      'scheduling/',
      'settings/',
    ],
    reason:
        'shared/ is the innermost folder: a clock, an id generator, a result '
        'type. If it starts importing the rest of the app, nothing below it '
        'can be read on its own any more.',
  ),
  _FolderRule(
    folderName: 'shared/ui',
    folderPath: 'lib/shared/ui',
    forbiddenPackages: <String>[
      'package:drift/',
      'package:sqlite3/',
      'package:path_provider/',
    ],
    forbiddenFolders: <String>['app/', 'features/', 'storage/'],
    reason:
        'shared/ui/ holds the colours, the toast, and the one badge every '
        'screen reuses. It may use Flutter, but it must not depend on any '
        'single screen or touch the database.',
  ),
  _FolderRule(
    folderName: 'documents',
    folderPath: 'lib/documents',
    forbiddenPackages: _flutterAndDatabasePackages,
    forbiddenFolders: <String>[
      'app/',
      'features/',
      'storage/',
      'scheduling/',
      'settings/',
    ],
    reason:
        'a document is text, blocks, and exact offsets into that text. It has '
        'no opinion about when it is due, how it is drawn, or how it is '
        'saved, so the markdown parsers stay testable on their own.',
  ),
  _FolderRule(
    folderName: 'scheduling',
    folderPath: 'lib/scheduling',
    forbiddenPackages: _flutterAndDatabasePackages,
    forbiddenFolders: <String>[
      'app/',
      'features/',
      'storage/database/',
      'storage/drift/',
    ],
    reason:
        'the scheduler is arithmetic. Keeping Flutter and SQLite out of it is '
        'what lets a due-date bug be reproduced in a plain unit test instead '
        'of by clicking through the app.',
  ),
  _FolderRule(
    folderName: 'settings',
    folderPath: 'lib/settings',
    forbiddenPackages: _flutterAndDatabasePackages,
    forbiddenFolders: <String>[
      'app/',
      'features/',
      'storage/database/',
      'storage/drift/',
    ],
    reason:
        'settings are plain values plus the rules for reading them back. The '
        'settings screen is a separate thing, in features/settings/.',
  ),
  _FolderRule(
    folderName: 'storage',
    folderPath: 'lib/storage',
    forbiddenPackages: <String>[
      'package:flutter_riverpod/',
      'package:riverpod/',
      'package:flutter/material.dart',
      'package:flutter/cupertino.dart',
    ],
    forbiddenFolders: <String>['app/', 'features/'],
    reason:
        'storage keeps the promises listed in storage/contracts/. It must not '
        'know which screen asked, or the database layer would have to change '
        'every time the UI does.',
  ),
  _FolderRule(
    folderName: 'features',
    folderPath: 'lib/features',
    forbiddenPackages: <String>['package:drift/', 'package:sqlite3/'],
    forbiddenFolders: <String>['storage/database/', 'storage/drift/'],
    reason:
        'a screen asks through storage/contracts/. The moment a screen writes '
        'a row itself, the same rule ends up implemented twice, differently.',
  ),
];

/// Matches the quoted path in `import '...'` and `export '...'`.
final RegExp _directivePattern = RegExp(
  """^\\s*(?:import|export)\\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

void main() {
  final Directory projectRoot = _findProjectRoot();

  group('folder rules', () {
    for (final _FolderRule rule in _rules) {
      test('${rule.folderName} imports only what it is allowed to', () {
        final Directory folder = Directory(
          '${projectRoot.path}/${rule.folderPath}',
        );
        if (!folder.existsSync()) {
          markTestSkipped('${rule.folderPath} does not exist yet');
          return;
        }

        final List<String> brokenRules = <String>[];
        for (final File file in _dartFilesIn(folder, rule.skippedSubfolders)) {
          final String relativePath = file.path
              .substring(projectRoot.path.length + 1)
              .replaceAll(r'\', '/');
          for (final RegExpMatch match in _directivePattern.allMatches(
            file.readAsStringSync(),
          )) {
            final String importedUri = match.group(1)!;
            for (final String forbidden in rule.forbiddenPackages) {
              if (importedUri.startsWith(forbidden)) {
                brokenRules.add('$relativePath imports $importedUri');
              }
            }
            for (final String forbidden in rule.forbiddenFolders) {
              if (importedUri.contains('incremental_reader/$forbidden')) {
                brokenRules.add('$relativePath reaches into $importedUri');
              }
            }
          }
        }

        expect(
          brokenRules,
          isEmpty,
          reason: '${rule.reason}\n  ${brokenRules.join('\n  ')}',
        );
      });
    }

    test('every folder named in the rules still exists', () {
      for (final _FolderRule rule in _rules) {
        expect(
          Directory('${projectRoot.path}/${rule.folderPath}').existsSync(),
          isTrue,
          reason: '${rule.folderPath} is missing',
        );
      }
    });
  });
}

/// Every hand-written `.dart` file under [folder], skipping generated code and
/// any subfolder that a later rule covers on its own terms.
Iterable<File> _dartFilesIn(Directory folder, List<String> skippedSubfolders) {
  final Set<String> skipped = skippedSubfolders
      .map((String name) => '${folder.path}/$name'.replaceAll(r'\', '/'))
      .toSet();
  return folder
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .where((File file) => !file.path.endsWith('.g.dart'))
      .where((File file) {
        final String path = file.path.replaceAll(r'\', '/');
        return !skipped.any((String prefix) => path.startsWith('$prefix/'));
      });
}

Directory _findProjectRoot() {
  Directory directory = Directory.current;
  while (!File('${directory.path}/pubspec.yaml').existsSync()) {
    final Directory parent = directory.parent;
    if (parent.path == directory.path) {
      fail('could not find pubspec.yaml above ${Directory.current.path}');
    }
    directory = parent;
  }
  return directory;
}
