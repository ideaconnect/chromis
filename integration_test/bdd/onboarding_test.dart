// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_launched_for_the_first_time.dart';
import './../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_tap.dart';
import './../../test/step/the_home_screen_is_shown.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''First-run onboarding''', () {
    testWidgets('''First launch shows the first intro page''', (tester) async {
      await theAppIsLaunchedForTheFirstTime(tester);
      await iSee(tester, 'Start from a photo');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Skip jumps straight to Home''', (tester) async {
      await theAppIsLaunchedForTheFirstTime(tester);
      await iTap(tester, 'Skip');
      await theHomeScreenIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Advancing through every page reaches Home''',
        (tester) async {
      await theAppIsLaunchedForTheFirstTime(tester);
      await iTap(tester, 'Next');
      await iTap(tester, 'Next');
      await iTap(tester, 'Get started');
      await theHomeScreenIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
