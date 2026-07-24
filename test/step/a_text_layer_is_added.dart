import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/core/models/layer.dart';

import '_e2e_support.dart';

/// Usage: a text layer is added
Future<void> aTextLayerIsAdded(WidgetTester tester) async {
  expect(selectedLayer(tester), isA<TextLayer>());
}
