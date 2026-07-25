import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected layer has a shadow
Future<void> theSelectedLayerHasAShadow(WidgetTester tester) async {
  expect(selectedLayer(tester)!.effects.shadow.isVisible, isTrue);
}
