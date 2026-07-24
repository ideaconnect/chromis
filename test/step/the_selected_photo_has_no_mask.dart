import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has no mask
Future<void> theSelectedPhotoHasNoMask(WidgetTester tester) async {
  expect(selectedImage(tester).maskPath, isNull);
}
