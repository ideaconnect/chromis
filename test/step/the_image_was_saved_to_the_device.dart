import 'package:flutter_test/flutter_test.dart';

import 'i_save_the_export_to_the_device.dart';

/// Usage: the image was saved to the device
///
/// Asserts the SUCCESS message captured by `I save the export to the device`,
/// not merely the absence of a crash.
///
/// `ExportScreen._save` catches everything and answers with a snack bar: it
/// shows "Couldn't save the image" when the platform channel returns null, and
/// "Export failed - try again" when the render throws. So the old
/// "no unhandled error occurred" would have passed on a device where saving
/// never worked at all - which is exactly the case this step exists to catch.
Future<void> theImageWasSavedToTheDevice(WidgetTester tester) async {
  expect(
    lastExportOutcome,
    isNotNull,
    reason:
        'saving neither confirmed nor failed within the timeout - the export '
        'is stuck, or the confirmation snack never appeared',
  );
  expect(
    exportFailureMessages,
    isNot(contains(lastExportOutcome)),
    reason: 'the export reported a failure: "$lastExportOutcome"',
  );
}
