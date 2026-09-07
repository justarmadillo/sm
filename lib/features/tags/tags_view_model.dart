/// Screen actions for creating, renaming, and deleting tags.
library;

import 'package:incremental_reader/features/tags/tags_command_runner.dart';
import 'package:incremental_reader/features/tags/tags_commands.dart';
import 'package:incremental_reader/shared/operation_id.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';

/// Keeps tag-screen intent construction out of its widgets.
final class TagsViewModel {
  const TagsViewModel(this._runner, this._newOperationId);

  final TagsCommandRunner _runner;
  final OperationId Function() _newOperationId;

  Future<Result<TagOutcome>> create(String name) =>
      _runner.create(CreateTag(_newOperationId(), name: name));

  Future<Result<TagOutcome>> rename(Tag tag, String name) => _runner.rename(
    RenameTag(_newOperationId(), tagId: tag.id, name: name),
  );

  Future<Result<TagOutcome>> delete(Tag tag) =>
      _runner.delete(DeleteTag(_newOperationId(), tagId: tag.id));
}
