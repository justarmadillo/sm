/// Whether the diagnostic log is written, how big it gets, and how many
/// files are kept.
library;

import 'package:meta/meta.dart';

/// The local rotating diagnostic log and the developer panel.
@immutable
final class DiagnosticsSettings {
  const DiagnosticsSettings({
    this.logEnabled = true,
    this.logMaxBytes = 2097152,
    this.logRetainedFiles = 5,
    this.showContentInPanel = false,
  });

  final bool logEnabled;
  final int logMaxBytes;
  final int logRetainedFiles;
  final bool showContentInPanel;

  DiagnosticsSettings copyWith({
    bool? logEnabled,
    int? logMaxBytes,
    int? logRetainedFiles,
    bool? showContentInPanel,
  }) => DiagnosticsSettings(
    logEnabled: logEnabled ?? this.logEnabled,
    logMaxBytes: logMaxBytes ?? this.logMaxBytes,
    logRetainedFiles: logRetainedFiles ?? this.logRetainedFiles,
    showContentInPanel: showContentInPanel ?? this.showContentInPanel,
  );

  @override
  bool operator ==(Object other) =>
      other is DiagnosticsSettings &&
      other.logEnabled == logEnabled &&
      other.logMaxBytes == logMaxBytes &&
      other.logRetainedFiles == logRetainedFiles &&
      other.showContentInPanel == showContentInPanel;

  @override
  int get hashCode => Object.hash(
    logEnabled,
    logMaxBytes,
    logRetainedFiles,
    showContentInPanel,
  );
}
