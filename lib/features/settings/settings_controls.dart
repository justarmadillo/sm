/// Small labelled controls shared by the Settings sections.
///
/// Every one of them carries an explanation rather than only a label. The
/// values behind these fields are the scheduler's constants, and a number with
/// no account of what it does is a number the user cannot honestly change —
/// which would make the whole screen decoration.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:incremental_reader/shared/ui/app_theme.dart';
import 'package:incremental_reader/shared/ui/screen_width.dart';

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
    this.controlWidth = 190,
  });

  final String label;

  /// What this value does. Written for someone deciding whether to change it.
  final String hint;

  final Widget control;
  final double controlWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    // A 190-pixel control beside a sentence leaves the sentence a column too
    // narrow to read on a phone, so there the control moves underneath it.
    child: isCompactWidth(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _labelAndHint(),
              const SizedBox(height: 8),
              _control(context),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _labelAndHint()),
              const SizedBox(width: 18),
              SizedBox(width: controlWidth, child: control),
            ],
          ),
  );

  /// What the setting is called, and what changing it does.
  Widget _labelAndHint() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text)),
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
  );

  /// The control keeps its own width where the screen still has it: a text
  /// field stretched across a phone reads as a paragraph, not a number.
  Widget _control(BuildContext context) => SizedBox(
    width: math.min(controlWidth, MediaQuery.sizeOf(context).width - 40),
    child: control,
  );
}

/// A whole-number field.
class IntField extends StatefulWidget {
  const IntField({
    required this.value,
    required this.onChanged,
    super.key,
    this.suffix,
    this.min,
    this.max,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? suffix;
  final int? min;
  final int? max;

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
      if (parsed == null) return;
      widget.onChanged(
        parsed.clamp(widget.min ?? parsed, widget.max ?? parsed).toInt(),
      );
    },
  );
}

/// A real-number field with optional inclusive bounds.
class DoubleField extends StatefulWidget {
  const DoubleField({
    required this.value,
    required this.onChanged,
    super.key,
    this.suffix,
    this.min,
    this.max,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String? suffix;
  final double? min;
  final double? max;

  @override
  State<DoubleField> createState() => _DoubleFieldState();
}

class _DoubleFieldState extends State<DoubleField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );

  static String _format(double value) {
    final String text = value.toStringAsFixed(6);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void didUpdateWidget(DoubleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final double? typed = double.tryParse(_controller.text);
    if (widget.value != oldWidget.value && typed != widget.value) {
      _controller.text = _format(widget.value);
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
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    ],
    decoration: InputDecoration(
      isDense: true,
      border: const OutlineInputBorder(),
      suffixText: widget.suffix,
    ),
    style: const TextStyle(fontSize: 13),
    onChanged: (String text) {
      final double? parsed = double.tryParse(text);
      if (parsed == null || !parsed.isFinite) return;
      widget.onChanged(
        parsed.clamp(widget.min ?? parsed, widget.max ?? parsed).toDouble(),
      );
    },
  );
}

/// A short free-text setting such as a Smart Postpone profile name.
class StringField extends StatefulWidget {
  const StringField({required this.value, required this.onChanged, super.key});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<StringField> createState() => _StringFieldState();
}

class _StringFieldState extends State<StringField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(StringField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
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
    decoration: const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    style: const TextStyle(fontSize: 13),
    onChanged: widget.onChanged,
  );
}

/// Editor for SM20's optional row-major 20 by 20 UInt16 Mercy matrix.
class UInt16MatrixField extends StatefulWidget {
  const UInt16MatrixField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<int>? value;
  final ValueChanged<List<int>?> onChanged;

  @override
  State<UInt16MatrixField> createState() => _UInt16MatrixFieldState();
}

class _UInt16MatrixFieldState extends State<UInt16MatrixField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.join(', ') ?? '',
  );
  String? _error;

  @override
  void didUpdateWidget(UInt16MatrixField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String oldValue = oldWidget.value?.join(',') ?? '';
    final String newValue = widget.value?.join(',') ?? '';
    if (oldValue != newValue && _normalized(_controller.text) != newValue) {
      _controller.text = widget.value?.join(', ') ?? '';
      _error = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _normalized(String text) => text
      .split(RegExp(r'[\s,;]+'))
      .where((String part) => part.isNotEmpty)
      .join(',');

  void _changed(String text) {
    if (text.trim().isEmpty) {
      setState(() => _error = null);
      widget.onChanged(null);
      return;
    }
    final List<String> parts = text
        .split(RegExp(r'[\s,;]+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    final values = <int>[];
    for (final String part in parts) {
      final int? value = int.tryParse(part);
      if (value == null || value < 0 || value > 0xFFFF) {
        setState(() => _error = 'Use unsigned 16-bit values (0–65535).');
        return;
      }
      values.add(value);
    }
    if (values.length != 400) {
      setState(() => _error = '${values.length}/400 values entered');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(List<int>.unmodifiable(values));
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    minLines: 3,
    maxLines: 6,
    decoration: InputDecoration(
      isDense: true,
      border: const OutlineInputBorder(),
      hintText: '400 comma- or space-separated UInt16 values',
      errorText: _error,
    ),
    style: const TextStyle(fontSize: 12),
    onChanged: _changed,
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
