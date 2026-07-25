// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/the_editor_is_shown.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/a_comic_bubble_layer_is_added.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Core editing on a blank canvas''', () {
    testWidgets('''Create a new project and open the editor''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await theEditorIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Add a comic bubble layer''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await iTapTheTool(tester, 'Bubble');
      await aComicBubbleLayerIsAdded(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
