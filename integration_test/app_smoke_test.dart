// On-device smoke suite: boots the real app on the connected hardware and
// exercises the flows that unit tests can't - real plugin/ONNX/font/asset init
// for the device ABI, theme, routing, provider startup, and reaching the editor
// with a live canvas. A device-only failure (missing asset, plugin init crash,
// render error) surfaces here instead of in manual use.
//
// One file, multiple tests, so a single on-device build runs the whole suite.
// Run: flutter test integration_test/app_smoke_test.dart -d <deviceId>
import 'package:chromis/core/models/layer.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/main.dart' as app;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // pumpAndSettle hangs here: the splash spinner, onboarding dot animations,
  // and the Home banner-ad slot never reach a steady state. Pump fixed frames
  // instead so async startup (onboarding flag, fonts, ads/UMP, IAP) completes.
  Future<void> settle(
    WidgetTester tester, {
    int rounds = 8,
    Duration step = const Duration(milliseconds: 400),
  }) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(step);
    }
  }

  // Boot the real app and, if first-run onboarding is showing, tap through to
  // Home. Idempotent - after the seen-flag is recorded, boot lands on Home and
  // neither control is present.
  Future<void> bootToHome(WidgetTester tester) async {
    app.main();
    await tester.pump(); // first frame
    await settle(tester);
    final skip = find.text('Skip');
    final getStarted = find.text('Get started');
    if (tester.any(skip)) {
      await tester.tap(skip);
      await settle(tester);
    } else if (tester.any(getStarted)) {
      await tester.tap(getStarted);
      await settle(tester);
    }
  }

  testWidgets('boots and reaches Home without crashing', (tester) async {
    await bootToHome(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text('New project'),
      findsOneWidget,
      reason: 'Home should show the New project CTA after startup',
    );
  });

  testWidgets('New project opens the editor with a live blank canvas', (
    tester,
  ) async {
    await bootToHome(tester);

    // Choose the blank-canvas mode, then create at the default preset (valid →
    // Create is enabled immediately). This reaches the editor with a blank
    // canvas, so no system photo picker is involved.
    await tester.tap(find.text('New project'));
    await settle(tester);
    await tester.tap(find.text('Blank canvas'));
    await settle(tester);
    expect(
      find.text('Create'),
      findsOneWidget,
      reason: 'The size sheet should offer a Create action',
    );
    await tester.tap(find.text('Create'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(EditorScreen),
      findsOneWidget,
      reason: 'Creating a project should push the editor and render it',
    );
  });

  testWidgets('adding a comic bubble edits the live canvas on-device', (
    tester,
  ) async {
    await bootToHome(tester);
    await tester.tap(find.text('New project'));
    await settle(tester);
    await tester.tap(find.text('Blank canvas'));
    await settle(tester);
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.byType(EditorScreen), findsOneWidget);

    // Read the real editor state so the assertion doesn't rely on rendered
    // text (a fresh bubble has an empty caption).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditorScreen)),
      listen: false,
    );
    final before = container.read(editorControllerProvider).layers.length;

    // Dock action: Bubble asks which format first, so the sheet's own tiles
    // are what actually create the layer. ensureVisible guards against the
    // horizontally-scrollable dock.
    final bubble = find.byKey(const ValueKey('dock-Bubble'));
    await tester.ensureVisible(bubble);
    await tester.tap(bubble);
    await settle(tester);

    // Every format is drawn by the real painter here, so this also proves the
    // shape paths render on-device before anything is committed to the canvas.
    expect(tester.takeException(), isNull);
    final format = find.byKey(const ValueKey('bubble-format-shout'));
    expect(
      format,
      findsOneWidget,
      reason: 'Bubble should open the format picker',
    );
    await tester.tap(format);
    await settle(tester);

    expect(tester.takeException(), isNull); // bubble painter renders on-device
    final layers = container.read(editorControllerProvider).layers;
    expect(
      layers.length,
      before + 1,
      reason: 'Picking a format should add exactly one layer',
    );
    final added = layers.whereType<BubbleLayer>();
    expect(
      added,
      isNotEmpty,
      reason: 'The added layer should be a comic bubble',
    );
    expect(
      added.single.shape,
      BubbleShape.shout,
      reason:
          'The layer should take the format that was picked, not the default',
    );
  });
}
