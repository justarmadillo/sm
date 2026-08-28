/// The Reader's side panel: outline and extracts.
///
/// A 50k-word chapter is not navigable by scrolling alone, and extraction
/// leaves no trace in the text itself — the gutter marks only show what is on
/// screen. The panel answers both: where am I in the structure, and what have
/// I already taken out of this source.
library;

import 'package:flutter/material.dart';
import 'package:incremental_reader/documents/block.dart';
import 'package:incremental_reader/documents/document.dart';
import 'package:incremental_reader/documents/extract.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

/// Which list the panel is showing.
enum ReaderPanelTab {
  /// Headings, as a navigable outline.
  outline,

  /// Extracts taken from this source.
  extracts,
}

/// How wide the panel is when it sits beside the reading column.
const double kReaderSidePanelWidth = 280;

/// The panel of outline and extracts, docked beside the reading column on a
/// wide window and slid over it in a drawer on a narrow one.
class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({
    required this.document,
    required this.extracts,
    required this.tab,
    required this.onTabChanged,
    required this.onGoToBlock,
    required this.onGoToExtract,
    required this.onClose,
    this.currentBlockId,
    this.focusedExtractId,
    this.width,
    super.key,
  });

  final Document document;
  final List<Extract> extracts;
  final ReaderPanelTab tab;
  final ValueChanged<ReaderPanelTab> onTabChanged;

  /// Scrolls the reader to a block.
  final void Function(String blockId) onGoToBlock;

  /// Scrolls to an extract *and* marks it in the text. Choosing an extract
  /// only to arrive at an unmarked paragraph is the failure this replaces.
  final void Function(Extract extract) onGoToExtract;

  final VoidCallback onClose;

  /// Topmost visible block, highlighted in the outline.
  final String? currentBlockId;

  /// The extract currently painted in the text, shown selected here too.
  final String? focusedExtractId;

  /// How wide to draw. Null inside a drawer, which sets its own width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final headings = <Block>[
      for (final block in document.blocks)
        if (block.type == BlockType.heading) block,
    ];

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelHeader(
            tab: tab,
            outlineCount: headings.length,
            extractCount: extracts.length,
            onTabChanged: onTabChanged,
            onClose: onClose,
          ),
          Expanded(
            child: switch (tab) {
              ReaderPanelTab.outline => _OutlineList(
                headings: headings,
                currentBlockId: currentBlockId,
                onGoToBlock: onGoToBlock,
              ),
              ReaderPanelTab.extracts => _ExtractList(
                extracts: extracts,
                focusedExtractId: focusedExtractId,
                onGoToExtract: onGoToExtract,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.tab,
    required this.outlineCount,
    required this.extractCount,
    required this.onTabChanged,
    required this.onClose,
  });

  final ReaderPanelTab tab;
  final int outlineCount;
  final int extractCount;
  final ValueChanged<ReaderPanelTab> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: <Widget>[
        _TabChip(
          label: 'Outline',
          count: outlineCount,
          selected: tab == ReaderPanelTab.outline,
          onTap: () => onTabChanged(ReaderPanelTab.outline),
        ),
        const SizedBox(width: 6),
        _TabChip(
          label: 'Extracts',
          count: extractCount,
          selected: tab == ReaderPanelTab.extracts,
          onTap: () => onTabChanged(ReaderPanelTab.extracts),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 16),
          tooltip: 'Hide panel',
          visualDensity: VisualDensity.compact,
          color: AppColors.muted,
        ),
      ],
    ),
  );
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label  $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.accent : AppColors.muted,
        ),
      ),
    ),
  );
}

class _OutlineList extends StatelessWidget {
  const _OutlineList({
    required this.headings,
    required this.currentBlockId,
    required this.onGoToBlock,
  });

  final List<Block> headings;
  final String? currentBlockId;
  final void Function(String blockId) onGoToBlock;

  @override
  Widget build(BuildContext context) {
    if (headings.isEmpty) {
      return const _EmptyPanel(
        'This source has no headings, so there is nothing to outline.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: headings.length,
      itemBuilder: (BuildContext context, int index) {
        final heading = headings[index];
        final level = heading.headingLevel ?? 1;
        final isCurrent = heading.id == currentBlockId;
        return InkWell(
          onTap: () => onGoToBlock(heading.id),
          child: Container(
            padding: EdgeInsets.fromLTRB(10.0 + (level - 1) * 11, 6, 10, 6),
            color: isCurrent
                ? AppColors.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Text(
              heading.renderedText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: level <= 2 ? 12.5 : 12,
                height: 1.35,
                fontWeight: level <= 2 ? FontWeight.w600 : FontWeight.w400,
                color: isCurrent ? AppColors.accent : AppColors.text,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExtractList extends StatelessWidget {
  const _ExtractList({
    required this.extracts,
    required this.focusedExtractId,
    required this.onGoToExtract,
  });

  final List<Extract> extracts;
  final String? focusedExtractId;
  final void Function(Extract extract) onGoToExtract;

  @override
  Widget build(BuildContext context) {
    if (extracts.isEmpty) {
      return const _EmptyPanel(
        'Nothing extracted yet. Select a passage and press Extract to turn it '
        'into its own scheduled element.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: extracts.length,
      itemBuilder: (BuildContext context, int index) {
        final extract = extracts[index];
        return _extractTile(extract, isFocused: extract.id == focusedExtractId);
      },
    );
  }

  /// One extract, tinted more strongly while it is the one painted in the
  /// document, so the list and the text agree on what is selected.
  Widget _extractTile(Extract extract, {required bool isFocused}) {
    return InkWell(
      onTap: () => onGoToExtract(extract),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        decoration: BoxDecoration(
          color: AppColors.extractInk.withValues(
            alpha: isFocused ? 0.12 : 0.04,
          ),
          border: Border.all(
            color: AppColors.extractInk.withValues(
              alpha: isFocused ? 0.55 : 0.18,
            ),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              extract.markdown,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.text,
                fontWeight: isFocused ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 5),
            _tileFooter(extract, isFocused: isFocused),
          ],
        ),
      ),
    );
  }

  /// Says whether the extract still matches the source words, and whether
  /// tapping will paint it or clear it.
  Widget _tileFooter(Extract extract, {required bool isFocused}) {
    return Row(
      children: <Widget>[
        Text(
          extract.isVerbatim ? 'as selected' : 'edited',
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const Spacer(),
        Text(
          isFocused ? 'shown in text' : 'show in text',
          style: TextStyle(
            fontSize: 10,
            color: isFocused
                ? AppColors.extractInk
                : AppColors.muted.withValues(alpha: 0.8),
            fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      message,
      style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted),
    ),
  );
}
