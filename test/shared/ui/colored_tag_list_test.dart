/// Verifies the shared bounded presentation of colored tags.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/shared/ui/colored_tag_list.dart';

void main() {
  testWidgets('shows colored labels and summarizes tags beyond the limit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ColoredTagList(
          tagNames: <String>['alpha', 'beta', 'gamma', 'delta'],
          maximumVisibleTags: 2,
        ),
      ),
    );

    expect(find.text('#alpha'), findsOneWidget);
    expect(find.text('#beta'), findsOneWidget);
    expect(find.text('#gamma'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    expect(tester.widget<Text>(find.text('#alpha')).style?.color, Colors.white);
  });
}
