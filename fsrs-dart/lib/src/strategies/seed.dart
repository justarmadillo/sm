/// Fuzz seed strategies.
///
/// The seed decides where inside the fuzz window a card lands, so it must be
/// derived from data that is stable for a given review: change the derivation
/// and every fuzzed interval changes with it.
library;

import '../js_compat.dart';
import '../models.dart';
import 'types.dart';

/// The default seed: review instant, repetition count, and `difficulty *
/// stability`.
String defaultInitSeedStrategy(SchedulerContext context) {
  final time = context.reviewTime.millisecondsSinceEpoch;
  final reps = context.current.reps;
  final mul = context.current.difficulty * context.current.stability;
  return '${time}_${reps}_${jsNumberToString(mul)}';
}

/// A seed derived from a stable card id plus its repetition count.
///
/// Use this when two cards may be reviewed in the same millisecond with the
/// same memory state, which would otherwise give them the same fuzz.
///
/// [cardId] may be a number (added to `reps`, as upstream does) or a string
/// (concatenated with `reps`, which is what JavaScript's `+` does there).
SeedStrategy genSeedStrategyWithCardId(Object Function(Card) cardId) {
  return (SchedulerContext context) {
    final id = cardId(context.current);
    final reps = context.current.reps;
    if (id is String) {
      final combined = '$id$reps';
      return combined.isEmpty ? '0' : combined;
    }
    final sum = (id as num) + reps;
    return sum == 0 ? '0' : jsNumberToString(sum);
  };
}

/// Derives Anki's stable `card id + repetition count` fuzz seed.
///
/// The caller supplies the persistent numeric card id because the portable
/// FSRS [Card] deliberately has no storage identity of its own.
SeedStrategy genAnkiSeedStrategyWithCardId(int Function(Card) cardId) {
  return (SchedulerContext context) {
    final seed = cardId(context.current) + context.current.reps;
    return seed == 0 ? '0' : jsNumberToString(seed);
  };
}
