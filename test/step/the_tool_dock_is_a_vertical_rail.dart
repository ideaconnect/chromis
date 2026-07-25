import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the tool dock is a vertical rail
///
/// Two dock buttons sharing a column, stacked - and hugging the left edge.
Future<void> theToolDockIsAVerticalRail(WidgetTester tester) async {
  final adjust = dockButtonRect(tester, 'Adjust');
  final layers = dockButtonRect(tester, 'Layers');
  expect(adjust.left, closeTo(layers.left, 0.5));
  expect((adjust.top - layers.top).abs(), greaterThan(1));
  expect(adjust.left, lessThan(100));
}
