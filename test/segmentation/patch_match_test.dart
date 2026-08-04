import 'dart:typed_data';

import 'package:chromis/features/segmentation/engines/inpaint/patch_match.dart';
import 'package:flutter_test/flutter_test.dart';

/// The content-aware fill core. Every assertion here is about a property the
/// algorithm must have rather than about exact pixels: PatchMatch is stochastic
/// (seeded, so reproducible, but not analytically predictable), and pinning
/// bytes would break on any tuning change while catching nothing real.
///
/// The one that matters most is "known pixels are never written". The fill
/// composites back over the full-resolution photo, so a core that quietly
/// rewrote a pixel outside the hole would resample the whole window - visible
/// as a soft rectangle around every removed object, and invisible to a test
/// that only looked at the hole.
void main() {
  Uint8List solid(int w, int h, int r, int g, int b) {
    final out = Uint8List(w * h * 3);
    for (var i = 0; i < w * h; i++) {
      out[i * 3] = r;
      out[i * 3 + 1] = g;
      out[i * 3 + 2] = b;
    }
    return out;
  }

  Uint8List box(int w, int h, int x0, int y0, int x1, int y1) {
    final out = Uint8List(w * h);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        out[y * w + x] = 1;
      }
    }
    return out;
  }

  void expectKnownUntouched(Uint8List before, Uint8List after, Uint8List hole) {
    for (var p = 0; p < hole.length; p++) {
      if (hole[p] != 0) continue;
      for (var c = 0; c < 3; c++) {
        expect(
          after[p * 3 + c],
          before[p * 3 + c],
          reason: 'pixel $p channel $c is outside the hole and must not move',
        );
      }
    }
  }

  test('a hole in a uniform photo comes back the same colour', () {
    const w = 80, h = 64;
    final rgb = solid(w, h, 200, 120, 60);
    final hole = box(w, h, 30, 24, 46, 40);

    final out = contentAwareFill(rgb, hole, w, h);

    for (var p = 0; p < w * h; p++) {
      if (hole[p] == 0) continue;
      expect(out[p * 3], closeTo(200, 1));
      expect(out[p * 3 + 1], closeTo(120, 1));
      expect(out[p * 3 + 2], closeTo(60, 1));
    }
    expectKnownUntouched(rgb, out, hole);
  });

  test('the fill matches the region it sits in, not the whole photo', () {
    // Left half warm, right half cold, hole entirely in the left half. An
    // implementation that averaged globally - or that matched patches without
    // excluding the hole from the source - would drag the cold half in.
    const w = 80, h = 64;
    final rgb = Uint8List(w * h * 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = (y * w + x) * 3;
        final left = x < w ~/ 2;
        rgb[p] = left ? 220 : 40;
        rgb[p + 1] = left ? 40 : 60;
        rgb[p + 2] = left ? 40 : 220;
      }
    }
    final hole = box(w, h, 8, 20, 24, 40);

    final out = contentAwareFill(rgb, hole, w, h);

    for (var p = 0; p < w * h; p++) {
      if (hole[p] == 0) continue;
      expect(out[p * 3], closeTo(220, 20), reason: 'pixel $p stayed warm');
      expect(out[p * 3 + 2], closeTo(40, 20), reason: 'pixel $p stayed warm');
    }
    expectKnownUntouched(rgb, out, hole);
  });

  test('an empty hole leaves the photo exactly as it was', () {
    const w = 48, h = 48;
    final rgb = solid(w, h, 10, 20, 30);
    final out = contentAwareFill(rgb, Uint8List(w * h), w, h);
    expect(out, rgb);
  });

  test('a photo that is ALL hole is returned unchanged', () {
    // Degenerate but reachable: there is no known texture to rebuild from, so
    // the honest answer is "no fill" and the caller falls back to erasing.
    const w = 40, h = 40;
    final rgb = solid(w, h, 90, 90, 90);
    final hole = Uint8List(w * h)..fillRange(0, w * h, 1);
    expect(contentAwareFill(rgb, hole, w, h), rgb);
  });

  test('an image smaller than one patch still returns intact known pixels', () {
    const w = 5, h = 5;
    final rgb = solid(w, h, 12, 34, 56);
    final hole = box(w, h, 2, 2, 2, 2);
    final out = contentAwareFill(rgb, hole, w, h);
    expect(out.length, rgb.length);
    expectKnownUntouched(rgb, out, hole);
  });

  test('the same seed fills the same way twice', () {
    // The random search is the only stochastic step; seeding it is what lets a
    // user re-run a fill and get the result they just saw, and what lets these
    // tests assert anything at all.
    const w = 64, h = 64;
    final rgb = Uint8List(w * h * 3);
    for (var i = 0; i < w * h; i++) {
      rgb[i * 3] = (i * 7) % 256;
      rgb[i * 3 + 1] = (i * 13) % 256;
      rgb[i * 3 + 2] = (i * 29) % 256;
    }
    final hole = box(w, h, 20, 20, 34, 34);
    expect(
      contentAwareFill(rgb, hole, w, h),
      contentAwareFill(rgb, hole, w, h),
    );
  });

  test('the source buffer is never mutated', () {
    const w = 48, h = 48;
    final rgb = solid(w, h, 5, 6, 7);
    final copy = Uint8List.fromList(rgb);
    contentAwareFill(rgb, box(w, h, 16, 16, 30, 30), w, h);
    expect(rgb, copy);
  });
}
