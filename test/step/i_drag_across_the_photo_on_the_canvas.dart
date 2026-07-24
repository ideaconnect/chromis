import 'package:chromis/features/editor/widgets/editor_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I drag across the photo on the canvas
Future<void> iDragAcrossThePhotoOnTheCanvas(WidgetTester tester) async {
  await tester.drag(find.byType(EditorCanvas), const Offset(60, 0));
  await settle(tester);
}
