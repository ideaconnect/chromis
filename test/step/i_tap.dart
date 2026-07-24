import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I tap {'Licenses'}
Future<void> iTap(WidgetTester tester, String param1) async {
  await tapText(tester, param1);
}
