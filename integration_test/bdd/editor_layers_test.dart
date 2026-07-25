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
import './../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_duplicate_the_selected_layer.dart';
import './../../test/step/i_delete_the_selected_layer.dart';
import './../../test/step/i_hide_the_selected_layer.dart';
import './../../test/step/the_selected_layer_is_hidden.dart';
import './../../test/step/i_undo_the_last_action.dart';
import './../../test/step/i_redo_the_last_action.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Editor layer management''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
    }

    testWidgets('''Add a text layer and see it listed''', (tester) async {
      await bddSetUp(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await theProjectHasLayers(tester, 1);
      await iSee(tester, 'Text layer');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Duplicate then delete a layer''', (tester) async {
      await bddSetUp(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await iDuplicateTheSelectedLayer(tester);
      await theProjectHasLayers(tester, 2);
      await iDeleteTheSelectedLayer(tester);
      await theProjectHasLayers(tester, 1);
    });
    testWidgets('''Toggle layer visibility''', (tester) async {
      await bddSetUp(tester);
      await iAddATextLayer(tester);
      await iTapTheTool(tester, 'Layers');
      await iHideTheSelectedLayer(tester);
      await theSelectedLayerIsHidden(tester);
    });
    testWidgets('''Undo and redo a layer add''', (tester) async {
      await bddSetUp(tester);
      await iAddATextLayer(tester);
      await theProjectHasLayers(tester, 1);
      await iUndoTheLastAction(tester);
      await theProjectHasLayers(tester, 0);
      await iRedoTheLastAction(tester);
      await theProjectHasLayers(tester, 1);
    });
  });
}
