/// Carries tag commands out inside the shared command boundary.
library;

import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/command_execution.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kTagCreatedType = 'tags.created';
const String kTagRenamedType = 'tags.renamed';
const String kTagDeletedType = 'tags.deleted';
const String kTagMergedType = 'tags.merged';
const String kElementTagsChangedType = 'tags.element_changed';

/// Applies tag definition and link changes without touching scheduling state.
final class TagsCommandRunner {
  const TagsCommandRunner({
    required TagRepository tags,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _tags = tags,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _diagnostics = diagnostics;

  final TagRepository _tags;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final DiagnosticSink _diagnostics;

  Future<Result<TagOutcome>> create(CreateTag command) =>
      _run<TagOutcome>(command, kTagCreatedType, () async {
        final String name = Tag.normalizeName(command.name);
        final Result<void>? refusal = await _validateName(name);
        if (refusal != null) return Err<TagOutcome>(refusal.failureOrNull!);
        final Tag tag = Tag(
          id: _ids.newId(),
          name: name,
          createdAtUtc: command.timestampUtc,
          updatedAtUtc: command.timestampUtc,
        );
        await _tags.insertTag(tag);
        await _appendActivity(command, kTagCreatedType, tagId: tag.id);
        return Ok<TagOutcome>(TagOutcome(tag));
      });

  Future<Result<TagOutcome>> rename(RenameTag command) =>
      _run<TagOutcome>(command, kTagRenamedType, () async {
        final Tag? stored = await _tags.findTag(command.tagId);
        if (stored == null) return _missingTag<TagOutcome>(command.tagId);
        final String name = Tag.normalizeName(command.name);
        final Result<void>? refusal = await _validateName(
          name,
          exceptTagId: command.tagId,
        );
        if (refusal != null) return Err<TagOutcome>(refusal.failureOrNull!);
        final Tag tag = Tag(
          id: stored.id,
          name: name,
          createdAtUtc: stored.createdAtUtc,
          updatedAtUtc: command.timestampUtc,
        );
        await _tags.updateTag(tag);
        await _appendActivity(command, kTagRenamedType, tagId: tag.id);
        return Ok<TagOutcome>(TagOutcome(tag));
      });

  Future<Result<TagOutcome>> delete(DeleteTag command) =>
      _run<TagOutcome>(command, kTagDeletedType, () async {
        final Tag? tag = await _tags.findTag(command.tagId);
        if (tag == null) return _missingTag<TagOutcome>(command.tagId);
        await _tags.deleteTag(tag.id);
        await _appendActivity(command, kTagDeletedType, tagId: tag.id);
        return Ok<TagOutcome>(TagOutcome(tag));
      });

  Future<Result<TagOutcome>> merge(MergeTags command) =>
      _run<TagOutcome>(command, kTagMergedType, () async {
        if (command.sourceTagIds.contains(command.intoTagId)) {
          return const Err<TagOutcome>(
            ValidationFailure('the surviving tag cannot also be a source'),
          );
        }
        final Tag? target = await _tags.findTag(command.intoTagId);
        if (target == null) return _missingTag<TagOutcome>(command.intoTagId);
        for (final String sourceId in command.sourceTagIds) {
          if (await _tags.findTag(sourceId) == null) {
            return _missingTag<TagOutcome>(sourceId);
          }
        }
        final Map<ElementRef, Set<String>> links =
            await _tags.listAllElementTags();
        for (final MapEntry<ElementRef, Set<String>> entry in links.entries) {
          if (entry.value.intersection(command.sourceTagIds).isEmpty) continue;
          await _tags.insertElementTags(
            <ElementRef>[entry.key],
            <String>{target.id},
            command.timestampUtc,
          );
        }
        for (final String sourceId in command.sourceTagIds) {
          await _tags.deleteTag(sourceId);
        }
        await _appendActivity(command, kTagMergedType, tagId: target.id);
        return Ok<TagOutcome>(TagOutcome(target));
      });

  Future<Result<ElementTagOutcome>> save(SaveTagsOfElement command) =>
      _changeLinks(command, <ElementRef>[command.ref], () async {
        await _tags.saveTagsOfElement(
          command.ref,
          command.tagIds,
          command.timestampUtc,
        );
      });

  Future<Result<ElementTagOutcome>> insert(InsertTagsOnElements command) =>
      _changeLinks(command, command.refs, () async {
        await _tags.insertElementTags(
          command.refs,
          command.tagIds,
          command.timestampUtc,
        );
      });

  Future<Result<ElementTagOutcome>> deleteFromElements(
    DeleteTagsFromElements command,
  ) => _changeLinks(command, command.refs, () async {
    await _tags.deleteElementTags(command.refs, command.tagIds);
  });

  Future<Result<ElementTagOutcome>> _changeLinks(
    AppCommand command,
    List<ElementRef> refs,
    Future<void> Function() change,
  ) => _run<ElementTagOutcome>(command, kElementTagsChangedType, () async {
    if (refs.isEmpty) {
      return const Err<ElementTagOutcome>(
        ValidationFailure('select at least one element'),
      );
    }
    await change();
    await _appendActivity(command, kElementTagsChangedType, ref: refs.first);
    return Ok<ElementTagOutcome>(ElementTagOutcome(refs.length));
  });

  Future<Result<void>?> _validateName(
    String name, {
    String? exceptTagId,
  }) async {
    if (name.isEmpty || name.length > 100) {
      return const Err<void>(
        ValidationFailure('a tag name must contain 1 to 100 characters'),
      );
    }
    final Tag? existing = await _tags.findTagByLowercaseName(
      Tag.toLowercaseName(name),
    );
    if (existing != null && existing.id != exceptTagId) {
      return const Err<void>(ValidationFailure('that tag already exists'));
    }
    return null;
  }

  Future<void> _appendActivity(
    AppCommand command,
    String type, {
    String? tagId,
    ElementRef? ref,
  }) => _learning.appendActivity(
    ActivityRecord(
      id: _ids.newId(),
      operationId: command.operationId.value,
      type: type,
      atUtc: command.timestampUtc,
      ref: ref,
      metadata: <String, Object?>{'tag_id': tagId},
    ),
  );

  Future<Result<T>> _run<T>(
    AppCommand command,
    String type,
    Future<Result<T>> Function() changes,
  ) => executeCommand<T>(
    command: command,
    activityType: type,
    clock: _clock,
    diagnostics: _diagnostics,
    withinTransaction: (Future<Result<T>> Function() body) =>
        _transactions.run<Result<T>>(body),
    wasAlreadyApplied: () =>
        _learning.hasActivity(command.operationId.value, type),
    changes: changes,
    advanceDatasetGeneration: _transfer.advanceGeneration,
  );

  Result<T> _missingTag<T>(String id) => Err<T>(
    NotFoundFailure('that tag no longer exists', entity: 'tag', id: id),
  );
}
