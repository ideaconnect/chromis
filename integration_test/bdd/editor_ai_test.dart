// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/step/the_app_is_launched_as_pro.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import '../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap_the_tool.dart';
import '../../test/step/i_run_background_removal.dart';
import '../../test/step/the_selected_photo_has_a_mask.dart';
import './../../test/step/no_unhandled_error_occurred.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''AI background removal''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsLaunchedAsPro(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
    }

    testWidgets('''Remove the background from a photo''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'AI Cut');
      await iRunBackgroundRemoval(tester);
      await theSelectedPhotoHasAMask(tester);
      await noUnhandledErrorOccurred(tester);
    }, tags: ['device']);
  });
}
