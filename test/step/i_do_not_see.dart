import 'package:flutter_test/flutter_test.dart';

/// Usage: I do not see {'Go Pro · remove ads'}
Future<void> iDoNotSee(WidgetTester tester, String param1) async {
  expect(find.text(param1), findsNothing);
}
