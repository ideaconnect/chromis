// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/i_open_the_photo_crop_editor.dart';
import './../../test/step/i_drag_the_crop_box_corner_inwards.dart';
import './../../test/step/i_confirm_the_crop.dart';
import './../../test/step/the_selected_photo_is_cropped.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/the_photo_is_cropped_to_the_right_half.dart';
import './../../test/step/the_photo_crop_is_reset.dart';
import './../../test/step/the_selected_photo_is_not_cropped.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor photo crop''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
    }

    testWidgets('''Crop a photo with the Crop button''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Adjust');
      await iOpenThePhotoCropEditor(tester);
      await iDragTheCropBoxCornerInwards(tester);
      await iConfirmTheCrop(tester);
      await theSelectedPhotoIsCropped(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Crop a photo''', (tester) async {
      await bddSetUp(tester);
      await thePhotoIsCroppedToTheRightHalf(tester);
      await theSelectedPhotoIsCropped(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Reset a crop''', (tester) async {
      await bddSetUp(tester);
      await thePhotoIsCroppedToTheRightHalf(tester);
      await thePhotoCropIsReset(tester);
      await theSelectedPhotoIsNotCropped(tester);
    });
  });
}
