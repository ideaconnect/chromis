import 'package:chromis/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app must be allowed to turn sideways.
///
/// This is a one-line setting with an outsized blast radius: while it was
/// locked to portraitUp the editor's whole landscape layout was dead code on a
/// real device, and nothing else in the suite noticed, because a widget test
/// resizes its own surface and never asks the platform.
void main() {
  test('landscape is a supported orientation', () {
    expect(supportedOrientations, contains(DeviceOrientation.landscapeLeft));
    expect(supportedOrientations, contains(DeviceOrientation.landscapeRight));
    expect(supportedOrientations, contains(DeviceOrientation.portraitUp));
  });

  test('upside-down portrait stays out', () {
    expect(
      supportedOrientations,
      isNot(contains(DeviceOrientation.portraitDown)),
      reason: 'the camera and picker hand-offs read badly upside down',
    );
  });

  testWidgets('the list is what actually reaches the platform', (tester) async {
    final sent = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          sent.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await SystemChrome.setPreferredOrientations(supportedOrientations);

    expect(sent, hasLength(1));
    expect(
      sent.single,
      containsAll(<String>[
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]),
    );
  });
}
