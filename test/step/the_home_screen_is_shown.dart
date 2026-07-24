import 'package:flutter_test/flutter_test.dart';

/// Usage: the Home screen is shown
Future<void> theHomeScreenIsShown(WidgetTester tester) async {
  expect(
    find.text('New project'),
    findsOneWidget,
    reason: 'Home should show the New project CTA',
  );
}
