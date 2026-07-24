import 'package:flutter_test/flutter_test.dart';

/// Usage: the export output summary is shown
Future<void> theExportOutputSummaryIsShown(WidgetTester tester) async {
  expect(find.textContaining('Output'), findsWidgets);
}
