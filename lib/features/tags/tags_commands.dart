/// Plain requests for changes to tags and element-tag links.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// Creates a tag from user-entered text.
final class CreateTag extends AppCommand {
  CreateTag(super.operationId, {required this.name, super.timestampUtc});
  final String name;
}

/// Changes a tag's spelling without changing its identity.
final class RenameTag extends AppCommand {
  RenameTag(
    super.operationId, {
    required this.tagId,
    required this.name,
    super.timestampUtc,
  });
  final String tagId;
  final String name;
}

/// Deletes one tag and its links, leaving elements untouched.
final class DeleteTag extends AppCommand {
  DeleteTag(super.operationId, {required this.tagId, super.timestampUtc});
  final String tagId;
}

/// Moves links from near-duplicate tags into one surviving tag.
final class MergeTags extends AppCommand {
  MergeTags(
    super.operationId, {
    required this.sourceTagIds,
    required this.intoTagId,
    super.timestampUtc,
  });
  final Set<String> sourceTagIds;
  final String intoTagId;
}

/// Replaces the direct tags of one element.
final class SaveTagsOfElement extends AppCommand {
  SaveTagsOfElement(
    super.operationId, {
    required this.ref,
    required this.tagIds,
    super.timestampUtc,
  });
  final ElementRef ref;
  final Set<String> tagIds;
}

/// Adds tags to every selected element without replacing other tags.
final class InsertTagsOnElements extends AppCommand {
  InsertTagsOnElements(
    super.operationId, {
    required this.refs,
    required this.tagIds,
    super.timestampUtc,
  });
  final List<ElementRef> refs;
  final Set<String> tagIds;
}

/// Removes tags from every selected element without replacing other tags.
final class DeleteTagsFromElements extends AppCommand {
  DeleteTagsFromElements(
    super.operationId, {
    required this.refs,
    required this.tagIds,
    super.timestampUtc,
  });
  final List<ElementRef> refs;
  final Set<String> tagIds;
}

/// The tag created or changed by a definition command.
final class TagOutcome {
  const TagOutcome(this.tag);
  final Tag tag;
}

/// How many element references a link command addressed.
final class ElementTagOutcome {
  const ElementTagOutcome(this.changedRefCount);
  final int changedRefCount;
}
