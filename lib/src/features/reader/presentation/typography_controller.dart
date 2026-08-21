/// Reader typography, persisted across sessions.
///
/// Reading settings are the kind a user adjusts once and expects to hold, so
/// they are written to the settings store rather than kept in view state. The
/// values are global; per-source overrides layer on top of them later without
/// changing this shape.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';

/// Setting keys for the reading column.
const String kFontSizeKey = 'reader.font_size';

/// Setting key for the measure of the reading column.
const String kColumnWidthKey = 'reader.column_width';

/// Setting key for line height.
const String kLineHeightKey = 'reader.line_height';

/// Smallest and largest offered body size.
const double kMinFontSize = 13;

/// Largest offered body size.
const double kMaxFontSize = 30;

/// Holds the current reading typography and persists changes.
final class ReaderTypographyNotifier extends Notifier<ReaderTypography> {
  bool _changedLocally = false;
  Future<void> _writes = Future<void>.value();

  @override
  ReaderTypography build() {
    // Start from the defaults and refine once storage answers, so the first
    // frame never waits on a disk read.
    unawaited(_restore());
    return ReaderTypography.standard;
  }

  Future<void> _restore() async {
    final settings = ref.read(settingsRepositoryProvider);
    final Map<String, String> stored;
    try {
      stored = await settings.readAll();
    } on Object {
      return;
    }
    if (_changedLocally) return;
    final fontSize = double.tryParse(stored[kFontSizeKey] ?? '');
    final columnWidth = double.tryParse(stored[kColumnWidthKey] ?? '');
    final lineHeight = double.tryParse(stored[kLineHeightKey] ?? '');
    if (fontSize == null && columnWidth == null && lineHeight == null) return;

    state = state.copyWith(
      fontSize: fontSize,
      columnWidth: columnWidth,
      lineHeight: lineHeight,
    );
  }

  /// Changes the body size by [delta] points, within the offered range.
  void nudgeFontSize(double delta) {
    final next = (state.fontSize + delta).clamp(kMinFontSize, kMaxFontSize);
    if (next == state.fontSize) return;
    _apply(state.copyWith(fontSize: next));
  }

  /// Sets the measure of the reading column.
  void setColumnWidth(double width) {
    final next = width.clamp(520.0, 1100.0);
    if (next == state.columnWidth) return;
    _apply(state.copyWith(columnWidth: next));
  }

  /// Sets the line height, as a multiple of the font size.
  void setLineHeight(double height) {
    final next = height.clamp(1.3, 2.2);
    if (next == state.lineHeight) return;
    _apply(state.copyWith(lineHeight: next));
  }

  /// Returns to the shipped defaults.
  void reset() => _apply(ReaderTypography.standard);

  void _apply(ReaderTypography next) {
    _changedLocally = true;
    state = next;
    _writes = _writes.then((_) async {
      final settings = ref.read(settingsRepositoryProvider);
      // A failed preference write must not interrupt reading.
      try {
        await settings.write(kFontSizeKey, '${next.fontSize}');
        await settings.write(kColumnWidthKey, '${next.columnWidth}');
        await settings.write(kLineHeightKey, '${next.lineHeight}');
      } on Object {
        return;
      }
    });
    unawaited(_writes);
  }
}

/// Current reading typography.
final NotifierProvider<ReaderTypographyNotifier, ReaderTypography>
readerTypographyProvider =
    NotifierProvider<ReaderTypographyNotifier, ReaderTypography>(
      ReaderTypographyNotifier.new,
    );
