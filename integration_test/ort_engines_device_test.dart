// MobileSAM and U²-Net on real hardware, with the session options the app
// ships (#64).
//
// Every ORT failure in the app degrades quietly: a SAM session that will not
// create reads as "object removal unavailable", a U²-Net one falls back to ML
// Kit, MI-GAN falls back to content-aware fill. So "the app did not crash"
// says nothing about whether ORT ran at all. This asserts that each model
// produced a result, through the app's own engines and session factories.
//
// It is also the first thing to run on a Snapdragon 8 Gen 5 / 8 Elite Gen 5
// phone (SME without SME2), the hardware #64 crashed on - there, a failure is
// the process dying rather than a red test. MI-GAN has its own file,
// inpaint_device_test.dart.
//
// Run it on an ARM phone, not only the emulator. An x86 emulator has no fp16
// arithmetic, so ORT takes a different path through an fp16 model there: 1.4.2
// passed this file on the emulator while MobileSAM would not even create a
// session on a Xiaomi 15 Ultra (see ort_session_options.dart).
//
// Run: flutter test integration_test/ort_engines_device_test.dart -d <deviceId>
import 'dart:io';

import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/engines/bundled/bundled_segmentation_engine.dart';
import 'package:chromis/features/segmentation/engines/object/mobile_sam_engine.dart';
import 'package:chromis/features/segmentation/segmentation_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _w = 800, _h = 600;
const _cx = 400, _cy = 300, _r = 120;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A striped scene with one flat orange disc in the middle: an unmistakable
  /// object for SAM's point prompt and an unmistakable subject for U²-Net.
  Future<String> writePhoto() async {
    final image = img.Image(width: _w, height: _h);
    for (var y = 0; y < _h; y++) {
      for (var x = 0; x < _w; x++) {
        final dx = x - _cx, dy = y - _cy;
        if (dx * dx + dy * dy <= _r * _r) {
          image.setPixelRgb(x, y, 245, 140, 30);
        } else {
          final band = ((x ~/ 19) + (y ~/ 23)) % 3;
          image.setPixelRgb(x, y, 40 + band * 8, 90 + band * 10, 120);
        }
      }
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ort_engines_probe.png');
    await file.writeAsBytes(img.encodePng(image));
    return file.path;
  }

  int at(AlphaMask mask, int x, int y) => mask.alpha[y * mask.width + x];

  double meanCorners(AlphaMask mask) =>
      [
        at(mask, 10, 10),
        at(mask, _w - 11, 10),
        at(mask, 10, _h - 11),
        at(mask, _w - 11, _h - 11),
      ].reduce((a, b) => a + b) /
      4;

  testWidgets('MobileSAM encoder and decoder run and find the object', (
    tester,
  ) async {
    AlphaMask? found;
    var ms = 0;
    await tester.runAsync(() async {
      final path = await writePhoto();
      // A fresh cache dir, so the encoder really runs instead of a cached
      // embedding from an earlier run being served.
      final cache = await Directory(
        '${(await getTemporaryDirectory()).path}/ort_probe_sam',
      ).create();
      final engine = MobileSamEngine(cacheDir: cache);
      try {
        final watch = Stopwatch()..start();
        found = await engine.segmentAt(path, [
          PromptPoint(Offset(_cx.toDouble(), _cy.toDouble())),
        ]);
        ms = watch.elapsedMilliseconds;
      } finally {
        await engine.dispose();
        await cache.delete(recursive: true);
      }
    });

    debugPrint('MobileSAM on-device: $ms ms, encoder + decoder');
    expect(found, isNotNull, reason: 'the decoder produced no mask');
    final mask = found!;
    expect((mask.width, mask.height), (_w, _h));
    expect(at(mask, _cx, _cy), 255, reason: 'the tapped point is the object');
    expect(meanCorners(mask), 0, reason: 'the background is not the object');

    final covered = mask.alpha.where((a) => a > 0).length;
    const disc = 3.14159 * _r * _r;
    debugPrint('MobileSAM on-device: mask covers $covered px, disc is $disc');
    expect(covered, inInclusiveRange(disc * 0.5, disc * 2));
  });

  testWidgets('U²-Net runs and lifts the subject off the background', (
    tester,
  ) async {
    late SegmentationResult result;
    var ms = 0;
    await tester.runAsync(() async {
      final path = await writePhoto();
      final watch = Stopwatch()..start();
      // Throws SegmentationException if the session will not create or run,
      // so a broken runtime fails here rather than falling back to ML Kit.
      result = await BundledSegmentationEngine().segment(
        SegmentationRequest(imagePath: path),
      );
      ms = watch.elapsedMilliseconds;
    });

    final mask = result.mask;
    final centre = at(mask, _cx, _cy);
    final corners = meanCorners(mask);
    debugPrint('U²-Net on-device: $ms ms, centre $centre, corners $corners');
    expect(result.engineId, 'bundled');
    expect((mask.width, mask.height), (_w, _h));
    expect(centre, greaterThan(corners + 100));
  });
}
