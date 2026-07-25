// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import '../../test/step/i_tap_the_filter.dart';
import '../../test/step/the_selected_photo_has_the_filter.dart';
import './../../test/step/i_move_the_slider.dart';
import '../../test/step/the_selected_photo_has_hdr.dart';
import '../../test/step/the_selected_photo_has_a_vignette.dart';
import '../../test/step/the_selected_layer_has_a_shadow.dart';
import '../../test/step/the_selected_layer_has_an_outline.dart';
import './../../test/step/i_tap.dart';
import '../../test/step/the_selected_layer_blends_with.dart';
import '../../test/step/the_selected_photo_has_no_effects.dart';
import './../../test/step/i_add_a_text_layer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor layer effects''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
      await iTapTheTool(tester, 'Effects');
    }

    testWidgets('''The Effects panel offers the whole look toolbox''',
        (tester) async {
      await bddSetUp(tester);
      await iSee(tester, 'FILTER');
      await iSee(tester, 'HDR');
      await iSee(tester, 'VIGNETTE');
      await iSee(tester, 'SHADOW');
      await iSee(tester, 'BLEND');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Apply a filter and fade it''', (tester) async {
      await bddSetUp(tester);
      await iTapTheFilter(tester, 'Noir');
      await theSelectedPhotoHasTheFilter(tester, 'noir');
      await iMoveTheSlider(tester, 'Strength');
      await theSelectedPhotoHasTheFilter(tester, 'noir');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''A filter can be taken back off''', (tester) async {
      await bddSetUp(tester);
      await iTapTheFilter(tester, 'Vivid');
      await theSelectedPhotoHasTheFilter(tester, 'vivid');
      await iTapTheFilter(tester, 'Original');
      await theSelectedPhotoHasTheFilter(tester, 'none');
    });
    testWidgets('''HDR and vignette''', (tester) async {
      await bddSetUp(tester);
      await iMoveTheSlider(tester, 'Tone + detail');
      await iMoveTheSlider(tester, 'Amount');
      await theSelectedPhotoHasHdr(tester);
      await theSelectedPhotoHasAVignette(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''A drop shadow with direction, blur and density''',
        (tester) async {
      await bddSetUp(tester);
      await iMoveTheSlider(tester, 'Opacity');
      await theSelectedLayerHasAShadow(tester);
      await iMoveTheSlider(tester, 'Direction');
      await iMoveTheSlider(tester, 'Distance');
      await iMoveTheSlider(tester, 'Blur');
      await iMoveTheSlider(tester, 'Density');
      await theSelectedLayerHasAShadow(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''A contour around the layer''', (tester) async {
      await bddSetUp(tester);
      await iMoveTheSlider(tester, 'Thickness');
      await theSelectedLayerHasAnOutline(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Blending the layer down''', (tester) async {
      await bddSetUp(tester);
      await iTap(tester, 'Multiply');
      await theSelectedLayerBlendsWith(tester, 'multiply');
      await iTap(tester, 'Screen');
      await theSelectedLayerBlendsWith(tester, 'screen');
    });
    testWidgets('''Reset clears every look at once''', (tester) async {
      await bddSetUp(tester);
      await iTapTheFilter(tester, 'Punch');
      await iMoveTheSlider(tester, 'Tone + detail');
      await iMoveTheSlider(tester, 'Thickness');
      await iTap(tester, 'Multiply');
      await theSelectedLayerBlendsWith(tester, 'multiply');
      await iTap(tester, 'Reset');
      await theSelectedPhotoHasNoEffects(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''A caption gets a shadow and an outline of its own''',
        (tester) async {
      await bddSetUp(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Effects');
      await iMoveTheSlider(tester, 'Opacity');
      await theSelectedLayerHasAShadow(tester);
      await iMoveTheSlider(tester, 'Thickness');
      await theSelectedLayerHasAnOutline(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
