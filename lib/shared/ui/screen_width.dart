/// How much horizontal room a screen has, in the only two sizes the layouts
/// care about.
///
/// This app was written for a desktop window and now also runs on a phone held
/// in one hand. Rather than scatter pixel comparisons through every screen,
/// each layout asks the one question that changes what it draws: is there room
/// for two things side by side, or only one?
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Below this many logical pixels a layout is drawn as a single column.
///
/// 720 is where the Reader's 280-pixel side panel stops leaving a readable
/// measure beside it, and that is the tightest of the app's two-pane screens.
const double kCompactWidthLimit = 720;

/// True when the window is too narrow for a docked panel beside the content,
/// or for a toolbar that lays every button out in one row.
bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactWidthLimit;

/// Space a Material dialog reserves outside its content: the 40-pixel inset on
/// each side of the dialog, plus the 24 pixels of content padding on each side.
const double _kDialogChrome = 128;

/// The width a dialog's body may actually take.
///
/// The dialogs here were sized for a desktop window, and a fixed
/// `SizedBox(width: 620)` on a phone overflows the screen rather than
/// shrinking to it. This keeps the desktop measure wherever it fits and hands
/// back whatever is left where it does not.
double dialogContentWidth(BuildContext context, {required double preferred}) {
  final double available = MediaQuery.sizeOf(context).width - _kDialogChrome;
  return math.max(0, math.min(preferred, available));
}
