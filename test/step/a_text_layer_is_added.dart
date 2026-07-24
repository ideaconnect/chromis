import 'package:chromis/core/models/layer.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: a text layer is added
Future<void> aTextLayerIsAdded(WidgetTester tester) async {
  expect(selectedLayer(tester), isA<TextLayer>());
}
