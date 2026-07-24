import 'package:chromis/core/models/layer.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected bubble shape is {'Thought'}
Future<void> theSelectedBubbleShapeIs(
  WidgetTester tester,
  String param1,
) async {
  final want = BubbleShape.values.firstWhere(
    (s) => s.name == param1.toLowerCase(),
  );
  expect(selectedBubble(tester).shape, want);
}
