import 'package:chromis/core/models/image_adjustments.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has default adjustments
Future<void> theSelectedPhotoHasDefaultAdjustments(WidgetTester tester) async {
  final l = selectedImage(tester);
  expect(l.adjustments, ImageAdjustments.identity);
  expect(l.opacity, 1.0);
  expect(l.outlineWidth, 0);
}
