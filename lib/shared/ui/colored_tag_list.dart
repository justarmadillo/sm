/// Compact, consistently colored tag labels shared by collection screens.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// A bounded run of tag pills that cannot let a heavily tagged element take
/// over a list row.
class ColoredTagList extends StatelessWidget {
  const ColoredTagList({
    required this.tagNames,
    this.maximumVisibleTags = 4,
    super.key,
  });

  final List<String> tagNames;
  final int maximumVisibleTags;

  @override
  Widget build(BuildContext context) {
    if (tagNames.isEmpty || maximumVisibleTags <= 0) {
      return const SizedBox.shrink();
    }
    final int visibleCount = tagNames.length.clamp(0, maximumVisibleTags);
    final int hiddenCount = tagNames.length - visibleCount;
    return Wrap(
      spacing: 4,
      runSpacing: 3,
      children: <Widget>[
        for (final String tagName in tagNames.take(visibleCount))
          _ColoredTag(tagName: tagName),
        if (hiddenCount > 0) _HiddenTagCount(hiddenCount: hiddenCount),
      ],
    );
  }
}

class _ColoredTag extends StatelessWidget {
  const _ColoredTag({required this.tagName});

  final String tagName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: _tagColor(tagName),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      '#$tagName',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
  );
}

class _HiddenTagCount extends StatelessWidget {
  const _HiddenTagCount({required this.hiddenCount});

  final int hiddenCount;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.muted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      '+$hiddenCount',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
  );
}

/// A small fixed palette keeps each name recognizable between screens and
/// launches without persisting a presentation concern in the collection.
///
/// Decorative on purpose, and kept clear of every hue that means something:
/// no orange (an action), no [AppColors.extractInk] purple, no
/// [AppColors.softMarker] teal. A tag that happened to land on the extract
/// colour would look like a claim about what the row is.
Color _tagColor(String tagName) {
  const List<Color> palette = <Color>[
    Color(0xFF8A4E91),
    Color(0xFF9A4D67),
    Color(0xFF2F766D),
    Color(0xFF65752D),
    Color(0xFF7A5C3A),
    Color(0xFF3F6B5A),
    Color(0xFF8C5A7A),
    Color(0xFF5F6B34),
  ];
  int stableHash = 0;
  for (final int character in tagName.toLowerCase().runes) {
    stableHash = (stableHash * 31 + character) & 0x7FFFFFFF;
  }
  return palette[stableHash % palette.length];
}
