import 'package:chromis/core/models/layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I pick the {'Shout'} bubble format
///
/// Answers the format picker that the Bubble tool now opens. Found by key, not
/// by label: the panel behind the sheet carries the same five format names, so
/// a text finder is ambiguous the moment a bubble already exists.
Future<void> iPickTheBubbleFormat(WidgetTester tester, String param1) async {
  final shape = BubbleShape.values.firstWhere(
    (s) => s.name == param1.toLowerCase(),
    orElse: () => throw ArgumentError('unknown bubble format "$param1"'),
  );
  final tile = find.byKey(ValueKey('bubble-format-${shape.name}'));
  await revealFinder(tester, tile);
  await scrollIntoView(tester, tile);
  await tester.tap(tile);
  await settle(tester);
}
