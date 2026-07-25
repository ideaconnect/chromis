// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/i_tap.dart';
import './../../test/step/a_text_layer_is_added.dart';
import './../../test/step/i_enter_as_the_caption.dart';
import './../../test/step/the_selected_caption_is.dart';
import './../../test/step/i_select_the_font.dart';
import './../../test/step/the_selected_font_is.dart';
import './../../test/step/i_move_the_slider.dart';
import './../../test/step/the_selected_text_size_changed.dart';
import './../../test/step/i_pick_a_different_text_color.dart';
import './../../test/step/the_selected_text_color_changed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor text tool''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
    }

    testWidgets('''Add text and type a caption''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Text');
      await iTap(tester, 'Add text');
      await aTextLayerIsAdded(tester);
      await iEnterAsTheCaption(tester, 'Hello');
      await theSelectedCaptionIs(tester, 'Hello');
    });
    testWidgets('''Pick a font''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Text');
      await iTap(tester, 'Add text');
      await iSelectTheFont(tester, 'Rubik');
      await theSelectedFontIs(tester, 'Rubik');
    });
    testWidgets('''Change size and colour''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Text');
      await iTap(tester, 'Add text');
      await iMoveTheSlider(tester, 'Size');
      await theSelectedTextSizeChanged(tester);
      await iPickADifferentTextColor(tester);
      await theSelectedTextColorChanged(tester);
    });
  });
}
