/// The Browser's tree: every element in the collection, nested and ordered
/// the way the user has filed it.
///
/// Two different questions are being answered by two different pieces of data,
/// and keeping them apart is the whole design of this file:
///
/// * **Where did this come from?** That is provenance, and it never moves. An
///   extract holds the byte range of the passage it was cut from, which is
///   what lets the Reader jump back to that exact passage. Nothing in the
///   Browser writes it.
/// * **Where do I keep this?** That is filing, and the user moves it freely.
///   It lives on the element's schedule row as a parent and an ordinal.
///
/// A collection that has never been reorganised looks identical either way,
/// because extraction files a new extract under the text it came from. The two
/// only diverge once something is moved, and then the extract keeps working in
/// context while sitting wherever the user put it.
library;

import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/source.dart';
import 'package:incremental_reader/documents/video.dart';
import 'package:incremental_reader/features/tags/element_tag_name_index.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/filing_tree.dart';
import 'package:incremental_reader/scheduling/study_day.dart';
import 'package:incremental_reader/scheduling/topics/topic_scheduler.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:incremental_reader/storage/contracts/video_repository.dart';
import 'package:meta/meta.dart';

/// One element in the tree, with the children filed under it.
@immutable
final class BrowserTreeNode {
  const BrowserTreeNode({
    required this.ref,
    required this.title,
    required this.addedAtUtc,
    required this.children,
    required this.directTagIds,
    required this.effectiveTagIds,
    this.tagNames = const <String>[],
    this.parentRef,
    this.thumbnailSource,
    this.dueDay,
    this.status,
    this.lifecycle,
  });

  final ElementRef ref;
  final String title;
  final DateTime addedAtUtc;

  /// A video's optional remote or embedded preview; null for other elements.
  final String? thumbnailSource;

  /// The element this one is filed under, or null at the top of the tree.
  ///
  /// The row needs it to know whether moving out one level is possible at all.
  final ElementRef? parentRef;

  /// What is filed under this element, in the user's order.
  final List<BrowserTreeNode> children;

  /// Tags written on this row rather than inherited through filing.
  final Set<String> directTagIds;

  /// Direct tags plus every tag inherited from filed ancestors.
  final Set<String> effectiveTagIds;

  /// Display names of direct and inherited tags, in alphabetic order.
  final List<String> tagNames;

  /// Canonical due day, or null for an element with no schedule row.
  final StudyDay? dueDay;

  /// SM20 status, for topics and extracts only.
  final Sm20ElementStatus? status;

  final ElementLifecycle? lifecycle;

  /// Total elements at and below this node.
  int get subtreeSize =>
      1 +
      children.fold<int>(
        0,
        (int total, BrowserTreeNode child) => total + child.subtreeSize,
      );
}

/// Builds the collection's tree as the Browser shows it.
final class BrowserTreeQuery {
  BrowserTreeQuery({
    required ContentRepository content,
    required VideoRepository videos,
    required LearningRepository learning,
    required TagRepository tags,
  }) : _content = content,
       _videos = videos,
       _learning = learning,
       _tags = tags;

  final ContentRepository _content;
  final VideoRepository _videos;
  final LearningRepository _learning;
  final TagRepository _tags;

  /// Everything in the collection, nested under whatever it is filed beneath.
  Future<List<BrowserTreeNode>> load() async {
    final List<_Element> elements = await _listEverything();
    final Map<String, ElementSchedule> schedules = await _schedulesById();
    final Map<ElementRef, Sm20ElementStatus> statuses = await _statuses(
      elements,
    );
    final ElementTagNameIndex tagNameIndex = await ElementTagNameIndex.load(
      _tags,
    );

    final FilingTree tree = FilingTree.of(<FilingLink>[
      for (final _Element element in elements)
        FilingLink(
          ref: element.ref,
          filedParentId: schedules[element.ref.id]?.parentElementId,
          provenanceParentId: element.provenanceParentId,
        ),
    ]);
    final Map<ElementRef, _Element> elementsByRef = <ElementRef, _Element>{
      for (final _Element element in elements) element.ref: element,
    };

    return _nodesFrom(
      tree.roots,
      parentRef: null,
      tree: tree,
      elementsByRef: elementsByRef,
      schedules: schedules,
      statuses: statuses,
      tagNameIndex: tagNameIndex,
      effectiveTagIds: tree.inheritTags(tagNameIndex.tagIdsByElement),
      alreadyPlaced: <String>{},
    );
  }

  /// Sources, extracts, videos, and cards with their visible tree titles.
  ///
  /// The fallback order is the order this list is built in: sources newest
  /// first, as the import list always showed them, then extracts and cards
  /// oldest first, so a nested branch reads top to bottom in the order it was
  /// made. An element that has never been moved has no ordinal and keeps that
  /// order forever.
  Future<List<_Element>> _listEverything() async {
    final List<Source> sources = await _content.listSources();
    final List<Extract> extracts = await _content.listExtracts();
    final List<VideoElement> videoElements = await _videos.listVideoElements();
    final List<Video> videos = await _videos.listVideos();
    final Map<String, Video> videosById = <String, Video>{
      for (final Video video in videos) video.id: video,
    };
    final List<Card> cards = await _content.listCards();

    final List<_Element> elements = <_Element>[];
    for (final Source source in sources) {
      elements.add(
        _Element(
          ref: ElementRef(id: source.id, type: ElementType.source),
          title: source.title,
          addedAtUtc: source.importedAtUtc,
          provenanceParentId: null,
          fallbackIndex: elements.length,
        ),
      );
    }
    for (final Extract extract in extracts) {
      elements.add(
        _Element(
          ref: ElementRef(id: extract.id, type: ElementType.extract),
          title: _titleOf(extract.markdown),
          addedAtUtc: extract.createdAtUtc,
          provenanceParentId: extract.provenance.parentId,
          fallbackIndex: elements.length,
        ),
      );
    }
    for (final VideoElement element in videoElements) {
      elements.add(
        _Element(
          ref: ElementRef(id: element.id, type: ElementType.video),
          title: element.displayTitle,
          addedAtUtc: element.createdAtUtc,
          thumbnailSource: videosById[element.videoId]?.thumbnailUrl,
          provenanceParentId: element.parentVideoElementId,
          fallbackIndex: elements.length,
        ),
      );
    }
    for (final Card card in cards) {
      elements.add(
        _Element(
          ref: ElementRef(id: card.id, type: ElementType.card),
          title: card.type == CardType.imageOcclusion && card.front.isEmpty
              ? 'Image occlusion'
              : _titleOf(card.front),
          addedAtUtc: card.createdAtUtc,
          provenanceParentId: card.parent?.id,
          fallbackIndex: elements.length,
        ),
      );
    }
    return elements;
  }

  Future<Map<String, ElementSchedule>> _schedulesById() async {
    final List<ElementSchedule> schedules = await _learning
        .listSchedulesByPriority();
    return <String, ElementSchedule>{
      for (final ElementSchedule schedule in schedules)
        schedule.ref.id: schedule,
    };
  }

  /// SM20 status for every topic and extract, in one read rather than one per
  /// row: a large collection is a lot of rows.
  Future<Map<ElementRef, Sm20ElementStatus>> _statuses(
    List<_Element> elements,
  ) async {
    final List<ElementRef> topicRefs = <ElementRef>[
      for (final _Element element in elements)
        if (element.ref.type != ElementType.card) element.ref,
    ];
    if (topicRefs.isEmpty) return <ElementRef, Sm20ElementStatus>{};
    final Map<ElementRef, TopicState> topics = await _learning.findTopics(
      topicRefs,
    );
    return <ElementRef, Sm20ElementStatus>{
      for (final MapEntry<ElementRef, TopicState> entry in topics.entries)
        entry.key: entry.value.status,
    };
  }

  /// Turns one level of elements into nodes, deepest last.
  ///
  /// [alreadyPlaced] stops a filing loop — which no command can create, but a
  /// hand-edited database could — from being walked forever.
  List<BrowserTreeNode> _nodesFrom(
    List<ElementRef> level, {
    required ElementRef? parentRef,
    required FilingTree tree,
    required Map<ElementRef, _Element> elementsByRef,
    required Map<String, ElementSchedule> schedules,
    required Map<ElementRef, Sm20ElementStatus> statuses,
    required ElementTagNameIndex tagNameIndex,
    required Map<ElementRef, Set<String>> effectiveTagIds,
    required Set<String> alreadyPlaced,
  }) {
    final List<_Element> ordered =
        <_Element>[for (final ElementRef ref in level) elementsByRef[ref]!]
          ..sort(
            (_Element first, _Element second) =>
                _compareFiling(first, second, schedules),
          );

    final List<BrowserTreeNode> nodes = <BrowserTreeNode>[];
    for (final _Element element in ordered) {
      if (!alreadyPlaced.add(element.ref.id)) continue;
      final ElementSchedule? schedule = schedules[element.ref.id];
      final Set<String> directTagIds = tagNameIndex.tagIdsOf(element.ref);
      final Set<String> inheritedAndDirect =
          effectiveTagIds[element.ref] ?? directTagIds;
      nodes.add(
        BrowserTreeNode(
          ref: element.ref,
          title: element.title,
          addedAtUtc: element.addedAtUtc,
          thumbnailSource: element.thumbnailSource,
          parentRef: parentRef,
          dueDay: schedule?.dueDay,
          status: statuses[element.ref],
          lifecycle: schedule?.lifecycle,
          directTagIds: directTagIds,
          effectiveTagIds: inheritedAndDirect,
          tagNames: tagNameIndex.listNamesFor(inheritedAndDirect),
          children: _nodesFrom(
            tree.childrenOf(element.ref),
            parentRef: element.ref,
            tree: tree,
            elementsByRef: elementsByRef,
            schedules: schedules,
            statuses: statuses,
            tagNameIndex: tagNameIndex,
            effectiveTagIds: effectiveTagIds,
            alreadyPlaced: alreadyPlaced,
          ),
        ),
      );
    }
    return nodes;
  }

  /// Ordinal first, then the order the elements were made in.
  ///
  /// A move renumbers every sibling it touches, so the mixed case — one row
  /// carrying an ordinal beside rows that have never moved — only lasts until
  /// the next move of that branch.
  static int _compareFiling(
    _Element first,
    _Element second,
    Map<String, ElementSchedule> schedules,
  ) {
    final int? firstOrdinal = schedules[first.ref.id]?.ordinal;
    final int? secondOrdinal = schedules[second.ref.id]?.ordinal;
    if (firstOrdinal != null && secondOrdinal != null) {
      final int byOrdinal = firstOrdinal.compareTo(secondOrdinal);
      if (byOrdinal != 0) return byOrdinal;
    } else if (firstOrdinal != null) {
      return -1;
    } else if (secondOrdinal != null) {
      return 1;
    }
    return first.fallbackIndex.compareTo(second.fallbackIndex);
  }

  static String _titleOf(String body) {
    final String flat = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.length <= 70) return flat;
    return '${flat.substring(0, 70)}…';
  }
}

/// One element of the collection, before it is placed in the tree.
@immutable
final class _Element {
  const _Element({
    required this.ref,
    required this.title,
    required this.addedAtUtc,
    required this.provenanceParentId,
    required this.fallbackIndex,
    this.thumbnailSource,
  });

  final ElementRef ref;
  final String title;
  final DateTime addedAtUtc;
  final String? thumbnailSource;

  /// The element this was cut or written from. Used only when nothing has been
  /// filed yet; a move never writes it.
  final String? provenanceParentId;

  /// Position in the collection-wide listing, used to order siblings that
  /// have never been moved.
  final int fallbackIndex;
}
