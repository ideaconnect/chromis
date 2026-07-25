import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I tap the {'Layers'} dock button
///
/// A RAW tap, with none of the "leave me working in that tool" helpfulness of
/// `I tap the {...} tool`: that step re-opens the panel if the tap folded it,
/// which is exactly the behaviour this one exists to observe.
Future<void> iTapTheDockButton(WidgetTester tester, String param1) async {
  final button = find.byKey(ValueKey('dock-$param1'));
  await scrollIntoView(tester, button);
  await tester.tap(button);
  await settle(tester);
}
