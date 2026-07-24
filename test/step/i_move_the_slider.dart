import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_editor_ai/core/widgets/labeled_slider.dart';

import '_e2e_support.dart';

/// Usage: I move the {'Saturation'} slider
Future<void> iMoveTheSlider(WidgetTester tester, String param1) async {
  final slider = find.descendant(
    of: find.ancestor(
      of: find.text(param1),
      matching: find.byType(LabeledSlider),
    ),
    matching: find.byType(Slider),
  );
  await tester.ensureVisible(slider);
  await tester.drag(slider, const Offset(300, 0));
  await settle(tester);
}
