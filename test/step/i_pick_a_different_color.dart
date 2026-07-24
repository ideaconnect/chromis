import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I pick a different {'Outline'} color
Future<void> iPickADifferentColor(WidgetTester tester, String param1) async {
  // The bubble panel builds two _swatchRow rows (editor_screen.dart ~1058):
  // a Row headed by Text('Fill' | 'Outline') followed by a Wrap of 9 tappable
  // color swatches (GestureDetectors). `.first` on the ancestor finder yields
  // the *nearest* Row - the swatch row for this label - so the swatch finder
  // stays scoped to just its 9 swatches. Index 2 is AppColors.pink, which is
  // neither the default fill (white) nor the default outline (#14101A), so it
  // always registers as a change from the current color.
  final row = find
      .ancestor(of: find.text(param1), matching: find.byType(Row))
      .first;
  final swatches = find.descendant(
    of: row,
    matching: find.byType(GestureDetector),
  );
  final swatch = swatches.at(2);
  await tester.ensureVisible(swatch); // the colour rows scroll off the panel
  await tester.tap(swatch);
  await settle(tester);
}
