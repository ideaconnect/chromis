import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has a mask
Future<void> theSelectedPhotoHasAMask(WidgetTester tester) async {
  expect(selectedImage(tester).maskPath, isNotNull);
}
