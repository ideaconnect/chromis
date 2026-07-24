// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap_the_tool.dart';
import '../../test/step/i_move_the_slider.dart';
import '../../test/step/the_selected_photo_has_been_adjusted.dart';
import './../../test/step/i_tap.dart';
import '../../test/step/the_selected_photo_has_default_adjustments.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor photo adjustments''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
    }

    testWidgets('''Brightness changes the photo''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Adjust');
      await iMoveTheSlider(tester, 'Brightness');
      await theSelectedPhotoHasBeenAdjusted(tester);
    });
    testWidgets('''Several adjustments then reset''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Adjust');
      await iMoveTheSlider(tester, 'Contrast');
      await iMoveTheSlider(tester, 'Saturation');
      await iMoveTheSlider(tester, 'Opacity');
      await iMoveTheSlider(tester, 'Cutout outline');
      await theSelectedPhotoHasBeenAdjusted(tester);
      await iTap(tester, 'Reset');
      await theSelectedPhotoHasDefaultAdjustments(tester);
    });
  });
}
