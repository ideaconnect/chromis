import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I open the menu
Future<void> iOpenTheMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu).first);
  await settle(tester);
}
