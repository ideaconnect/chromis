import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the editor canvas is wider than {600} px
Future<void> theEditorCanvasIsWiderThanPx(
  WidgetTester tester,
  num param1,
) async {
  final width = tester.getSize(find.byType(EditorCanvas)).width;
  expect(
    width,
    greaterThan(param1.toDouble()),
    reason: 'the canvas rendered ${width.round()}px - still on the phone cap',
  );
}
