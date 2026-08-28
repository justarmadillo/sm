/// Keyboard and scrollbar behavior shared by desktop scrolling screens.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/shared/ui/desktop_scroll_view.dart';

void main() {
  testWidgets('shows a fixed scrollbar and scrolls with arrow keys', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopListView(
            children: List<Widget>.generate(
              100,
              (int rowIndex) =>
                  SizedBox(height: 40, child: Text('Row $rowIndex')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    expect(scrollbar.thumbVisibility, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scrollableState.position.pixels, greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(scrollableState.position.pixels, 0);
  });

  testWidgets('keeps the same scrollbar range through a full drag', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopListView(
            children: List<Widget>.generate(
              100,
              (int rowIndex) => SizedBox(
                height: rowIndex.isEven ? 30 : 70,
                child: Text('Row $rowIndex'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable),
    );
    final initialMaximum = scrollableState.position.maxScrollExtent;

    await tester.drag(find.byType(Scrollbar), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(scrollableState.position.maxScrollExtent, initialMaximum);
  });
}
