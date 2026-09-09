/// The strip of status text a study screen shows above its content.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

/// Lays out a study screen's status parts: the first two on the left, the rest
/// pushed to the right.
///
/// Extract and Video put different words in this bar, but the arrangement has
/// to stay the same or the two screens stop looking like the same app. The
/// same trade the Reader's bar makes: nothing here is droppable, so on a narrow
/// window the parts wrap rather than overflow.
class StudyStatusBar extends StatelessWidget {
  const StudyStatusBar({required this.parts, super.key});

  /// Left to right, in reading order. The first two sit on the left.
  final List<Widget> parts;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: isCompactWidth(context)
        ? Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: parts,
          )
        : Row(
            children: <Widget>[
              ...parts.take(2),
              const Spacer(),
              ...parts.skip(2),
            ],
          ),
  );
}
