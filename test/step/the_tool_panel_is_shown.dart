import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the tool panel is shown
Future<void> theToolPanelIsShown(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('collapse-panel')), findsOneWidget);
  expect(find.byKey(const ValueKey('expand-panel')), findsNothing);
}
