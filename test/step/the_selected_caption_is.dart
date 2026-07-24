import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected caption is {'Hello'}
Future<void> theSelectedCaptionIs(WidgetTester tester, String param1) async {
  expect(selectedText(tester).text, param1);
}
