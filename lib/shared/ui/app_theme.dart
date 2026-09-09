/// The application's visual language.
///
/// Modelled on Notion: a warm paper canvas, white cards separated by hairlines
/// rather than shadows, near-black type, and exactly one structural accent —
/// here an orange rather than Notion's blue. Long-form reading is what this app
/// is for, so the chrome around the Reader stays quiet and the accent is spent
/// only on actions, links and the active state.
///
/// One light theme only. There is no dark theme and no [ThemeMode] switch: the
/// paper canvas is the brand, and a second palette would double every colour
/// decision below for a surface the reader never asked for.
library;

import 'package:flutter/material.dart';

/// Palette. Small on purpose — every colour here has one job.
///
/// Five hues carry every signal in the app, and each one is dark enough to
/// pass WCAG AA (4.5:1) as text on [surface], because all five are used as ink
/// somewhere: orange for actions and topics, purple for extracts, green for
/// cards, teal for soft markers and video, red for failure.
abstract final class AppColors {
  /// Page background behind the reading column: a warm paper, not a clinical
  /// white. White is reserved for [surface] so cards read as figures standing
  /// on the page.
  static const Color background = Color(0xFFF7F6F3);

  /// Surface of cards, bars, and panels.
  static const Color surface = Color(0xFFFFFFFF);

  /// One step below [background], for a row or panel that must recede behind
  /// the surface it sits beside without becoming a second card.
  static const Color surfaceSunken = Color(0xFFF2F0EC);

  /// Primary body text.
  static const Color text = Color(0xFF1A1A1A);

  /// Secondary text: metadata, hints, counts.
  static const Color muted = Color(0xFF615D59);

  /// Captions and placeholders — the quietest ink that is still legible.
  /// Never use it for anything the reader has to act on.
  static const Color faint = Color(0xFFA39E98);

  /// Hairlines and dividers. Warm, so it disappears into [background] instead
  /// of ruling a grey line across the paper.
  static const Color border = Color(0xFFE7E4DF);

  /// Accent used for actions and the resume marker.
  ///
  /// This is the deep end of the orange ramp, not the brand orange
  /// [accentBright], because the accent is used as *ink* far more often than
  /// as a fill: buttons, icons, active tabs, link text. At 5.0:1 against
  /// [surface] it is readable in both directions — dark orange text on white,
  /// and white text on a dark orange button.
  static const Color accent = Color(0xFFB0561B);

  /// The brand orange. Too light to carry text either way — 2.5:1 against both
  /// white and black — so it is spent only on shapes that mean something by
  /// their size or position: indicator bars, marker dots, progress fills.
  static const Color accentBright = Color(0xFFE8873A);

  /// Pointer-over state of an [accent] fill.
  static const Color accentHover = Color(0xFFC2611C);

  /// Pressed state of an [accent] fill.
  static const Color accentPressed = Color(0xFF8F4413);

  /// The lightest orange: the tint behind a selected row, a hovered menu item,
  /// or an [accent]-inked chip. Light enough that [accent] and [text] both
  /// stay readable on it.
  static const Color accentWash = Color(0xFFFDF1E7);

  /// Wash behind an active text selection.
  static const Color selection = Color(0x33E8873A);

  /// The soft position indicator, distinct from the explicit marker.
  ///
  /// Teal rather than a second orange: "roughly where you were" and "the place
  /// you marked" must never read as the same signal, and two tones of one hue
  /// is exactly how they would. The same teal carries every other quiet,
  /// non-urgent flag — the pending lane, a leech, a video.
  static const Color softMarker = Color(0xFF2A7F7B);

  /// Ink of everything that refers to an extract: gutter bars, panel rows,
  /// and the rule under extracted text. Deliberately not the accent, so
  /// "where I stopped reading" and "what I already took out" never read as
  /// the same signal.
  static const Color extractInk = Color(0xFF6C4E9E);

  /// Persistent wash behind text that has already been extracted. Weak on
  /// purpose: it must survive on every paragraph without fighting the words.
  static const Color extractWash = Color(0x146C4E9E);

  /// The same wash for the one extract the user is currently looking at,
  /// after choosing it in the side panel.
  static const Color extractFocusWash = Color(0x4D6C4E9E);

  /// Ink of everything that refers to a card, so a mixed list can say which
  /// rows are cards without repeating the word on every one.
  static const Color cardInk = Color(0xFF4A7C59);

  /// Failure: an error toast, a destructive confirmation, the region being
  /// asked about on an occlusion.
  static const Color danger = Color(0xFFA33A2C);

  /// The tint behind a [danger] message that is a warning rather than a stop.
  static const Color dangerWash = Color(0xFFFBECE9);

  /// Background of inline and block code.
  static const Color codeBackground = Color(0xFFF3F1ED);

  /// Wash behind a row the user has dismissed. Warm and desaturated: a
  /// dismissed row still has to be readable, and it must not compete with
  /// [selection] one row below it.
  static const Color dismissedWash = Color(0xFFF5EFD9);

  /// Fill of an occlusion mask — a warm near-black, so a masked rectangle
  /// reads as part of this app rather than as a hole punched by another one.
  static const Color mask = Color(0xFF2B2724);
}

/// The 8px spacing scale.
///
/// Named by how much room the gap gives rather than by a size letter, so a
/// call site says what it wants: `AppSpacing.tight` between an icon and its
/// label, `AppSpacing.section` between two blocks of a settings page.
abstract final class AppSpacing {
  /// 4 — inside a chip, between an icon and the word next to it.
  static const double hair = 4;

  /// 8 — the base unit; between controls in one row.
  static const double tight = 8;

  /// 12 — between rows of a list.
  static const double snug = 12;

  /// 16 — the default padding of a bar or a small panel.
  static const double standard = 16;

  /// 24 — the interior padding of a card.
  static const double loose = 24;

  /// 28 — between a card and the one below it.
  static const double wide = 28;

  /// 32 — between two sections of a screen.
  static const double section = 32;
}

/// The corner radius scale.
///
/// The contrast between the shapes is deliberate and worth preserving: a form
/// field stays nearly square at [field] while a badge is a full [pill], and
/// the difference is what tells the two apart at a glance.
abstract final class AppRadius {
  /// 4 — form fields, small tags, inline chips.
  static const double field = 4;

  /// 6 — menu items and list rows.
  static const double row = 6;

  /// 8 — buttons, toolbars, popovers, small cards.
  static const double button = 8;

  /// 12 — cards and content tiles.
  static const double card = 12;

  /// 16 — dialogs, sheets, image wells.
  static const double panel = 16;

  /// A full pill: badges, status labels, circular icon buttons.
  static const double pill = 999;
}

/// Elevation, built the way Notion builds it: many near-transparent layers, so
/// a surface looks gently lifted off the paper instead of dropped onto it.
///
/// Most surfaces should use neither of these. A hairline [AppColors.border] is
/// the default way to say "this is a separate thing"; a shadow is for something
/// that genuinely floats over content — a toolbar over the text it acts on, a
/// dialog over the screen.
abstract final class AppShadows {
  /// Level 1 — a toolbar, a floating button, a card that must lift slightly
  /// off the canvas.
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x07000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 4)),
  ];

  /// Level 2 — modals, popovers, toasts.
  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0C000000), blurRadius: 14, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 52, offset: Offset(0, 23)),
  ];
}

/// The type ramp of the chrome — everything outside the reading column, which
/// has its own scale in [ReaderTypography].
///
/// Headings carry weight and negative tracking; body copy stays at weight 400
/// and a comfortable line height. That contrast is the only expressive lever
/// the type uses, which is why none of these styles carry a colour: the colour
/// comes from the [AppColors] role the text is playing.
abstract final class AppTextStyles {
  /// A screen's own title, the largest type in the chrome.
  static const TextStyle heading = TextStyle(
    fontSize: 22,
    height: 1.27,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  /// A section heading inside a screen.
  static const TextStyle subheading = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  /// The title of a card or a settings row.
  static const TextStyle title = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  /// Default body copy.
  static const TextStyle body = TextStyle(fontSize: 15, height: 1.45);

  /// Dense body: list rows, table cells, navigation.
  static const TextStyle bodyDense = TextStyle(fontSize: 13, height: 1.35);

  /// Button labels.
  static const TextStyle button = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  /// Captions, footnotes and counts.
  static const TextStyle caption = TextStyle(fontSize: 12, height: 1.4);

  /// The smallest label: a badge, a status pill, a column header.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}

/// The single application theme.
ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: _scheme,
  scaffoldBackgroundColor: AppColors.background,
  canvasColor: AppColors.surface,
  dividerColor: AppColors.border,
  // Inter is the face Notion's own type is cut from. It is not bundled, so
  // this asks for it and falls back to whatever the platform ships; the ramp
  // in [AppTextStyles] is what actually carries the voice.
  fontFamily: 'Inter',
  fontFamilyFallback: const <String>[
    'Segoe UI Variable',
    'Segoe UI',
    'Roboto',
    'Helvetica',
    'Arial',
  ],
  visualDensity: VisualDensity.standard,
  textTheme: _textTheme,
  appBarTheme: _appBarTheme,
  dividerTheme: _dividerTheme,
  cardTheme: _cardTheme,
  dialogTheme: _dialogTheme,
  popupMenuTheme: _popupMenuTheme,
  menuTheme: _menuTheme,
  tooltipTheme: _tooltipTheme,
  listTileTheme: _listTileTheme,
  inputDecorationTheme: _inputDecorationTheme,
  textSelectionTheme: _textSelectionTheme,
  textButtonTheme: _textButtonTheme,
  filledButtonTheme: _filledButtonTheme,
  outlinedButtonTheme: _outlinedButtonTheme,
  elevatedButtonTheme: _elevatedButtonTheme,
  iconButtonTheme: _iconButtonTheme,
  segmentedButtonTheme: _segmentedButtonTheme,
  chipTheme: _chipTheme,
  sliderTheme: _sliderTheme,
  progressIndicatorTheme: _progressIndicatorTheme,
  scrollbarTheme: _scrollbarTheme,
  snackBarTheme: _snackBarTheme,
  bottomSheetTheme: _bottomSheetTheme,
  switchTheme: _switchTheme,
  checkboxTheme: _checkboxTheme,
  radioTheme: _radioTheme,
);

/// Every "on" colour is spelled out, and so is every surface step.
///
/// Two traps live here. Material fills selected chips, tonal buttons and
/// indicators from the *container* roles, and a role left unset keeps
/// Material's own default ink — which is black; naming only the orange half of
/// a pair is what would put black text on an orange chip. And Material 3
/// derives its own surface steps unless they are named, which on a warm paper
/// canvas produces cold lavender-grey panels.
const ColorScheme _scheme = ColorScheme(
  brightness: Brightness.light,
  primary: AppColors.accent,
  onPrimary: Colors.white,
  primaryContainer: AppColors.accentWash,
  onPrimaryContainer: AppColors.accent,
  secondary: AppColors.accent,
  onSecondary: Colors.white,
  secondaryContainer: AppColors.accentWash,
  onSecondaryContainer: AppColors.accent,
  tertiary: AppColors.softMarker,
  onTertiary: Colors.white,
  tertiaryContainer: AppColors.surfaceSunken,
  onTertiaryContainer: AppColors.softMarker,
  error: AppColors.danger,
  onError: Colors.white,
  errorContainer: AppColors.dangerWash,
  onErrorContainer: AppColors.danger,
  surface: AppColors.surface,
  onSurface: AppColors.text,
  surfaceDim: AppColors.surfaceSunken,
  surfaceBright: AppColors.surface,
  surfaceContainerLowest: AppColors.surface,
  surfaceContainerLow: Color(0xFFFBFAF8),
  surfaceContainer: AppColors.background,
  surfaceContainerHigh: AppColors.surfaceSunken,
  surfaceContainerHighest: Color(0xFFEDEAE4),
  onSurfaceVariant: AppColors.muted,
  outline: AppColors.border,
  outlineVariant: Color(0xFFEFECE7),
  // No tonal overlay on raised surfaces: elevation here is a hairline or one
  // of the [AppShadows] stacks, never a tint that would warm-shift a white
  // card into peach.
  surfaceTint: Colors.transparent,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: AppColors.text,
  onInverseSurface: Colors.white,
  inversePrimary: AppColors.accentBright,
);

final TextTheme _textTheme = const TextTheme()
    .copyWith(
      headlineSmall: AppTextStyles.heading,
      titleLarge: AppTextStyles.subheading,
      titleMedium: AppTextStyles.title,
      titleSmall: AppTextStyles.eyebrow,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.bodyDense,
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.caption,
      labelSmall: AppTextStyles.eyebrow,
    )
    .apply(bodyColor: AppColors.text, displayColor: AppColors.text);

/// The bar sits on the page, not above it: same paper, no hairline, no
/// shadow. A white strip with a rule under it split every screen into chrome
/// and content, and the split was the loudest edge on the screen — louder
/// than the cards it was meant to frame.
const AppBarTheme _appBarTheme = AppBarTheme(
  backgroundColor: AppColors.background,
  foregroundColor: AppColors.text,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  scrolledUnderElevation: 0,
  centerTitle: false,
  titleTextStyle: TextStyle(
    color: AppColors.text,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  ),
  iconTheme: IconThemeData(color: AppColors.text, size: 20),
  actionsIconTheme: IconThemeData(color: AppColors.muted, size: 20),
);

/// A hairline that takes up one pixel and no more: `space` defaults to 16,
/// which would open a gap on both sides of every divider in a dense list.
const DividerThemeData _dividerTheme = DividerThemeData(
  color: AppColors.border,
  thickness: 1,
  space: 1,
);

const CardThemeData _cardTheme = CardThemeData(
  color: AppColors.surface,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
    side: BorderSide(color: AppColors.border),
  ),
);

const DialogThemeData _dialogTheme = DialogThemeData(
  backgroundColor: AppColors.surface,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.panel)),
    side: BorderSide(color: AppColors.border),
  ),
  titleTextStyle: TextStyle(
    color: AppColors.text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  ),
  contentTextStyle: TextStyle(
    color: AppColors.text,
    fontSize: 14,
    height: 1.45,
  ),
);

const PopupMenuThemeData _popupMenuTheme = PopupMenuThemeData(
  color: AppColors.surface,
  surfaceTintColor: Colors.transparent,
  elevation: 3,
  shadowColor: Color(0x1F000000),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
    side: BorderSide(color: AppColors.border),
  ),
  textStyle: TextStyle(color: AppColors.text, fontSize: 14),
);

const MenuThemeData _menuTheme = MenuThemeData(
  style: MenuStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(AppColors.surface),
    surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
    elevation: WidgetStatePropertyAll<double>(3),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
  ),
);

const TooltipThemeData _tooltipTheme = TooltipThemeData(
  decoration: BoxDecoration(
    color: AppColors.text,
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.row)),
  ),
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  textStyle: TextStyle(color: Colors.white, fontSize: 12),
  waitDuration: Duration(milliseconds: 400),
);

const ListTileThemeData _listTileTheme = ListTileThemeData(
  iconColor: AppColors.muted,
  textColor: AppColors.text,
  selectedColor: AppColors.accent,
  selectedTileColor: AppColors.accentWash,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.row)),
  ),
);

/// Fields stay nearly square at [AppRadius.field] — a pill-shaped input would
/// read as a button, and the button is the one thing on the screen that has to
/// be unmistakable.
final InputDecorationTheme _inputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: AppColors.surface,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  hintStyle: const TextStyle(color: AppColors.faint, fontSize: 14),
  // A unit is not part of the value the user typed, so it is inked as the
  // label it is rather than as more of the number.
  suffixStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
  labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
  floatingLabelStyle: const TextStyle(color: AppColors.accent, fontSize: 14),
  border: _fieldBorder(AppColors.border),
  enabledBorder: _fieldBorder(AppColors.border),
  focusedBorder: _fieldBorder(AppColors.accent, width: 1.5),
  errorBorder: _fieldBorder(AppColors.danger),
  focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.5),
  disabledBorder: _fieldBorder(AppColors.border),
);

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.field)),
      borderSide: BorderSide(color: color, width: width),
    );

const TextSelectionThemeData _textSelectionTheme = TextSelectionThemeData(
  cursorColor: AppColors.accent,
  selectionColor: AppColors.selection,
  selectionHandleColor: AppColors.accent,
);

final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
  style: TextButton.styleFrom(
    foregroundColor: AppColors.accent,
    textStyle: AppTextStyles.button,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 34),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
    ),
  ).copyWith(overlayColor: _overlay(AppColors.accent)),
);

/// The one filled action on a screen. Flat: a shadow under a button that is
/// already the only orange thing in view says nothing the colour has not.
final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
  style:
      FilledButton.styleFrom(
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.surfaceSunken,
        disabledForegroundColor: AppColors.faint,
        elevation: 0,
        textStyle: AppTextStyles.button,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minimumSize: const Size(0, 36),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
        ),
      ).copyWith(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.surfaceSunken;
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.accentPressed;
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.accentHover;
          }
          return AppColors.accent;
        }),
      ),
);

final OutlinedButtonThemeData _outlinedButtonTheme = OutlinedButtonThemeData(
  style: OutlinedButton.styleFrom(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.text,
    textStyle: AppTextStyles.button,
    side: const BorderSide(color: AppColors.border),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    minimumSize: const Size(0, 36),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
    ),
  ).copyWith(overlayColor: _overlay(AppColors.text)),
);

/// Kept in step with the outlined button rather than with Material's raised
/// default, so a screen that reaches for either gets the same white utility
/// button and no stray drop shadow.
final ElevatedButtonThemeData _elevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.text,
    disabledBackgroundColor: AppColors.surfaceSunken,
    disabledForegroundColor: AppColors.faint,
    elevation: 0,
    textStyle: AppTextStyles.button,
    side: const BorderSide(color: AppColors.border),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    minimumSize: const Size(0, 36),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
    ),
  ).copyWith(overlayColor: _overlay(AppColors.text)),
);

final IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
  style: IconButton.styleFrom(
    foregroundColor: AppColors.muted,
    highlightColor: AppColors.accentWash,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.row)),
    ),
  ).copyWith(overlayColor: _overlay(AppColors.text)),
);

final SegmentedButtonThemeData _segmentedButtonTheme = SegmentedButtonThemeData(
  style: SegmentedButton.styleFrom(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.muted,
    selectedBackgroundColor: AppColors.accentWash,
    selectedForegroundColor: AppColors.accent,
    side: const BorderSide(color: AppColors.border),
    textStyle: AppTextStyles.button,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
    ),
  ),
);

const ChipThemeData _chipTheme = ChipThemeData(
  backgroundColor: AppColors.surface,
  selectedColor: AppColors.accentWash,
  checkmarkColor: AppColors.accent,
  side: BorderSide(color: AppColors.border),
  labelStyle: TextStyle(color: AppColors.text, fontSize: 13),
  secondaryLabelStyle: TextStyle(color: AppColors.accent, fontSize: 13),
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.field)),
  ),
);

/// The track uses the brand orange rather than the accent: a slider track is a
/// shape whose length carries the meaning, which is exactly the job
/// [AppColors.accentBright] exists for.
const SliderThemeData _sliderTheme = SliderThemeData(
  activeTrackColor: AppColors.accentBright,
  inactiveTrackColor: AppColors.surfaceSunken,
  thumbColor: AppColors.accent,
  overlayColor: AppColors.selection,
  trackHeight: 3,
);

const ProgressIndicatorThemeData _progressIndicatorTheme =
    ProgressIndicatorThemeData(
      color: AppColors.accentBright,
      linearTrackColor: AppColors.surfaceSunken,
      circularTrackColor: AppColors.surfaceSunken,
    );

final ScrollbarThemeData _scrollbarTheme = ScrollbarThemeData(
  thickness: const WidgetStatePropertyAll<double>(8),
  radius: const Radius.circular(AppRadius.button),
  thumbColor: WidgetStateProperty.resolveWith<Color?>(
    (Set<WidgetState> states) => states.contains(WidgetState.hovered)
        ? const Color(0x59615D59)
        : const Color(0x33615D59),
  ),
);

const SnackBarThemeData _snackBarTheme = SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor: AppColors.text,
  contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
  actionTextColor: AppColors.accentBright,
  elevation: 3,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
  ),
);

const BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
  backgroundColor: AppColors.surface,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
  ),
);

final SwitchThemeData _switchTheme = SwitchThemeData(
  thumbColor: WidgetStateProperty.resolveWith<Color?>(
    (Set<WidgetState> states) =>
        states.contains(WidgetState.selected) ? Colors.white : AppColors.muted,
  ),
  trackColor: WidgetStateProperty.resolveWith<Color?>(
    (Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? AppColors.accent
        : AppColors.surfaceSunken,
  ),
  trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
    (Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? AppColors.accent
        : AppColors.border,
  ),
);

final CheckboxThemeData _checkboxTheme = CheckboxThemeData(
  fillColor: WidgetStateProperty.resolveWith<Color?>(
    (Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? AppColors.accent
        : Colors.transparent,
  ),
  checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
  side: const BorderSide(color: AppColors.border, width: 1.5),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(3)),
  ),
);

final RadioThemeData _radioTheme = RadioThemeData(
  fillColor: WidgetStateProperty.resolveWith<Color?>(
    (Set<WidgetState> states) => states.contains(WidgetState.selected)
        ? AppColors.accent
        : AppColors.border,
  ),
);

/// Hover and press states as a wash of the control's own ink, so nothing picks
/// up Material's default grey ripple on the warm canvas.
WidgetStateProperty<Color?> _overlay(Color ink) =>
    WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.pressed)) {
        return ink.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return ink.withValues(alpha: 0.06);
      }
      return null;
    });

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
  ///
  /// Tracking tightens as the heading grows, the way it does in the chrome:
  /// at these sizes a heading set at body tracking reads stretched.
  TextStyle heading(int level) {
    const scale = <int, double>{1: 1.7, 2: 1.4, 3: 1.2, 4: 1.1, 5: 1, 6: 1};
    const tracking = <int, double>{1: -0.8, 2: -0.5, 3: -0.25, 4: -0.15};
    return body.copyWith(
      fontSize: fontSize * (scale[level] ?? 1),
      height: 1.3,
      fontWeight: level <= 2 ? FontWeight.w700 : FontWeight.w600,
      letterSpacing: tracking[level] ?? 0,
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
