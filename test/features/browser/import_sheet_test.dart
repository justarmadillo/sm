/// Full-page topic creation from typed or pasted Markdown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/features/browser/import_sheet.dart';

void main() {
  testWidgets('topic creation opens as a page and returns its content', (
    WidgetTester tester,
  ) async {
    ImportRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () async =>
                result = await openTopicCreationPage(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add topic'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Memory systems');
    await tester.enterText(
      find.byType(TextField).last,
      '# Memory systems\n\nSpaced retrieval.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final Finder addButton = find.widgetWithText(FilledButton, 'Add');
    expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Open'), findsOneWidget);
    final ImportRequest request = result!;
    expect(request.title, 'Memory systems');
    expect(request.markdown, contains('Spaced retrieval.'));
  });
}
