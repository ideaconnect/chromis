import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I tap the {'Bubble'} tool
///
/// Taps a dock tool button by its stable key. Not by label: several tool names
/// ('Adjust', 'Text', 'Layers') also render as the panel header, and in
/// landscape the dock scrolls, so ensureVisible brings it into reach first.
Future<void> iTapTheTool(WidgetTester tester, String param1) async {
  final tool = find.byKey(ValueKey('dock-$param1'));
  await tester.ensureVisible(tool);
  await tester.tap(tool);
  await settle(tester);
}
