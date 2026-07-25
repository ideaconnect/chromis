// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/the_home_screen_is_shown.dart';
import './../../test/step/no_unhandled_error_occurred.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''App installs and launches on the device''', () {
    testWidgets('''Cold start reaches the Home screen''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await theHomeScreenIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
