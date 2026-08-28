/// The knowledge tree: every element in the collection, in its real shape.
///
/// The hierarchy is not a filing system laid over the content, it is the
/// content's own provenance. An extract belongs under the text it was cut
/// from, and a card belongs under the passage it was written from, at whatever
/// depth that happens to be. Nothing here caps the nesting, because nothing in
/// the model does: an extract of an extract of an extract is ordinary.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/scheduling_context.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:meta/meta.dart';

/// One element in the tree, with the children it owns.
@immutable
final class LibraryTreeNode {
  const LibraryTreeNode({
    required this.ref,
    required this.title,
    required this.preview,
    required this.children,
    this.dueDay,
    this.status,
    this.lifecycle,
  });

  final ElementRef ref;
  final String title;

  /// A short excerpt, empty when the element has no body worth showing.
  final String preview;

  /// Extracts and cards taken from this element, in creation order.
  final List<LibraryTreeNode> children;

  /// Canonical due day for a scheduled element, or null for a card, whose due
  /// instant is finer-grained than a day.
  final StudyDay? dueDay;

  /// SM20 status, for topics and extracts only.
  final Sm20ElementStatus? status;

  final ElementLifecycle? lifecycle;

  /// Total elements at and below this node.
  int get subtreeSize =>
      1 +
      children.fold<int>(
        0,
        (int total, LibraryTreeNode c) => total + c.subtreeSize,
      );
}

/// Builds the collection's knowledge tree.
final class LibraryTreeQuery {
  LibraryTreeQuery({
    required ContentRepository content,
    required LearningRepository learning,
    required SchedulingContext context,
  }) : _content = content,
       _learning = learning,
       _context = context;

  final ContentRepository _content;
  final LearningRepository _learning;
  final SchedulingContext _context;

  /// Every source, with its descendants nested beneath it.
  Future<List<LibraryTreeNode>> load() async {
    final List<Source> sources = await _content.listSources();
    final List<LibraryTreeNode> roots = <LibraryTreeNode>[];
    for (final Source source in sources) {
      roots.add(await _sourceNode(source));
    }
    return roots;
  }

  Future<LibraryTreeNode> _sourceNode(Source source) async {
    final ElementRef ref = ElementRef(id: source.id, type: ElementType.source);
    final TopicState? topic = await _learning.findTopic(ref);
    return LibraryTreeNode(
      ref: ref,
      title: source.title,
      preview: _excerpt(source.markdown),
      dueDay: topic?.schedule.algorithmicDueDay,
      status: topic?.status,
      lifecycle: topic?.schedule.lifecycle,
      children: <LibraryTreeNode>[
        for (final Extract extract in await _content.listExtractsOfSource(
          source.id,
        ))
          await _extractNode(extract),
        for (final Card card in await _content.listCardsOfSource(source.id))
          await _cardNode(card),
      ],
    );
  }

  /// Recurses, because an extract can be cut from another extract.
  Future<LibraryTreeNode> _extractNode(Extract extract) async {
    final ElementRef ref = ElementRef(
      id: extract.id,
      type: ElementType.extract,
    );
    final TopicState? topic = await _learning.findTopic(ref);
    return LibraryTreeNode(
      ref: ref,
      title: _titleOf(extract.markdown),
      preview: _excerpt(extract.markdown),
      dueDay: topic?.schedule.algorithmicDueDay,
      status: topic?.status,
      lifecycle: topic?.schedule.lifecycle,
      children: <LibraryTreeNode>[
        for (final Extract child in await _content.listExtractsOfParent(
          extract.id,
        ))
          await _extractNode(child),
        for (final Card card in await _content.listCardsOfExtract(extract.id))
          await _cardNode(card),
      ],
    );
  }

  Future<LibraryTreeNode> _cardNode(Card card) async {
    final ElementRef ref = ElementRef(id: card.id, type: ElementType.card);
    final CardState? state = await _learning.findCardState(card.id);
    final StudyDayCalendar calendar = await _context.calendar();
    return LibraryTreeNode(
      ref: ref,
      title: _titleOf(card.front),
      preview: '',
      dueDay: state == null ? null : calendar.dayOf(state.memory.dueAtUtc),
      lifecycle: state?.schedule.lifecycle,
      children: const <LibraryTreeNode>[],
    );
  }

  static String _titleOf(String body) {
    final String flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 70) return flat;
    return '${flat.substring(0, 70)}…';
  }

  static String _excerpt(String body) {
    final String flat = body
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (flat.length <= 110) return flat;
    return '${flat.substring(0, 110)}…';
  }
}
