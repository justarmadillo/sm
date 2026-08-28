/// The priority slider, available on every surface.
///
/// SuperMemo's Alt+P. Two things make it usable rather than arbitrary: the
/// scale runs 0% (most important) to 100% (least), which feels upside down for
/// about a week and then saves a keystroke on every judgement; and the dialog
/// names the elements immediately above and below, because "more important
/// than this, less important than that" is a decision a person can actually
/// make, while an abstract 42% is not.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:incremental_reader/features/priority/priority_query.dart';
import 'package:incremental_reader/features/priority/priority_view_model.dart';
import 'package:incremental_reader/scheduling/element.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';
import 'package:incremental_reader/shared/ui/toast_message.dart';

/// The Windows shortcut that opens the slider, matching SuperMemo.
const SingleActivator kPriorityShortcut = SingleActivator(
  LogicalKeyboardKey.keyP,
  alt: true,
);

/// Opens the slider for [elementRef]. Returns true when priority changed.
Future<bool> showPriorityDialog(
  BuildContext context,
  WidgetRef ref, {
  required ElementRef elementRef,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _PriorityDialog(elementRef: elementRef),
    ) ??
    false;

class _PriorityDialog extends ConsumerWidget {
  const _PriorityDialog({required this.elementRef});

  final ElementRef elementRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PrioritySliderState> state = ref.watch(
      prioritySliderViewModelProvider(elementRef),
    );
    final PrioritySliderViewModel model = ref.read(
      prioritySliderViewModelProvider(elementRef).notifier,
    );

    return AlertDialog(
      title: const Text('Element priority'),
      content: SizedBox(
        width: dialogContentWidth(context, preferred: 460),
        child: state.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stack) => SizedBox(
            height: 160,
            child: Center(child: Text('No priority for this element.\n$error')),
          ),
          data: (PrioritySliderState slider) =>
              _SliderBody(state: slider, model: model),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.valueOrNull == null || state.valueOrNull!.isBusy
              ? null
              : () async {
                  final bool didCommit = await model.commit();
                  if (!context.mounted) return;
                  if (didCommit) {
                    Navigator.of(context).pop(true);
                  } else {
                    final String? message = ref
                        .read(prioritySliderViewModelProvider(elementRef))
                        .valueOrNull
                        ?.message
                        ?.text;
                    if (message != null) {
                      showToast(context, message, isError: true);
                    }
                  }
                },
          child: const Text('Set'),
        ),
      ],
    );
  }
}

class _SliderBody extends StatelessWidget {
  const _SliderBody({required this.state, required this.model});

  final PrioritySliderState state;
  final PrioritySliderViewModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _readout(),
        _slider(),
        _scaleLegend(),
        const SizedBox(height: 16),
        // Naming the neighbours is what turns an abstract percent into a
        // judgement the user can actually make. These follow the slider: they
        // name where the element would land at the drafted percent, not where
        // it sits now.
        _NeighbourLine(label: 'Before', entry: state.draftAbove),
        const SizedBox(height: 6),
        _NeighbourLine(label: 'After', entry: state.draftBelow),
        const SizedBox(height: 14),
        const Text(
          'If you hesitate between a lower priority and a higher one, the '
          'lower is nearly always right: new material always feels urgent, '
          'and a queue where everything is urgent sorts nothing.',
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45),
        ),
      ],
    );
  }

  /// The drafted percent, its position in the collection, and the two keys
  /// that nudge it one place at a time.
  ///
  /// The position is shown alongside the percent because "12.5%" means
  /// nothing on its own, while "position 40 of 320" does.
  Widget _readout() {
    final int total = state.context.position.total;
    final int position = ((state.draftPercent / 100) * (total - 1)).round() + 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          '${state.draftPercent.toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'position $position of $total',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'More important (Shift+Ctrl+Up)',
          onPressed: state.isBusy
              ? null
              : () => model.step(shouldIncrease: true),
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: 'Less important (Shift+Ctrl+Down)',
          onPressed: state.isBusy
              ? null
              : () => model.step(shouldIncrease: false),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    );
  }

  Widget _slider() {
    return Slider(
      value: state.draftPercent,
      max: 100,
      divisions: 200,
      label: '${state.draftPercent.toStringAsFixed(1)}%',
      onChanged: state.isBusy ? null : model.draft,
    );
  }

  /// The scale runs the opposite way to intuition, so both ends say so.
  Widget _scaleLegend() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            '0% — most important',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          Text(
            '100% — least',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _NeighbourLine extends StatelessWidget {
  const _NeighbourLine({required this.label, required this.entry});

  final String label;
  final PriorityEntry? entry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.background,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            entry == null
                ? '—'
                : '${entry!.percent.toStringAsFixed(1)}%  ${entry!.preview}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
        ),
      ],
    ),
  );
}

/// A compact percent badge, for queue rows and Browser rows.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.percent, super.key, this.onTap});

  /// `0` is the most important.
  final double percent;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // A single hue whose weight tracks importance: the top of the collection
    // reads as solid, the bottom fades out. Never a second colour, which
    // would compete with the extract and marker inks.
    final double weight = (1 - percent / 100).clamp(0.15, 1);
    return Tooltip(
      message: 'Priority ${percent.toStringAsFixed(0)}% (Alt+P to change)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.10 * weight + 0.04),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.55 * weight + 0.12),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${percent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent.withValues(alpha: 0.55 * weight + 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
