import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the selected layer is hidden
Future<void> theSelectedLayerIsHidden(WidgetTester tester) async {
  expect(selectedLayer(tester)!.visible, isFalse);
}
