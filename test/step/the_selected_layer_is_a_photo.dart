import 'package:chromis/core/models/layer.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected layer is a photo
Future<void> theSelectedLayerIsAPhoto(WidgetTester tester) async {
  expect(selectedLayer(tester), isA<ImageLayer>());
}
