/// A pure Dart port of ts-fsrs 5.4.1 — the Free Spaced Repetition Scheduler,
/// FSRS-6.
///
/// No Flutter dependency: this package is plain Dart so the scheduler can be
/// tested and reasoned about without a widget tree or a platform channel.
///
/// ```dart
/// final scheduler = fsrs();
/// final card = createEmptyCard(DateTime.utc(2022, 11, 29, 12, 30));
/// final result = scheduler.next(card, DateTime.utc(2022, 11, 29, 12, 30),
///     Rating.good);
/// print(result.card.due);
/// ```
library;

export 'src/abstract_scheduler.dart';
export 'src/alea.dart';
export 'src/algorithm.dart';
export 'src/constant.dart';
export 'src/convert.dart';
export 'src/default.dart';
export 'src/error.dart';
export 'src/fsrs.dart';
export 'src/help.dart';
export 'src/impl/basic_scheduler.dart';
export 'src/impl/long_term_scheduler.dart';
export 'src/js_compat.dart';
export 'src/models.dart';
export 'src/reschedule.dart';
export 'src/strategies/learning_steps.dart';
export 'src/strategies/seed.dart';
export 'src/strategies/types.dart';
