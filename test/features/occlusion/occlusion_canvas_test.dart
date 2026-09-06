/// Drawing, selection, and deletion behavior of the occlusion editor canvas.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/occlusion/widgets/occlusion_canvas.dart';

void main() {
  testWidgets('draws, moves, resizes from every border, and deletes', (
    WidgetTester tester,
  ) async {
    var regions = <OcclusionRegion>[];
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Center(
            child: SizedBox(
              width: 300,
              height: 240,
              child: OcclusionCanvas(
                imageProvider: MemoryImage(
                  base64Decode(
                    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
                    'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
                  ),
                ),
                imageWidthPx: 200,
                imageHeightPx: 100,
                regions: regions,
                newRegionId: () => 'region-1',
                onChanged: (List<OcclusionRegion> replacement) =>
                    setState(() => regions = replacement),
              ),
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(OcclusionCanvas));
    await tester.dragFrom(center - const Offset(30, 20), const Offset(60, 40));
    await tester.pump();
    expect(regions, hasLength(1));
    expect(regions.single.width, closeTo(0.3, 0.01));
    expect(regions.single.height, closeTo(0.4, 0.01));

    final Finder regionFinder = find.byKey(
      const ValueKey<String>('occlusion-region-region-1'),
    );
    Future<void> movePointer(Offset start, Offset delta) async {
      await tester.timedDragFrom(
        start,
        delta,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
    }

    Rect regionRect = tester.getRect(regionFinder);
    await movePointer(
      Offset(
        regionRect.left + regionRect.width * 0.75,
        regionRect.top + regionRect.height * 0.65,
      ),
      const Offset(20, 10),
    );
    expect(regions.single.left, closeTo(0.45, 0.02));
    expect(regions.single.top, closeTo(0.4, 0.02));

    regionRect = tester.getRect(regionFinder);
    await movePointer(
      Offset(regionRect.right - 1, regionRect.center.dy),
      const Offset(20, 0),
    );
    expect(regions.single.width, closeTo(0.4, 0.02));

    regionRect = tester.getRect(regionFinder);
    await movePointer(
      Offset(regionRect.left + 1, regionRect.center.dy),
      const Offset(-10, 0),
    );
    expect(regions.single.left, closeTo(0.4, 0.02));
    expect(regions.single.width, closeTo(0.45, 0.02));

    regionRect = tester.getRect(regionFinder);
    await movePointer(
      Offset(regionRect.center.dx, regionRect.top + 1),
      const Offset(0, -10),
    );
    expect(regions.single.top, closeTo(0.3, 0.02));
    expect(regions.single.height, closeTo(0.5, 0.02));

    regionRect = tester.getRect(regionFinder);
    await movePointer(
      Offset(regionRect.center.dx, regionRect.bottom - 1),
      const Offset(0, 10),
    );
    expect(regions.single.height, closeTo(0.6, 0.02));

    expect(find.byIcon(Icons.open_in_full), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(regions, isEmpty);
  });
}
