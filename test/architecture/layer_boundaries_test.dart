/// Enforces the dependency rule mechanically.
///
/// Layering that is only written down erodes: one convenient
/// `import 'package:flutter/material.dart'` in a domain file, and the
/// schedulers can no longer be tested without a widget binding. This test
/// fails the build instead.
library;

import 'dart:io';

import 'package:test/test.dart';

/// One layer and what it is allowed to depend on.
final class _LayerRule {
  const _LayerRule({
    required this.name,
    required this.directory,
    required this.forbiddenPackages,
    required this.forbiddenLayers,
    this.reason = '',
  });

  final String name;
  final String directory;

  /// `package:` prefixes this layer must never import.
  final List<String> forbiddenPackages;

  /// Sibling layer directories this layer must never reach into.
  final List<String> forbiddenLayers;

  final String reason;
}

const List<_LayerRule> _rules = <_LayerRule>[
  _LayerRule(
    name: 'domain',
    directory: 'lib/src/domain',
    forbiddenPackages: <String>[
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:riverpod/',
      'package:drift/',
      'package:drift_flutter/',
      'package:sqlite3/',
      'package:path_provider/',
      'package:scrollable_positioned_list/',
    ],
    forbiddenLayers: <String>['data/', 'features/', 'app/', 'application/'],
    reason:
        'domain must stay pure Dart so schedulers and anchors are '
        'testable without Flutter or SQLite',
  ),
  _LayerRule(
    name: 'application',
    directory: 'lib/src/application',
    forbiddenPackages: <String>[
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:riverpod/',
      'package:drift/',
      'package:drift_flutter/',
      'package:sqlite3/',
      'package:path_provider/',
    ],
    forbiddenLayers: <String>['data/', 'features/', 'app/'],
    reason:
        'handlers coordinate domain and repository interfaces, never '
        'concrete storage or widgets',
  ),
  _LayerRule(
    name: 'core',
    directory: 'lib/src/core',
    forbiddenPackages: <String>[
      'package:flutter/',
      'package:flutter_riverpod/',
      'package:riverpod/',
      'package:drift/',
    ],
    forbiddenLayers: <String>[
      'domain/',
      'application/',
      'data/',
      'features/',
      'app/',
    ],
    reason: 'core is the innermost layer and depends on nothing above it',
  ),
  _LayerRule(
    name: 'data',
    directory: 'lib/src/data',
    forbiddenPackages: <String>[
      'package:flutter_riverpod/',
      'package:riverpod/',
      'package:flutter/material.dart',
      'package:flutter/cupertino.dart',
    ],
    forbiddenLayers: <String>['features/', 'app/'],
    reason:
        'storage implements application ports and knows nothing about '
        'presentation or dependency wiring',
  ),
  _LayerRule(
    name: 'features',
    directory: 'lib/src/features',
    forbiddenPackages: <String>['package:drift/', 'package:sqlite3/'],
    forbiddenLayers: <String>['data/database/', 'data/repositories/'],
    reason:
        'presentation talks to view models and application APIs, never '
        'to DAOs',
  ),
];

final RegExp _importPattern = RegExp(
  """^\\s*(?:import|export)\\s+['"]([^'"]+)['"]""",
  multiLine: true,
);

void main() {
  final projectRoot = _findProjectRoot();

  group('layer boundaries', () {
    for (final rule in _rules) {
      test('${rule.name} imports stay inside its allowed dependencies', () {
        final directory = Directory('${projectRoot.path}/${rule.directory}');
        if (!directory.existsSync()) {
          markTestSkipped('${rule.directory} does not exist yet');
          return;
        }

        final violations = <String>[];
        for (final file in _dartFilesIn(directory)) {
          final relative = file.path
              .substring(projectRoot.path.length + 1)
              .replaceAll(r'\', '/');
          for (final match in _importPattern.allMatches(
            file.readAsStringSync(),
          )) {
            final uri = match.group(1)!;
            for (final forbidden in rule.forbiddenPackages) {
              if (uri.startsWith(forbidden)) {
                violations.add('$relative imports $uri');
              }
            }
            for (final layer in rule.forbiddenLayers) {
              if (uri.contains('/$layer') || uri.startsWith(layer)) {
                violations.add('$relative reaches into $uri');
              }
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason: '${rule.reason}\n  ${violations.join('\n  ')}',
        );
      });
    }

    test('every layer directory in the plan exists', () {
      for (final rule in _rules) {
        expect(
          Directory('${projectRoot.path}/${rule.directory}').existsSync(),
          isTrue,
          reason: '${rule.directory} is missing',
        );
      }
    });
  });
}

Iterable<File> _dartFilesIn(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .where((File f) => !f.path.endsWith('.g.dart'));

Directory _findProjectRoot() {
  var directory = Directory.current;
  while (!File('${directory.path}/pubspec.yaml').existsSync()) {
    final parent = directory.parent;
    if (parent.path == directory.path) {
      fail('could not find pubspec.yaml above ${Directory.current.path}');
    }
    directory = parent;
  }
  return directory;
}
