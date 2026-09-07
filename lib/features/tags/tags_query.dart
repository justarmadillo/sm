/// Read-only models for the Tags screen.
library;

import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// A tag and the number of elements carrying it directly.
final class TagListEntry {
  const TagListEntry({required this.tag, required this.elementCount});
  final Tag tag;
  final int elementCount;
}

/// Reads the complete, alphabetized tag list.
final class TagsQuery {
  const TagsQuery(this._tags);
  final TagRepository _tags;

  Future<List<TagListEntry>> load() async {
    final List<Tag> tags = await _tags.listTags();
    final Map<String, int> counts = await _tags.countElementsByTag();
    return <TagListEntry>[
      for (final Tag tag in tags)
        TagListEntry(tag: tag, elementCount: counts[tag.id] ?? 0),
    ];
  }
}
