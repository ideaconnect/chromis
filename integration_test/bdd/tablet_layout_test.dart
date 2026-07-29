// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import '../../test/step/the_screen_is_resized_to_a.dart';
import '../../test/step/the_editor_canvas_is_wider_than_px.dart';
import '../../test/step/the_editor_canvas_is_at_most_px_wide.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import '../../test/step/the_start_cards_are_side_by_side.dart';
import '../../test/step/the_start_cards_are_stacked.dart';
import '../../test/step/the_tool_panel_is_at_most_px_tall.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Tablet layout''', () {
    testWidgets('''A tablet in portrait gives the canvas the width''', (
      tester,
    ) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await theScreenIsResizedToA(tester, 'tablet portrait');
      await theEditorCanvasIsWiderThanPx(tester, 600);
      await theScreenIsResizedToA(tester, 'phone portrait');
      await theEditorCanvasIsAtMostPxWide(tester, 460);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Home pairs its start cards on a tablet only''', (
      tester,
    ) async {
      await theAppIsFreshlyLaunched(tester);
      await theScreenIsResizedToA(tester, 'tablet landscape');
      await theStartCardsAreSideBySide(tester);
      await theScreenIsResizedToA(tester, 'phone portrait');
      await theStartCardsAreStacked(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''The tool panel still hugs its content on a tablet''', (
      tester,
    ) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await theScreenIsResizedToA(tester, 'tablet portrait');
      await theToolPanelIsAtMostPxTall(tester, 200);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
