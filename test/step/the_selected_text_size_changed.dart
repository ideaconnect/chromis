import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected text size changed
Future<void> theSelectedTextSizeChanged(WidgetTester tester) async {
  expect(selectedText(tester).fontSize, isNot(40.0));
}
