import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the tool panel is at most {200} px tall
///
/// The panel SURFACE, not the scroll view inside it: that shrink-wraps either
/// way, which is how a "panel fills its height cap" regression once shipped.
Future<void> theToolPanelIsAtMostPxTall(WidgetTester tester, num param1) async {
  final height = tester
      .getSize(find.byKey(const ValueKey('tool-panel')))
      .height;
  expect(
    height,
    lessThanOrEqualTo(param1.toDouble()),
    reason: 'the empty state reserved ${height.round()}px',
  );
}
