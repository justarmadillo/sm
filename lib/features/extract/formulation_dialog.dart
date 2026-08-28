/// Batch Q&A and cloze formulation without leaving the current extract.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';

/// Opens batch formulation over [seedText].
///
/// The dialog is deliberately parent-agnostic: cards can be made from an
/// extract, from a selection in an article, or from nothing at all, and the
/// only thing that changes is the text it starts with and what it calls the
/// element the cards will hang off.
Future<List<CardDraft>?> showFormulationDialog(
  BuildContext context, {
  required String seedText,
  required int existingCardCount,
  String parentNoun = 'extract',
}) => showDialog<List<CardDraft>>(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext context) => _FormulationDialog(
    seedText: seedText,
    existingCardCount: existingCardCount,
    parentNoun: parentNoun,
  ),
);

class _FormulationDialog extends StatefulWidget {
  const _FormulationDialog({
    required this.seedText,
    required this.existingCardCount,
    required this.parentNoun,
  });

  final String seedText;
  final int existingCardCount;
  final String parentNoun;

  @override
  State<_FormulationDialog> createState() => _FormulationDialogState();
}

enum _DraftKind { qa, cloze }

class _FormulationDialogState extends State<_FormulationDialog> {
  final TextEditingController _question = TextEditingController();
  final TextEditingController _answer = TextEditingController();
  late final TextEditingController _cloze = TextEditingController(
    text: widget.seedText,
  );
  final List<CardDraft> _queued = <CardDraft>[];
  _DraftKind _kind = _DraftKind.qa;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _cloze.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clozeCountInEditor = clozeOrdinals(_cloze.text).length;
    final stagedCardCount = _stagedCardCount();
    final totalCardCount =
        stagedCardCount + _cardCountInEditor(clozeCountInEditor);

    return AlertDialog(
      title: const Text('Formulate cards'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_introLine()),
              const SizedBox(height: 16),
              _cardKindSelector(),
              const SizedBox(height: 16),
              if (_kind == _DraftKind.qa)
                ..._questionAndAnswerFields()
              else
                ..._clozeFields(context, clozeCountInEditor),
              if (_error != null) ..._errorLine(context),
              const SizedBox(height: 14),
              _stagingRow(stagedCardCount),
              if (_queued.isNotEmpty) ..._stagedCardChips(),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            totalCardCount == 0
                ? 'Create cards'
                : 'Create $totalCardCount '
                      'card${totalCardCount == 1 ? '' : 's'}',
          ),
        ),
      ],
    );
  }

  /// How many review cards the already-staged drafts will produce.
  ///
  /// One per Q&A draft, but one per deletion in a cloze draft: `{{c1}}` and
  /// `{{c2}}` in the same text are two separate cards.
  int _stagedCardCount() => _queued.fold<int>(0, (int total, CardDraft draft) {
    return total +
        switch (draft) {
          QaCardDraft() => 1,
          ClozeCardDraft(:final text) => clozeOrdinals(text).length,
        };
  });

  /// How many cards the fields as currently filled in would add, counting an
  /// incomplete Q&A pair as none.
  int _cardCountInEditor(int clozeCountInEditor) => switch (_kind) {
    _DraftKind.qa
        when _question.text.trim().isNotEmpty &&
            _answer.text.trim().isNotEmpty =>
      1,
    _DraftKind.cloze => clozeCountInEditor,
    _ => 0,
  };

  /// Says whether this element already has cards, so adding more is clearly
  /// additive rather than a replacement.
  String _introLine() => widget.existingCardCount == 0
      ? 'Create one or more cards. The ${widget.parentNoun} stays scheduled.'
      : '${widget.existingCardCount} linked card'
            '${widget.existingCardCount == 1 ? '' : 's'} already exist. '
            'New cards are added independently.';

  /// Question-and-answer, or cloze.
  Widget _cardKindSelector() {
    return SegmentedButton<_DraftKind>(
      segments: const <ButtonSegment<_DraftKind>>[
        ButtonSegment<_DraftKind>(
          value: _DraftKind.qa,
          label: Text('Question & answer'),
          icon: Icon(Icons.quiz_outlined),
        ),
        ButtonSegment<_DraftKind>(
          value: _DraftKind.cloze,
          label: Text('Cloze'),
          icon: Icon(Icons.short_text),
        ),
      ],
      selected: <_DraftKind>{_kind},
      onSelectionChanged: (Set<_DraftKind> value) => setState(() {
        _kind = value.single;
        _error = null;
      }),
    );
  }

  List<Widget> _questionAndAnswerFields() => <Widget>[
    TextField(
      key: const ValueKey<String>('formulation-question'),
      controller: _question,
      autofocus: true,
      minLines: 2,
      maxLines: 5,
      decoration: const InputDecoration(labelText: 'Question'),
      onChanged: (_) => _clearError(),
    ),
    const SizedBox(height: 10),
    TextField(
      key: const ValueKey<String>('formulation-answer'),
      controller: _answer,
      minLines: 3,
      maxLines: 8,
      decoration: const InputDecoration(labelText: 'Answer'),
      onChanged: (_) => _clearError(),
    ),
  ];

  /// The cloze text field, the button that wraps a selection, and a preview
  /// line per deletion so the user sees each card before creating it.
  List<Widget> _clozeFields(BuildContext context, int clozeCountInEditor) =>
      <Widget>[
        TextField(
          key: const ValueKey<String>('formulation-cloze'),
          controller: _cloze,
          autofocus: true,
          minLines: 7,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'Canonical cloze text',
            helperText: 'Example: The capital is {{c1::Paris}}.',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: _wrapSelectionAsCloze,
              icon: const Icon(Icons.data_object, size: 16),
              label: const Text('Make selection a cloze'),
            ),
            Text(
              clozeCountInEditor == 0
                  ? 'No valid deletions yet'
                  : '$clozeCountInEditor review card'
                        '${clozeCountInEditor == 1 ? '' : 's'}',
            ),
          ],
        ),
        if (clozeCountInEditor > 0) ...<Widget>[
          const SizedBox(height: 10),
          for (final ordinal in clozeOrdinals(_cloze.text))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'c$ordinal  ${renderClozeQuestion(_cloze.text, ordinal)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ];

  List<Widget> _errorLine(BuildContext context) => <Widget>[
    const SizedBox(height: 10),
    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  ];

  /// "Add another" puts the current fields aside and clears them, so several
  /// cards can be written before anything is saved.
  Widget _stagingRow(int stagedCardCount) {
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _queueCurrent,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add another'),
        ),
        const Spacer(),
        if (_queued.isNotEmpty) Text('$stagedCardCount cards staged'),
      ],
    );
  }

  /// One removable chip per staged draft.
  List<Widget> _stagedCardChips() => <Widget>[
    const SizedBox(height: 10),
    Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (var index = 0; index < _queued.length; index++)
          InputChip(
            label: Text(_draftLabel(_queued[index], index)),
            onDeleted: () => setState(() => _queued.removeAt(index)),
          ),
      ],
    ),
  ];

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  CardDraft? _currentDraft({required bool allowEmpty}) {
    switch (_kind) {
      case _DraftKind.qa:
        final question = _question.text.trim();
        final answer = _answer.text.trim();
        if (question.isEmpty && answer.isEmpty && allowEmpty) return null;
        if (question.isEmpty || answer.isEmpty) {
          _error = 'Question and answer are both required.';
          return null;
        }
        return QaCardDraft(question: question, answer: answer);
      case _DraftKind.cloze:
        final text = _cloze.text.trim();
        if (text.isEmpty && allowEmpty) return null;
        final deletions = parseClozeDeletions(text);
        if (deletions.isEmpty ||
            deletions.any(
              (ClozeDeletion deletion) => deletion.answer.trim().isEmpty,
            )) {
          _error = 'Add at least one valid {{c1::answer}} deletion.';
          return null;
        }
        return ClozeCardDraft(text);
    }
  }

  void _queueCurrent() {
    setState(() {
      _error = null;
      final draft = _currentDraft(allowEmpty: false);
      if (draft == null) return;
      _queued.add(draft);
      _clearCurrent();
    });
  }

  void _submit() {
    List<CardDraft>? submitted;
    setState(() {
      _error = null;
      final draft = _currentDraft(allowEmpty: _queued.isNotEmpty);
      if (_error != null) return;
      final drafts = <CardDraft>[..._queued];
      if (draft != null) drafts.add(draft);
      if (drafts.isEmpty) {
        _error = 'Add at least one card.';
        return;
      }
      submitted = List<CardDraft>.unmodifiable(drafts);
    });
    if (submitted != null) Navigator.of(context).pop(submitted);
  }

  void _clearCurrent() {
    switch (_kind) {
      case _DraftKind.qa:
        _question.clear();
        _answer.clear();
      case _DraftKind.cloze:
        _cloze.clear();
    }
  }

  void _wrapSelectionAsCloze() {
    final selection = _cloze.selection;
    if (!selection.isValid || selection.isCollapsed) {
      setState(() => _error = 'Select the answer text first.');
      return;
    }
    final selected = selection.textInside(_cloze.text);
    final ordinals = clozeOrdinals(_cloze.text);
    final ordinal = ordinals.isEmpty ? 1 : ordinals.last + 1;
    final replacement = '{{c$ordinal::$selected}}';
    final text = _cloze.text;
    _cloze.value = TextEditingValue(
      text:
          selection.textBefore(text) + replacement + selection.textAfter(text),
      selection: TextSelection.collapsed(
        offset: selection.start + replacement.length,
      ),
    );
    setState(() => _error = null);
  }

  String _draftLabel(CardDraft draft, int index) => switch (draft) {
    QaCardDraft(:final question) =>
      '${index + 1}. Q&A · ${_ellipsize(question)}',
    ClozeCardDraft(:final text) =>
      '${index + 1}. Cloze · ${clozeOrdinals(text).length} cards',
  };

  String _ellipsize(String value) =>
      value.length <= 32 ? value : '${value.substring(0, 29)}…';
}
