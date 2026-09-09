/// A compact colored status label shared by study screens.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Draws [text] as a subtle pill using [color] for both tint and ink.
///
/// Fully pill-shaped, unlike the square-cornered element type badge beside it:
/// the badge names what a row *is* and the pill names what is *happening to
/// it*, and the two shapes are what keeps a row from reading as two labels of
/// the same kind.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.text, required this.color, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.tight,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(text, style: AppTextStyles.eyebrow.copyWith(color: color)),
  );
}
