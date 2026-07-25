import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the tool panel is hidden
Future<void> theToolPanelIsHidden(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('collapse-panel')), findsNothing);
  expect(find.byKey(const ValueKey('expand-panel')), findsOneWidget);
}
