import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I see {'Full privacy policy'}
Future<void> iSee(WidgetTester tester, String param1) async {
  final f = find.text(param1);
  // Might be below the fold in a lazy list (e.g. the Licenses screen, or any
  // screen at all once the phone is turned sideways and the fold moves up).
  await revealFinder(tester, f);
  expect(f, findsWidgets, reason: 'expected to see "$param1"');
}
