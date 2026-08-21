/// Small labelled controls shared by the Settings sections.
///
/// Every one of them carries an explanation rather than only a label. The
/// values behind these fields are the scheduler's constants, and a number with
/// no account of what it does is a number the user cannot honestly change —
/// which would make the whole screen decoration.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';

/// A titled group of settings.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.description,
    required this.children,
    super.key,
  });

  final String title;

  /// What the group as a whole controls, and why it matters.
  final String description;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

/// One labelled row with an explanation underneath.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.label,
    required this.hint,
    required this.control,
    super.key,
  });

  final String label;

  /// What this value does. Written for someone deciding whether to change it.
  final String hint;

  final Widget control;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
              const SizedBox(height: 2),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(width: 190, child: control),
      ],
    ),
  );
}

/// A whole-number field.
class IntField extends StatefulWidget {
  const IntField({
    required this.value,
    required this.onChanged,
    super.key,
    this.suffix,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? suffix;

  @override
  State<IntField> createState() => _IntFieldState();
}

class _IntFieldState extends State<IntField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(IntField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rewrite the field when the value changed underneath it — for
    // example after Restore defaults — so typing is never interrupted.
    if (widget.value != oldWidget.value &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
    ],
    decoration: InputDecoration(
      isDense: true,
      border: const OutlineInputBorder(),
      suffixText: widget.suffix,
    ),
    style: const TextStyle(fontSize: 13),
    onChanged: (String text) {
      final int? parsed = int.tryParse(text);
      if (parsed != null) widget.onChanged(parsed);
    },
  );
}

/// A slider over a real-valued setting, showing its current value.
class DoubleSliderField extends StatelessWidget {
  const DoubleSliderField({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    super.key,
    this.divisions,
    this.format,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;

  /// How to render the value. Defaults to two decimal places.
  final String Function(double value)? format;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Text(
        format?.call(value) ?? value.toStringAsFixed(2),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
      SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          overlayShape: SliderComponentShape.noOverlay,
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

/// A comma-separated list of positive integers, such as an interval sequence.
class IntListField extends StatefulWidget {
  const IntListField({
    required this.values,
    required this.onChanged,
    super.key,
  });

  final List<int> values;
  final ValueChanged<List<int>> onChanged;

  @override
  State<IntListField> createState() => _IntListFieldState();
}

class _IntListFieldState extends State<IntListField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.values.join(', '),
  );

  @override
  void didUpdateWidget(IntListField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.values.join(',') != oldWidget.values.join(',') &&
        _parse(_controller.text).join(',') != widget.values.join(',')) {
      _controller.text = widget.values.join(', ');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<int> _parse(String text) => <int>[
    for (final String part in text.split(','))
      if (int.tryParse(part.trim()) case final int value when value > 0) value,
  ];

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
      hintText: '1, 3, 7, 14',
    ),
    style: const TextStyle(fontSize: 13),
    onChanged: (String text) {
      final List<int> parsed = _parse(text);
      // An empty sequence cannot schedule anything, so it is simply not
      // reported until the user has typed at least one interval.
      if (parsed.isNotEmpty) widget.onChanged(parsed);
    },
  );
}

/// A yes/no setting.
class SwitchField extends StatelessWidget {
  const SwitchField({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Switch(value: value, onChanged: onChanged),
  );
}

/// A choice between named options.
class ChoiceField<T> extends StatelessWidget {
  const ChoiceField({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isDense: true,
    decoration: const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    style: const TextStyle(fontSize: 13, color: AppColors.text),
    items: <DropdownMenuItem<T>>[
      for (final MapEntry<T, String> entry in options.entries)
        DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: (T? next) {
      if (next != null) onChanged(next);
    },
  );
}
