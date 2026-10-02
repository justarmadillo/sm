/// Full-page topic creation from typed, pasted, or opened Markdown.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/features/browser/import_sheet.dart';
import 'package:incremental_reader/features/browser/markdown_file_input.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

void main() {
  final SourceImageImport figure = _image('a');
  final SourceImageImport picture = _image('b');

  /// Opens the topic page over a launcher, and collects what it returns.
  Future<ImportRequest? Function()> openPage(
    WidgetTester tester,
    MarkdownFileInput input,
  ) async {
    ImportRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () async => result = await openTopicCreationPage(
              context,
              markdownFileInput: input,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return () => result;
  }

  Future<void> tapAdd(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final Finder addButton = find.widgetWithText(FilledButton, 'Add');
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
  }

  testWidgets('topic creation opens as a page and returns its content', (
    WidgetTester tester,
  ) async {
    final result = await openPage(tester, const _FakeMarkdownFileInput());

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add topic'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Memory systems');
    await tester.enterText(
      find.byType(TextField).last,
      '# Memory systems\n\nSpaced retrieval.',
    );
    await tapAdd(tester);

    expect(find.text('Open'), findsOneWidget);
    final ImportRequest request = result()!;
    expect(request.title, 'Memory systems');
    expect(request.markdown, contains('Spaced retrieval.'));
    expect(request.images, isEmpty);
  });

  testWidgets('an opened file brings its images and counts the missing', (
    WidgetTester tester,
  ) async {
    final result = await openPage(
      tester,
      _FakeMarkdownFileInput(
        opened: MarkdownWithImages(
          markdown:
              '# Paper\n\n![](${figure.srcRef})\n\n![](${picture.srcRef})',
          fileName: 'paper.zip',
          images: <SourceImageImport>[figure, picture],
          missingImageCount: 1,
        ),
      ),
    );

    await tester.tap(find.text('Open markdown or zip'));
    await tester.pump();

    expect(find.text('2 images attached'), findsOneWidget);
    expect(find.text('· 1 not found'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Paper',
    );

    await tester.enterText(
      find.byType(TextField).last,
      '# Paper\n\n![](${figure.srcRef})',
    );
    await tester.pump();
    expect(find.text('1 image attached'), findsOneWidget);
    await tapAdd(tester);

    final ImportRequest request = result()!;
    expect(
      request.images.map((SourceImageImport image) => image.srcRef),
      <String>[figure.srcRef],
    );
  });

  testWidgets('a markdown file without its folder says to zip the folder', (
    WidgetTester tester,
  ) async {
    await openPage(
      tester,
      const _FakeMarkdownFileInput(
        opened: MarkdownWithImages(
          markdown: '# Paper\n\n![](fig.png)',
          fileName: 'paper.md',
          images: <SourceImageImport>[],
          missingImageCount: 1,
          shouldZipFolderForImages: true,
        ),
      ),
    );

    await tester.tap(find.text('Open markdown or zip'));
    await tester.pump();

    expect(
      find.text('Zip the Marker folder to bring its images'),
      findsOneWidget,
    );
    await tester.pump(kToastDuration);
  });

  testWidgets('a file that cannot become a topic says why', (
    WidgetTester tester,
  ) async {
    await openPage(
      tester,
      const _FakeMarkdownFileInput(
        failure: MarkdownFileInputException('This zip has no markdown file'),
      ),
    );

    await tester.tap(find.text('Open markdown or zip'));
    await tester.pump();

    expect(find.text('This zip has no markdown file'), findsOneWidget);
    await tester.pump(kToastDuration);
  });
}

/// Returns one prepared file, or fails, without touching a real picker.
final class _FakeMarkdownFileInput implements MarkdownFileInput {
  const _FakeMarkdownFileInput({this.opened, this.failure});

  final MarkdownWithImages? opened;
  final MarkdownFileInputException? failure;

  @override
  Future<MarkdownWithImages?> chooseMarkdownFile() async {
    final MarkdownFileInputException? failure = this.failure;
    if (failure != null) throw failure;
    return opened;
  }
}

/// An already-validated image whose hash is [hexDigit] repeated.
SourceImageImport _image(String hexDigit) => SourceImageImport(
  bytes: Uint8List(1),
  altText: 'Image',
  sha256: hexDigit * 64,
  mime: 'image/png',
  widthPx: 1,
  heightPx: 1,
);
