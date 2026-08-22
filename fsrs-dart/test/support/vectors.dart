/// Loading and serialization shared by the golden-vector tests.
///
/// The serializers here mirror the ones in `tool/gen_ts_vectors.mts` field for
/// field: a vector comparison is only as good as the agreement between the two
/// encoders, so they are kept deliberately dumb and explicit.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fsrs_dart/fsrs.dart';

/// Reads a vector file from `test/vectors`.
Map<String, Object?> loadVectors(String fileName) {
  final file = File('test/vectors/$fileName');
  if (!file.existsSync()) {
    throw StateError(
      'Missing vector file ${file.path}. Regenerate it with the scripts in '
      'fsrs-dart/tool/.',
    );
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

/// The ISO-8601 form the JavaScript and Python generators emit.
String iso(DateTime value) => value.toUtc().toIso8601String();

/// Serializes a card into the generator's JSON shape.
Map<String, Object?> serializeCard(Card card) => <String, Object?>{
      'due': iso(card.due),
      'stability': card.stability,
      'difficulty': card.difficulty,
      'elapsed_days': card.elapsedDays,
      'scheduled_days': card.scheduledDays,
      'learning_steps': card.learningSteps,
      'reps': card.reps,
      'lapses': card.lapses,
      'state': card.state.value,
      'last_review': card.lastReview == null ? null : iso(card.lastReview!),
    };

/// Serializes a review log into the generator's JSON shape.
Map<String, Object?> serializeLog(ReviewLog log) => <String, Object?>{
      'rating': log.rating.value,
      'state': log.state.value,
      'due': iso(log.due),
      'stability': log.stability,
      'difficulty': log.difficulty,
      'elapsed_days': log.elapsedDays,
      'last_elapsed_days': log.lastElapsedDays,
      'scheduled_days': log.scheduledDays,
      'learning_steps': log.learningSteps,
      'review': iso(log.review),
    };

/// Rebuilds a card from the generator's JSON shape.
Card cardFromVector(Map<String, Object?> json) => Card(
      due: DateTime.parse(json['due']! as String),
      stability: (json['stability']! as num).toDouble(),
      difficulty: (json['difficulty']! as num).toDouble(),
      elapsedDays: (json['elapsed_days']! as num).toInt(),
      scheduledDays: (json['scheduled_days']! as num).toInt(),
      learningSteps: (json['learning_steps']! as num).toInt(),
      reps: (json['reps']! as num).toInt(),
      lapses: (json['lapses']! as num).toInt(),
      state: State.fromValue((json['state']! as num).toInt()),
      lastReview: json['last_review'] == null
          ? null
          : DateTime.parse(json['last_review']! as String),
    );

/// Casts a JSON list of numbers to doubles.
List<double> doubles(Object? value) =>
    (value! as List<Object?>).map((Object? e) => (e! as num).toDouble())
        .toList();

/// Casts a JSON list of strings.
List<String> strings(Object? value) =>
    (value! as List<Object?>).map((Object? e) => e! as String).toList();
