/// Compact, consistently colored tag labels shared by collection screens.
library;

import 'package:flutter/material.dart';

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
      borderRadius: BorderRadius.circular(10),
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
      color: const Color(0xFF6B6862),
      borderRadius: BorderRadius.circular(10),
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
Color _tagColor(String tagName) {
  const List<Color> palette = <Color>[
    Color(0xFF3567A8),
    Color(0xFF7651A8),
    Color(0xFF9A4D67),
    Color(0xFF2F766D),
    Color(0xFF9A5B32),
    Color(0xFF65752D),
    Color(0xFF4B6691),
    Color(0xFF8A4E91),
  ];
  int stableHash = 0;
  for (final int character in tagName.toLowerCase().runes) {
    stableHash = (stableHash * 31 + character) & 0x7FFFFFFF;
  }
  return palette[stableHash % palette.length];
}
