import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo is not cropped
Future<void> theSelectedPhotoIsNotCropped(WidgetTester tester) async {
  expect(selectedImage(tester).isCropped, isFalse);
}
