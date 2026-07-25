import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has HDR
Future<void> theSelectedPhotoHasHdr(WidgetTester tester) async {
  expect(selectedImage(tester).adjustments.hdr, greaterThan(0));
}
