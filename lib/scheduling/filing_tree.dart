/// Where each element is filed, and which tags it inherits from above.
///
/// The Browser draws this tree and the daily queue asks it which elements a
/// cram-only tag reaches. Both read the same parent rule from here, so the row
/// the Browser shows as cram-only is exactly the row the queue leaves out.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:meta/meta.dart';

/// One element and the two parents it may be filed under.
@immutable
final class FilingLink {
  const FilingLink({
    required this.ref,
    this.filedParentId,
    this.provenanceParentId,
  });

  final ElementRef ref;

  /// The parent the user filed this under, from `element_schedules`.
  final String? filedParentId;

  /// The element this was cut or written from. A move never writes it.
  final String? provenanceParentId;

  /// The filed parent when there is one, otherwise the provenance parent.
  ///
  /// The fallback is what makes a collection built before filing existed open
  /// in its provenance shape rather than as one flat list.
  String? get parentId => filedParentId ?? provenanceParentId;
}

/// The collection as a forest of filed elements.
final class FilingTree {
  FilingTree._({
    required this.roots,
    required Map<String, List<ElementRef>> childrenByParentId,
  }) : _childrenByParentId = childrenByParentId;

  /// Builds the forest, keeping each level in the order [links] arrive in.
  factory FilingTree.of(Iterable<FilingLink> links) {
    final List<FilingLink> all = links.toList(growable: false);
    final Set<String> presentIds = <String>{
      for (final FilingLink link in all) link.ref.id,
    };
    final List<ElementRef> roots = <ElementRef>[];
    final Map<String, List<ElementRef>> childrenByParentId =
        <String, List<ElementRef>>{};
    for (final FilingLink link in all) {
      final String? parentId = link.parentId;
      // A parent that is no longer in the collection cannot hold anything, so
      // its orphans surface at the top rather than disappearing with it.
      if (parentId == null || !presentIds.contains(parentId)) {
        roots.add(link.ref);
      } else {
        childrenByParentId
            .putIfAbsent(parentId, () => <ElementRef>[])
            .add(link.ref);
      }
    }
    return FilingTree._(
      roots: List<ElementRef>.unmodifiable(roots),
      childrenByParentId: childrenByParentId,
    );
  }

  /// Elements with no parent in the collection.
  final List<ElementRef> roots;

  final Map<String, List<ElementRef>> _childrenByParentId;

  /// What is filed directly under [parent], in arrival order.
  List<ElementRef> childrenOf(ElementRef parent) =>
      _childrenByParentId[parent.id] ?? const <ElementRef>[];

  /// Each reachable element's direct tags plus every tag of its ancestors.
  ///
  /// Elements caught in a filing loop — which no command can create, but a
  /// hand-edited database could — are never reached from a root, so they are
  /// left out here exactly as the Browser leaves them out of its tree.
  Map<ElementRef, Set<String>> inheritTags(
    Map<ElementRef, Set<String>> directTagIds,
  ) {
    final Map<ElementRef, Set<String>> effective = <ElementRef, Set<String>>{};
    final List<(ElementRef, Set<String>)> pending = <(ElementRef, Set<String>)>[
      for (final ElementRef root in roots) (root, const <String>{}),
    ];
    while (pending.isNotEmpty) {
      final (ElementRef ref, Set<String> inherited) = pending.removeLast();
      if (effective.containsKey(ref)) continue;
      final Set<String> tagIds = Set<String>.unmodifiable(<String>{
        ...inherited,
        ...?directTagIds[ref],
      });
      effective[ref] = tagIds;
      for (final ElementRef child in childrenOf(ref)) {
        pending.add((child, tagIds));
      }
    }
    return effective;
  }

  /// Elements carrying [tagId] directly or through a filed ancestor.
  Set<ElementRef> listInheritors({
    required String tagId,
    required Map<ElementRef, Set<String>> directTagIds,
  }) => <ElementRef>{
    for (final MapEntry<ElementRef, Set<String>> entry in inheritTags(
      directTagIds,
    ).entries)
      if (entry.value.contains(tagId)) entry.key,
  };
}
