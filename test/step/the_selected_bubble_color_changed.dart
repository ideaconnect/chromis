import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected bubble {'Fill'} color changed
Future<void> theSelectedBubbleColorChanged(
  WidgetTester tester,
  String param1,
) async {
  final b = selectedBubble(tester);
  final actual = param1 == 'Fill' ? b.fillColor : b.strokeColor;
  final def = param1 == 'Fill' ? 0xFFFFFFFF : 0xFF14101A;
  // Compare the packed ARGB int (a Color never == a bare int, which would make
  // the assertion vacuously pass), so this fails if the color did not change.
  expect(actual.toARGB32(), isNot(def));
}
