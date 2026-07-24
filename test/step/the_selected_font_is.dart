import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected font is {'Rubik'}
Future<void> theSelectedFontIs(WidgetTester tester, String param1) async {
  expect(selectedText(tester).fontFamily, param1);
}
