import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I undo the last action
Future<void> iUndoTheLastAction(WidgetTester tester) async {
  editorController(tester).undo();
  await settle(tester);
}
