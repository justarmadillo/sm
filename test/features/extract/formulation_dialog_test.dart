import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/features/extract/formulation_dialog.dart';

void main() {
  final extract = Extract(
    id: 'extract-1',
    markdown: 'Paris is the capital of France.',
    provenance: const Provenance(
      sourceId: 'source-1',
      parentId: 'source-1',
      hasSourceAsParent: true,
      startAnchor: ReaderAnchor(utf8Offset: 0),
      endAnchor: ReaderAnchor(utf8Offset: 5),
      selectedTextHash:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ),
    createdAtUtc: DateTime.utc(2026),
  );

  testWidgets('stages mixed Q&A and multi-ordinal cloze drafts', (
    WidgetTester tester,
  ) async {
    late Future<List<CardDraft>?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () {
              result = showFormulationDialog(
                context,
                seedText: extract.markdown,
                existingCardCount: 0,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-question')),
      'What is the capital of France?',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-answer')),
      'Paris',
    );
    await tester.tap(find.text('Add another'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cloze'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-cloze')),
      '{{c1::Paris}} is the capital of {{c2::France}}.',
    );
    await tester.pump();

    expect(find.text('Create 3 cards'), findsOneWidget);
    await tester.tap(find.text('Create 3 cards'));
    await tester.pumpAndSettle();

    final drafts = (await result)!;
    expect(drafts, hasLength(2));
    expect(drafts.first, isA<QaCardDraft>());
    final cloze = drafts.last as ClozeCardDraft;
    expect(clozeOrdinals(cloze.text), <int>[1, 2]);
  });

  testWidgets('keeps the dialog open and explains an incomplete Q&A', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => showFormulationDialog(
              context,
              seedText: extract.markdown,
              existingCardCount: 0,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-question')),
      'Question without an answer',
    );
    await tester.tap(find.text('Create cards'));
    await tester.pump();

    expect(find.text('Question and answer are both required.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('splits a pasted list into an overlapper draft', (
    WidgetTester tester,
  ) async {
    late Future<List<CardDraft>?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () {
              result = showFormulationDialog(
                context,
                seedText: '1. Alpha\n2. Beta\n- Gamma',
                existingCardCount: 0,
                overlapContextBefore: 2,
                overlapContextAfter: 1,
              );
            },
            child: const Text('Open overlapper'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open overlapper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overlapper'));
    await tester.pumpAndSettle();
    final splitButton = find.byKey(
      const ValueKey<String>('split-overlapper-items'),
    );
    await tester.ensureVisible(splitButton);
    await tester.tap(splitButton);
    await tester.pump();
    await tester.tap(find.text('Create 3 cards'));
    await tester.pumpAndSettle();

    final draft = (await result)!.single as ClozeOverlapperCardDraft;
    expect(draft.text, '{{c1::Alpha}}\n{{c2::Beta}}\n{{c3::Gamma}}');
    expect(draft.contextBefore, 2);
    expect(draft.contextAfter, 1);
  });
}
