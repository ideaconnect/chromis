// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/a_comic_bubble_layer_is_added.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_tap.dart';
import '../../test/step/i_enter_as_the_bubble_text.dart';
import '../../test/step/the_selected_bubble_shape_is.dart';
import '../../test/step/the_selected_bubble_text_is.dart';
import '../../test/step/i_pick_a_different_color.dart';
import '../../test/step/the_selected_bubble_color_changed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor comic bubble tool''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
    }

    testWidgets('''Add a comic bubble layer''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Bubble');
      await aComicBubbleLayerIsAdded(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Change the shape and the text''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Bubble');
      await iTap(tester, 'Thought');
      await iEnterAsTheBubbleText(tester, 'Boom');
      await theSelectedBubbleShapeIs(tester, 'Thought');
      await theSelectedBubbleTextIs(tester, 'Boom');
    });
    testWidgets('''Set fill and outline colours''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Bubble');
      await iPickADifferentColor(tester, 'Fill');
      await iPickADifferentColor(tester, 'Outline');
      await theSelectedBubbleColorChanged(tester, 'Fill');
      await theSelectedBubbleColorChanged(tester, 'Outline');
    });
  });
}
