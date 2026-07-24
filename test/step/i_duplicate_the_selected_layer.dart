import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I duplicate the selected layer
Future<void> iDuplicateTheSelectedLayer(WidgetTester tester) async {
  final id = selectedLayer(tester)!.id;
  editorController(tester).duplicateLayer(id);
  await settle(tester);
}
