import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I create a new blank project
///
/// Taps the Home "New project" CTA and confirms the size sheet at its default
/// (valid) preset — reaching the editor with a blank canvas, no photo picker.
Future<void> iCreateANewBlankProject(WidgetTester tester) async {
  await tester.tap(find.text('New project'));
  await settle(tester);
  await tester.tap(find.text('Create'));
  await settle(tester);
}
