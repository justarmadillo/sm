/// Where automatic backups are mirrored and how often they are due.
library;

import 'package:meta/meta.dart';

/// Supported fixed cadences for automatic collection backups.
enum AutomaticBackupInterval {
  daily(1),
  everyThreeDays(3),
  weekly(7);

  const AutomaticBackupInterval(this.days);

  final int days;
}

/// Installation-facing automatic backup preferences.
@immutable
final class BackupSettings {
  const BackupSettings({
    this.interval = AutomaticBackupInterval.daily,
    this.directoryLocation = '',
    this.directoryLabel = '',
  });

  final AutomaticBackupInterval interval;

  /// A Windows directory path or an Android persisted document-tree URI.
  final String directoryLocation;

  /// Human-readable form of [directoryLocation] shown in Settings.
  final String directoryLabel;

  bool get hasSelectedDirectory => directoryLocation.isNotEmpty;

  BackupSettings copyWith({
    AutomaticBackupInterval? interval,
    String? directoryLocation,
    String? directoryLabel,
  }) => BackupSettings(
    interval: interval ?? this.interval,
    directoryLocation: directoryLocation ?? this.directoryLocation,
    directoryLabel: directoryLabel ?? this.directoryLabel,
  );

  @override
  bool operator ==(Object other) =>
      other is BackupSettings &&
      other.interval == interval &&
      other.directoryLocation == directoryLocation &&
      other.directoryLabel == directoryLabel;

  @override
  int get hashCode => Object.hash(interval, directoryLocation, directoryLabel);
}
