/// Verifies the shared visual language used throughout the application.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

void main() {
  test('all filled button variants inherit white label text', () {
    final ButtonStyle style = buildAppTheme().filledButtonTheme.style!;

    expect(style.foregroundColor!.resolve(<WidgetState>{}), Colors.white);
    expect(
      style.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled}),
      Colors.white,
    );
  });
}
