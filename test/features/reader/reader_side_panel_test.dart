/// The Reader outline panel's default selection and editing controls.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/outline.dart';
import 'package:incremental_reader/features/reader/widgets/reader_side_panel.dart';

const String _markdown = '''
# First

## Child

# Second
''';

void main() {
  testWidgets('first heading is selected before the user taps a row', (
    WidgetTester tester,
  ) async {
    OutlineEntry? renamedEntry;
    String? renamedText;
    await tester.pumpWidget(
      _panel(
        editing: _editing(
          onRename: (OutlineEntry entry, String text) {
            renamedEntry = entry;
            renamedText = text;
          },
        ),
      ),
    );

    final Finder renameFinder = find.widgetWithIcon(
      IconButton,
      Icons.edit_outlined,
    );
    expect(tester.widget<IconButton>(renameFinder).onPressed, isNotNull);

    await tester.tap(renameFinder);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    expect(renamedEntry?.text, 'First');
    expect(renamedText, 'Renamed');
  });

  testWidgets('hierarchy and ordering buttons call the selected row actions', (
    WidgetTester tester,
  ) async {
    final List<String> actions = <String>[];
    await tester.pumpWidget(
      _panel(
        editing: _editing(
          onChangeLevel: (OutlineEntry entry, int level) {
            actions.add('${entry.text}:level:$level');
          },
          onMoveSection: (OutlineEntry entry, {required bool shouldMoveUp}) {
            actions.add('${entry.text}:up:$shouldMoveUp');
          },
          onRemove: (OutlineEntry entry) {
            actions.add('${entry.text}:remove');
          },
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.format_indent_increase));
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.tap(find.text('Child'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.format_indent_decrease));

    expect(actions, <String>[
      'First:level:2',
      'First:up:false',
      'First:remove',
      'Child:level:1',
    ]);
  });
}

Widget _panel({required OutlineEditing editing}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: kReaderSidePanelWidth,
        height: 500,
        child: ReaderSidePanel(
          document: Document.parse(sourceId: 'source', markdown: _markdown),
          extracts: const [],
          tab: ReaderPanelTab.outline,
          onTabChanged: (_) {},
          onGoToBlock: (_) {},
          onGoToExtract: (_) {},
          onClose: () {},
          outlineEditing: editing,
        ),
      ),
    ),
  );
}

OutlineEditing _editing({
  void Function(OutlineEntry entry, String text)? onRename,
  void Function(OutlineEntry entry, String text)? onAddAfter,
  void Function(OutlineEntry entry)? onRemove,
  void Function(OutlineEntry entry, int level)? onChangeLevel,
  void Function(OutlineEntry entry, {required bool shouldMoveUp})?
  onMoveSection,
}) {
  return OutlineEditing(
    onRename: onRename ?? (_, _) {},
    onAddAfter: onAddAfter ?? (_, _) {},
    onRemove: onRemove ?? (_) {},
    onChangeLevel: onChangeLevel ?? (_, _) {},
    onMoveSection: onMoveSection ?? (_, {required shouldMoveUp}) {},
  );
}
