import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected bubble text is {'Boom'}
Future<void> theSelectedBubbleTextIs(WidgetTester tester, String param1) async {
  expect(selectedBubble(tester).text, param1);
}
