/// Parent choice, orphan roots, loop safety, and tag inheritance of the
/// filing tree shared by the Browser and the daily queue.
library;

import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/scheduling/filing_tree.dart';
import 'package:test/test.dart';

const ElementRef _source = ElementRef(id: 'source', type: ElementType.source);
const ElementRef _otherSource = ElementRef(
  id: 'other-source',
  type: ElementType.source,
);
const ElementRef _extract = ElementRef(
  id: 'extract',
  type: ElementType.extract,
);
const ElementRef _card = ElementRef(id: 'card', type: ElementType.card);

void main() {
  test('a filed parent wins over the provenance parent', () {
    final FilingTree tree = FilingTree.of(const <FilingLink>[
      FilingLink(ref: _source),
      FilingLink(ref: _otherSource),
      FilingLink(
        ref: _extract,
        filedParentId: 'other-source',
        provenanceParentId: 'source',
      ),
    ]);

    expect(tree.childrenOf(_otherSource), <ElementRef>[_extract]);
    expect(tree.childrenOf(_source), isEmpty);
  });

  test('no filed parent falls back to provenance', () {
    final FilingTree tree = FilingTree.of(const <FilingLink>[
      FilingLink(ref: _source),
      FilingLink(ref: _extract, provenanceParentId: 'source'),
    ]);

    expect(tree.roots, <ElementRef>[_source]);
    expect(tree.childrenOf(_source), <ElementRef>[_extract]);
  });

  test('a parent missing from the collection makes the element a root', () {
    final FilingTree tree = FilingTree.of(const <FilingLink>[
      FilingLink(ref: _extract, provenanceParentId: 'deleted-source'),
    ]);

    expect(tree.roots, <ElementRef>[_extract]);
  });

  test('tags flow down through every level and add to direct tags', () {
    final FilingTree tree = FilingTree.of(const <FilingLink>[
      FilingLink(ref: _source),
      FilingLink(ref: _extract, provenanceParentId: 'source'),
      FilingLink(ref: _card, provenanceParentId: 'extract'),
    ]);

    final Map<ElementRef, Set<String>> effective = tree.inheritTags(
      <ElementRef, Set<String>>{
        _source: <String>{'biology'},
        _card: <String>{'exam'},
      },
    );

    expect(effective[_source], <String>{'biology'});
    expect(effective[_extract], <String>{'biology'});
    expect(effective[_card], <String>{'biology', 'exam'});
  });

  test('members of a filing loop are never reached', () {
    final FilingTree tree = FilingTree.of(const <FilingLink>[
      FilingLink(ref: _source),
      FilingLink(ref: _extract, filedParentId: 'card'),
      FilingLink(ref: _card, filedParentId: 'extract'),
    ]);

    final Map<ElementRef, Set<String>> effective = tree.inheritTags(
      <ElementRef, Set<String>>{
        _extract: <String>{'cram'},
      },
    );

    expect(effective.keys, <ElementRef>[_source]);
  });

  test('listInheritors names the tagged element and everything below it', () {
    final FilingTree tree = FilingTree.of(const <FilingLink>[
      FilingLink(ref: _source),
      FilingLink(ref: _otherSource),
      FilingLink(ref: _extract, provenanceParentId: 'source'),
      FilingLink(ref: _card, provenanceParentId: 'extract'),
    ]);

    expect(
      tree.listInheritors(
        tagId: 'cram',
        directTagIds: <ElementRef, Set<String>>{
          _extract: <String>{'cram'},
        },
      ),
      <ElementRef>{_extract, _card},
    );
  });
}
