import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I pick a different text color
Future<void> iPickADifferentTextColor(WidgetTester tester) async {
  // The swatches (editor_screen _textPanel) are the only circular Containers in
  // the panel; index 0 is the default white, so tap index 2 (a non-white accent).
  final swatches = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle,
  );
  await tester.tap(swatches.at(2));
  await settle(tester);
}
