import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/engines/inpaint/content_fill_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// The image half of content-aware fill: which crop of the photo it runs on,
/// and whether the object is actually gone from the bytes that come back.
void main() {
  group('contentFillWindow', () {
    test('a small object in a big photo is filled at native resolution', () {
      // The whole point of windowing. MI-GAN squeezes the entire photo into
      // 512² and blows the result back up, so a 100 px object in a 2000 px
      // photo is synthesized ~25 px wide; here the window is 250 px and the
      // fill happens at the object's real size.
      final w = contentFillWindow(2000, 1500, 900, 700, 100, 80);
      expect(w.workW, w.w, reason: 'no downscale was needed');
      expect(w.workH, w.h);
      expect(w.x, lessThanOrEqualTo(900), reason: 'covers the object');
      expect(w.y, lessThanOrEqualTo(700));
      expect(w.x + w.w, greaterThanOrEqualTo(1000));
      expect(w.y + w.h, greaterThanOrEqualTo(780));
      expect(w.w, greaterThan(100), reason: 'and context around it to match');
    });

    test('the window is clamped to the photo', () {
      final w = contentFillWindow(400, 300, 0, 0, 50, 50);
      expect(w.x, 0);
      expect(w.y, 0);
      expect(w.x + w.w, lessThanOrEqualTo(400));
      expect(w.y + w.h, lessThanOrEqualTo(300));
    });

    test('a window too big to afford is downscaled, keeping its aspect', () {
      final w = contentFillWindow(2000, 1500, 200, 200, 800, 600);
      expect(w.w, greaterThan(512), reason: 'the native window is too big');
      expect(math.max(w.workW, w.workH), 512);
      expect(w.workW / w.workH, closeTo(w.w / w.h, 0.02));
    });

    test('the working size never exceeds the window', () {
      for (final box in const [
        [0, 0, 4, 4],
        [10, 10, 900, 20],
        [1990, 1490, 10, 10],
      ]) {
        final w = contentFillWindow(2000, 1500, box[0], box[1], box[2], box[3]);
        expect(w.workW, lessThanOrEqualTo(w.w), reason: '$box');
        expect(w.workH, lessThanOrEqualTo(w.h), reason: '$box');
        expect(w.workW, greaterThan(0), reason: '$box');
        expect(w.workH, greaterThan(0), reason: '$box');
      }
    });
  });

  group('ContentFillEngine', () {
    const width = 240, height = 180;
    // The object: a pure-red square on a green checkerboard, so "did it work?"
    // is a question about hue rather than about exact pixels.
    const ox = 90, oy = 60, os = 60;

    Uint8List photo() {
      final image = img.Image(width: width, height: height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final light = ((x ~/ 8) + (y ~/ 8)).isEven;
          final inObject = x >= ox && x < ox + os && y >= oy && y < oy + os;
          if (inObject) {
            image.setPixelRgb(x, y, 235, 30, 30);
          } else {
            image.setPixelRgb(x, y, light ? 40 : 52, light ? 120 : 142, 60);
          }
        }
      }
      return Uint8List.fromList(img.encodePng(image));
    }

    AlphaMask objectMask(int w, int h) {
      final alpha = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final ix = x * width ~/ w;
          final iy = y * height ~/ h;
          if (ix >= ox && ix < ox + os && iy >= oy && iy < oy + os) {
            alpha[y * w + x] = 255;
          }
        }
      }
      return AlphaMask(width: w, height: h, alpha: alpha);
    }

    /// Every pixel the object used to occupy, as (r, g, b).
    List<List<int>> objectPixels(img.Image image) => [
      for (var y = oy; y < oy + os; y++)
        for (var x = ox; x < ox + os; x++)
          [
            image.getPixel(x, y).r.toInt(),
            image.getPixel(x, y).g.toInt(),
            image.getPixel(x, y).b.toInt(),
          ],
    ];

    for (final scale in const [1, 2]) {
      test('the object is replaced by its surroundings (mask 1/$scale)', () {
        final bytes = photo();
        final mask = objectMask(width ~/ scale, height ~/ scale);

        // The mask is routinely a different resolution than the photo - it
        // comes from a segmentation engine's own grid - so the 1/2-scale case
        // is the realistic one, not the edge case.
        return const ContentFillEngine().fill(bytes, mask).then((out) {
          expect(out, isNotNull, reason: 'a small object is fillable');
          final filled = img.decodePng(out!)!;
          expect(filled.width, width);
          expect(filled.height, height);

          final reds = objectPixels(
            filled,
          ).where((p) => p[0] > p[1] && p[0] > p[2]).length;
          expect(
            reds,
            0,
            reason:
                'every pixel of the object should now read as background '
                'green, not red',
          );
          for (final p in objectPixels(filled)) {
            expect(p[1], greaterThan(80), reason: 'filled with the green');
            expect(p[1], lessThan(190));
          }

          // Untouched photo stays untouched, byte for byte - the fill window
          // is local and the composite is weighted, so nothing outside it may
          // be resampled.
          final original = img.decodePng(bytes)!;
          for (final at in const [
            [2, 2],
            [width - 3, 2],
            [2, height - 3],
            [width - 3, height - 3],
          ]) {
            final a = filled.getPixel(at[0], at[1]);
            final b = original.getPixel(at[0], at[1]);
            expect(a.r, b.r, reason: 'corner $at');
            expect(a.g, b.g, reason: 'corner $at');
            expect(a.b, b.b, reason: 'corner $at');
          }
        });
      });
    }

    test('an empty mask is not a fill', () async {
      final out = await const ContentFillEngine().fill(
        photo(),
        AlphaMask.empty(width, height),
      );
      expect(out, isNull, reason: 'nothing was marked');
    });

    test('a mask over the whole photo is refused, not smeared', () async {
      // No known texture left to rebuild from. Returning null is what makes
      // the editor fall back to erasing and say so, instead of writing a
      // uniform blur over the picture and calling it a fill.
      final out = await const ContentFillEngine().fill(
        photo(),
        AlphaMask.filled(width, height, 255),
      );
      expect(out, isNull);
    });
  });
}
