// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/i_pick_the_bubble_format.dart';
import './../../test/step/a_comic_bubble_layer_is_added.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/the_selected_bubble_shape_is.dart';
import './../../test/step/i_dismiss_the_bubble_format_picker.dart';
import './../../test/step/no_comic_bubble_layer_was_added.dart';
import './../../test/step/i_change_the_bubble_format_to.dart';
import './../../test/step/i_enter_as_the_bubble_text.dart';
import './../../test/step/the_selected_bubble_text_is.dart';
import './../../test/step/i_pick_a_different_color.dart';
import './../../test/step/the_selected_bubble_color_changed.dart';

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
      await iPickTheBubbleFormat(tester, 'Speech');
      await aComicBubbleLayerIsAdded(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets(
      '''Outline: Every format can be picked when adding a bubble (Speech)''',
      (tester) async {
        await bddSetUp(tester);
        await iTapTheTool(tester, 'Bubble');
        await iPickTheBubbleFormat(tester, 'Speech');
        await aComicBubbleLayerIsAdded(tester);
        await theSelectedBubbleShapeIs(tester, 'Speech');
        await noUnhandledErrorOccurred(tester);
      },
    );
    testWidgets(
      '''Outline: Every format can be picked when adding a bubble (Thought)''',
      (tester) async {
        await bddSetUp(tester);
        await iTapTheTool(tester, 'Bubble');
        await iPickTheBubbleFormat(tester, 'Thought');
        await aComicBubbleLayerIsAdded(tester);
        await theSelectedBubbleShapeIs(tester, 'Thought');
        await noUnhandledErrorOccurred(tester);
      },
    );
    testWidgets(
      '''Outline: Every format can be picked when adding a bubble (Shout)''',
      (tester) async {
        await bddSetUp(tester);
        await iTapTheTool(tester, 'Bubble');
        await iPickTheBubbleFormat(tester, 'Shout');
        await aComicBubbleLayerIsAdded(tester);
        await theSelectedBubbleShapeIs(tester, 'Shout');
        await noUnhandledErrorOccurred(tester);
      },
    );
    testWidgets(
      '''Outline: Every format can be picked when adding a bubble (Caption)''',
      (tester) async {
        await bddSetUp(tester);
        await iTapTheTool(tester, 'Bubble');
        await iPickTheBubbleFormat(tester, 'Caption');
        await aComicBubbleLayerIsAdded(tester);
        await theSelectedBubbleShapeIs(tester, 'Caption');
        await noUnhandledErrorOccurred(tester);
      },
    );
    testWidgets(
      '''Outline: Every format can be picked when adding a bubble (Whisper)''',
      (tester) async {
        await bddSetUp(tester);
        await iTapTheTool(tester, 'Bubble');
        await iPickTheBubbleFormat(tester, 'Whisper');
        await aComicBubbleLayerIsAdded(tester);
        await theSelectedBubbleShapeIs(tester, 'Whisper');
        await noUnhandledErrorOccurred(tester);
      },
    );
    testWidgets('''Dismissing the format picker adds nothing''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Bubble');
      await iDismissTheBubbleFormatPicker(tester);
      await noComicBubbleLayerWasAdded(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Change the format and the text''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Bubble');
      await iPickTheBubbleFormat(tester, 'Speech');
      await iChangeTheBubbleFormatTo(tester, 'Thought');
      await iEnterAsTheBubbleText(tester, 'Boom');
      await theSelectedBubbleShapeIs(tester, 'Thought');
      await theSelectedBubbleTextIs(tester, 'Boom');
    });
    testWidgets('''Set fill and outline colours''', (tester) async {
      await bddSetUp(tester);
      await iTapTheTool(tester, 'Bubble');
      await iPickTheBubbleFormat(tester, 'Caption');
      await iPickADifferentColor(tester, 'Fill');
      await iPickADifferentColor(tester, 'Outline');
      await theSelectedBubbleColorChanged(tester, 'Fill');
      await theSelectedBubbleColorChanged(tester, 'Outline');
    });
  });
}
