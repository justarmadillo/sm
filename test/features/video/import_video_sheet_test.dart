/// Portable thumbnail encoding used by local and clipboard video images.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/features/reader/reader_commands.dart';
import 'package:incremental_reader/features/video/import_video_sheet.dart';

void main() {
  test('chosen thumbnail bytes become a portable image data URI', () {
    final SourceImageImport image = SourceImageImport(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      altText: 'Preview',
      sha256: 'unused by thumbnail encoding',
      mime: 'image/png',
      widthPx: 2,
      heightPx: 1,
    );

    expect(videoThumbnailDataUrl(image), 'data:image/png;base64,AQID');
  });

  testWidgets('video creation uses a full page and returns its details', (
    WidgetTester tester,
  ) async {
    VideoImportRequest? result;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) =>
                FilledButton(
                  onPressed: () async =>
                      result = await openVideoCreationPage(context, ref),
                  child: const Text('Open'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add video'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://video.test/v',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Useful talk');
    await tester.enterText(find.byType(TextField).at(2), '12:34');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    final VideoImportRequest request = result!;
    expect(request.title, 'Useful talk');
    expect(request.durationSeconds, 754);
  });
}
