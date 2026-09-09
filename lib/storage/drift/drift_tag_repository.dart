/// Saves and queries flat tags using Drift.
library;

import 'package:drift/drift.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/epoch_milliseconds.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:incremental_reader/storage/database/app_database.dart';

/// Drift implementation of the tag storage contract.
final class DriftTagRepository implements TagRepository {
  const DriftTagRepository(this._database);

  final AppDatabase _database;

  Tag _fromRow(TagRow row) => Tag(
    id: row.id,
    name: row.name,
    createdAtUtc: fromEpochMs(row.createdAtUtc),
    updatedAtUtc: fromEpochMs(row.updatedAtUtc),
  );

  @override
  Future<List<Tag>> listTags() async => <Tag>[
    for (final TagRow row
        in await (_database.select(_database.tags)
              ..orderBy(<OrderingTerm Function($TagsTable)>[
                ($TagsTable tags) => OrderingTerm.asc(tags.nameLowercase),
              ]))
            .get())
      _fromRow(row),
  ];

  @override
  Future<Tag?> findTag(String id) async {
    final TagRow? row = await (_database.select(
      _database.tags,
    )..where(($TagsTable tags) => tags.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<Tag?> findTagByLowercaseName(String lowercaseName) async {
    final TagRow? row =
        await (_database.select(_database.tags)..where(
              ($TagsTable tags) => tags.nameLowercase.equals(lowercaseName),
            ))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  TagsCompanion _companion(Tag tag) => TagsCompanion.insert(
    id: tag.id,
    name: tag.name,
    nameLowercase: Tag.toLowercaseName(tag.name),
    createdAtUtc: toEpochMs(tag.createdAtUtc),
    updatedAtUtc: toEpochMs(tag.updatedAtUtc),
  );

  @override
  Future<void> insertTag(Tag tag) =>
      _database.into(_database.tags).insert(_companion(tag));

  @override
  Future<void> updateTag(Tag tag) =>
      _database.update(_database.tags).write(_companion(tag));

  @override
  Future<void> deleteTag(String id) async {
    await (_database.delete(
      _database.tags,
    )..where(($TagsTable tags) => tags.id.equals(id))).go();
  }

  @override
  Future<Map<ElementRef, Set<String>>> listAllElementTags() async {
    final List<ElementTagRow> rows = await _database
        .select(_database.elementTags)
        .get();
    final Map<ElementRef, Set<String>> result = <ElementRef, Set<String>>{};
    for (final ElementTagRow row in rows) {
      final ElementRef ref = ElementRef(
        id: row.elementId,
        type: ElementType.values[row.elementType],
      );
      result.putIfAbsent(ref, () => <String>{}).add(row.tagId);
    }
    return result;
  }

  @override
  Future<List<String>> listTagIdsOfElement(ElementRef ref) async => <String>[
    for (final ElementTagRow row
        in await (_database.select(_database.elementTags)..where(
              ($ElementTagsTable links) =>
                  links.elementId.equals(ref.id) &
                  links.elementType.equals(ref.type.index),
            ))
            .get())
      row.tagId,
  ];

  @override
  Future<void> saveTagsOfElement(
    ElementRef ref,
    Set<String> tagIds,
    DateTime nowUtc,
  ) async {
    await deleteTagsOfElement(ref);
    await insertElementTags(<ElementRef>[ref], tagIds, nowUtc);
  }

  @override
  Future<void> insertElementTags(
    List<ElementRef> refs,
    Set<String> tagIds,
    DateTime nowUtc,
  ) async {
    if (refs.isEmpty || tagIds.isEmpty) return;
    await _database.batch((Batch batch) {
      for (final ElementRef ref in refs) {
        for (final String tagId in tagIds) {
          batch.insert(
            _database.elementTags,
            ElementTagsCompanion.insert(
              tagId: tagId,
              elementId: ref.id,
              elementType: ref.type.index,
              taggedAtUtc: toEpochMs(nowUtc),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }

  @override
  Future<void> deleteElementTags(
    List<ElementRef> refs,
    Set<String> tagIds,
  ) async {
    if (refs.isEmpty || tagIds.isEmpty) return;
    for (final ElementRef ref in refs) {
      await (_database.delete(_database.elementTags)..where(
            ($ElementTagsTable links) =>
                links.elementId.equals(ref.id) &
                links.elementType.equals(ref.type.index) &
                links.tagId.isIn(tagIds),
          ))
          .go();
    }
  }

  @override
  Future<void> deleteTagsOfElement(ElementRef ref) async {
    await (_database.delete(_database.elementTags)..where(
          ($ElementTagsTable links) =>
              links.elementId.equals(ref.id) &
              links.elementType.equals(ref.type.index),
        ))
        .go();
  }

  @override
  Future<Map<String, int>> countElementsByTag() async {
    final rows = await _database
        .customSelect(
          'SELECT tag_id, COUNT(*) AS element_count FROM element_tags '
          'GROUP BY tag_id',
        )
        .get();
    return <String, int>{
      for (final row in rows)
        row.read<String>('tag_id'): row.read<int>('element_count'),
    };
  }
}
