/// The bar of actions pinned to the bottom of a study screen.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// The surface Done, Later and Dismiss sit on, whatever screen offers them.
///
/// Only the frame is shared: what goes inside it is the screen's own hint and
/// its own buttons. The frame is worth sharing anyway, because of the last
/// line of it — the bar is the last thing above the Android gesture strip, so
/// it has to give that strip its own space or Done sits under the swipe area.
/// A screen that drew its own frame would be one screen away from forgetting
/// that.
class StudyActionBar extends StatelessWidget {
  const StudyActionBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(top: false, child: child),
  );
}
