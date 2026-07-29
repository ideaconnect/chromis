import 'package:chromis/core/models/layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I change the bubble format to {'Thought'}
///
/// Uses the Bubble panel's format row (the picker is for creation only). Keyed
/// rather than by label so it can never match the creation sheet's tiles.
Future<void> iChangeTheBubbleFormatTo(
  WidgetTester tester,
  String param1,
) async {
  final shape = BubbleShape.values.firstWhere(
    (s) => s.name == param1.toLowerCase(),
    orElse: () => throw ArgumentError('unknown bubble format "$param1"'),
  );
  final tile = find.byKey(ValueKey('bubble-shape-${shape.name}'));
  await revealFinder(tester, tile);
  await scrollIntoView(tester, tile);
  await tester.tap(tile);
  await settle(tester);
}
