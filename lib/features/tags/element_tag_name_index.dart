/// Resolves stable tag identifiers into display names for screen read models.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// One collection-wide tag snapshot, loaded in two reads instead of one read
/// per visible row.
final class ElementTagNameIndex {
  const ElementTagNameIndex._({
    required this.tags,
    required this.tagIdsByElement,
  });

  final List<Tag> tags;
  final Map<ElementRef, Set<String>> tagIdsByElement;

  static Future<ElementTagNameIndex> load(TagRepository repository) async =>
      ElementTagNameIndex._(
        tags: await repository.listTags(),
        tagIdsByElement: await repository.listAllElementTags(),
      );

  Set<String> tagIdsOf(ElementRef ref) =>
      tagIdsByElement[ref] ?? const <String>{};

  List<String> listNamesOf(ElementRef ref) => listNamesFor(tagIdsOf(ref));

  /// Iterating definitions rather than identifiers preserves the repository's
  /// alphabetic order and quietly ignores links to a deleted definition.
  List<String> listNamesFor(Set<String> tagIds) => <String>[
    for (final Tag tag in tags)
      if (tagIds.contains(tag.id)) tag.name,
  ];
}
