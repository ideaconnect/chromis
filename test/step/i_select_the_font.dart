import 'package:chromis/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I select the {'Rubik'} font
Future<void> iSelectTheFont(WidgetTester tester, String param1) async {
  final f = find.text(param1);
  if (f.evaluate().isEmpty) {
    // The font row is a lazy horizontal ListView, so a chip past the right
    // edge is not in the tree yet - scroll until it builds.
    //
    // Target the scrollable that actually HOLDS a font chip, not simply the
    // first horizontal one: the panel's caption TextField carries its own
    // horizontal Scrollable and sits above the row, so "the first horizontal
    // scrollable" scrolls the text field and the chip never appears. That is a
    // real failure on any screen wide enough to push the last font off the
    // edge, which is how it was found (Pixel 10 Pro emulator).
    final row = find.ancestor(
      of: find.text(AppFonts.bundledFonts.first),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.horizontal,
      ),
    );
    if (row.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(
          f,
          100,
          scrollable: row.first,
          maxScrolls: 15,
        );
      } catch (_) {}
      await settle(tester);
    }
  }
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await settle(tester);
}
