// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import '../../test/step/i_open_the_menu.dart';
import '../../test/step/i_tap.dart';
import '../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''About, privacy and licenses''', () {
    testWidgets('''Open the privacy summary''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iOpenTheMenu(tester);
      await iTap(tester, 'Privacy & Cookies');
      await iSee(tester, 'Full privacy policy');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Open the licenses screen''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iOpenTheMenu(tester);
      await iTap(tester, 'Licenses');
      await iSee(tester, 'View full license texts');
      await noUnhandledErrorOccurred(tester);
    });
  });
}
