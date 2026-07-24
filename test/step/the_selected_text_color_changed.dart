import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected text color changed
Future<void> theSelectedTextColorChanged(WidgetTester tester) async {
  expect(selectedText(tester).color, isNot(0xFFFFFFFF));
}
