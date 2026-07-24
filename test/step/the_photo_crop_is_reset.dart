import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the photo crop is reset
Future<void> thePhotoCropIsReset(WidgetTester tester) async {
  final id = selectedImage(tester).id;
  editorController(tester).setImageCrop(id, const Rect.fromLTRB(0, 0, 1, 1));
  await settle(tester);
}
