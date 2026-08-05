// On-device content-aware fill: the half of the feature a widget test cannot
// reach. The engine decodes and re-encodes with the device ABI's codecs, does
// its work in a real `Isolate.run`, and has to finish inside the patience of
// somebody watching a "Filling in the background…" overlay - none of which a
// host-side test measures. It also drives the real cut-out panel on device, so
// the Fill/Erase chooser is proven to build on hardware and not just in a pump.
//
// One file, multiple tests, so a single on-device build runs the whole suite.
// Run: flutter test integration_test/content_fill_device_test.dart -d <deviceId>
import 'dart:io';

import 'package:chromis/core/models/layer.dart';
import 'package:chromis/features/editor/editor_screen.dart';
import 'package:chromis/features/editor/state/editor_controller.dart';
import 'package:chromis/features/editor/state/editor_tool.dart';
import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/engines/inpaint/content_fill_engine.dart';
import 'package:chromis/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A photo at the size the app actually holds: ImageImportService caps imports
  // at 2048 on the long edge, so 1600x1200 is a realistic worst case rather
  // than a toy. Textured, because a fill into flat colour proves nothing.
  Uint8List photo(int width, int height, int ox, int oy, int size) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (x >= ox && x < ox + size && y >= oy && y < oy + size) {
          image.setPixelRgb(x, y, 235, 30, 30); // the object
        } else {
          final light = ((x ~/ 24) + (y ~/ 24)).isEven;
          image.setPixelRgb(x, y, light ? 40 : 54, light ? 118 : 140, 60);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  AlphaMask objectMask(
    int width,
    int height,
    int ox,
    int oy,
    int size, {
    int divisor = 2,
  }) {
    // Deliberately coarser than the photo: a segmentation engine hands back a
    // mask on its own grid, never the photo's.
    final w = width ~/ divisor;
    final h = height ~/ divisor;
    final alpha = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final ix = x * divisor;
        final iy = y * divisor;
        if (ix >= ox && ix < ox + size && iy >= oy && iy < oy + size) {
          alpha[y * w + x] = 255;
        }
      }
    }
    return AlphaMask(width: w, height: h, alpha: alpha);
  }

  // pumpAndSettle hangs in this app (splash spinner, onboarding dots, the Home
  // banner-ad slot never reach a steady state), so pump fixed frames instead -
  // same helper app_smoke_test.dart uses, and the reason a shorter wait here
  // missed the size sheet's Create button entirely.
  Future<void> settle(
    WidgetTester tester, {
    int rounds = 8,
    Duration step = const Duration(milliseconds: 400),
  }) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(step);
    }
  }

  /// Runs a fill on the real event loop and reports how long it took.
  Future<({Uint8List? out, int ms})> timedFill(
    WidgetTester tester,
    Uint8List bytes,
    AlphaMask mask,
  ) async {
    Uint8List? out;
    var ms = 0;
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      out = await const ContentFillEngine().fill(bytes, mask);
      ms = watch.elapsedMilliseconds;
    });
    return (out: out, ms: ms);
  }

  void expectObjectGone(
    Uint8List filled,
    int ox,
    int oy,
    int size,
    Uint8List original,
    int width,
    int height,
  ) {
    final after = img.decodePng(filled)!;
    expect(after.width, width, reason: 'the photo keeps its size');
    expect(after.height, height);
    var red = 0;
    for (var y = oy; y < oy + size; y++) {
      for (var x = ox; x < ox + size; x++) {
        final p = after.getPixel(x, y);
        if (p.r > p.g && p.r > p.b) red++;
      }
    }
    expect(red, 0, reason: 'no pixel of the object may survive the fill');

    final before = img.decodePng(original)!;
    for (final at in [
      [2, 2],
      [width - 3, 2],
      [2, height - 3],
      [width - 3, height - 3],
    ]) {
      final a = after.getPixel(at[0], at[1]);
      final b = before.getPixel(at[0], at[1]);
      expect(a.r, b.r, reason: 'corner $at must be untouched');
      expect(a.g, b.g, reason: 'corner $at must be untouched');
      expect(a.b, b.b, reason: 'corner $at must be untouched');
    }
  }

  testWidgets('fills a small object in a 1600x1200 photo, at native res', (
    tester,
  ) async {
    const w = 1600, h = 1200, ox = 700, oy = 500, size = 90;
    final bytes = photo(w, h, ox, oy, size);
    final result = await timedFill(
      tester,
      bytes,
      objectMask(w, h, ox, oy, size),
    );
    debugPrint('CONTENT FILL: small object (${size}px) took ${result.ms} ms');

    expect(result.out, isNotNull, reason: 'a small object is fillable');
    expectObjectGone(result.out!, ox, oy, size, bytes, w, h);
    // The window here is ~250px, under the 512 cap, so no downscale is paid.
    // Generous: this is a gate against a pathological regression, not a
    // benchmark - emulators are slower than the phones this ships to.
    expect(
      result.ms,
      lessThan(20000),
      reason: 'a small fill must not take the user hostage',
    );
  });

  testWidgets('fills a large object, taking the downscale path', (
    tester,
  ) async {
    // A 400px object makes a 1000px window, past the 512 working cap, so this
    // is the branch that downscales, fills and lifts the result back up.
    const w = 1600, h = 1200, ox = 600, oy = 400, size = 400;
    final bytes = photo(w, h, ox, oy, size);
    final result = await timedFill(
      tester,
      bytes,
      objectMask(w, h, ox, oy, size),
    );
    debugPrint('CONTENT FILL: large object (${size}px) took ${result.ms} ms');

    expect(result.out, isNotNull);
    expectObjectGone(result.out!, ox, oy, size, bytes, w, h);
    expect(
      result.ms,
      lessThan(45000),
      reason: 'the worst case still has to finish',
    );
  });

  testWidgets('reports where the fill spends its time', (tester) async {
    // Not an assertion so much as a measurement that has to live somewhere a
    // device can take it. The first run of this file showed a 90 px object
    // costing almost as much as a 400 px one, which cannot be the patch search
    // - that scales with the window - so the fixed cost had to be the codec.
    // Printing the split is what turns "the fill is slow" into a decision.
    const w = 1600, h = 1200;
    final bytes = photo(w, h, 700, 500, 90);
    var decodeMs = 0, encodeMs = 0;
    await tester.runAsync(() async {
      final watch = Stopwatch()..start();
      final decoded = img.decodePng(bytes)!;
      decodeMs = watch.elapsedMilliseconds;
      watch.reset();
      img.encodePng(decoded);
      encodeMs = watch.elapsedMilliseconds;
    });
    final total = await timedFill(
      tester,
      bytes,
      objectMask(w, h, 700, 500, 90),
    );
    debugPrint(
      'CONTENT FILL BREAKDOWN ${w}x$h: decode ${decodeMs}ms + '
      'encode ${encodeMs}ms of ${total.ms}ms total '
      '(fill work ${total.ms - decodeMs - encodeMs}ms)',
    );
    expect(total.out, isNotNull);
  });

  testWidgets('the cut-out panel offers Fill and Erase on device', (
    tester,
  ) async {
    // The chooser used to be built only when an optional MI-GAN asset was
    // bundled. On device is where "is the asset there?" is a real question, so
    // this is the run that proves the answer no longer matters.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/content_fill_probe.png');
    await tester.runAsync(
      () => file.writeAsBytes(photo(640, 480, 260, 180, 80), flush: true),
    );

    app.main();
    await tester.pump(); // first frame
    await settle(tester);
    for (final label in ['Skip', 'Get started']) {
      if (tester.any(find.text(label))) {
        await tester.tap(find.text(label));
        await settle(tester);
        break;
      }
    }
    await tester.tap(find.text('New project'));
    await settle(tester);
    await tester.tap(find.text('Blank canvas'));
    await settle(tester);
    expect(
      find.text('Create'),
      findsOneWidget,
      reason: 'the size sheet should offer a Create action',
    );
    await tester.tap(find.text('Create'));
    await settle(tester);
    expect(find.byType(EditorScreen), findsOneWidget);

    // The gallery picker is real OS UI, so seed the photo layer through the
    // controller instead - the panel only cares that an ImageLayer is selected.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditorScreen)),
      listen: false,
    );
    final controller = container.read(editorControllerProvider.notifier);
    controller.addImageLayer(assetPath: file.path, name: 'Photo');
    controller.setTool(EditorTool.cutout);
    await settle(tester);
    expect(
      container.read(editorControllerProvider).selectedLayer,
      isA<ImageLayer>(),
    );

    await tester.tap(find.text('Remove object'));
    await settle(tester, rounds: 3);

    expect(tester.takeException(), isNull);
    expect(find.text('Fill in'), findsOneWidget);
    expect(
      find.text('Fill rebuilds the background from the rest of the photo.'),
      findsOneWidget,
      reason: 'Fill is the default and it says so, with no model bundled',
    );
  });
}
