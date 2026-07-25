import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the screen is resized to a {'tablet portrait'}
Future<void> theScreenIsResizedToA(WidgetTester tester, String param1) async {
  await resizeSurface(tester, param1);
}
