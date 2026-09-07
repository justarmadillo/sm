/// What the app promises about flat tags and their direct element links.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:meta/meta.dart';

/// A user-defined tag, stored without its display hash.
@immutable
final class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  final String id;
  final String name;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Removes display syntax and collapses whitespace so equivalent input has
  /// one stable stored spelling.
  static String normalizeName(String typed) {
    String normalized = typed.trim();
    if (normalized.startsWith('#')) normalized = normalized.substring(1);
    return normalized.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// The case-insensitive identity persisted in the unique column.
  static String toLowercaseName(String typed) =>
      normalizeName(typed).toLowerCase();
}

/// Persists tag definitions and direct element-tag relationships.
abstract interface class TagRepository {
  Future<List<Tag>> listTags();
  Future<Tag?> findTag(String id);
  Future<Tag?> findTagByLowercaseName(String lowercaseName);
  Future<void> insertTag(Tag tag);
  Future<void> updateTag(Tag tag);
  Future<void> deleteTag(String id);
  Future<Map<ElementRef, Set<String>>> listAllElementTags();
  Future<List<String>> listTagIdsOfElement(ElementRef ref);
  Future<void> saveTagsOfElement(
    ElementRef ref,
    Set<String> tagIds,
    DateTime nowUtc,
  );
  Future<void> insertElementTags(
    List<ElementRef> refs,
    Set<String> tagIds,
    DateTime nowUtc,
  );
  Future<void> deleteElementTags(List<ElementRef> refs, Set<String> tagIds);
  Future<void> deleteTagsOfElement(ElementRef ref);
  Future<Map<String, int>> countElementsByTag();
}
