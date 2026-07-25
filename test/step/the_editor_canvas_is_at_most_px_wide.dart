import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the editor canvas is at most {460} px wide
Future<void> theEditorCanvasIsAtMostPxWide(
  WidgetTester tester,
  num param1,
) async {
  final width = tester.getSize(find.byType(EditorCanvas)).width;
  expect(
    width,
    lessThanOrEqualTo(param1.toDouble()),
    reason: 'the phone canvas grew to ${width.round()}px',
  );
}
