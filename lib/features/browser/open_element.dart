/// The one way to open any element for reading or editing, wherever it was
/// clicked.
///
/// The Browser used to answer a click with a docked pane holding its own copy
/// of the text, which meant two places that could edit an extract and two
/// shapes of "the element on screen". A source is read in the Reader and an
/// extract in the Extract screen; this sends every list to those, in browse
/// mode, so there is one reader for both browsing and reading. A card has no
/// screen of its own — it is reviewed, not read — so it is edited in place in
/// a dialog rather than gaining a third window.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/browser/browser_providers.dart';
import 'package:incremental_reader/features/browser/browser_view_model.dart';
import 'package:incremental_reader/features/browser/element_content_query.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// The body of one element, for whatever is editing it.
final AutoDisposeFutureProviderFamily<ElementContent?, ElementRef>
elementContentProvider = FutureProvider.autoDispose
    .family<ElementContent?, ElementRef>(
      (Ref ref, ElementRef elementRef) =>
          ref.watch(elementContentQueryProvider).load(elementRef),
    );

/// Opens [elementRef] the way its own kind is opened.
///
/// Browse, not a scheduled sitting: being handed an element by the queue is
/// not the same as going to look at it, and offering Done here would invite
/// recording a repetition that never happened.
Future<void> openElement(
  BuildContext context,
  WidgetRef ref, {
  required ElementRef elementRef,
}) async {
  switch (elementRef.type) {
    case ElementType.source:
      await openReader(
        context,
        ref,
        sourceId: elementRef.id,
        mode: ReaderMode.browse,
      );
    case ElementType.extract:
      await openExtract(
        context,
        ref,
        extractId: elementRef.id,
        mode: ExtractMode.browse,
      );
    case ElementType.card:
      await showCardEditor(context, ref, cardRef: elementRef);
  }
  if (context.mounted) ref.invalidate(elementContentProvider(elementRef));
}

/// Edits a card's question and answer in place.
Future<void> showCardEditor(
  BuildContext context,
  WidgetRef ref, {
  required ElementRef cardRef,
}) => showDialog<void>(
  context: context,
  builder: (BuildContext context) => _CardEditorDialog(cardRef: cardRef),
);

class _CardEditorDialog extends ConsumerWidget {
  const _CardEditorDialog({required this.cardRef});

  final ElementRef cardRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ElementContent?> content = ref.watch(
      elementContentProvider(cardRef),
    );
    return content.when(
      loading: () => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (Object error, StackTrace stack) =>
          AlertDialog(content: Text('Could not load this card.\n$error')),
      data: (ElementContent? loaded) => loaded == null
          ? const AlertDialog(content: Text('This card is no longer here.'))
          : _CardEditorFields(content: loaded),
    );
  }
}

class _CardEditorFields extends ConsumerStatefulWidget {
  const _CardEditorFields({required this.content});

  final ElementContent content;

  @override
  ConsumerState<_CardEditorFields> createState() => _CardEditorFieldsState();
}

class _CardEditorFieldsState extends ConsumerState<_CardEditorFields> {
  late final TextEditingController _question = TextEditingController(
    text: widget.content.body,
  );
  late final TextEditingController _answer = TextEditingController(
    text: widget.content.back ?? '',
  );

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  /// A cloze card's answer is derived from its question, so [ElementContent]
  /// leaves `back` null there and only one field is offered.
  bool get _hasAnswerField => widget.content.back != null;

  Future<void> _save() async {
    await ref
        .read(browserViewModelProvider.notifier)
        .editCard(
          widget.content.ref.id,
          front: _question.text,
          back: _hasAnswerField ? _answer.text : null,
        );
    if (!mounted) return;
    ref.invalidate(elementContentProvider(widget.content.ref));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Card'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _fieldLabel('Question'),
          TextField(
            controller: _question,
            minLines: 3,
            maxLines: null,
            style: const TextStyle(fontSize: 13, height: 1.45),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          if (_hasAnswerField) ...<Widget>[
            _fieldLabel('Answer'),
            TextField(
              controller: _answer,
              minLines: 2,
              maxLines: null,
              style: const TextStyle(fontSize: 13, height: 1.45),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Edits never reschedule.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppColors.muted),
    ),
  );
}
