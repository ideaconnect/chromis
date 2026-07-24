import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I add a text layer
Future<void> iAddATextLayer(WidgetTester tester) async {
  editorController(tester).addTextLayer();
  await settle(tester);
}
