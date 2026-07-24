import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the app is launched for the first time
Future<void> theAppIsLaunchedForTheFirstTime(WidgetTester tester) async {
  await bootFirstRun(tester);
}
