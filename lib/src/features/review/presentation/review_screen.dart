/// Reveal-first review surface for FSRS cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../app/toast.dart';
import '../../../domain/content/card.dart';
import '../../../domain/content/document.dart';
import '../../../domain/scheduling/card_scheduler.dart';
import '../../extract/presentation/extract_screen.dart';
import '../../extract/presentation/extract_view_model.dart';
import '../../queue/presentation/study_route_result.dart';
import '../../reader/presentation/block_span_builder.dart';
import '../../reader/presentation/reader_screen.dart';
import '../../reader/presentation/reader_view_model.dart';
import '../../reader/presentation/typography_controller.dart';
import 'review_view_model.dart';

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
        model.clearMessage();
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
      data: (ReviewUiState data) => _ReviewBody(state: data, model: model),
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
      appBar: AppBar(
        title: const Text('Review'),
        actions: <Widget>[
          if (state.card.parent case final CardParent parent)
            TextButton.icon(
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
              icon: const Icon(Icons.account_tree_outlined, size: 17),
              label: Text(parent.isExtract ? 'Open extract' : 'Open article'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
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
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: <Widget>[
              _ReviewStatus(state: state),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _CardPanel(
                            label: 'QUESTION',
                            markdown: state.question,
                          ),
                          if (state.answerRevealed) ...<Widget>[
                            const SizedBox(height: 18),
                            _CardPanel(
                              label: 'ANSWER',
                              markdown: state.answer,
                              emphasized: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _ReviewActions(state: state, model: model),
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
        const Spacer(),
        const Text(
          'Space: reveal · 1 Again · 2 Hard · 3 Good · 4 Easy',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
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
    child: Center(
      child: state.answerRevealed
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
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
              ],
            )
          : FilledButton.icon(
              onPressed: state.isBusy ? null : model.revealAnswer,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Show answer  (Space)'),
            ),
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
