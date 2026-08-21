/// Read model for the minimal M3 heterogeneous study queue.
library;

import 'package:meta/meta.dart';

import '../../core/clock.dart';
import '../../domain/content/card.dart';
import '../../domain/content/source.dart';
import '../../domain/scheduling/element.dart';
import '../../domain/scheduling/queue_policy.dart';
import '../../domain/scheduling/study_day.dart';
import '../ports/repositories.dart';

/// Presentation-neutral queue row. Answers are deliberately never projected.
@immutable
final class QueueEntry {
  const QueueEntry({
    required this.candidate,
    required this.actionLabel,
    required this.title,
    required this.preview,
  });

  final QueueCandidate candidate;
  final String actionLabel;
  final String title;
  final String preview;

  ElementRef get ref => candidate.ref;
}

final class QueueQuery {
  const QueueQuery({
    required ContentRepository content,
    required LearningRepository learning,
    required Clock clock,
    required StudyDayCalendar calendar,
    MinimalQueuePolicy policy = const MinimalQueuePolicy(),
  }) : _content = content,
       _learning = learning,
       _clock = clock,
       _calendar = calendar,
       _policy = policy;

  final ContentRepository _content;
  final LearningRepository _learning;
  final Clock _clock;
  final StudyDayCalendar _calendar;
  final MinimalQueuePolicy _policy;

  Future<List<QueueEntry>> load() async {
    final now = _clock.nowUtc();
    final today = _calendar.dayOf(now);
    final topicSchedules = await _learning.listEligible(
      day: today,
      types: const <ElementType>{ElementType.source, ElementType.extract},
    );
    final topics = await _learning.findTopics(<ElementRef>[
      for (final schedule in topicSchedules) schedule.ref,
    ]);
    final cards = await _learning.listDueCards(now);
    final ordered = _policy.build(
      candidates: <QueueCandidate>[
        for (final schedule in topicSchedules)
          if (topics[schedule.ref] case final topic?)
            QueueCandidate.topic(topic),
        for (final card in cards) QueueCandidate.card(card),
      ],
      nowUtc: now,
      today: today,
    );

    final result = <QueueEntry>[];
    for (final candidate in ordered) {
      final entry = await _project(candidate);
      if (entry != null) result.add(entry);
    }
    return List<QueueEntry>.unmodifiable(result);
  }

  Future<QueueEntry?> _project(QueueCandidate candidate) async {
    return switch (candidate.ref.type) {
      ElementType.source => _sourceEntry(candidate),
      ElementType.extract => _extractEntry(candidate),
      ElementType.card => _cardEntry(candidate),
    };
  }

  Future<QueueEntry?> _sourceEntry(QueueCandidate candidate) async {
    final source = await _content.findSource(candidate.ref.id);
    if (source == null) return null;
    return QueueEntry(
      candidate: candidate,
      actionLabel: 'Read',
      title: source.title,
      preview: _excerpt(source.markdown),
    );
  }

  Future<QueueEntry?> _extractEntry(QueueCandidate candidate) async {
    final extract = await _content.findExtract(candidate.ref.id);
    if (extract == null) return null;
    final source = await _content.findSource(extract.provenance.sourceId);
    return QueueEntry(
      candidate: candidate,
      actionLabel: 'Process',
      title: source?.title ?? 'Extract',
      preview: _excerpt(extract.markdown),
    );
  }

  /// The article a card ultimately came from, through whichever parent it
  /// has. A standalone card has none, and the entry falls back to its type.
  Future<Source?> _sourceOfCard(Card card) async {
    final parent = card.parent;
    if (parent == null) return null;
    if (parent.isSource) return _content.findSource(parent.id);
    final extract = await _content.findExtract(parent.id);
    if (extract == null) return null;
    return _content.findSource(extract.provenance.sourceId);
  }

  Future<QueueEntry?> _cardEntry(QueueCandidate candidate) async {
    final card = await _content.findCard(candidate.ref.id);
    if (card == null) return null;
    final source = await _sourceOfCard(card);
    final question = switch (card.kind) {
      CardKind.qa => card.front,
      CardKind.cloze => renderClozeQuestion(card.front, card.clozeOrdinal!),
    };
    return QueueEntry(
      candidate: candidate,
      actionLabel: 'Review',
      title: source?.title ?? 'Card',
      preview: _excerpt(question),
    );
  }
}

String _excerpt(String markdown, {int maximum = 180}) {
  final collapsed = markdown.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maximum) return collapsed;
  return '${collapsed.substring(0, maximum - 1).trimRight()}…';
}
