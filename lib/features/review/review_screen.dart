/// Reveal-first review surface for FSRS cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/documents/card.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/features/daily_queue/study_screen_outcome.dart';
import 'package:incremental_reader/features/extract/extract_screen.dart';
import 'package:incremental_reader/features/extract/extract_view_model.dart';
import 'package:incremental_reader/features/priority/priority_dialog.dart';
import 'package:incremental_reader/features/reader/reader_screen.dart';
import 'package:incremental_reader/features/reader/reader_view_model.dart';
import 'package:incremental_reader/features/reader/typography_controller.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/features/review/review_view_model.dart';
import 'package:incremental_reader/scheduling/cards/card_scheduler.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

Future<StudyRouteResult> openReview(
  BuildContext context,
  WidgetRef ref, {
  required String cardId,
}) async =>
    await Navigator.of(context).push<StudyRouteResult>(
      MaterialPageRoute<StudyRouteResult>(
        builder: (BuildContext context) => ReviewScreen(cardId: cardId),
      ),
    ) ??
    StudyRouteResult.canceled;

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({required this.cardId, super.key});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewViewModelProvider(cardId));
    final model = ref.read(reviewViewModelProvider(cardId).notifier);

    ref.listen<AsyncValue<ReviewUiState>>(reviewViewModelProvider(cardId), (
      AsyncValue<ReviewUiState>? previous,
      AsyncValue<ReviewUiState> next,
    ) {
      final data = next.valueOrNull;
      if (data == null) return;
      if (data.message case final message?) {
        showToast(context, message.text, isError: message.isError);
        model.shouldClearMessage();
      }
      if (data.isDone && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(StudyRouteResult.committed);
      }
    });

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Could not open this card.\n$error')),
      ),
      data: (ReviewUiState review) => _ReviewBody(state: review, model: model),
    );
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.state, required this.model});

  final ReviewUiState state;
  final ReviewViewModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _appBar(context, ref),
      body: CallbackShortcuts(
        bindings: _keyboardShortcuts(context, ref),
        child: Focus(
          autofocus: true,
          child: Column(
            children: <Widget>[
              _ReviewStatus(state: state),
              Expanded(child: _cardArea()),
              _ReviewActions(state: state, model: model),
            ],
          ),
        ),
      ),
    );
  }

  /// The title bar: priority, edit, and the way back to where the card came
  /// from.
  PreferredSizeWidget _appBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: const Text('Review'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Priority (Alt+P)',
          onPressed: state.isBusy ? null : () => _openPriority(context, ref),
          icon: const Icon(Icons.tune, size: 18),
        ),
        IconButton(
          tooltip: 'Edit this card (E)',
          onPressed: state.isBusy || state.isEditing
              ? null
              : () => model.setEditing(true),
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
        if (state.card.parent case final CardParent parent)
          _openParentButton(context, ref, parent),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Opens the extract or article this card was formulated from, in browse
  /// mode: looking at the source is not a repetition of it.
  Widget _openParentButton(
    BuildContext context,
    WidgetRef ref,
    CardParent parent,
  ) {
    return TextButton.icon(
      onPressed: state.isBusy
          ? null
          : () => parent.isExtract
                ? openExtract(
                    context,
                    ref,
                    extractId: parent.id,
                    mode: ExtractMode.browse,
                  )
                : openReader(
                    context,
                    ref,
                    sourceId: parent.id,
                    mode: ReaderMode.browse,
                  ),
      icon: Icon(
        state.isLeech
            ? Icons.warning_amber_rounded
            : Icons.account_tree_outlined,
        size: 17,
        color: state.isLeech ? AppColors.softMarker : null,
      ),
      label: Text(parent.isExtract ? 'Open extract' : 'Open article'),
    );
  }

  void _openPriority(BuildContext context, WidgetRef ref) {
    showPriorityDialog(
      context,
      ref,
      elementRef: ElementRef(id: state.card.id, type: ElementType.card),
    );
  }

  /// Space or Enter reveals; 1-4 grade, on both the number row and the numpad.
  ///
  /// Undo-last-grade and edit-during-review are both one key away: a misgraded
  /// card and a badly worded one are the two things that go wrong mid-session,
  /// and neither should cost a trip to another screen.
  Map<ShortcutActivator, VoidCallback> _keyboardShortcuts(
    BuildContext context,
    WidgetRef ref,
  ) {
    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space): model.revealAnswer,
      const SingleActivator(LogicalKeyboardKey.enter): model.revealAnswer,
      const SingleActivator(LogicalKeyboardKey.digit1): () =>
          model.grade(CardRating.again),
      const SingleActivator(LogicalKeyboardKey.digit2): () =>
          model.grade(CardRating.hard),
      const SingleActivator(LogicalKeyboardKey.digit3): () =>
          model.grade(CardRating.good),
      const SingleActivator(LogicalKeyboardKey.digit4): () =>
          model.grade(CardRating.easy),
      const SingleActivator(LogicalKeyboardKey.numpad1): () =>
          model.grade(CardRating.again),
      const SingleActivator(LogicalKeyboardKey.numpad2): () =>
          model.grade(CardRating.hard),
      const SingleActivator(LogicalKeyboardKey.numpad3): () =>
          model.grade(CardRating.good),
      const SingleActivator(LogicalKeyboardKey.numpad4): () =>
          model.grade(CardRating.easy),
      const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
          model.undoLastGrade,
      const SingleActivator(LogicalKeyboardKey.keyE): () =>
          model.setEditing(true),
      kPriorityShortcut: () => _openPriority(context, ref),
    };
  }

  /// The card itself: the editor while editing, otherwise the question and —
  /// once revealed — the answer.
  Widget _cardArea() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (state.isEditing)
                _CardEditor(state: state, model: model)
              else ...<Widget>[
                _CardPanel(label: 'QUESTION', markdown: state.question),
                if (state.isAnswerRevealed) ...<Widget>[
                  const SizedBox(height: 18),
                  _CardPanel(
                    label: 'ANSWER',
                    markdown: state.answer,
                    emphasized: true,
                  ),
                ],
              ],
              if (state.isLeech && !state.isEditing) ...<Widget>[
                const SizedBox(height: 18),
                _LeechNotice(lapses: state.lapses),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.state});

  final ReviewUiState state;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: <Widget>[
        const Icon(Icons.quiz_outlined, size: 16, color: Colors.teal),
        const SizedBox(width: 8),
        Text(
          state.cardState.memory.isNew
              ? 'New card'
              : state.cardState.memory.state.name,
          style: const TextStyle(fontSize: 12, color: AppColors.text),
        ),
        if (state.buriedSiblings > 0) ...<Widget>[
          const SizedBox(width: 12),
          Tooltip(
            message:
                'Cards cut from the same passage give each other away, so '
                'they were pushed to tomorrow rather than reviewed now.',
            child: Text(
              '${state.buriedSiblings} sibling'
              '${state.buriedSiblings == 1 ? '' : 's'} buried',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
        const Spacer(),
        // A legend for keys a phone does not have, and the widest thing on
        // the bar: it is dropped rather than wrapped when there is no room.
        if (!isCompactWidth(context))
          const Flexible(
            child: Text(
              'Space: reveal · 1–4 grade · Ctrl+Z undo · E edit · Alt+P priority',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
      ],
    ),
  );
}

class _CardPanel extends ConsumerWidget {
  const _CardPanel({
    required this.label,
    required this.markdown,
    this.emphasized = false,
  });

  final String label;
  final String markdown;
  final bool emphasized;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = ref.watch(readerTypographyProvider);
    final document = Document.parse(
      sourceId: 'review-${label.toLowerCase()}',
      markdown: markdown,
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.accent.withValues(alpha: 0.06)
            : AppColors.surface,
        border: Border.all(
          color: emphasized ? AppColors.accent : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          for (final block in document.blocks) ...<Widget>[
            SelectableText.rich(buildBlockSpan(block, typography)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.state, required this.model});

  final ReviewUiState state;
  final ReviewViewModel model;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    // The last row above the Android gesture strip: without this the grade
    // buttons sit under the swipe area.
    child: SafeArea(
      top: false,
      child: Center(
        child: state.isAnswerRevealed
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  if (state.canUndo)
                    TextButton.icon(
                      onPressed: state.isBusy ? null : model.undoLastGrade,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Undo'),
                    ),
                  _RatingButton(
                    number: 1,
                    label: 'Again',
                    color: Colors.red.shade700,
                    onPressed: state.isBusy
                        ? null
                        : () => model.grade(CardRating.again),
                  ),
                  _RatingButton(
                    number: 2,
                    label: 'Hard',
                    color: Colors.orange.shade800,
                    onPressed: state.isBusy
                        ? null
                        : () => model.grade(CardRating.hard),
                  ),
                  _RatingButton(
                    number: 3,
                    label: 'Good',
                    color: AppColors.accent,
                    onPressed: state.isBusy
                        ? null
                        : () => model.grade(CardRating.good),
                  ),
                  _RatingButton(
                    number: 4,
                    label: 'Easy',
                    color: Colors.teal,
                    onPressed: state.isBusy
                        ? null
                        : () => model.grade(CardRating.easy),
                  ),
                  TextButton.icon(
                    // Not a grade. "Wrong task right now" is a different fact
                    // about the day from "I could not recall this", and the log
                    // keeps them apart.
                    onPressed: state.isBusy ? null : model.postpone,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Later'),
                  ),
                ],
              )
            : FilledButton.icon(
                onPressed: state.isBusy ? null : model.revealAnswer,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Show answer  (Space)'),
              ),
      ),
    ),
  );
}

/// Inline editing during review.
///
/// Never reschedules: a typo found mid-review is not new evidence about
/// memory, and rescheduling on an edit would punish the user for improving
/// their own material.
class _CardEditor extends StatefulWidget {
  const _CardEditor({required this.state, required this.model});

  final ReviewUiState state;
  final ReviewViewModel model;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final TextEditingController _front = TextEditingController(
    text: widget.state.card.front,
  );
  late final TextEditingController _back = TextEditingController(
    text: widget.state.card.back,
  );

  bool get _isCloze => widget.state.card.kind == CardKind.cloze;

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.accent),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          _isCloze ? 'CLOZE TEXT' : 'QUESTION',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _front,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_isCloze)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Keep the {{c1::…}} deletions. The canonical text is the single '
              'source of truth, so editing the sentence can never '
              'desynchronize what this card tests.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          )
        else ...<Widget>[
          const SizedBox(height: 14),
          const Text(
            'ANSWER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _back,
            maxLines: null,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: widget.state.isBusy
                  ? null
                  : () => widget.model.setEditing(false),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.state.isBusy
                  ? null
                  : () => widget.model.edit(
                      front: _front.text,
                      back: _isCloze ? null : _back.text,
                    ),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The escape hatch for a card that keeps failing.
class _LeechNotice extends StatelessWidget {
  const _LeechNotice({required this.lapses});

  final int lapses;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.softMarker.withValues(alpha: 0.10),
      border: Border.all(color: AppColors.softMarker.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: <Widget>[
        const Icon(
          Icons.warning_amber_rounded,
          size: 18,
          color: AppColors.softMarker,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'This card has failed $lapses times. Repeated failure is usually '
            'a badly written card rather than a hard fact — open the source '
            'passage above and rewrite it, or lower its priority.',
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.number,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final int number;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: 0.7)),
      minimumSize: const Size(112, 44),
    ),
    child: Text('$number  $label'),
  );
}
