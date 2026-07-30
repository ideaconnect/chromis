import 'package:chromis/features/editor/widgets/crop_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I drag the crop box corner inwards
///
/// Grabs the bottom-right handle a few pixels INSIDE its centre, the way a
/// finger does. Dead centre on the corner is the one spot that also falls
/// outside the crop body's own bounds, so a perfectly centred drag would pass
/// even if the handles lost the gesture arena to the body pan - which they did.
Future<void> iDragTheCropBoxCornerInwards(WidgetTester tester) async {
  final preview = tester.getRect(
    find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(RawImage),
    ),
  );
  final handle = tester.getRect(find.byKey(cropHandleKeys.bottomRight));
  await tester.dragFrom(
    handle.center - const Offset(5, 5),
    Offset(-preview.width / 4, -preview.height / 4),
  );
  await settle(tester, rounds: 4);
}
