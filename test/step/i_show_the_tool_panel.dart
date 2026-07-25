import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I show the tool panel
Future<void> iShowTheToolPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('expand-panel')));
  await settle(tester);
}
