import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the tool dock is a horizontal bar
Future<void> theToolDockIsAHorizontalBar(WidgetTester tester) async {
  final adjust = dockButtonRect(tester, 'Adjust');
  final layers = dockButtonRect(tester, 'Layers');
  expect(adjust.top, closeTo(layers.top, 0.5));
  expect((adjust.left - layers.left).abs(), greaterThan(1));
}
