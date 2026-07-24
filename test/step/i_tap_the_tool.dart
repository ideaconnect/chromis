import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I tap the {'Bubble'} tool
///
/// Taps a dock tool button by its label. The dock button is the LAST match -
/// some tool names ('Adjust', 'Text', 'Erase') also render as the panel header
/// above the dock. ensureVisible guards the horizontally-scrollable dock.
Future<void> iTapTheTool(WidgetTester tester, String param1) async {
  final tool = find.text(param1).last;
  await tester.ensureVisible(tool);
  await tester.tap(tool);
  await settle(tester);
}
