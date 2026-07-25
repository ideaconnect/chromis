// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_open_the_menu.dart';
import './../../test/step/i_see.dart';
import './../../test/step/i_tap.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/the_app_is_launched_as_pro.dart';
import './../../test/step/i_do_not_see.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Go Pro upsell and entitlement''', () {
    testWidgets('''A non-Pro user sees the upgrade and restore''', (
      tester,
    ) async {
      await theAppIsFreshlyLaunched(tester);
      await iOpenTheMenu(tester);
      await iSee(tester, 'Go Pro · remove ads');
      await iTap(tester, 'Go Pro · remove ads');
      await iSee(tester, 'Remove ads forever');
      await iSee(tester, 'Restore purchase');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''A Pro user no longer sees the upsell''', (tester) async {
      await theAppIsLaunchedAsPro(tester);
      await iOpenTheMenu(tester);
      await iDoNotSee(tester, 'Go Pro · remove ads');
      await noUnhandledErrorOccurred(tester);
    });
  });
}
