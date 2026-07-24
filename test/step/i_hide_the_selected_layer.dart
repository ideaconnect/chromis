import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I hide the selected layer
Future<void> iHideTheSelectedLayer(WidgetTester tester) async {
  final id = selectedLayer(tester)!.id;
  editorController(tester).toggleVisibility(id);
  await settle(tester);
}
