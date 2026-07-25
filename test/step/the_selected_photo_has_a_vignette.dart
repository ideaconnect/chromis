import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has a vignette
Future<void> theSelectedPhotoHasAVignette(WidgetTester tester) async {
  expect(selectedImage(tester).vignette.isVisible, isTrue);
}
