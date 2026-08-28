/// One label for what an element *is*, shared by every list that shows a mix.
///
/// Topics, extracts and cards are scheduled by different machinery and answer
/// different questions, so a list that shows all three has to say which is
/// which. Defining the icon, colour and word in one place keeps the queue and
/// the priority browser from drifting into two vocabularies for one idea.
library;

import 'package:flutter/material.dart';

import 'package:incremental_reader/src/app/theme.dart';
import 'package:incremental_reader/src/domain/scheduling/element.dart';

/// Icon, colour and word for [type].
({IconData icon, Color color, String label}) elementTypeStyle(
  ElementType type,
) => switch (type) {
  ElementType.source => (
    icon: Icons.menu_book_outlined,
    color: AppColors.accent,
    label: 'topic',
  ),
  ElementType.extract => (
    icon: Icons.content_cut,
    color: AppColors.extractInk,
    label: 'extract',
  ),
  ElementType.card => (
    icon: Icons.quiz_outlined,
    color: Colors.teal,
    label: 'card',
  ),
};

/// A compact `icon + word` badge naming an element's type.
class ElementTypeBadge extends StatelessWidget {
  const ElementTypeBadge({
    required this.type,
    this.showLabel = true,
    super.key,
  });

  final ElementType type;

  /// Whether to draw the word as well as the icon.
  ///
  /// The icon alone is only enough where the surrounding list is already all
  /// one type; anywhere the types are mixed, the word carries the meaning.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color, String label}) style = elementTypeStyle(
      type,
    );
    if (!showLabel) {
      return Icon(style.icon, size: 16, color: style.color);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.10),
        border: Border.all(color: style.color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 11,
              color: style.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
