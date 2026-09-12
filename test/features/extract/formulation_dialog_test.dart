/// Widget tests for staged card formulation and its returned tag selection.
library;

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
    late Future<FormulationResult?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () {
              result = openFormulationPage(
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
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-extra')),
      'France uses the euro.',
    );
    await tester.tap(find.text('Add another'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cloze'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-cloze')),
      '{{c1::Paris}} is the capital of {{c2::France}}.',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-extra')),
      'A map can help.',
    );
    await tester.pump();

    expect(find.text('Create 3 cards'), findsOneWidget);
    await tester.tap(find.text('Create 3 cards'));
    await tester.pumpAndSettle();

    final drafts = (await result)!.drafts;
    expect(drafts, hasLength(2));
    final qa = drafts.first as QaCardDraft;
    expect(qa.extra, 'France uses the euro.');
    final cloze = drafts.last as ClozeCardDraft;
    expect(clozeOrdinals(cloze.text), <int>[1, 2]);
    expect(cloze.extra, 'A map can help.');
  });

  testWidgets('keeps the page open and explains an incomplete Q&A', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () => openFormulationPage(
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
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Add cards'), findsOneWidget);
  });

  testWidgets('splits a pasted list into an overlapper draft', (
    WidgetTester tester,
  ) async {
    late Future<FormulationResult?> result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () {
              result = openFormulationPage(
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
    await tester.enterText(
      find.byKey(const ValueKey<String>('formulation-extra')),
      'Remember the complete sequence.',
    );
    await tester.pump();
    await tester.tap(find.text('Create 3 cards'));
    await tester.pumpAndSettle();

    final draft = (await result)!.drafts.single as ClozeOverlapperCardDraft;
    expect(draft.text, '{{c1::Alpha}}\n{{c2::Beta}}\n{{c3::Gamma}}');
    expect(draft.contextBefore, 2);
    expect(draft.contextAfter, 1);
    expect(draft.extra, 'Remember the complete sequence.');
  });
}
