import 'dart:io';
import 'dart:ui' as ui;

import 'package:chromis/core/rendering/image_decode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [decodeImageFile] is the single place every photo in the app is decoded, and
/// the reason it exists is the dispose ORDER inside it. Releasing the
/// `ImageDescriptor` before `Codec.getNextFrame()` leaves the decoder with no
/// bytes: Skia answers "Codec failed to produce an image", Impeller - what an
/// Android build actually runs - has no such guard. Three hand-copied decoders
/// meant one of them could get it wrong, and one did, which is what broke the
/// Adjust panel's Crop button.
///
/// Real files and the real engine decoder throughout: a fake would test
/// nothing, since the bug lives entirely in dart:ui's lifetime rules.
void main() {
  late Directory tmp;

  /// Writes a real encoded PNG of [w]x[h] and returns its path.
  Future<String> writePng(String name, int w, int h) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..color = const Color(0xFF3366AA),
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
    tmp = await Directory.systemTemp.createTemp('chromis_decode');
  });

  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    'decodes a file and reports the SOURCE size, not the decoded one',
    () async {
      final path = await writePng('big.png', 2000, 1500);
      final decoded = await decodeImageFile(path, maxWidth: 1080);
      expect(decoded, isNotNull);
      expect(decoded!.image.width, 1080);
      expect(decoded.image.height, 810);
      // The crop overlay's px readout and minimum-crop size are in source pixels,
      // so a downscaled preview must still know what it came from.
      expect(decoded.sourceWidth, 2000);
      expect(decoded.sourceHeight, 1500);
      decoded.image.dispose();
    },
  );

  test('never upscales past the source', () async {
    final path = await writePng('small.png', 640, 480);
    final decoded = await decodeImageFile(path, maxWidth: 4096);
    expect(decoded!.image.width, 640);
    expect(decoded.image.height, 480);
    decoded.image.dispose();
  });

  test('a height cap scales by height, keeping the aspect ratio', () async {
    // A stitched screenshot: narrow enough to pass any width cap, tall enough
    // to be tens of MB of bitmap if decoded whole.
    final path = await writePng('tall.png', 600, 4000);
    final decoded = await decodeImageFile(
      path,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    expect(decoded, isNotNull);
    expect(decoded!.image.height, lessThanOrEqualTo(1080));
    // Aspect preserved: passing both dimensions to the codec would stretch it.
    expect(
      decoded.image.width / decoded.image.height,
      closeTo(600 / 4000, 0.01),
    );
    expect(decoded.sourceHeight, 4000);
    decoded.image.dispose();
  });

  test('no cap decodes at full size', () async {
    final path = await writePng('plain.png', 300, 200);
    final decoded = await decodeImageFile(path);
    expect(decoded!.image.width, 300);
    decoded.image.dispose();
  });

  test('a missing file is null, not a throw', () async {
    expect(await decodeImageFile('${tmp.path}/nope.png'), isNull);
  });

  test('bytes that are not an image are null, not a throw', () async {
    final file = File('${tmp.path}/junk.png');
    await file.writeAsString('this is not a PNG');
    expect(await decodeImageFile(file.path), isNull);
  });

  test(
    'REGRESSION: disposing the descriptor before getNextFrame breaks the decode',
    () async {
      // The exact sequence that shipped in `_cropSelectedImage`, so the reason
      // decodeImageFile orders its teardown the way it does is on the record
      // rather than in a comment alone. If a future engine makes this legal the
      // test fails loudly and the guard can be reconsidered - it must never be
      // quietly reintroduced on the strength of "it looks equivalent".
      final path = await writePng('order.png', 2000, 1500);
      final bytes = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final codec = await descriptor.instantiateCodec(targetWidth: 1080);
      descriptor.dispose(); // too early - the codec copied nothing
      buffer.dispose();
      await expectLater(
        codec.getNextFrame(),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('Codec failed to produce an image'),
          ),
        ),
      );
      codec.dispose();

      // Same bytes through the shared decoder: fine.
      final ok = await decodeImageFile(path, maxWidth: 1080);
      expect(ok, isNotNull);
      ok!.image.dispose();
    },
  );
}
