// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/i_add_a_text_layer.dart';
import './../../test/step/i_tap_the_tool.dart';
import './../../test/step/the_project_has_layers.dart';
import './../../test/step/i_do_not_see.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap.dart';
import '../../test/step/the_selected_layer_is_a_photo.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_undo_the_last_action.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Merging and flattening layers''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
    }

    testWidgets('''Nothing to merge with a single layer''', (tester) async {
      await bddSetUp(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await theProjectHasLayers(tester, 1);
      await iDoNotSee(tester, 'Merge down');
      await iDoNotSee(tester, 'Flatten');
    });
    testWidgets('''Merge the selected layer into the one below''', (
      tester,
    ) async {
      await bddSetUp(tester);
      await aPhotoLayerIsAdded(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await theProjectHasLayers(tester, 2);
      await iTap(tester, 'Merge down');
      await theProjectHasLayers(tester, 1);
      await theSelectedLayerIsAPhoto(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Flatten the whole stack''', (tester) async {
      await bddSetUp(tester);
      await aPhotoLayerIsAdded(tester);
      await aPhotoLayerIsAdded(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await theProjectHasLayers(tester, 3);
      await iTap(tester, 'Flatten');
      await theProjectHasLayers(tester, 1);
      await theSelectedLayerIsAPhoto(tester);
    });
    testWidgets('''A merge is one undo step''', (tester) async {
      await bddSetUp(tester);
      await aPhotoLayerIsAdded(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await iTap(tester, 'Flatten');
      await theProjectHasLayers(tester, 1);
      await iUndoTheLastAction(tester);
      await theProjectHasLayers(tester, 2);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
