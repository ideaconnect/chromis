import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I redo the last action
Future<void> iRedoTheLastAction(WidgetTester tester) async {
  editorController(tester).redo();
  await settle(tester);
}
