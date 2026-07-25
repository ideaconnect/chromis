import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resizes the test screen to [size] logical pixels for the rest of the test.
///
/// Use this rather than `tester.binding.setSurfaceSize`. That one only changes
/// the RenderView's configuration, so a widget laid out by constraints sees the
/// new size but `MediaQuery` does not - it reads `FlutterView.physicalSize`,
/// which stays at the 800x600 default. Anything keyed off MediaQuery (the
/// tablet gate, `SheetBody`'s height cap, view insets) is then silently tested
/// at the wrong size, and the test passes for the wrong reason.
///
/// Setting the view directly moves both, so constraints and MediaQuery agree -
/// which is the only arrangement that matches a real device.
void setSurface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
