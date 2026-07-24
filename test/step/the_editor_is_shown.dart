import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/features/editor/editor_screen.dart';

/// Usage: the editor is shown
Future<void> theEditorIsShown(WidgetTester tester) async {
  expect(
    find.byType(EditorScreen),
    findsOneWidget,
    reason: 'Creating a project should push and render the editor',
  );
}
