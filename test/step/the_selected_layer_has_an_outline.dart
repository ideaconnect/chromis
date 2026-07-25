import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected layer has an outline
Future<void> theSelectedLayerHasAnOutline(WidgetTester tester) async {
  expect(selectedLayer(tester)!.effects.stroke.isVisible, isTrue);
}
