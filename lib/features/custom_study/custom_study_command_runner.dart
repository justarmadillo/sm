/// Carries custom-deck commands out inside the shared command boundary.
library;

import 'package:incremental_reader/features/custom_study/custom_study_commands.dart';
import 'package:incremental_reader/shared/clock.dart';
import 'package:incremental_reader/shared/command_base.dart';
import 'package:incremental_reader/shared/command_execution.dart';
import 'package:incremental_reader/shared/diagnostics_sink.dart';
import 'package:incremental_reader/shared/id_generator.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/custom_deck_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';
import 'package:incremental_reader/storage/contracts/transfer_repository.dart';

const String kCustomDeckCreatedType = 'custom_deck.created';
const String kCustomDeckUpdatedType = 'custom_deck.updated';
const String kCustomDeckDeletedType = 'custom_deck.deleted';

/// The largest session cap a deck accepts.
const int kMaximumSessionLimit = 9999;

/// Saves, changes, and deletes decks. Never touches an element or a schedule.
final class CustomStudyCommandRunner {
  const CustomStudyCommandRunner({
    required CustomDeckRepository decks,
    required TagRepository tags,
    required LearningRepository learning,
    required TransferRepository transfer,
    required TransactionRunner transactions,
    required Clock clock,
    required IdGenerator ids,
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : _decks = decks,
       _tags = tags,
       _learning = learning,
       _transfer = transfer,
       _transactions = transactions,
       _clock = clock,
       _ids = ids,
       _diagnostics = diagnostics;

  final CustomDeckRepository _decks;
  final TagRepository _tags;
  final LearningRepository _learning;
  final TransferRepository _transfer;
  final TransactionRunner _transactions;
  final Clock _clock;
  final IdGenerator _ids;
  final DiagnosticSink _diagnostics;

  Future<Result<CustomDeckOutcome>> create(CreateCustomDeck command) => _run(
    command,
    type: kCustomDeckCreatedType,
    changes: () async {
      final String name = CustomDeck.normalizeName(command.name);
      final AppFailure? refusal = await _refusalFor(
        name: name,
        filter: command.filter,
      );
      if (refusal != null) return Err<CustomDeckOutcome>(refusal);
      final CustomDeck deck = CustomDeck(
        id: _ids.newId(),
        name: name,
        filter: command.filter,
        createdAtUtc: command.timestampUtc,
        updatedAtUtc: command.timestampUtc,
      );
      await _decks.insertDeck(deck);
      await _log(command, kCustomDeckCreatedType, deckId: deck.id);
      return Ok<CustomDeckOutcome>(CustomDeckOutcome(deck));
    },
  );

  Future<Result<CustomDeckOutcome>> update(UpdateCustomDeck command) => _run(
    command,
    type: kCustomDeckUpdatedType,
    changes: () async {
      final CustomDeck? stored = await _decks.findDeck(command.deckId);
      if (stored == null) return _missingDeck(command.deckId);
      final CustomDeck deck = stored.copyWith(
        name: CustomDeck.normalizeName(command.name ?? stored.name),
        filter: command.filter,
        updatedAtUtc: command.timestampUtc,
      );
      final AppFailure? refusal = await _refusalFor(
        name: deck.name,
        filter: deck.filter,
        exceptDeckId: deck.id,
      );
      if (refusal != null) return Err<CustomDeckOutcome>(refusal);
      await _decks.updateDeck(deck);
      await _log(command, kCustomDeckUpdatedType, deckId: deck.id);
      return Ok<CustomDeckOutcome>(CustomDeckOutcome(deck));
    },
  );

  Future<Result<CustomDeckOutcome>> delete(DeleteCustomDeck command) => _run(
    command,
    type: kCustomDeckDeletedType,
    changes: () async {
      final CustomDeck? deck = await _decks.findDeck(command.deckId);
      if (deck == null) return _missingDeck(command.deckId);
      await _decks.deleteDeck(deck.id);
      await _log(command, kCustomDeckDeletedType, deckId: deck.id);
      return Ok<CustomDeckOutcome>(CustomDeckOutcome(deck));
    },
  );

  /// Null when [name] and [filter] can be saved; otherwise why not.
  Future<AppFailure?> _refusalFor({
    required String name,
    required CustomDeckFilter filter,
    String? exceptDeckId,
  }) async {
    if (name.isEmpty || name.length > 100) {
      return const ValidationFailure(
        'a deck name must contain 1 to 100 characters',
      );
    }
    final CustomDeck? sameName = await _decks.findDeckByLowercaseName(
      CustomDeck.toLowercaseName(name),
    );
    if (sameName != null && sameName.id != exceptDeckId) {
      return const ValidationFailure('a deck with that name already exists');
    }
    if (filter.types.isEmpty) {
      return const ValidationFailure('choose at least one kind of element');
    }
    if (filter.includeTagIds.intersection(filter.excludeTagIds).isNotEmpty) {
      return const ValidationFailure(
        'a tag cannot be both included and excluded',
      );
    }
    final int? limit = filter.sessionLimit;
    if (limit != null && (limit < 1 || limit > kMaximumSessionLimit)) {
      return const ValidationFailure(
        'a session limit must be between 1 and $kMaximumSessionLimit',
      );
    }
    for (final String tagId in <String>{
      ...filter.includeTagIds,
      ...filter.excludeTagIds,
    }) {
      if (await _tags.findTag(tagId) == null) {
        return NotFoundFailure(
          'that tag no longer exists',
          entity: 'tag',
          id: tagId,
        );
      }
    }
    return null;
  }

  Future<void> _log(
    AppCommand command,
    String type, {
    required String deckId,
  }) => _learning.appendActivity(
    ActivityRecord.forCommand(
      command,
      type,
      id: _ids.newId(),
      metadata: <String, Object?>{'custom_deck_id': deckId},
    ),
  );

  Future<Result<CustomDeckOutcome>> _run(
    AppCommand command, {
    required String type,
    required Future<Result<CustomDeckOutcome>> Function() changes,
  }) => executeCommand<CustomDeckOutcome>(
    command: command,
    activityType: type,
    clock: _clock,
    diagnostics: _diagnostics,
    withinTransaction: (Future<Result<CustomDeckOutcome>> Function() body) =>
        _transactions.run<Result<CustomDeckOutcome>>(body),
    wasAlreadyApplied: () =>
        _learning.hasActivity(command.operationId.value, type),
    changes: changes,
    advanceDatasetGeneration: _transfer.advanceGeneration,
  );

  Result<CustomDeckOutcome> _missingDeck(String id) => Err<CustomDeckOutcome>(
    NotFoundFailure(
      'that deck no longer exists',
      entity: 'custom_deck',
      id: id,
    ),
  );
}
