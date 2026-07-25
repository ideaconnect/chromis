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
    // Found by the row's OWN key. Two earlier attempts each failed on the
    // device: "the first horizontal scrollable" is the caption TextField,
    // which sits above the row and carries one of its own; and "an ancestor of
    // a font chip" evaporates on the first drag, because the anchor chip is
    // exactly what scrolls out of the tree.
    final row = find.descendant(
      of: find.byKey(const ValueKey('font-row')),
      matching: find.byType(Scrollable),
    );
    if (row.evaluate().isNotEmpty) {
      // And the row has to be on screen before it can be dragged: the panel
      // scrolls too, and a horizontal drag aimed at a row that has scrolled out
      // of it lands on whatever is behind.
      await scrollIntoView(tester, row.first);
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
  await scrollIntoView(tester, f.first);
  await tester.tap(f.first);
  await settle(tester);
}
