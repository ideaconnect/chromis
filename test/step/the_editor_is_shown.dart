import 'package:chromis/features/editor/editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the editor is shown
Future<void> theEditorIsShown(WidgetTester tester) async {
  expect(
    find.byType(EditorScreen),
    findsOneWidget,
    reason: 'Creating a project should push and render the editor',
  );
}
