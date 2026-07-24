import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I enter {'Boom'} as the bubble text
Future<void> iEnterAsTheBubbleText(WidgetTester tester, String param1) async {
  // The bubble panel's caption field (editor_screen.dart ~944) is the first
  // TextField in the shown panel; hint "Bubble text…".
  await tester.enterText(find.byType(TextField).first, param1);
  await settle(tester);
}
