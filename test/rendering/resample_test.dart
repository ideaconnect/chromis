import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chromis/core/rendering/resample.dart';
import 'package:flutter_test/flutter_test.dart';

/// The CPU resampler behind Resize image. Byte arrays in and out, so these run
/// without an engine or a decoded file.
void main() {
  /// [w]x[h] RGBA of one colour.
  Uint8List flat(int w, int h, List<int> rgba) {
    final out = Uint8List(w * h * 4);
    for (var i = 0; i < out.length; i += 4) {
      out.setRange(i, i + 4, rgba);
    }
    return out;
  }

  /// A deterministic pseudo-random opaque picture - something with detail in
  /// it, so a bug that only shows on texture cannot hide behind a flat fill.
  Uint8List noise(int w, int h) {
    final out = Uint8List(w * h * 4);
    var seed = 12345;
    for (var i = 0; i < out.length; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      out[i] = (i % 4 == 3) ? 255 : seed >> 16 & 0xff;
    }
    return out;
  }

  Uint8List run(
    Uint8List src,
    int sw,
    int sh,
    int dw,
    int dh,
    ResampleMethod method, {
    int channels = 4,
  }) => resamplePixels(
    src,
    srcWidth: sw,
    srcHeight: sh,
    dstWidth: dw,
    dstHeight: dh,
    channels: channels,
    method: method,
  );

  test('the output is the size asked for, for every method', () {
    for (final method in ResampleMethod.values) {
      for (final (dw, dh) in const [(7, 3), (40, 60), (1, 1), (13, 29)]) {
        final out = run(noise(20, 30), 20, 30, dw, dh, method);
        expect(out.length, dw * dh * 4, reason: '$method to ${dw}x$dh');
      }
    }
  });

  test('resampling to the same size changes nothing', () {
    // Every kernel is 1 at its centre and 0 on every other integer, so at
    // scale 1 each output pixel reads exactly its own source pixel.
    final src = noise(17, 11);
    for (final method in ResampleMethod.values) {
      expect(run(src, 17, 11, 17, 11, method), src, reason: '$method');
    }
  });

  test('a flat colour stays exactly that colour, up and down', () {
    // The weights are normalised, edges included - a missing renormalisation
    // shows up here as a darkened border.
    final src = flat(9, 9, const [200, 120, 40, 255]);
    for (final method in ResampleMethod.values) {
      for (final (dw, dh) in const [(3, 3), (4, 7), (25, 25), (31, 12)]) {
        final out = run(src, 9, 9, dw, dh, method);
        expect(out, flat(dw, dh, const [200, 120, 40, 255]), reason: '$method');
      }
    }
  });

  test('nearest neighbour invents no colours, enlarging or shrinking', () {
    // What pixel art is resized with: every output pixel is a source pixel.
    final src = noise(8, 8);
    final palette = <int>{
      for (var i = 0; i < src.length; i += 4)
        src[i] << 16 | src[i + 1] << 8 | src[i + 2],
    };
    for (final (dw, dh) in const [(32, 32), (3, 5), (8, 20)]) {
      final out = run(src, 8, 8, dw, dh, ResampleMethod.nearest);
      for (var i = 0; i < out.length; i += 4) {
        expect(
          palette.contains(out[i] << 16 | out[i + 1] << 8 | out[i + 2]),
          isTrue,
        );
      }
    }
  });

  test('nearest neighbour at 4x makes exact 4x4 blocks', () {
    final src = noise(3, 2);
    final out = run(src, 3, 2, 12, 8, ResampleMethod.nearest);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 12; x++) {
        final o = (y * 12 + x) * 4;
        final s = ((y ~/ 4) * 3 + x ~/ 4) * 4;
        expect(out.sublist(o, o + 4), src.sublist(s, s + 4));
      }
    }
  });

  test('a hidden pixel\'s colour does not bleed into a visible one', () {
    // Filtered straight-alpha, the transparent black pixel would drag the red
    // toward a dark fringe - the edge of every shrunk cut-out. Premultiplied,
    // its colour weighs nothing because its alpha is nothing.
    final src = Uint8List.fromList(const [
      255, 0, 0, 255, // opaque red
      0, 0, 0, 0, //     transparent black
    ]);
    for (final method in [
      ResampleMethod.bilinear,
      ResampleMethod.bicubic,
      ResampleMethod.lanczos,
    ]) {
      final out = run(src, 2, 1, 1, 1, method);
      expect(out[0], 255, reason: '$method: red');
      expect(out[1], 0, reason: '$method: green');
      expect(out[2], 0, reason: '$method: blue');
      expect(out[3], inInclusiveRange(1, 254), reason: '$method: alpha');
    }
  });

  test('shrinking averages every source pixel, it does not skip any', () {
    // A one-pixel checkerboard has no detail that survives a 4x shrink: a
    // filter whose footprint did not widen with the scale would sample a few
    // pixels and land on black or white, which is aliasing.
    const n = 64;
    final src = Uint8List(n * n * 4);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final o = (y * n + x) * 4;
        final v = (x + y).isEven ? 255 : 0;
        src
          ..[o] = v
          ..[o + 1] = v
          ..[o + 2] = v
          ..[o + 3] = 255;
      }
    }
    for (final method in [
      ResampleMethod.bilinear,
      ResampleMethod.bicubic,
      ResampleMethod.lanczos,
    ]) {
      final out = run(src, n, n, n ~/ 4, n ~/ 4, method);
      // Away from the edges, where the renormalised taps are not symmetric -
      // Lanczos at 4x reaches 12 source pixels either side.
      for (var y = 3; y < n ~/ 4 - 3; y++) {
        for (var x = 3; x < n ~/ 4 - 3; x++) {
          final o = (y * (n ~/ 4) + x) * 4;
          expect(out[o], inInclusiveRange(120, 135), reason: '$method $x,$y');
        }
      }
    }
  });

  test('shrinking, Lanczos keeps the most detail and bilinear the least', () {
    // Fine stripes - a sine with a 6 px period - halved, so they land at 3 px,
    // still above the new Nyquist limit. How much of their contrast survives
    // is the kernel's frequency response, and the order is the reason the
    // sheet calls Lanczos the best for shrinking.
    const w = 240;
    final src = Uint8List(w * 4);
    for (var x = 0; x < w; x++) {
      final v = (128 + 100 * math.sin(2 * math.pi * (x + 0.5) / 6)).round();
      src.setRange(x * 4, x * 4 + 4, [v, v, v, 255]);
    }
    int contrast(ResampleMethod method) {
      final out = run(src, w, 1, w ~/ 2, 1, method);
      var lo = 255, hi = 0;
      for (var x = 10; x < w ~/ 2 - 10; x++) {
        final v = out[x * 4];
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
      return hi - lo;
    }

    final bilinear = contrast(ResampleMethod.bilinear);
    final bicubic = contrast(ResampleMethod.bicubic);
    final lanczos = contrast(ResampleMethod.lanczos);
    expect(bicubic, greaterThan(bilinear));
    expect(lanczos, greaterThan(bicubic));
  });

  test('enlarging, bicubic is crisper than bilinear and overshoot clamps', () {
    // A hard black|white edge, 8 pixels of each, enlarged 8x. How far the
    // result is from an ideal step - each pixel's distance to the nearer of
    // black and white - is how much the edge was smeared. (Lanczos is left
    // out of the ordering on purpose: on an enlarged step its transition is
    // no steeper than bicubic's, and its second lobe adds the faint halo the
    // sheet warns about - its edge is in shrinking, tested above.)
    final src = Uint8List(16 * 4);
    for (var x = 0; x < 16; x++) {
      final v = x < 8 ? 0 : 255;
      src.setRange(x * 4, x * 4 + 4, [v, v, v, 255]);
    }
    Uint8List enlarge(ResampleMethod method) => run(src, 16, 1, 128, 1, method);
    int smear(ResampleMethod method) {
      final out = enlarge(method);
      var total = 0;
      for (var i = 0; i < out.length; i += 4) {
        total += out[i] < 255 - out[i] ? out[i] : 255 - out[i];
      }
      return total;
    }

    expect(smear(ResampleMethod.nearest), 0);
    expect(
      smear(ResampleMethod.bicubic),
      lessThan(smear(ResampleMethod.bilinear)),
    );

    // Lanczos overshoots past white just right of the edge and under black
    // just left of it. Clamped, those read 255 and 0; wrapped into a byte they
    // would read as a dark or bright speck instead.
    final lanczos = enlarge(ResampleMethod.lanczos);
    for (var x = 72; x < 90; x++) {
      expect(lanczos[x * 4], greaterThan(200), reason: 'bright side, $x');
    }
    for (var x = 38; x < 56; x++) {
      expect(lanczos[x * 4], lessThan(55), reason: 'dark side, $x');
    }
    // And beyond the kernel's reach the picture is untouched.
    for (var x = 0; x < 30; x++) {
      expect(lanczos[x * 4], 0, reason: 'far dark side, $x');
    }
    for (var x = 100; x < 128; x++) {
      expect(lanczos[x * 4], 255, reason: 'far bright side, $x');
    }
  });

  test('a mask resamples as one channel', () {
    final alpha = Uint8List.fromList(List.generate(16, (i) => i * 16));
    for (final method in ResampleMethod.values) {
      final out = run(alpha, 4, 4, 8, 2, method, channels: 1);
      expect(out.length, 16, reason: '$method');
    }
    // And a flat one stays flat.
    final full = Uint8List(25)..fillRange(0, 25, 255);
    expect(
      run(full, 5, 5, 11, 3, ResampleMethod.lanczos, channels: 1),
      Uint8List(33)..fillRange(0, 33, 255),
    );
  });

  test('a large shrink still produces something', () {
    // 400 -> 3 is a footprint of over a hundred source pixels per output one,
    // which is what sizes the tap table.
    final out = run(noise(400, 300), 400, 300, 3, 2, ResampleMethod.lanczos);
    expect(out.length, 3 * 2 * 4);
    for (var i = 3; i < out.length; i += 4) {
      expect(out[i], 255);
    }
  });
}
