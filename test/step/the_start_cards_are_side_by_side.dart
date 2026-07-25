import 'package:flutter_test/flutter_test.dart';

/// Usage: the start cards are side by side
Future<void> theStartCardsAreSideBySide(WidgetTester tester) async {
  final a = tester.getRect(find.text('New project'));
  final b = tester.getRect(find.text('Open a photo'));
  expect(a.top, closeTo(b.top, 1), reason: 'the two start cards share a row');
}
