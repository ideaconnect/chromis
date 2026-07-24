import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I delete the selected layer
Future<void> iDeleteTheSelectedLayer(WidgetTester tester) async {
  final id = selectedLayer(tester)!.id;
  editorController(tester).removeLayer(id);
  await settle(tester);
}
