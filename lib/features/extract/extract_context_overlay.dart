/// The context overlay: where an extract came from, without leaving the page.
///
/// An extract on its own is often unreadable a week later — "the second one is
/// larger" means nothing without its neighbours. Context restores that by
/// showing the passage in place, with the blocks around it, and it is a
/// *browse* surface: opening it changes no position and no schedule.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/documents/reader_anchor.dart';
import 'package:incremental_reader/features/reader/widgets/block_span_builder.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Shows the context of [extracts] taken from [block].
Future<ExtractContextAction?> showExtractContext(
  BuildContext context, {
  required Document document,
  required Block block,
  required List<Extract> extracts,
}) => showDialog<ExtractContextAction>(
  context: context,
  builder: (BuildContext context) => _ExtractContextDialog(
    document: document,
    block: block,
    extracts: extracts,
  ),
);

/// What the user chose to do from the context overlay.
@immutable
final class ExtractContextAction {
  const ExtractContextAction.goToAnchor(this.anchor, {this.extractId});

  /// Scroll the Reader to this exact source position.
  final ReaderAnchor anchor;

  /// Exact extract selected when several overlap at the same anchor.
  final String? extractId;
}

class _ExtractContextDialog extends StatefulWidget {
  const _ExtractContextDialog({
    required this.document,
    required this.block,
    required this.extracts,
  });

  final Document document;
  final Block block;
  final List<Extract> extracts;

  @override
  State<_ExtractContextDialog> createState() => _ExtractContextDialogState();
}

class _ExtractContextDialogState extends State<_ExtractContextDialog> {
  /// How many blocks of surrounding text to show on each side.
  int _radius = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _title(),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ..._extractList(context),
              const SizedBox(height: 16),
              const Text(
                'In the document',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              _surroundingText(),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          // Two more blocks each time, up to a limit: this is a peek at the
          // context, not a second reader.
          onPressed: _radius >= 6
              ? null
              : () => setState(() => _radius = _radius + 2),
          child: const Text('Expand'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  /// The "Browsing" badge says looking here does not count as a repetition.
  Widget _title() {
    return Row(
      children: <Widget>[
        const Text('Context'),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.softMarker.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Browsing',
            style: TextStyle(fontSize: 11, color: AppColors.softMarker),
          ),
        ),
      ],
    );
  }

  /// Every extract taken from this block, each one a way back to it.
  List<Widget> _extractList(BuildContext context) {
    return <Widget>[
      Text(
        widget.extracts.length == 1
            ? '1 extract taken here'
            : '${widget.extracts.length} extracts taken here',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 8),
      for (final extract in widget.extracts)
        _ExtractCard(
          extract: extract,
          onOpen: () => Navigator.of(context).pop(
            ExtractContextAction.goToAnchor(
              extract.provenance.startAnchor,
              extractId: extract.id,
            ),
          ),
        ),
    ];
  }

  /// The block and [_radius] blocks either side of it, clamped to the
  /// document so the first and last blocks still show what they can.
  Widget _surroundingText() {
    final index = widget.document.indexOfBlock(widget.block.id) ?? 0;
    final lastIndex = widget.document.blocks.length - 1;
    final from = (index - _radius).clamp(0, lastIndex);
    final to = (index + _radius).clamp(0, lastIndex);
    final surrounding = widget.document.blocks.sublist(from, to + 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final surroundingBlock in surrounding)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: buildBlockSpan(
                  surroundingBlock,
                  ReaderTypography.standard,
                  highlights: _highlightsFor(surroundingBlock),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<BlockHighlight> _highlightsFor(Block block) {
    if (block.id != widget.block.id) return const <BlockHighlight>[];
    return <BlockHighlight>[
      for (final extract in widget.extracts)
        BlockHighlight(
          start: block.utf8ToRendered(
            extract.provenance.startAnchor.utf8Offset,
          ),
          end: block.utf8ToRendered(extract.provenance.endAnchor.utf8Offset),
          color: AppColors.extractFocusWash,
          underlineColor: AppColors.extractInk,
        ),
    ];
  }
}

class _ExtractCard extends StatelessWidget {
  const _ExtractCard({required this.extract, required this.onOpen});

  final Extract extract;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.06),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SelectableText(
          extract.markdown,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text(
              extract.isVerbatim ? 'As selected' : 'Edited',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const Spacer(),
            TextButton(onPressed: onOpen, child: const Text('Show selection')),
          ],
        ),
      ],
    ),
  );
}
