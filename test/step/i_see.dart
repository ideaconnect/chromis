import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I see {'Full privacy policy'}
Future<void> iSee(WidgetTester tester, String param1) async {
  final f = find.text(param1);
  if (f.evaluate().isEmpty) {
    // Might be below the fold in a lazy ListView (e.g. the Licenses screen) —
    // scroll it into view before asserting.
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(
          f,
          150,
          scrollable: scrollable.first,
          maxScrolls: 40,
        );
      } catch (_) {}
      await settle(tester);
    }
  }
  expect(f, findsWidgets, reason: 'expected to see "$param1"');
}
