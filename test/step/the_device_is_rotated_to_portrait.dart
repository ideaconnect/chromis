import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the device is rotated to portrait
Future<void> theDeviceIsRotatedToPortrait(WidgetTester tester) async {
  await rotateSurface(tester, landscape: false);
}
