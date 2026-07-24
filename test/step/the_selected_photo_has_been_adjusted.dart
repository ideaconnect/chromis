import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/core/models/image_adjustments.dart';

import '_e2e_support.dart';

/// Usage: the selected photo has been adjusted
Future<void> theSelectedPhotoHasBeenAdjusted(WidgetTester tester) async {
  final l = selectedImage(tester);
  expect(
    l.adjustments != ImageAdjustments.identity ||
        l.opacity != 1.0 ||
        l.outlineWidth > 0,
    isTrue,
  );
}
