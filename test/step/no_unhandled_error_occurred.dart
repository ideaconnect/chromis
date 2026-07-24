import 'package:flutter_test/flutter_test.dart';

/// Usage: no unhandled error occurred
///
/// Fails the scenario if any earlier step left an uncaught exception (a render
/// error, a thrown provider, etc.).
Future<void> noUnhandledErrorOccurred(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
}
