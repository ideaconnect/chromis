import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has the {'noir'} filter
Future<void> theSelectedPhotoHasTheFilter(
  WidgetTester tester,
  String param1,
) async {
  expect(selectedImage(tester).adjustments.filter.name, param1);
}
