import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I dismiss the bubble format picker
///
/// Taps the scrim above the sheet, which is how a bottom sheet is cancelled by
/// hand. The barrier is the whole screen, so a point near the very top is
/// guaranteed to be above the sheet however tall it grew.
Future<void> iDismissTheBubbleFormatPicker(WidgetTester tester) async {
  expect(
    find.byKey(const ValueKey('bubble-format-speech')),
    findsOneWidget,
    reason: 'the Bubble tool should have opened the format picker',
  );
  await tester.tapAt(const Offset(20, 10));
  await settle(tester);
}
