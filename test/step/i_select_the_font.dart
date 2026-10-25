import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I select the {'Rubik'} font
Future<void> iSelectTheFont(WidgetTester tester, String param1) async {
  // The panel shows one font field, not a strip of chips: it opens a sheet
  // with a search field over every font. Searching rather than scrolling,
  // because the list is lazy and on a device its length depends on how many
  // fonts the phone itself ships - a scroll distance that finds Rubik on one
  // phone overshoots it on the next.
  final field = find.byKey(const ValueKey('font-field'));
  await scrollIntoView(tester, field.first);
  await tester.tap(field.first);
  await settle(tester);
  await tester.enterText(find.byKey(const ValueKey('font-search')), param1);
  await settle(tester);
  final row = find.descendant(
    of: find.byKey(const ValueKey('font-list')),
    matching: find.text(param1),
  );
  await tester.tap(row.first);
  await settle(tester);
}
