/// Removing the HTML Marker leaves in its markdown, which the Reader would
/// otherwise show as literal tags.
///
/// Every input below mirrors a pattern found in Marker's own published example
/// output: page anchors before headings and figures, links to those anchors,
/// footnote superscripts, bold table cells, and line breaks inside cells.
library;

import 'package:incremental_reader/documents/marker_cleanup.dart';
import 'package:test/test.dart';

void main() {
  test('removes the page anchors Marker puts before headings and figures', () {
    expect(
      cleanMarkerMarkdown(
        '### <span id="page-2-0"></span>3.1 Methods\n\n'
        '<span id="page-23-0"></span>![](_page_23_Figure_3.jpeg)',
      ),
      '### 3.1 Methods\n\n![](_page_23_Figure_3.jpeg)',
    );
  });

  test('keeps the text of links to those anchors, which lead nowhere', () {
    expect(
      cleanMarkerMarkdown(
        'As shown in [\\[24\\]](#page-8-15) and Exercise [11.10.](#page-132-0)',
      ),
      'As shown in \\[24\\] and Exercise 11.10.',
    );
  });

  test('keeps an image whose link happens to start with #', () {
    expect(cleanMarkerMarkdown('![](#figure)'), '![](#figure)');
  });

  test('turns footnote superscripts into superscript characters', () {
    expect(
      cleanMarkerMarkdown('Deprecated<sup>1</sup> since CO<sub>2</sub>.'),
      'Deprecated¹ since CO₂.',
    );
  });

  test('keeps the text of a superscript that has no superscript form', () {
    expect(cleanMarkerMarkdown('Value<sup>a</sup>'), 'Valuea');
  });

  test('turns bold tags into markdown bold, spaces kept outside', () {
    expect(
      cleanMarkerMarkdown('| AMDCN | <b>9.77</b> | <b> 13.16 </b> |<b></b>'),
      '| AMDCN | **9.77** |  **13.16**  |',
    );
  });

  test('joins lines broken inside a table cell with a space', () {
    expect(
      cleanMarkerMarkdown(
        '| Method | GAME<br>(L=0) |\n|---|---|\n| SIFT<br>from [14] | 13.76 |',
      ),
      '| Method | GAME (L=0) |\n|---|---|\n| SIFT from [14] | 13.76 |',
    );
  });

  test('leaves code and math exactly as written', () {
    const String markdown =
        '```html\n<b>bold</b><br><sup>1</sup>\n```\n\n\$\$\n<b>x</b>\n\$\$';
    expect(cleanMarkerMarkdown(markdown), markdown);
  });

  test('a Marker page comes out with no tags left', () {
    expect(
      cleanMarkerMarkdown(
        '# <span id="page-4-0"></span>**Chapter 1**\n\n'
        'Counting objects<sup>1</sup> is hard; see [\\[15\\]](#page-8-3).\n\n'
        '<span id="page-1-0"></span>![](_page_1_Figure_0.jpeg)\n\n'
        '| Method | MAE<br>(test) |\n|---|---|\n| Ours | <b>9.77</b> |\n\n'
        '<span id="page-2-1"></span><sup>1</sup> Code is available.',
      ),
      '# **Chapter 1**\n\n'
      'Counting objects¹ is hard; see \\[15\\].\n\n'
      '![](_page_1_Figure_0.jpeg)\n\n'
      '| Method | MAE (test) |\n|---|---|\n| Ours | **9.77** |\n\n'
      '¹ Code is available.',
    );
  });
}
