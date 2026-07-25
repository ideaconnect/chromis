import 'package:chromis/features/editor/widgets/filter_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I tap the {'Noir'} filter
///
/// The strip is a lazy horizontal list of fifteen looks, so most tiles start
/// off-screen - and tapping one leaves the strip scrolled, because
/// `ensureVisible` aligns the target to the leading edge. A tile picked earlier
/// in the same scenario can therefore sit off EITHER end. Rewinding to the
/// start first makes the search direction unambiguous.
Future<void> iTapTheFilter(WidgetTester tester, String param1) async {
  final tile = find.text(param1);
  final strip = find.descendant(
    of: find.byType(FilterStrip),
    matching: find.byType(Scrollable),
  );
  if (strip.evaluate().isNotEmpty) {
    // The panel scrolls too, and a horizontal drag aimed at a strip that has
    // been scrolled out of the panel's viewport lands on the page behind it.
    await tester.ensureVisible(find.byType(FilterStrip));
    await settle(tester);
    await tester.drag(strip.first, const Offset(1600, 0));
    await settle(tester);
    if (tile.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        tile,
        120,
        scrollable: strip.first,
        maxScrolls: 30,
      );
      await settle(tester);
    }
  }
  await scrollIntoView(tester, tile.first);
  await tester.tap(tile.first);
  await settle(tester);
}
