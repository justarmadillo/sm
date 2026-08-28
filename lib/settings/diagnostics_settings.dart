/// Whether the diagnostic log is written, how big it gets, and how many
/// files are kept.
library;

import 'package:meta/meta.dart';

/// The local rotating diagnostic log and the developer panel.
@immutable
final class DiagnosticsSettings {
  const DiagnosticsSettings({
    this.isLogEnabled = true,
    this.logMaxBytes = 2097152,
    this.logRetainedFiles = 5,
    this.shouldShowContentInPanel = false,
  });

  final bool isLogEnabled;
  final int logMaxBytes;
  final int logRetainedFiles;
  final bool shouldShowContentInPanel;

  DiagnosticsSettings copyWith({
    bool? isLogEnabled,
    int? logMaxBytes,
    int? logRetainedFiles,
    bool? shouldShowContentInPanel,
  }) => DiagnosticsSettings(
    isLogEnabled: isLogEnabled ?? this.isLogEnabled,
    logMaxBytes: logMaxBytes ?? this.logMaxBytes,
    logRetainedFiles: logRetainedFiles ?? this.logRetainedFiles,
    shouldShowContentInPanel: shouldShowContentInPanel ?? this.shouldShowContentInPanel,
  );

  @override
  bool operator ==(Object other) =>
      other is DiagnosticsSettings &&
      other.isLogEnabled == isLogEnabled &&
      other.logMaxBytes == logMaxBytes &&
      other.logRetainedFiles == logRetainedFiles &&
      other.shouldShowContentInPanel == shouldShowContentInPanel;

  @override
  int get hashCode => Object.hash(
    isLogEnabled,
    logMaxBytes,
    logRetainedFiles,
    shouldShowContentInPanel,
  );
}
