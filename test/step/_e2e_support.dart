import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chromis/core/models/layer.dart';
import 'package:chromis/features/editor/services/image_import.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_state.dart';
import 'package:chromis/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';

/// Shared helpers for the BDD step definitions (not a step itself - the leading
/// underscore keeps it out of bdd_widget_test's way).

/// `pumpAndSettle` hangs on this app - the splash spinner, onboarding dots and
/// the Home banner-ad slot never reach a steady state. Pump fixed frames so
/// async startup (onboarding flag, fonts, ads/UMP, IAP) completes instead.
Future<void> settle(
  WidgetTester tester, {
  int rounds = 8,
  Duration step = const Duration(milliseconds: 400),
}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(step);
  }
}

// ---------------------------------------------------------------------------
// Launch variants. Each writes the desired settings.json BEFORE app.main() so
// scenarios are isolated from one another (settings.json persists on-device).
// ---------------------------------------------------------------------------

Future<void> _writeSettings({
  required bool onboarded,
  required bool pro,
}) async {
  final base = await getApplicationDocumentsDirectory();
  await File('${base.path}/settings.json').writeAsString(
    jsonEncode({'onboardingSeen': onboarded, 'proEntitled': pro}),
  );
}

Future<void> _boot(WidgetTester tester) async {
  // A previous scenario may have left the surface rotated; every launch starts
  // from the device's real geometry. Only when it was actually overridden,
  // though: calling setSurfaceSize at all perturbs the view metrics enough to
  // change the layout (it cost the onboarding page 40px of height), and a
  // feature that never rotates must be unaffected by this file.
  if (_surfaceOverridden) {
    await tester.binding.setSurfaceSize(null);
    _surfaceOverridden = false;
  }
  _rotationBase = null;
  app.main();
  await tester.pump(); // first frame
  await settle(tester);
}

// ---------------------------------------------------------------------------
// Orientation. The surface is resized rather than the device's real sensor
// orientation driven: asking the OS to rotate mid-test is racy and tells us
// nothing about the layout that the constraints do not.
// ---------------------------------------------------------------------------

/// The device's unrotated logical size, captured on the first rotation so
/// going back to portrait restores exactly what launch had.
Size? _rotationBase;

/// Whether this scenario resized the surface, so the next launch knows whether
/// it has anything to restore.
bool _surfaceOverridden = false;

Future<void> rotateSurface(
  WidgetTester tester, {
  required bool landscape,
}) async {
  final view = tester.view;
  _rotationBase ??= view.physicalSize / view.devicePixelRatio;
  final base = _rotationBase!;
  final short = math.min(base.width, base.height);
  final long = math.max(base.width, base.height);
  await tester.binding.setSurfaceSize(
    landscape ? Size(long, short) : Size(short, long),
  );
  _surfaceOverridden = true;
  await settle(tester);
}

/// A dock button's rect, found by the stable key rather than its label - the
/// dock's wording repeats the panel titles, so a text finder is ambiguous.
Rect dockButtonRect(WidgetTester tester, String label) {
  final finder = find.byKey(ValueKey('dock-$label'));
  expect(finder, findsOneWidget, reason: 'no dock button labelled $label');
  return tester.getRect(finder);
}

/// Boot to Home as a free (non-Pro) user with onboarding already seen. Keeps
/// the historical "tap Skip if shown" fallback as a harmless safety net.
Future<void> bootToHome(WidgetTester tester) async {
  await _writeSettings(onboarded: true, pro: false);
  await _boot(tester);
  final skip = find.text('Skip');
  if (tester.any(skip)) {
    await tester.tap(skip);
    await settle(tester);
  }
}

/// Boot as a Pro user (onboarding seen). Pro opens the AI rewarded-gate for
/// free (no ad dialog) and hides the ads/upsell.
Future<void> bootAsPro(WidgetTester tester) async {
  await _writeSettings(onboarded: true, pro: true);
  await _boot(tester);
}

/// Boot with a cleared first-run flag so onboarding is shown (page 1).
Future<void> bootFirstRun(WidgetTester tester) async {
  await _writeSettings(onboarded: false, pro: false);
  await _boot(tester);
}

// ---------------------------------------------------------------------------
// Provider + state access (works on any screen - reads the root container).
// ---------------------------------------------------------------------------

ProviderContainer containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp).first),
  listen: false,
);

EditorController editorController(WidgetTester tester) =>
    containerOf(tester).read(editorControllerProvider.notifier);

EditorState editorState(WidgetTester tester) =>
    containerOf(tester).read(editorControllerProvider);

Layer? selectedLayer(WidgetTester tester) => editorState(tester).selectedLayer;

ImageLayer selectedImage(WidgetTester tester) =>
    selectedLayer(tester) as ImageLayer;

TextLayer selectedText(WidgetTester tester) =>
    selectedLayer(tester) as TextLayer;

BubbleLayer selectedBubble(WidgetTester tester) =>
    selectedLayer(tester) as BubbleLayer;

// ---------------------------------------------------------------------------
// Headless photo seeding - no system picker. Copies a bundled asset to the
// app's project-assets dir (a real on-disk file) and adds it as an ImageLayer.
// Call AFTER the editor is on screen (a project must be loaded).
// ---------------------------------------------------------------------------

Future<void> seedPhoto(WidgetTester tester) async {
  final c = containerOf(tester);
  final data = await rootBundle.load('assets/branding/logo.png');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final path = await c.read(imageImportServiceProvider).storeBytes(bytes);
  c.read(editorControllerProvider.notifier).addImageLayer(assetPath: path);
  await settle(tester);
}

/// Tap a visible text label and let the UI settle. The primary interaction -
/// the app is built from custom widgets wrapping Text, so find.text is the
/// canonical finder.
Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await tester.ensureVisible(f); // scroll it into view if the panel scrolled
  await tester.tap(f);
  await settle(tester);
}
