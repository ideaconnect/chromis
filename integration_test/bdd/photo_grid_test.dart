// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import './../../test/step/the_app_is_freshly_launched.dart';
import './../../test/step/i_create_a_new_blank_project.dart';
import './../../test/step/a_photo_grid_project_is_open_with_photos.dart';
import './../../test/step/i_see.dart';
import './../../test/step/no_unhandled_error_occurred.dart';
import './../../test/step/i_tap.dart';
import './../../test/step/i_move_the_slider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('''Photo grid (collage)''', () {
    testWidgets('''The Grid tool is the collage's home''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoGridProjectIsOpenWithPhotos(tester, 3);
      await iSee(tester, 'Photo grid');
      await iSee(tester, 'PHOTOS');
      await iSee(tester, 'LAYOUT');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Change the layout and the photo count''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoGridProjectIsOpenWithPhotos(tester, 3);
      await iTap(tester, 'Rows');
      await iTap(tester, '4');
      await iSee(tester, 'Photo grid');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Restyle the border''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoGridProjectIsOpenWithPhotos(tester, 2);
      await iMoveTheSlider(tester, 'Border');
      await iMoveTheSlider(tester, 'Corners');
      await noUnhandledErrorOccurred(tester);
    });
    testWidgets('''Export a collage''', (tester) async {
      await theAppIsFreshlyLaunched(tester);
      await iCreateANewBlankProject(tester);
      await aPhotoGridProjectIsOpenWithPhotos(tester, 2);
      await iTap(tester, 'Export');
      await iSee(tester, 'Export & share');
      await noUnhandledErrorOccurred(tester);
    });
  });
}
