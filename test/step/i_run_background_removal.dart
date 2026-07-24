import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I run background removal
Future<void> iRunBackgroundRemoval(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Remove background'));
  await settle(tester, rounds: 20);
}
