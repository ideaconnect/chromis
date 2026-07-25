import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I tap the {'Bubble'} tool
///
/// Leaves the editor working in that tool, with its panel showing.
///
/// Found by key, not by label: several tool names ('Adjust', 'Text', 'Layers')
/// also render as the panel header. And the panel is re-opened afterwards
/// because in landscape a tap on the tool you are already in folds it away -
/// deliberate behaviour (that is how the canvas gets the full width, and
/// `editor_landscape.feature` pins it), but never what a scenario naming a tool
/// is asking for.
Future<void> iTapTheTool(WidgetTester tester, String param1) async {
  final tool = find.byKey(ValueKey('dock-$param1'));
  await scrollIntoView(tester, tool);
  await tester.tap(tool);
  await settle(tester);
  final expand = find.byKey(const ValueKey('expand-panel'));
  if (expand.evaluate().isNotEmpty) {
    await tester.tap(expand);
    await settle(tester);
  }
}
