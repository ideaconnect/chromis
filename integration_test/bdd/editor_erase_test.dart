// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/i_drag_across_the_photo_on_the_canvas.dart';
import './../../test/step/the_selected_photo_has_a_mask.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/the_selected_photo_has_no_mask.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor erase tool''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
    }

    testWidgets('''Dragging erases part of the photo''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Erase');
      await iDragAcrossThePhotoOnTheCanvas(tester);
      await theSelectedPhotoHasAMask(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Selecting the erase tool alone leaves the photo untouched''',
        (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Erase');
      await theSelectedPhotoHasNoMask(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
