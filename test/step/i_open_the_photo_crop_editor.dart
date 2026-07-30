import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// Usage: I open the photo crop editor
///
/// Presses the Adjust panel's own Crop button, which is the part no other crop
/// step touches: the two state-path scenarios call `setImageCrop` on the
/// controller, so they passed for the whole time the button was dead. It
/// decoded the photo with the `ImageDescriptor` released before the codec ran,
/// which fails every time.
///
/// The label depends on whether a crop is already applied, and both spellings
/// must open the same editor.
Future<void> iOpenThePhotoCropEditor(WidgetTester tester) async {
  final button = find.text('Crop photo');
  await tapText(tester, button.evaluate().isEmpty ? 'Edit crop' : 'Crop photo');
  // Reading the file and decoding it happens off the platform thread, so give
  // it more than the tap's own settle before deciding it did not open.
  await settle(tester, rounds: 12);
  expect(
    find.text('Done'),
    findsOneWidget,
    reason:
        'the crop editor did not open - if a "Couldn\'t open the photo to '
        'crop" toast is on screen, the decode failed',
  );
}
