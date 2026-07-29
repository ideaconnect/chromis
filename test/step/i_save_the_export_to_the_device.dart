import 'package:flutter_test/flutter_test.dart';

import '_e2e_support.dart';

/// What the last "save to device" reported, for the matching Then step.
///
/// Cross-step state because the answer is a snack bar with a 4-second life and
/// the tap has to start watching for it immediately - a separate Then step that
/// looks afterwards can only ever see an empty screen.
String? lastExportOutcome;

/// The messages `ExportScreen._save` can end with. Success is a prefix because
/// the real snack is `Saved · <location>`.
const _savedPrefix = 'Saved';
const exportFailureMessages = <String>[
  "Couldn't save the image",
  'Export failed - try again',
];

/// Usage: I save the export to the device
///
/// Taps "Save to device" and watches for the outcome, rather than tapping and
/// settling - see [pumpUntilAnyText].
Future<void> iSaveTheExportToTheDevice(WidgetTester tester) async {
  lastExportOutcome = null;
  final button = find.text('Save to device');
  await revealFinder(tester, button);
  await scrollIntoView(tester, button);
  await tester.tap(button.first);
  lastExportOutcome = await pumpUntilAnyText(tester, [
    _savedPrefix,
    ...exportFailureMessages,
  ]);
}
