/// Verifies the shared visual language used throughout the application.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incremental_reader/shared/ui/app_theme.dart';

void main() {
  test('all filled button variants inherit white label text', () {
    final ButtonStyle style = buildAppTheme().filledButtonTheme.style!;

    expect(style.foregroundColor!.resolve(<WidgetState>{}), Colors.white);
  });

  // Material's tonal variant reads its fill from the secondary *container*
  // role, which is the pale [AppColors.accentWash]. Left alone it would put
  // the white label above on a near-white button, so the theme paints every
  // filled variant with the accent itself.
  test(
    'a filled button is the accent whichever variant a screen reaches for',
    () {
      final ButtonStyle style = buildAppTheme().filledButtonTheme.style!;

      expect(style.backgroundColor!.resolve(<WidgetState>{}), AppColors.accent);
      expect(
        style.backgroundColor!.resolve(<WidgetState>{WidgetState.hovered}),
        AppColors.accentHover,
      );
      expect(
        style.backgroundColor!.resolve(<WidgetState>{WidgetState.pressed}),
        AppColors.accentPressed,
      );
    },
  );

  // The label may not stay white once the button is disabled: a disabled
  // button drops to a pale fill, and white on that is a label nobody can
  // read. Ink and fill have to be named together or one of them goes blind.
  test('a disabled filled button keeps its label legible', () {
    final ButtonStyle style = buildAppTheme().filledButtonTheme.style!;
    const Set<WidgetState> disabled = <WidgetState>{WidgetState.disabled};

    expect(style.backgroundColor!.resolve(disabled), AppColors.surfaceSunken);
    expect(style.foregroundColor!.resolve(disabled), AppColors.faint);
  });
}
