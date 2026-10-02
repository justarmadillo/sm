/// The one answer to "is this element kept out of spaced repetition?"
///
/// An element is cram-only when it carries the `#cram` tag, or is filed under
/// something that does. Cram-only elements are studied in custom decks and
/// nowhere else: the daily queue leaves them out, and no grade or Done moves
/// their schedule.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/filing_tree.dart';
import 'package:incremental_reader/storage/contracts/content_repository.dart';
import 'package:incremental_reader/storage/contracts/learning_repository.dart';
import 'package:incremental_reader/storage/contracts/tag_repository.dart';
import 'package:incremental_reader/storage/contracts/video_repository.dart';

/// What a command runner says when asked to advance a cram-only schedule.
const String kCramOnlyRefusal =
    'cram-only elements are studied in custom decks; their schedule does not '
    'advance';

/// Reads which elements the `#cram` tag reaches, directly or through filing.
final class CramScopeQuery {
  const CramScopeQuery({
    required TagRepository tags,
    required ContentRepository content,
    required VideoRepository videos,
    required LearningRepository learning,
  }) : _tags = tags,
       _content = content,
       _videos = videos,
       _learning = learning;

  final TagRepository _tags;
  final ContentRepository _content;
  final VideoRepository _videos;
  final LearningRepository _learning;

  /// Every cram-only element.
  ///
  /// Returns early, before building any tree, when there is no `#cram` tag or
  /// nothing carries it, so a collection that never uses cram pays two small
  /// reads per queue load and nothing more.
  Future<Set<ElementRef>> listCramOnlyRefs() async {
    final Tag? cram = await _tags.findTagByLowercaseName(Tag.cramLowercaseName);
    if (cram == null) return const <ElementRef>{};
    final Set<ElementRef> tagged = await _tags.listElementsWithTag(cram.id);
    if (tagged.isEmpty) return const <ElementRef>{};
    final FilingTree tree = FilingTree.of(await _listFilingLinks());
    return tree.listInheritors(
      tagId: cram.id,
      directTagIds: <ElementRef, Set<String>>{
        for (final ElementRef ref in tagged) ref: <String>{cram.id},
      },
    );
  }

  /// Whether [ref] is cram-only.
  Future<bool> isCramOnly(ElementRef ref) async =>
      (await listCramOnlyRefs()).contains(ref);

  /// Every element with both of its parents, the same population the Browser
  /// draws.
  ///
  /// Schedules of every lifecycle are read because inheritance passes through
  /// a dismissed parent exactly as it does in the Browser.
  Future<List<FilingLink>> _listFilingLinks() async {
    final Map<ElementRef, String?> provenanceParents = await _content
        .listProvenanceParents();
    final Map<String, String?> videoParents = await _videos
        .listVideoElementParents();
    final Map<String, String?> filedParents = <String, String?>{
      for (final ElementSchedule schedule in await _learning.listSchedules(
        types: ElementType.values.toSet(),
      ))
        schedule.ref.id: schedule.parentElementId,
    };
    return <FilingLink>[
      for (final MapEntry<ElementRef, String?> entry
          in provenanceParents.entries)
        FilingLink(
          ref: entry.key,
          filedParentId: filedParents[entry.key.id],
          provenanceParentId: entry.value,
        ),
      for (final MapEntry<String, String?> entry in videoParents.entries)
        FilingLink(
          ref: ElementRef(id: entry.key, type: ElementType.video),
          filedParentId: filedParents[entry.key],
          provenanceParentId: entry.value,
        ),
    ];
  }
}
