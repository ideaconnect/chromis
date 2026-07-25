// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_tap.dart';
import './../../test/step/the_editor_is_shown.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_enter_a_custom_canvas_size_of_by.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''New-project canvas size sheet''', () {
    testWidgets('''Create from a preset''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iTap(tester, 'New project');
      await iTap(tester, 'Blank canvas');
      await iTap(tester, 'Story');
      await iTap(tester, 'Create');
      await theEditorIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Create with a custom size''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iTap(tester, 'New project');
      await iTap(tester, 'Blank canvas');
      await iEnterACustomCanvasSizeOfBy(tester, 1000, 1600);
      await iTap(tester, 'Create');
      await theEditorIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
