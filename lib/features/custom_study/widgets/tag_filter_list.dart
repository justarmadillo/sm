/// Every tag with how many elements carry it, each one off, included, or
/// excluded — the browse-by-tag half of custom study.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// One row per tag; a tap moves it off → included → excluded → off.
///
/// `#cram` is listed first: it is the one tag with a meaning of its own, and
/// a deck built from it is how cram-only elements get studied at all.
class TagFilterList extends StatefulWidget {
  const TagFilterList({
    required this.tags,
    required this.filter,
    required this.tagCounts,
    required this.isEnabled,
    required this.onCycle,
    this.isScrollable = true,
    super.key,
  });

  final List<Tag> tags;
  final CustomDeckFilter filter;
  final Map<String, int> tagCounts;
  final bool isEnabled;
  final ValueChanged<String> onCycle;

  /// False when a parent already scrolls, as on a phone.
  final bool isScrollable;

  @override
  State<TagFilterList> createState() => _TagFilterListState();
}

class _TagFilterListState extends State<TagFilterList> {
  String _search = '';

  List<Tag> get _visibleTags {
    final String needle = _search.trim().toLowerCase();
    final List<Tag> matching = <Tag>[
      for (final Tag tag in widget.tags)
        if (needle.isEmpty || tag.name.toLowerCase().contains(needle)) tag,
    ];
    return <Tag>[
      ...matching.where((Tag tag) => tag.isCram),
      ...matching.where((Tag tag) => !tag.isCram),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[
      _searchField(),
      if (widget.tags.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No tags yet. Tag elements in the Browser to study them here.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      for (final Tag tag in _visibleTags) _tagRow(tag),
    ];
    return widget.isScrollable
        ? ListView(padding: const EdgeInsets.only(bottom: 16), children: rows)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          );
  }

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: TextField(
      decoration: const InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 18),
        hintText: 'Find a tag',
      ),
      onChanged: (String typed) => setState(() => _search = typed),
    ),
  );

  Widget _tagRow(Tag tag) {
    final bool isIncluded = widget.filter.includeTagIds.contains(tag.id);
    final bool isExcluded = widget.filter.excludeTagIds.contains(tag.id);
    return ListTile(
      dense: true,
      leading: Icon(
        isIncluded
            ? Icons.check_box
            : isExcluded
            ? Icons.block
            : Icons.check_box_outline_blank,
        size: 20,
        color: isIncluded
            ? AppColors.accent
            : isExcluded
            ? AppColors.danger
            : AppColors.faint,
      ),
      title: Row(
        children: <Widget>[
          if (tag.isCram) ...<Widget>[
            const Tooltip(
              message: 'Cram only',
              child: Icon(Icons.bolt, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              '#${tag.name}',
              overflow: TextOverflow.ellipsis,
              style: isExcluded
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
          ),
        ],
      ),
      trailing: Text(
        '${widget.tagCounts[tag.id] ?? 0}',
        style: const TextStyle(color: AppColors.muted),
      ),
      onTap: widget.isEnabled ? () => widget.onCycle(tag.id) : null,
    );
  }
}
