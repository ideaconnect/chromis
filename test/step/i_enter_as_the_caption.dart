import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I enter {'Hello'} as the caption
Future<void> iEnterAsTheCaption(WidgetTester tester, String param1) async {
  await tester.enterText(find.byType(TextField).first, param1);
  await settle(tester);
}
