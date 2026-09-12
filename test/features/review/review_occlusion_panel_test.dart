/// Review-side image occlusion reveal and restore behavior.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/review/widgets/review_occlusion_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const occlusion = CardOcclusion(
    cardId: 'card-1',
    imageSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    imageMime: 'image/png',
    imageWidthPx: 100,
    imageHeightPx: 100,
    regions: <OcclusionRegion>[
      OcclusionRegion(
        id: 'active',
        left: 0.1,
        top: 0.1,
        width: 0.2,
        height: 0.2,
      ),
      OcclusionRegion(
        id: 'other',
        left: 0.5,
        top: 0.5,
        width: 0.2,
        height: 0.2,
      ),
    ],
    activeRegionId: 'active',
    mode: OcclusionMode.hideAllGuessOne,
  );

  final imageProvider = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
      'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );

  Future<void> pumpPanel(
    WidgetTester tester, {
    required bool isAnswerRevealed,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ReviewOcclusionPanel(
              imageProvider: imageProvider,
              occlusion: occlusion,
              isAnswerRevealed: isAnswerRevealed,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('offers reveal all only after the answer is shown', (
    WidgetTester tester,
  ) async {
    await pumpPanel(tester, isAnswerRevealed: false);

    expect(find.text('Reveal all occlusions'), findsNothing);

    await pumpPanel(tester, isAnswerRevealed: true);

    expect(find.text('Reveal all occlusions'), findsOneWidget);
  });

  testWidgets('reveals and restores every answer-side occlusion', (
    WidgetTester tester,
  ) async {
    await pumpPanel(tester, isAnswerRevealed: true);

    expect(
      find.byKey(const ValueKey<String>('occlusion-mask-active')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('occlusion-mask-other')),
      findsOneWidget,
    );

    await tester.tap(find.text('Reveal all occlusions'));
    await tester.pump();

    expect(find.text('Restore occlusions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('occlusion-mask-other')),
      findsNothing,
    );

    await tester.tap(find.text('Restore occlusions'));
    await tester.pump();

    expect(find.text('Reveal all occlusions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('occlusion-mask-other')),
      findsOneWidget,
    );
  });
}
