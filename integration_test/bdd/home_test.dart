// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/the_home_screen_is_shown.dart';
import './../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_open_the_menu.dart';
import './../../test/step/i_tap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Home screen and navigation menu''', () {
    testWidgets('''Home shows the new-project action and empty state''',
        (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await theHomeScreenIsShown(tester);
      await iSee(tester, 'New project');
      await iSee(tester, 'No projects yet');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''The menu opens All projects''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iOpenTheMenu(tester);
      await iTap(tester, 'All projects');
      await iSee(tester, 'All projects');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''The menu opens the About sheet''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iOpenTheMenu(tester);
      await iTap(tester, 'About');
      await iSee(tester, 'The great work we build on');
      await noUnhandledErrorOccurred(tester);
    });
  });
}
