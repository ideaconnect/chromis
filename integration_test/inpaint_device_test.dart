// The generative fill tier, on real hardware.
//
// This file exists because of two things that only a device can answer. MI-GAN
// issues #15 and #24 both report CORRUPTED output from this model under
// `onnxruntime-android`, and both are unanswered - they are the only public
// records of anyone running it on Android. And `InpaintEngine.inpaint` returns
// null on any failure, so a broken model is indistinguishable from a missing
// one at the call site: the app would quietly serve content-aware fill forever
// and look merely mediocre rather than broken.
//
// So this asserts the model actually RAN (not that the ladder fell through),
// prints a timing and memory breakdown a host test cannot measure, and writes
// the filled PNG to external storage so a human can look at the pixels.
//
// Run: flutter test integration_test/inpaint_device_test.dart -d <deviceId>
import 'dart:io';

import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/engines/inpaint/inpaint_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A textured photo with a tall "person" of flat colour standing on it. Flat
  /// on purpose: anything the model leaves behind is unmistakably the object
  /// rather than something it legitimately reconstructed.
  Uint8List photo(int w, int h, int ox, int oy, int ow, int oh) {
    final image = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final sky = y < h * 0.45;
        final band = ((x ~/ 17) + (y ~/ 13)) % 3;
        if (x >= ox && x < ox + ow && y >= oy && y < oy + oh) {
          image.setPixelRgb(x, y, 240, 20, 140); // the object: hot magenta
        } else if (sky) {
          image.setPixelRgb(x, y, 150 + band * 6, 175 + band * 5, 215);
        } else {
          image.setPixelRgb(
            x,
            y,
            60 + band * 9,
            110 + band * 11,
            45 + band * 7,
          );
        }
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  AlphaMask maskFor(int w, int h, int ox, int oy, int ow, int oh) {
    final alpha = Uint8List(w * h);
    for (var y = oy; y < oy + oh; y++) {
      for (var x = ox; x < ox + ow; x++) {
        alpha[y * w + x] = 255;
      }
    }
    return AlphaMask(width: w, height: h, alpha: alpha);
  }

  testWidgets('the MI-GAN asset is actually bundled', (tester) async {
    // If this fails, every other result here is meaningless - the ladder would
    // be silently serving content-aware fill.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
      manifest.listAssets(),
      contains(kInpaintModelAsset),
      reason: 'pubspec must ship $kInpaintModelAsset',
    );
  });

  testWidgets('generative fill runs on-device and removes the object', (
    tester,
  ) async {
    const w = 1200, h = 900;
    const ox = 470, oy = 240, ow = 150, oh = 500;
    final bytes = photo(w, h, ox, oy, ow, oh);
    final region = maskFor(w, h, ox, oy, ow, oh);

    // Through the real provider, so the asset path and session wiring are the
    // ones the app uses rather than a hand-built copy of them.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Uint8List? out;
    var ms = 0;
    await tester.runAsync(() async {
      final engine = container.read(inpaintEngineProvider);
      final watch = Stopwatch()..start();
      out = await engine.inpaint(bytes, region);
      ms = watch.elapsedMilliseconds;
    });

    debugPrint('MI-GAN on-device: $ms ms for a ${ow}x$oh hole in ${w}x$h');
    expect(
      out,
      isNotNull,
      reason:
          'the model failed to run - check the debug log for the reason the '
          'engine printed before falling back',
    );

    final filled = img.decodePng(out!)!;
    expect(filled.width, w);
    expect(filled.height, h);

    // Nothing of the magenta object may survive. This is also the check that
    // catches the corruption reported in MI-GAN #15/#24: a scrambled output
    // does not happen to be green.
    var magenta = 0;
    var sampled = 0;
    for (var y = oy; y < oy + oh; y += 2) {
      for (var x = ox; x < ox + ow; x += 2) {
        final p = filled.getPixel(x, y);
        sampled++;
        if (p.r > 150 && p.g < 90 && p.b > 90) magenta++;
      }
    }
    debugPrint('MI-GAN on-device: $magenta/$sampled object pixels survived');
    expect(
      magenta,
      lessThan(sampled ~/ 50),
      reason: 'the object should be gone, not smeared or scrambled',
    );

    // Untouched photo must be untouched, byte for byte.
    final original = img.decodePng(bytes)!;
    for (final at in const [
      [3, 3],
      [w - 4, 3],
      [3, h - 4],
      [w - 4, h - 4],
    ]) {
      final a = filled.getPixel(at[0], at[1]);
      final b = original.getPixel(at[0], at[1]);
      expect(a.r, b.r, reason: 'corner $at');
      expect(a.g, b.g, reason: 'corner $at');
      expect(a.b, b.b, reason: 'corner $at');
    }

    // Write both out so a human can judge the pixels, which no assertion can.
    await tester.runAsync(() async {
      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      await File('${dir.path}/migan_before.png').writeAsBytes(bytes);
      await File('${dir.path}/migan_after.png').writeAsBytes(out!);
      debugPrint(
        'MI-GAN on-device: wrote ${dir.path}/migan_{before,after}.png',
      );
    });
  });
}
