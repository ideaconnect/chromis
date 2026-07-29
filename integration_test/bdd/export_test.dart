// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_launched_as_pro.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_layer_is_added.dart';
import './../../test/step/i_tap.dart';
import './../../test/step/i_see.dart';
import './../../test/step/the_export_output_summary_is_shown.dart';
import './../../test/step/i_save_the_export_to_the_device.dart';
import './../../test/step/the_image_was_saved_to_the_device.dart';
import './../../test/step/no_unhandled_error_occurred.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Export and share''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theAppIsLaunchedAsPro(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoLayerIsAdded(tester);
    }

    testWidgets('''Export a PNG at half resolution''', (tester) async {
      await bddSetUp(tester);
      await iTap(tester, 'Export');
      await iSee(tester, 'Export & share');
      await iTap(tester, 'PNG');
      await iTap(tester, '50%');
      await theExportOutputSummaryIsShown(tester);
      await iSaveTheExportToTheDevice(tester);
      await theImageWasSavedToTheDevice(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Export a JPG''', (tester) async {
      await bddSetUp(tester);
      await iTap(tester, 'Export');
      await iTap(tester, 'JPG');
      await theExportOutputSummaryIsShown(tester);
      await iSaveTheExportToTheDevice(tester);
      await theImageWasSavedToTheDevice(tester);
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Choose the WebP format''', (tester) async {
      await bddSetUp(tester);
      await iTap(tester, 'Export');
      await iTap(tester, 'WebP');
      await theExportOutputSummaryIsShown(tester);
      await noUnhandledErrorOccurred(tester);
    });
  });
}
