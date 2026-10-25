/// Resampling a photo to a new pixel size, on the CPU.
///
/// The GPU cannot be asked for this. A draw resamples with whatever
/// `FilterQuality` maps to on the backend it lands on - nearest, bilinear and
/// mipmapped bilinear, with no promise of which cubic `high` is, if any - and
/// it has no Lanczos at all. A method the user picks BY NAME has to be the
/// method that runs, so the pixels are computed here and the renderer then
/// draws them at 1:1, where its own filter has nothing left to do.
///
/// Byte arrays in and out, like `patch_match.dart`, so it runs in
/// `Isolate.run` and tests without decoding an image.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// How a photo's pixels are interpolated when the image is resized.
///
/// [label] is identity as much as presentation - see `localized_labels.dart`
/// for the names the user reads.
enum ResampleMethod {
  /// Each output pixel copies the one source pixel under its centre. No new
  /// colours are invented, which is what pixel art and screenshots want.
  nearest('Nearest'),

  /// A tent filter: smooth, soft, never overshoots.
  bilinear('Bilinear'),

  /// Catmull-Rom (a = -0.5): sharper than bilinear for a slight ring at hard
  /// edges. The usual default.
  bicubic('Bicubic'),

  /// Lanczos, three lobes: the sharpest of the four and the best at shrinking,
  /// with the most ringing.
  lanczos('Lanczos');

  const ResampleMethod(this.label);

  final String label;
}

/// [src] resampled from [srcWidth]x[srcHeight] to [dstWidth]x[dstHeight].
///
/// [channels] is 4 for straight-alpha RGBA or 1 for a mask's coverage. RGBA is
/// filtered PREMULTIPLIED and divided back out at the end: filtered straight,
/// a transparent pixel's colour - which nothing ever shows - bleeds into its
/// opaque neighbours, and a cut-out shrunk that way comes back with a dark
/// fringe wherever the hidden pixels were dark.
///
/// Shrinking widens the filter by the shrink factor, so every source pixel
/// contributes - the difference between a downscale and a decimation that
/// aliases. The overshoot of the sharper kernels is clamped into 0…255.
Uint8List resamplePixels(
  Uint8List src, {
  required int srcWidth,
  required int srcHeight,
  required int dstWidth,
  required int dstHeight,
  required int channels,
  required ResampleMethod method,
}) {
  assert(channels == 1 || channels == 4);
  assert(src.length == srcWidth * srcHeight * channels);
  if (method == ResampleMethod.nearest) {
    return _nearest(src, srcWidth, srcHeight, dstWidth, dstHeight, channels);
  }
  final (support, kernel) = switch (method) {
    ResampleMethod.bilinear => (1.0, _triangle),
    ResampleMethod.bicubic => (2.0, _catmullRom),
    ResampleMethod.lanczos => (3.0, _lanczos3),
    ResampleMethod.nearest => throw StateError('handled above'),
  };
  final xs = _Taps.build(srcWidth, dstWidth, support, kernel);
  final ys = _Taps.build(srcHeight, dstHeight, support, kernel);
  final rowLength = dstWidth * channels;
  final out = Uint8List(dstWidth * dstHeight * channels);

  // Two passes, horizontal then vertical, but never the whole intermediate
  // image: a 2048 -> 4096 upscale would hold 100 MB of floats for it. Output
  // rows only ever need source rows further down than the last one did, so the
  // horizontally filtered rows live in a ring as tall as the widest vertical
  // footprint and each is filtered exactly once.
  final ring = List.generate(ys.stride, (_) => Float32List(rowLength));
  final acc = Float32List(rowLength);
  var next = 0; // the next source row not yet filtered horizontally
  for (var y = 0; y < dstHeight; y++) {
    final first = ys.start[y];
    final count = ys.count[y];
    if (next < first) next = first;
    while (next < first + count) {
      _filterRow(src, next, srcWidth, channels, xs, ring[next % ys.stride]);
      next++;
    }
    acc.fillRange(0, rowLength, 0);
    final weights = y * ys.stride;
    for (var k = 0; k < count; k++) {
      final w = ys.weights[weights + k];
      final row = ring[(first + k) % ys.stride];
      for (var i = 0; i < rowLength; i++) {
        acc[i] += row[i] * w;
      }
    }
    final o = y * rowLength;
    if (channels == 1) {
      for (var i = 0; i < rowLength; i++) {
        out[o + i] = _byte(acc[i]);
      }
    } else {
      for (var i = 0; i < rowLength; i += 4) {
        final alpha = acc[i + 3];
        // Below half a step the pixel rounds to fully transparent, and its
        // colour is then meaningless - dividing by a near-zero alpha would
        // only amplify ringing into it.
        if (alpha < 0.5) continue;
        out[o + i] = _byte(acc[i] / alpha);
        out[o + i + 1] = _byte(acc[i + 1] / alpha);
        out[o + i + 2] = _byte(acc[i + 2] / alpha);
        out[o + i + 3] = _byte(alpha);
      }
    }
  }
  return out;
}

/// Filters source row [y] horizontally into [into], premultiplying RGBA.
///
/// The colour channels come out as channel x alpha (0…65025) and alpha as
/// itself, so the vertical pass and the final divide work in one space.
void _filterRow(
  Uint8List src,
  int y,
  int srcWidth,
  int channels,
  _Taps xs,
  Float32List into,
) {
  final base = y * srcWidth * channels;
  final dstWidth = xs.start.length;
  if (channels == 1) {
    for (var x = 0; x < dstWidth; x++) {
      final p = base + xs.start[x];
      final weights = x * xs.stride;
      final n = xs.count[x];
      var v = 0.0;
      for (var k = 0; k < n; k++) {
        v += src[p + k] * xs.weights[weights + k];
      }
      into[x] = v;
    }
    return;
  }
  for (var x = 0; x < dstWidth; x++) {
    var p = base + xs.start[x] * 4;
    final weights = x * xs.stride;
    final n = xs.count[x];
    var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    for (var k = 0; k < n; k++) {
      final wa = xs.weights[weights + k] * src[p + 3];
      r += src[p] * wa;
      g += src[p + 1] * wa;
      b += src[p + 2] * wa;
      a += wa;
      p += 4;
    }
    final o = x * 4;
    into[o] = r;
    into[o + 1] = g;
    into[o + 2] = b;
    into[o + 3] = a;
  }
}

Uint8List _nearest(
  Uint8List src,
  int srcWidth,
  int srcHeight,
  int dstWidth,
  int dstHeight,
  int channels,
) {
  // The source pixel under each output pixel's centre.
  Int32List pick(int from, int to) {
    final scale = from / to;
    final index = Int32List(to);
    for (var i = 0; i < to; i++) {
      final s = ((i + 0.5) * scale).toInt();
      index[i] = s < from ? s : from - 1;
    }
    return index;
  }

  final xs = pick(srcWidth, dstWidth);
  final ys = pick(srcHeight, dstHeight);
  final out = Uint8List(dstWidth * dstHeight * channels);
  var o = 0;
  for (var y = 0; y < dstHeight; y++) {
    final row = ys[y] * srcWidth;
    for (var x = 0; x < dstWidth; x++) {
      final p = (row + xs[x]) * channels;
      for (var c = 0; c < channels; c++) {
        out[o++] = src[p + c];
      }
    }
  }
  return out;
}

/// Rounds to the nearest byte. Written out rather than `clamp()`: that is
/// declared on `num`, so it boxes even on doubles, and this runs per channel
/// of every output pixel - the same trap `patch_match.dart` paid for.
int _byte(double v) => v <= 0 ? 0 : (v >= 255 ? 255 : (v + 0.5).toInt());

/// Which source samples each output sample reads along one axis, and how much
/// each one counts.
class _Taps {
  _Taps(this.start, this.count, this.weights, this.stride);

  final Int32List start;
  final Int32List count;

  /// `count[i]` weights for output [i], starting at `i * stride`, summing to 1.
  final Float32List weights;

  /// The most taps any output sample has.
  final int stride;

  /// The same construction Pillow uses: a source sample's centre is at
  /// `j + 0.5`, an output sample's at `(i + 0.5) * scale`, and the kernel is
  /// stretched by the scale when shrinking so its footprint covers every source
  /// sample that falls inside the output one. Taps past the edge are dropped
  /// and the rest renormalised, which is an edge-extend without a branch.
  factory _Taps.build(
    int from,
    int to,
    double support,
    double Function(double) kernel,
  ) {
    final scale = from / to;
    final stretch = scale > 1 ? scale : 1.0;
    final radius = support * stretch;
    final stride = (2 * radius).ceil() + 2;
    final start = Int32List(to);
    final count = Int32List(to);
    final weights = Float32List(to * stride);
    for (var i = 0; i < to; i++) {
      final centre = (i + 0.5) * scale;
      final lo = math.max(0, (centre - radius + 0.5).floor());
      final hi = math.min(from, (centre + radius + 0.5).floor());
      final n = math.min(stride, math.max(1, hi - lo));
      start[i] = math.min(lo, from - 1);
      count[i] = math.min(n, from - start[i]);
      var total = 0.0;
      for (var k = 0; k < count[i]; k++) {
        final w = kernel((start[i] + k + 0.5 - centre) / stretch);
        weights[i * stride + k] = w;
        total += w;
      }
      if (total.abs() < 1e-9) {
        // Every tap on a zero of the kernel - only possible with one or two
        // taps at an edge. Fall back to the nearest sample rather than divide
        // by nothing.
        final nearest = math.min(
          count[i] - 1,
          math.max(0, (centre - start[i]).floor()),
        );
        for (var k = 0; k < count[i]; k++) {
          weights[i * stride + k] = k == nearest ? 1 : 0;
        }
        continue;
      }
      for (var k = 0; k < count[i]; k++) {
        weights[i * stride + k] /= total;
      }
    }
    return _Taps(start, count, weights, stride);
  }
}

double _triangle(double x) {
  final t = x.abs();
  return t < 1 ? 1 - t : 0;
}

double _catmullRom(double x) {
  const a = -0.5;
  final t = x.abs();
  if (t < 1) return ((a + 2) * t - (a + 3)) * t * t + 1;
  if (t < 2) return ((a * t - 5 * a) * t + 8 * a) * t - 4 * a;
  return 0;
}

double _lanczos3(double x) {
  if (x == 0) return 1;
  if (x <= -3 || x >= 3) return 0;
  final px = math.pi * x;
  return 3 * math.sin(px) * math.sin(px / 3) / (px * px);
}
