import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I hide the tool panel
Future<void> iHideTheToolPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('collapse-panel')));
  await settle(tester);
}
