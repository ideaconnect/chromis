import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I confirm the crop
Future<void> iConfirmTheCrop(WidgetTester tester) async {
  await tapText(tester, 'Done');
  await settle(tester, rounds: 6);
}
