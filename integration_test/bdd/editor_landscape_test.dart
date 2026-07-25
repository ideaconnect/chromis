// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/the_device_is_rotated_to_landscape.dart';
import './../../test/step/the_tool_dock_is_a_vertical_rail.dart';
import './../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_hide_the_tool_panel.dart';
import './../../test/step/the_tool_panel_is_hidden.dart';
import './../../test/step/i_show_the_tool_panel.dart';
import './../../test/step/the_tool_panel_is_shown.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/i_move_the_slider.dart';
import './../../test/step/the_selected_photo_has_been_adjusted.dart';
import './../../test/step/the_device_is_rotated_to_portrait.dart';
import './../../test/step/the_tool_dock_is_a_horizontal_bar.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor in landscape''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
    }

    testWidgets('''The dock becomes a vertical rail''', (tester) async {
      await bddSetUp(tester);
      await theDeviceIsRotatedToLandscape(tester);
      await theToolDockIsAVerticalRail(tester);
      await iSee(tester, 'Effects');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''The tool panel folds away and comes back''', (tester) async {
      await bddSetUp(tester);
      await theDeviceIsRotatedToLandscape(tester);
      await iHideTheToolPanel(tester);
      await theToolPanelIsHidden(tester);
      await iShowTheToolPanel(tester);
      await theToolPanelIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Tapping the tool you are already on folds the panel away''',
        (tester) async {
      await bddSetUp(tester);
      await theDeviceIsRotatedToLandscape(tester);
      await iTapTheTool(tester, 'Layers');
      await theToolPanelIsShown(tester);
      await iTapTheTool(tester, 'Layers');
      await theToolPanelIsHidden(tester);
      await iTapTheTool(tester, 'Layers');
      await theToolPanelIsShown(tester);
    });
    testWidgets('''Tools still work in landscape''', (tester) async {
      await bddSetUp(tester);
      await theDeviceIsRotatedToLandscape(tester);
      await iTapTheTool(tester, 'Layers');
      await iTapTheTool(tester, 'Adjust');
      await iMoveTheSlider(tester, 'Brightness');
      await theSelectedPhotoHasBeenAdjusted(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Back to portrait, the dock is horizontal again''',
        (tester) async {
      await bddSetUp(tester);
      await theDeviceIsRotatedToLandscape(tester);
      await theToolDockIsAVerticalRail(tester);
      await theDeviceIsRotatedToPortrait(tester);
      await theToolDockIsAHorizontalBar(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
