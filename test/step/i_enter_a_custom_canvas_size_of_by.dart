import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I enter a custom canvas size of {1000} by {1600}
Future<void> iEnterACustomCanvasSizeOfBy(
  WidgetTester tester,
  num param1,
  num param2,
) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Width'),
    param1.toInt().toString(),
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Height'),
    param2.toInt().toString(),
  );
  await settle(tester);
}
