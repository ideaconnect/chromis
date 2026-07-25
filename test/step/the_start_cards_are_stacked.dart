import 'package:flutter_test/flutter_test.dart';

/// Usage: the start cards are stacked
Future<void> theStartCardsAreStacked(WidgetTester tester) async {
  final a = tester.getRect(find.text('New project'));
  final b = tester.getRect(find.text('Open a photo'));
  expect(
    a.top,
    lessThan(b.top - 20),
    reason: 'a phone has no room for two cards in a row',
  );
}
