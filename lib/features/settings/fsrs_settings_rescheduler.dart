/// Saves settings and optionally moves existing review cards onto the new FSRS policy.
library;

import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/cards/fsrs_memory_recomputer.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/settings/app_settings.dart';
import 'package:incremental_reader/settings/card_settings.dart';
import 'package:incremental_reader/settings/settings_list_equality.dart';
import 'package:incremental_reader/settings/settings_store.dart';
import 'package:incremental_reader/shared/result.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/transaction_runner.dart';

final class FsrsSettingsSaveResult {
  const FsrsSettingsSaveResult({
    required this.settings,
    required this.cardsUpdated,
  });

  final Result<AppSettings> settings;
  final int cardsUpdated;
}

/// Keeps settings and the due dates derived from them in one transaction.
final class FsrsSettingsRescheduler {
  const FsrsSettingsRescheduler({
    required SettingsStore settings,
    required SchedulingContext context,
    required LearningRepository learning,
    required TransactionRunner transactions,
  }) : _settings = settings,
       _context = context,
       _learning = learning,
       _transactions = transactions;

  final SettingsStore _settings;
  final SchedulingContext _context;
  final LearningRepository _learning;
  final TransactionRunner _transactions;

  Future<FsrsSettingsSaveResult> save({
    required AppSettings previous,
    required AppSettings replacement,
  }) => _transactions.run(() async {
    final Result<AppSettings> saved = await _settings.save(replacement);
    if (saved.isErr || !_shouldReschedule(previous, replacement)) {
      return FsrsSettingsSaveResult(settings: saved, cardsUpdated: 0);
    }

    final scheduler = await _context.cardScheduler();
    final today = await _context.today();
    final cards = await _learning.listCardStates();
    final reviews = await _learning.listOptimizerReviews();
    final reviewsByCard = <String, List<ReviewRecord>>{};
    for (final review in reviews) {
      reviewsByCard
          .putIfAbsent(review.cardId, () => <ReviewRecord>[])
          .add(review);
    }
    final recomputer = FsrsMemoryRecomputer(calendar: scheduler.calendar);
    final bool parametersChanged =
        !doubleListsAreEqual(
          previous.cards.fsrsParameters,
          replacement.cards.fsrsParameters,
        ) ||
        previous.cards.fsrsParametersVersion !=
            replacement.cards.fsrsParametersVersion;
    var cardsUpdated = 0;
    for (final before in cards) {
      if (!before.schedule.lifecycle.isSchedulable) continue;
      final withCurrentMemory = parametersChanged
          ? recomputer.recompute(
              before,
              reviews: reviewsByCard[before.ref.id] ?? const <ReviewRecord>[],
              parameters: replacement.cards.fsrsParameters,
              parametersVersion: replacement.cards.fsrsParametersVersion,
            )
          : before;
      final after = scheduler.rescheduleForSettings(
        withCurrentMemory,
        today: today,
      );
      if (after == before) continue;
      await _learning.saveCardState(after);
      cardsUpdated++;
    }
    return FsrsSettingsSaveResult(settings: saved, cardsUpdated: cardsUpdated);
  });

  bool _shouldReschedule(AppSettings previous, AppSettings replacement) {
    if (!replacement.cards.shouldRescheduleAfterSettingsChange) return false;
    return previous.studyDay != replacement.studyDay ||
        _intervalPolicyChanged(previous.cards, replacement.cards);
  }

  bool _intervalPolicyChanged(CardSettings before, CardSettings after) =>
      before.desiredRetention != after.desiredRetention ||
      !doubleListsAreEqual(before.fsrsParameters, after.fsrsParameters) ||
      before.fsrsParametersVersion != after.fsrsParametersVersion ||
      before.maximumIntervalDays != after.maximumIntervalDays ||
      before.isFuzzingEnabled != after.isFuzzingEnabled;
}
