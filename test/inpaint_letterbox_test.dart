import 'dart:typed_data';

import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/engines/inpaint/inpaint_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the MI-GAN letterbox geometry: a non-square photo must map into the
/// square 512 field fit-contain (undistorted), and _postprocess crops the fill
/// back out of the SAME rect. A wrong box would misplace the synthesized fill.
void main() {
  test('square photo fills the whole 512 field (no padding)', () {
    final b = inpaintLetterbox(100, 100);
    expect(b.x, 0);
    expect(b.y, 0);
    expect(b.w, 512);
    expect(b.h, 512);
  });

  test('landscape 2:1 photo is letterboxed with top/bottom padding', () {
    final b = inpaintLetterbox(200, 100);
    expect(b.w, 512);
    expect(b.h, 256);
    expect(b.x, 0);
    expect(b.y, 128); // centered vertically
  });

  test('portrait 1:2 photo is letterboxed with left/right padding', () {
    final b = inpaintLetterbox(100, 200);
    expect(b.w, 256);
    expect(b.h, 512);
    expect(b.x, 128); // centered horizontally
    expect(b.y, 0);
  });

  test('box always fits the 512 field and preserves aspect', () {
    const cases = [
      [1920, 1080],
      [640, 480],
      [1000, 3000],
      [37, 512],
    ];
    for (final dims in cases) {
      final b = inpaintLetterbox(dims[0], dims[1]);
      expect(b.x + b.w, lessThanOrEqualTo(512), reason: '$dims width overflow');
      expect(
        b.y + b.h,
        lessThanOrEqualTo(512),
        reason: '$dims height overflow',
      );
      expect(b.w, greaterThan(0));
      expect(b.h, greaterThan(0));
      final srcAr = dims[0] / dims[1];
      final boxAr = b.w / b.h;
      expect(boxAr, closeTo(srcAr, 0.03), reason: '$dims aspect distorted');
    }
  });

  group('inpaintWindow', () {
    // The model input is a fixed 512 square, so what the window contains
    // decides how many pixels the OBJECT gets. Showing it the whole photo is
    // what made a person come back ~64 px wide and then get blown up.
    test('a small object gets a window close around it, not the photo', () {
      final win = inpaintWindow(2048, 1536, 800, 400, 256, 853);
      expect(win.w, lessThan(2048), reason: 'not the whole photo');
      expect(win.w, win.h, reason: 'square, so the 512 field is fully used');
      // Contains the object.
      expect(win.x, lessThanOrEqualTo(800));
      expect(win.y, lessThanOrEqualTo(400));
      expect(win.x + win.w, greaterThanOrEqualTo(1056));
      expect(win.y + win.h, greaterThanOrEqualTo(1253));
      // And meaningfully more of the object than the whole-photo path would.
      expect(256 * 512 / win.w, greaterThan(256 * 512 / 2048));
    });

    test('it stays inside the photo', () {
      for (final box in const [
        [0, 0, 40, 40],
        [2000, 1500, 40, 30],
        [10, 10, 2000, 1500],
      ]) {
        final win = inpaintWindow(2048, 1536, box[0], box[1], box[2], box[3]);
        expect(win.x, greaterThanOrEqualTo(0), reason: '$box');
        expect(win.y, greaterThanOrEqualTo(0), reason: '$box');
        expect(win.x + win.w, lessThanOrEqualTo(2048), reason: '$box');
        expect(win.y + win.h, lessThanOrEqualTo(1536), reason: '$box');
      }
    });

    test('an object bigger than the photo clamps to the photo', () {
      final win = inpaintWindow(800, 600, 0, 0, 800, 600);
      expect(win.w, lessThanOrEqualTo(800));
      expect(win.h, lessThanOrEqualTo(600));
    });
  });

  group('inpaintRegionBox', () {
    AlphaMask mask(int w, int h, int x0, int y0, int x1, int y1) {
      final a = Uint8List(w * h);
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          a[y * w + x] = 255;
        }
      }
      return AlphaMask(width: w, height: h, alpha: a);
    }

    test('nothing marked is null, not an empty box', () {
      expect(inpaintRegionBox(AlphaMask.empty(64, 64), 640, 640), isNull);
    });

    test('a mask at a different resolution maps into image pixels', () {
      // The mask comes off a segmentation engine's own grid, never the
      // photo's - getting this scaling wrong puts the window in the wrong place
      // and the fill lands somewhere else entirely.
      final box = inpaintRegionBox(mask(100, 100, 20, 30, 39, 59), 1000, 1000)!;
      expect(box.x, 200);
      expect(box.y, 300);
      expect(box.w, 200);
      expect(box.h, 300);
    });
  });
}
