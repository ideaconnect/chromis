import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I select the {'Rubik'} font
Future<void> iSelectTheFont(WidgetTester tester, String param1) async {
  final f = find.text(param1);
  if (f.evaluate().isEmpty) {
    // The font row is a lazy horizontal ListView. Find it by axis (stable as
    // items build/unbuild while scrolling) and scroll until the chip appears.
    final row = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axis == Axis.horizontal,
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
