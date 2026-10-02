/// Pointing a converter's relative image links at the app's own image store.
///
/// The property under test is that only what the Reader would draw as an
/// image is touched: a link inside a code block is example text, not a figure,
/// and rewriting it would silently change the code the user is reading.
library;

import 'package:incremental_reader/documents/markdown_image_references.dart';
import 'package:test/test.dart';

void main() {
  final String figureSha256 = 'a' * 64;
  final String pictureSha256 = 'b' * 64;

  group('listRelativeImageReferences', () {
    test('lists each relative image once, in reading order', () {
      expect(
        listRelativeImageReferences(
          '# Paper\n\n![](_page_1_Figure_0.jpeg)\n\n'
          'Text ![](_page_2_Picture_0.jpeg) inline.\n\n'
          '![](_page_1_Figure_0.jpeg)',
        ),
        <String>['_page_1_Figure_0.jpeg', '_page_2_Picture_0.jpeg'],
      );
    });

    test('skips links that already point somewhere the app can open', () {
      expect(
        listRelativeImageReferences(
          '![](ir-asset:$figureSha256)\n\n'
          '![](https://example.com/figure.png)\n\n'
          '![](http://example.com/figure.png)\n\n'
          '![](data:image/png;base64,AAAA)\n\n'
          '![](/absolute/figure.png)\n\n'
          '![](C:/Users/figure.png)\n\n'
          '![](#figure)',
        ),
        isEmpty,
      );
    });

    test('decodes escapes and drops a leading ./ so one file has one name', () {
      expect(
        listRelativeImageReferences(
          '![](./images/fig%201.png)\n\n![](<images/fig 2.png>)',
        ),
        <String>['images/fig 1.png', 'images/fig 2.png'],
      );
    });

    test('ignores image syntax inside a code block', () {
      expect(
        listRelativeImageReferences('```\n![](example.png)\n```'),
        isEmpty,
      );
    });
  });

  group('rewriteImageReferences', () {
    test('points resolved images at the store and leaves the rest alone', () {
      expect(
        rewriteImageReferences(
          '# Paper\n\n![Figure 1](_page_1_Figure_0.jpeg)\n\n'
          'Text ![](missing.png) inline.',
          <String, String>{'_page_1_Figure_0.jpeg': figureSha256},
        ),
        '# Paper\n\n![Figure 1](ir-asset:$figureSha256)\n\n'
        'Text ![](missing.png) inline.',
      );
    });

    test('matches the same names the list reports, and drops the title', () {
      expect(
        rewriteImageReferences(
          '![fig](./images/fig%201.png "Figure one")',
          <String, String>{'images/fig 1.png': figureSha256},
        ),
        '![fig](ir-asset:$figureSha256)',
      );
    });

    test('rewrites images inside list items and quotes', () {
      expect(
        rewriteImageReferences(
          '- item ![](a.png)\n\n> ![](b.png)',
          <String, String>{'a.png': figureSha256, 'b.png': pictureSha256},
        ),
        '- item ![](ir-asset:$figureSha256)\n\n'
        '> ![](ir-asset:$pictureSha256)',
      );
    });

    test('never touches a code block', () {
      const String markdown = '```\n![](a.png)\n```\n\n![](a.png)';
      expect(
        rewriteImageReferences(markdown, <String, String>{
          'a.png': figureSha256,
        }),
        '```\n![](a.png)\n```\n\n![](ir-asset:$figureSha256)',
      );
    });
  });
}
