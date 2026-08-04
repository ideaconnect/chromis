import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromis/core/models/layer.dart';
import 'package:chromis/core/models/project.dart';
import 'package:chromis/core/theme/app_theme.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/editor/widgets/crop_overlay.dart';
import 'package:chromis/features/editor/widgets/project_canvas.dart';
import 'package:chromis/features/go_pro/iap.dart';
import 'package:chromis/features/home/project_repository.dart';
import 'package:chromis/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface.dart';

/// The Adjust panel's "Crop photo" button, driven through the real screen.
///
/// This is the coverage whose absence let the button ship dead: `editor_crop.
/// feature` asserts the crop STATE by calling `setImageCrop` on the controller
/// directly, so nothing ever pressed the button, decoded a real file, or opened
/// the overlay - and the decode inside it could never succeed.
///
/// Everything behind the tap is real dart:io and real engine work, which
/// completes on the real event loop that `testWidgets`' fake-async zone never
/// turns. Hence [pumpReal]: without interleaving [WidgetTester.runAsync] the
/// handler parks on its first await and the test passes by doing nothing.
void main() {
  late Directory tmp;
  late String smallPng; // 640x480   - decoded whole
  late String bigPng; //   2000x1500 - takes the downscale branch
  late String tinyPng; //  8x8       - smaller than the minimum crop

  Future<String> writePng(String name, int w, int h) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF3366AA),
    );
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      w / 4,
      Paint()..color = const Color(0xFFFFCC00),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(
      data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = await Directory.systemTemp.createTemp('chromis_crop_btn');
    smallPng = await writePng('small.png', 640, 480);
    bigPng = await writePng('big.png', 2000, 1500);
    // Every fixture is written HERE, not inside a test: `Picture.toImage`
    // completes on the real event loop, which the fake-async zone a
    // `testWidgets` body runs in never turns - awaiting it there hangs.
    tinyPng = await writePng('tiny.png', 8, 8);
  });

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() => ProjectCanvas.existsCache.clear());
  tearDown(() => ProjectCanvas.fileExists = ProjectCanvas.defaultFileExists);

  /// Pumps [rounds] frames with real async work allowed through between them,
  /// and returns every exception the framework raised.
  Future<List<Object>> pumpReal(WidgetTester tester, {int rounds = 10}) async {
    final errors = <Object>[];
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final Object? e = tester.takeException();
      if (e != null) errors.add(e);
    }
    return errors;
  }

  Future<ProviderContainer> pumpEditor(
    WidgetTester tester,
    String assetPath, {
    Size surface = const Size(412, 915),
    Rect crop = const Rect.fromLTRB(0, 0, 1, 1),
    double textScale = 1.0,
  }) async {
    setSurface(tester, surface);
    final container = ProviderContainer(
      overrides: [
        isProProvider.overrideWithValue(true),
        // A crop is an edit, so the editor's debounced auto-save fires during
        // these pumps; the real repository would go looking for a platform
        // documents directory that a widget test does not have.
        projectRepositoryProvider.overrideWithValue(_RecordingRepo()),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadProject(Project.empty(id: 'p'));
    final layer = controller.addImageLayer(assetPath: assetPath, name: 'Photo');
    if (crop != const Rect.fromLTRB(0, 0, 1, 1)) {
      controller.setImageCrop(layer.id, crop);
    }
    controller.setTool(EditorTool.adjust);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: darkAppTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: surface,
              textScaler: TextScaler.linear(textScale),
            ),
            child: const EditorScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return container;
  }

  ImageLayer selected(ProviderContainer c) =>
      c.read(editorControllerProvider).selectedLayer! as ImageLayer;

  /// The overlay's preview rect - the crop handles sit on its corners.
  Rect previewRect(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(Scaffold).last,
      matching: find.byType(RawImage),
    ),
  );

  for (final big in [false, true]) {
    testWidgets(
      'Crop photo opens the crop editor (${big ? '2000x1500' : '640x480'})',
      (tester) async {
        await pumpEditor(tester, big ? bigPng : smallPng);
        await tester.tap(find.text('Crop photo'));
        final errors = await pumpReal(tester);

        expect(errors, isEmpty);
        expect(
          find.textContaining("Couldn't open the photo to crop"),
          findsNothing,
          reason: 'a readable photo must not report a failure',
        );
        expect(
          find.text('Done'),
          findsOneWidget,
          reason: 'the overlay is open',
        );
        // The px readout is in SOURCE pixels even though the preview is capped at
        // 1080 - the crop it returns is normalized against the source.
        expect(
          find.text(big ? '2000 × 1500 px' : '640 × 480 px'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('dragging a corner handle and confirming crops the layer', (
    tester,
  ) async {
    final container = await pumpEditor(tester, bigPng);
    expect(selected(container).isCropped, isFalse);

    await tester.tap(find.text('Crop photo'));
    expect(await pumpReal(tester), isEmpty);

    // Pull the bottom-right corner in by a quarter of the preview. Grabbed a
    // few px INSIDE the corner, the way a finger does - dead centre on the
    // corner is the one spot that also escapes the body pan detector, so a
    // centred drag would pass even with the handles losing the gesture arena.
    final preview = previewRect(tester);
    final handle = tester.getRect(find.byKey(cropHandleKeys.bottomRight));
    await tester.dragFrom(
      handle.center - const Offset(5, 5),
      Offset(-preview.width / 4, -preview.height / 4),
    );
    await tester.pump();
    // The readout is live proof the box moved, in source px.
    expect(find.text('1500 × 1125 px'), findsOneWidget);

    await tester.tap(find.text('Done'));
    expect(await pumpReal(tester), isEmpty);

    final layer = selected(container);
    expect(layer.isCropped, isTrue, reason: 'the drag must reach the model');
    expect(layer.cropRect.left, 0);
    expect(layer.cropRect.top, 0);
    expect(layer.cropRect.right, closeTo(0.75, 0.01));
    expect(layer.cropRect.bottom, closeTo(0.75, 0.01));
    expect(find.text('Photo cropped'), findsOneWidget);
  });

  testWidgets('dragging the crop body moves it without resizing', (
    tester,
  ) async {
    final container = await pumpEditor(
      tester,
      bigPng,
      crop: const Rect.fromLTRB(0, 0, 0.5, 0.5),
    );
    await tester.tap(find.text('Edit crop'));
    expect(await pumpReal(tester), isEmpty);

    final preview = previewRect(tester);
    await tester.dragFrom(
      preview.topLeft + Offset(preview.width / 4, preview.height / 4),
      Offset(preview.width / 4, preview.height / 4),
    );
    await tester.pump();
    await tester.tap(find.text('Done'));
    expect(await pumpReal(tester), isEmpty);

    final crop = selected(container).cropRect;
    expect(crop.width, closeTo(0.5, 0.01), reason: 'a move must not resize');
    expect(crop.height, closeTo(0.5, 0.01));
    expect(crop.left, closeTo(0.25, 0.01));
    expect(crop.top, closeTo(0.25, 0.01));
  });

  testWidgets('Edit crop reopens on the existing crop and preserves it', (
    tester,
  ) async {
    const seeded = Rect.fromLTRB(0.25, 0.1, 0.75, 0.9);
    final container = await pumpEditor(tester, smallPng, crop: seeded);

    await tester.tap(find.text('Edit crop'));
    expect(await pumpReal(tester), isEmpty);
    // Seeded from the layer, not reset to the full frame: 50% of 640 wide.
    expect(find.text('320 × 384 px'), findsOneWidget);

    await tester.tap(find.text('Done'));
    expect(await pumpReal(tester), isEmpty);
    expect(selected(container).cropRect, seeded);
  });

  testWidgets('cancelling the overlay leaves the crop alone', (tester) async {
    final container = await pumpEditor(tester, smallPng);
    await tester.tap(find.text('Crop photo'));
    expect(await pumpReal(tester), isEmpty);
    await tester.tap(find.byTooltip('Cancel crop'));
    expect(await pumpReal(tester), isEmpty);
    expect(selected(container).isCropped, isFalse);
  });

  testWidgets('an unreadable source reports instead of crashing', (
    tester,
  ) async {
    ProjectCanvas.fileExists = (_) => false;
    await pumpEditor(tester, '${tmp.path}/does_not_exist.png');
    await tester.tap(find.text('Crop photo'));
    final errors = await pumpReal(tester);
    expect(errors, isEmpty);
    expect(
      find.textContaining("Couldn't open the photo to crop"),
      findsOneWidget,
      reason: 'an unreadable file is the case the toast is FOR',
    );
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('Crop photo works in landscape', (tester) async {
    await pumpEditor(tester, smallPng, surface: const Size(900, 412));
    await tester.tap(find.text('Crop photo'));
    final errors = await pumpReal(tester);
    expect(errors, isEmpty);
    expect(find.text('Done'), findsOneWidget);
  });

  // The two-button state: 'Edit crop' + 'Reset crop' share one Row, which has
  // overflowed here before.
  for (final surface in const [Size(412, 915), Size(900, 412)]) {
    testWidgets('the cropped Adjust panel lays out at $surface', (
      tester,
    ) async {
      final container = await pumpEditor(
        tester,
        smallPng,
        surface: surface,
        crop: const Rect.fromLTRB(0.5, 0, 1, 1),
      );
      expect(await pumpReal(tester), isEmpty);
      expect(find.text('Edit crop'), findsOneWidget);
      expect(find.text('Reset crop'), findsOneWidget);

      await tester.tap(find.text('Reset crop'));
      await tester.pump();
      expect(selected(container).isCropped, isFalse);
      expect(find.text('Crop photo'), findsOneWidget);
    });
  }

  testWidgets('a source under the 16 px minimum crop still drags', (
    tester,
  ) async {
    // `_minW` is 16/srcWidth, so an 8 px source makes the minimum crop wider
    // than the whole image and inverts the clamp range in _resize - which
    // throws ArgumentError rather than simply refusing to shrink.
    await pumpEditor(tester, tinyPng);
    await tester.tap(find.text('Crop photo'));
    expect(await pumpReal(tester), isEmpty);

    final handle = tester.getRect(find.byKey(cropHandleKeys.bottomRight));
    await tester.dragFrom(
      handle.center - const Offset(5, 5),
      const Offset(-40, -40),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // And the other three corners, which take the opposite clamp branches.
    for (final key in [
      cropHandleKeys.topLeft,
      cropHandleKeys.topRight,
      cropHandleKeys.bottomLeft,
    ]) {
      final rect = tester.getRect(find.byKey(key));
      await tester.dragFrom(rect.center, const Offset(12, 12));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$key');
    }
  });

  // Large system font + the narrow landscape rail is where this Row has least
  // room, and 'Reset crop' only exists in the cropped state - so the widest
  // arrangement of it is also the least-visited one.
  testWidgets('the cropped Adjust panel survives a large text scale', (
    tester,
  ) async {
    const surface = Size(900, 412);
    await pumpEditor(
      tester,
      smallPng,
      surface: surface,
      crop: const Rect.fromLTRB(0.5, 0, 1, 1),
      textScale: 1.8,
    );
    // Geometry, not `takeException`: at 1.8x the shared LabeledSlider below
    // these buttons overflows too - a pre-existing fault of its own, in a
    // widget every panel uses, so it is not this test's subject. Drain it and
    // assert on where the two buttons actually landed instead.
    while (tester.takeException() != null) {}
    final edit = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Edit crop'),
    );
    final reset = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Reset crop'),
    );
    expect(edit.left, greaterThanOrEqualTo(0));
    expect(reset.right, lessThanOrEqualTo(surface.width));
    expect(
      reset.top,
      greaterThanOrEqualTo(edit.bottom),
      reason: 'the two buttons must not be laid on top of each other',
    );
    // They are STACKED now, not side by side. Sharing a row left Reset crop a
    // third of the panel less 48dp of M3 button padding - about 72dp of text,
    // which fits English "Reset crop" and no translation of it: German showed
    // "Zuschnitt …" beside a full "Zuschnitt bearbeiten". Full width is what
    // makes the label readable in every language, so pin that rather than the
    // old horizontal order.
    expect(
      reset.width,
      closeTo(edit.width, 1),
      reason:
          'Reset crop must get the same full panel width as Edit crop, not a '
          'third of it - measuring against the panel, which is the landscape '
          'rail here, not against the surface',
    );
  });
}

/// Captures saves instead of touching the filesystem.
class _RecordingRepo implements ProjectRepository {
  final List<Project> saved = [];

  @override
  Future<void> save(Project project) async => saved.add(project);

  @override
  Future<List<Project>> list() async => saved;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
