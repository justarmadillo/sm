/// Database recovery shown before any database-dependent provider exists.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:incremental_reader/app/startup_gate.dart';
import 'package:incremental_reader/storage/files/backup_restore_service.dart';
import 'package:incremental_reader/storage/files/backup_service.dart';
import 'package:path/path.dart' as p;

/// Minimal application shell that remains usable when collection open fails.
final class RecoveryApp extends StatelessWidget {
  const RecoveryApp({
    required this.failure,
    required this.backupDirectory,
    super.key,
  });

  final StartupFailure failure;
  final Directory backupDirectory;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Incremental Reader recovery',
    debugShowCheckedModeBanner: false,
    home: RecoveryScreen(failure: failure, backupDirectory: backupDirectory),
  );
}

final class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    required this.failure,
    required this.backupDirectory,
    super.key,
  });

  final StartupFailure failure;
  final Directory backupDirectory;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

final class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _isRestoring = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final List<File> backups = listBackupFiles(widget.backupDirectory);
    return Scaffold(
      appBar: AppBar(title: const Text('Collection recovery')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            widget.failure.message,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'The collection was not opened, so no further changes were made. '
            'Choose a backup below, then relaunch the app after restoration.',
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          const SizedBox(height: 24),
          if (backups.isEmpty) const Text('No backups were found.'),
          for (final File backup in backups) _backupTile(backup),
        ],
      ),
    );
  }

  Widget _backupTile(File backup) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(p.basename(backup.path)),
    subtitle: Text(_formatBytes(backup.lengthSync())),
    trailing: FilledButton(
      onPressed: _isRestoring ? null : () => _restore(backup),
      child: Text(_isRestoring ? 'Restoring…' : 'Restore'),
    ),
  );

  Future<void> _restore(File backup) async {
    setState(() {
      _isRestoring = true;
      _message = null;
    });
    final result = await BackupRestoreService.fromBackupDirectory(
      widget.backupDirectory,
    ).restore(backup);
    if (!mounted) return;
    setState(() {
      _isRestoring = false;
      _message = result.isOk
          ? 'Backup restored. Close and relaunch the app.'
          : result.failureOrNull!.message;
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
