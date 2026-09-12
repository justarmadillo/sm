/// Answer-side image occlusion with reveal-all and restore controls.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/occlusion.dart';
import 'package:incremental_reader/features/occlusion/widgets/occlusion_view.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Lets the learner inspect every label after attempting the card while
/// preserving the mode's normal answer-side masks as a reversible view.
class ReviewOcclusionPanel extends StatefulWidget {
  const ReviewOcclusionPanel({
    required this.imageProvider,
    required this.occlusion,
    required this.isAnswerRevealed,
    this.onOpenImage,
    super.key,
  });

  final ImageProvider imageProvider;
  final CardOcclusion occlusion;
  final bool isAnswerRevealed;
  final ValueChanged<bool>? onOpenImage;

  @override
  State<ReviewOcclusionPanel> createState() => _ReviewOcclusionPanelState();
}

class _ReviewOcclusionPanelState extends State<ReviewOcclusionPanel> {
  bool _shouldRevealAllOcclusions = false;

  @override
  void didUpdateWidget(covariant ReviewOcclusionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.occlusion.cardId != widget.occlusion.cardId ||
        !widget.isAnswerRevealed) {
      _shouldRevealAllOcclusions = false;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _image(),
        if (widget.isAnswerRevealed) _revealButton(),
      ],
    ),
  );

  Widget _image() => GestureDetector(
    onTap: widget.onOpenImage == null
        ? null
        : () => widget.onOpenImage!(_shouldRevealAllOcclusions),
    child: OcclusionView(
      imageProvider: widget.imageProvider,
      occlusion: widget.occlusion,
      isAnswerRevealed: widget.isAnswerRevealed,
      shouldRevealAllOcclusions: _shouldRevealAllOcclusions,
    ),
  );

  Widget _revealButton() => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Center(
      child: OutlinedButton.icon(
        key: const ValueKey<String>('reveal-all-occlusions'),
        onPressed: () => setState(
          () => _shouldRevealAllOcclusions = !_shouldRevealAllOcclusions,
        ),
        icon: Icon(
          _shouldRevealAllOcclusions
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
        label: Text(
          _shouldRevealAllOcclusions
              ? 'Restore occlusions'
              : 'Reveal all occlusions',
        ),
      ),
    ),
  );
}
