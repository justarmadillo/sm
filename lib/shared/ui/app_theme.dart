/// The application's visual language.
///
/// Deliberately plain: one light theme, few colours, and typography tuned for
/// long-form reading. The Reader is where the user spends their time, so the
/// chrome around it stays quiet.
library;

import 'package:flutter/material.dart';

/// Palette. Small on purpose — every colour here has one job.
abstract final class AppColors {
  /// Page background behind the reading column.
  static const Color background = Color(0xFFFBFAF8);

  /// Surface of cards, bars, and panels.
  static const Color surface = Color(0xFFFFFFFF);

  /// Primary body text.
  static const Color text = Color(0xFF1C1B1A);

  /// Secondary text: metadata, hints, counts.
  static const Color muted = Color(0xFF6B6862);

  /// Hairlines and dividers.
  static const Color border = Color(0xFFE3E0DA);

  /// Accent used for actions and the resume marker.
  static const Color accent = Color(0xFF2F6F4F);

  /// Wash behind an active text selection.
  static const Color selection = Color(0x332F6F4F);

  /// The soft position indicator, distinct from the explicit marker.
  static const Color softMarker = Color(0xFFB08A3E);

  /// Ink of everything that refers to an extract: gutter bars, panel rows,
  /// and the rule under extracted text. Deliberately not the accent, so
  /// "where I stopped reading" and "what I already took out" never read as
  /// the same signal.
  static const Color extractInk = Color(0xFF3E6FA8);

  /// Persistent wash behind text that has already been extracted. Weak on
  /// purpose: it must survive on every paragraph without fighting the words.
  static const Color extractWash = Color(0x143E6FA8);

  /// The same wash for the one extract the user is currently looking at,
  /// after choosing it in the side panel.
  static const Color extractFocusWash = Color(0x4D3E6FA8);

  /// Background of inline and block code.
  static const Color codeBackground = Color(0xFFF2F0EC);
}

/// The single application theme.
ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.accent,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.border,
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: AppColors.border)),
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
    ),
  );
}

/// Typography of the reading column.
///
/// Held separately from [ThemeData] because the plan calls for per-source
/// overrides: a source can carry its own size and measure without the rest of
/// the application changing.
@immutable
final class ReaderTypography {
  const ReaderTypography({
    this.fontFamily,
    this.fontSize = 18,
    this.lineHeight = 1.65,
    this.paragraphSpacing = 18,
    this.columnWidth = 720,
  });

  /// Reader defaults.
  static const ReaderTypography standard = ReaderTypography();

  final String? fontFamily;
  final double fontSize;

  /// Multiple of [fontSize].
  final double lineHeight;

  /// Vertical gap between blocks, in logical pixels.
  final double paragraphSpacing;

  /// Maximum measure of the reading column, in logical pixels.
  final double columnWidth;

  /// Base body style.
  TextStyle get body => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize,
    height: lineHeight,
    color: AppColors.text,
  );

  /// Style for a heading of [level].
  TextStyle heading(int level) {
    const scale = <int, double>{1: 1.7, 2: 1.4, 3: 1.2, 4: 1.1, 5: 1, 6: 1};
    return body.copyWith(
      fontSize: fontSize * (scale[level] ?? 1),
      height: 1.3,
      fontWeight: level <= 2 ? FontWeight.w700 : FontWeight.w600,
    );
  }

  /// Style for code, inline and block.
  TextStyle get code => body.copyWith(
    fontFamily: 'Consolas',
    fontSize: fontSize * 0.9,
    height: 1.5,
  );

  ReaderTypography copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? columnWidth,
  }) => ReaderTypography(
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    columnWidth: columnWidth ?? this.columnWidth,
  );
}
