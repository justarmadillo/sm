/// Reader typography and layout preferences, remembered between sessions.
library;

import 'package:meta/meta.dart';

/// Reader behaviour that is a preference rather than a scheduling rule.
@immutable
final class ReaderSettings {
  const ReaderSettings({this.reminderWords = 500});

  final int reminderWords;

  ReaderSettings copyWith({int? reminderWords}) =>
      ReaderSettings(reminderWords: reminderWords ?? this.reminderWords);

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings && other.reminderWords == reminderWords;

  @override
  int get hashCode => reminderWords.hashCode;
}
