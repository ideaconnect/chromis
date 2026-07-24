import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the app is launched as Pro
Future<void> theAppIsLaunchedAsPro(WidgetTester tester) async {
  await bootAsPro(tester);
}
