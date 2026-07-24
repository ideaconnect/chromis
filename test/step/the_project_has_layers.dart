import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: the project has {1} layers
Future<void> theProjectHasLayers(WidgetTester tester, num param1) async {
  expect(editorState(tester).layers.length, param1.toInt());
}
