import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the app is freshly launched
Future<void> theAppIsFreshlyLaunched(WidgetTester tester) async {
  await bootToHome(tester);
}
