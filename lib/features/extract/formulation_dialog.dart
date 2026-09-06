/// Batch Q&A and cloze formulation without leaving the current extract.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/features/extract/formulation_commands.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

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
  int overlapContextBefore = 1,
  int overlapContextAfter = 0,
  String parentNoun = 'extract',
}) => showDialog<List<CardDraft>>(
  context: context,
  barrierDismissible: false,
  builder: (BuildContext context) => _FormulationDialog(
    seedText: seedText,
    existingCardCount: existingCardCount,
    parentNoun: parentNoun,
    overlapContextBefore: overlapContextBefore,
    overlapContextAfter: overlapContextAfter,
  ),
);

class _FormulationDialog extends StatefulWidget {
  const _FormulationDialog({
    required this.seedText,
    required this.existingCardCount,
    required this.parentNoun,
    required this.overlapContextBefore,
    required this.overlapContextAfter,
  });

  final String seedText;
  final int existingCardCount;
  final String parentNoun;
  final int overlapContextBefore;
  final int overlapContextAfter;

  @override
  State<_FormulationDialog> createState() => _FormulationDialogState();
}

enum _DraftType { qa, cloze, clozeOverlapper }

class _FormulationDialogState extends State<_FormulationDialog> {
  final TextEditingController _question = TextEditingController();
  final TextEditingController _answer = TextEditingController();
  late final TextEditingController _cloze = TextEditingController(
    text: widget.seedText,
  );
  late final TextEditingController _contextBefore = TextEditingController(
    text: '${widget.overlapContextBefore}',
  );
  late final TextEditingController _contextAfter = TextEditingController(
    text: '${widget.overlapContextAfter}',
  );
  final List<CardDraft> _queued = <CardDraft>[];
  _DraftType _type = _DraftType.qa;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _cloze.dispose();
    _contextBefore.dispose();
    _contextAfter.dispose();
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
        width: dialogContentWidth(context, preferred: 720),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(_introLine()),
              const SizedBox(height: 16),
              _cardTypeSelector(context),
              const SizedBox(height: 16),
              if (_type == _DraftType.qa)
                ..._questionAnswerFields()
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
          ClozeOverlapperCardDraft(:final text) => clozeOrdinals(text).length,
        };
  });

  /// How many cards the fields as currently filled in would add, counting an
  /// incomplete Q&A pair as none.
  int _cardCountInEditor(int clozeCountInEditor) => switch (_type) {
    _DraftType.qa
        when _question.text.trim().isNotEmpty &&
            _answer.text.trim().isNotEmpty =>
      1,
    _DraftType.cloze => clozeCountInEditor,
    _DraftType.clozeOverlapper => clozeCountInEditor,
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
  ///
  /// The two icons are dropped on a narrow window: they decorate a choice the
  /// words already make, and they are what pushes the pair past a phone's
  /// dialog width.
  Widget _cardTypeSelector(BuildContext context) {
    final bool hasRoomForIcons = !isCompactWidth(context);
    return SegmentedButton<_DraftType>(
      segments: <ButtonSegment<_DraftType>>[
        ButtonSegment<_DraftType>(
          value: _DraftType.qa,
          label: const Text('Question & answer'),
          icon: hasRoomForIcons ? const Icon(Icons.quiz_outlined) : null,
        ),
        ButtonSegment<_DraftType>(
          value: _DraftType.cloze,
          label: const Text('Cloze'),
          icon: hasRoomForIcons ? const Icon(Icons.short_text) : null,
        ),
        ButtonSegment<_DraftType>(
          value: _DraftType.clozeOverlapper,
          label: const Text('Overlapper'),
          icon: hasRoomForIcons ? const Icon(Icons.view_agenda_outlined) : null,
        ),
      ],
      selected: <_DraftType>{_type},
      onSelectionChanged: (Set<_DraftType> value) => setState(() {
        _type = value.single;
        _error = null;
      }),
    );
  }

  List<Widget> _questionAnswerFields() => <Widget>[
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
            if (_type == _DraftType.clozeOverlapper)
              OutlinedButton.icon(
                key: const ValueKey<String>('split-overlapper-items'),
                onPressed: _splitIntoItems,
                icon: const Icon(Icons.format_list_numbered, size: 16),
                label: const Text('Split into items'),
              ),
            Text(
              clozeCountInEditor == 0
                  ? 'No valid deletions yet'
                  : '$clozeCountInEditor review card'
                        '${clozeCountInEditor == 1 ? '' : 's'}',
            ),
          ],
        ),
        if (_type == _DraftType.clozeOverlapper) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: _contextField(_contextBefore, 'Before')),
              const SizedBox(width: 12),
              Expanded(child: _contextField(_contextAfter, 'After')),
            ],
          ),
        ],
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
        // Flexible, not fixed: the count is the half that gives way when the
        // dialog is only as wide as a phone.
        if (_queued.isNotEmpty)
          Flexible(
            child: Text(
              '$stagedCardCount cards staged',
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
    switch (_type) {
      case _DraftType.qa:
        final question = _question.text.trim();
        final answer = _answer.text.trim();
        if (question.isEmpty && answer.isEmpty && allowEmpty) return null;
        if (question.isEmpty || answer.isEmpty) {
          _error = 'Question and answer are both required.';
          return null;
        }
        return QaCardDraft(question: question, answer: answer);
      case _DraftType.cloze:
      case _DraftType.clozeOverlapper:
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
        if (_type == _DraftType.cloze) return ClozeCardDraft(text);
        final before = int.tryParse(_contextBefore.text.trim());
        final after = int.tryParse(_contextAfter.text.trim());
        if (before == null || after == null) {
          _error = 'Before and After must be whole numbers.';
          return null;
        }
        return ClozeOverlapperCardDraft(
          text: text,
          contextBefore: before,
          contextAfter: after,
        );
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
    switch (_type) {
      case _DraftType.qa:
        _question.clear();
        _answer.clear();
      case _DraftType.cloze:
      case _DraftType.clozeOverlapper:
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

  Widget _contextField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: InputDecoration(
          labelText: label,
          helperText: '-1 reveals all',
        ),
        onChanged: (_) => _clearError(),
      );

  /// Turns each non-empty pasted line into one portable cloze deletion.
  void _splitIntoItems() {
    final lines = _cloze.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(
          (line) => line.replaceFirst(RegExp(r'^(?:[-*+]\s+|\d+[.)]\s+)'), ''),
        )
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      setState(() => _error = 'Paste one or more list items first.');
      return;
    }
    _cloze.text = <String>[
      for (var index = 0; index < lines.length; index++)
        '{{c${index + 1}::${lines[index]}}}',
    ].join('\n');
    setState(() => _error = null);
  }

  String _draftLabel(CardDraft draft, int index) => switch (draft) {
    QaCardDraft(:final question) =>
      '${index + 1}. Q&A · ${_ellipsize(question)}',
    ClozeCardDraft(:final text) =>
      '${index + 1}. Cloze · ${clozeOrdinals(text).length} cards',
    ClozeOverlapperCardDraft(:final text) =>
      '${index + 1}. Overlapper · ${clozeOrdinals(text).length} cards',
  };

  String _ellipsize(String value) =>
      value.length <= 32 ? value : '${value.substring(0, 29)}…';
}
