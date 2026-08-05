import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../alpha_mask.dart';
import 'patch_match.dart';

/// Content-aware fill: replaces a removed object with texture rebuilt from the
/// surrounding photo. Always available - it is pure Dart ([contentAwareFill]),
/// so unlike the optional MI-GAN tier there is no model to bundle and nothing to
/// fail on a device that cannot run ONNX.
///
/// The fill runs on a WINDOW around the object rather than on the whole photo,
/// which is the difference between a sharp patch and a smudge. MI-GAN has to
/// squeeze the entire image into its 512² input, so a small object in a 2048 px
/// photo is synthesized at a fraction of its real size and then blown back up;
/// here a small object is filled at native resolution, and only a hole big
/// enough to exceed [_maxWorkSide] is ever downscaled. Sampling locally also
/// gives better matches: the texture next to the object is what should replace
/// it.
class ContentFillEngine {
  const ContentFillEngine();

  /// Fills the [region] (alpha above [_holeCutoff] = the object to remove) in
  /// the photo at [imageBytes], returning PNG bytes of the whole image with that
  /// region replaced - or null when there is nothing to fill or too little
  /// photo left to fill it from, in which case the caller falls back to erasing.
  Future<Uint8List?> fill(Uint8List imageBytes, AlphaMask region) =>
      Isolate.run(() => _fill(imageBytes, region));
}

/// Coverage at or below this is not part of the object. Deliberately low: a
/// segmentation mask's edge is soft, and everything the object tinted has to go.
const _holeCutoff = 32;

/// Extra pixels (at working scale) filled beyond the mask, to swallow the colour
/// fringe a soft mask edge leaves behind.
const _guard = 3;

/// Half-width of the ramp from filled to original. The seam is a blend, not a
/// cut, so the synthesized texture is never outlined.
const _seam = 2;

/// The fill runs at native resolution up to this; larger windows are downscaled
/// (PatchMatch cost is per pixel, and a phone has a budget).
const _maxWorkSide = 512;

/// Margin around the object's bounding box, as a fraction of its longer side.
/// This is the context PatchMatch samples from - too little and the fill just
/// repeats a sliver of its own surroundings.
const _marginFactor = 0.75;
const _minMargin = 24;

/// Past this the window is nearly all hole, so there is no texture left to
/// rebuild from; erasing is the honest answer.
const _maxHoleFraction = 0.9;

/// The crop of the photo the fill runs on: [x],[y],[w],[h] in image pixels, and
/// the resolution ([workW]×[workH]) PatchMatch actually sees - equal to w×h
/// unless the window is too big to afford at native size.
typedef FillWindow = ({int x, int y, int w, int h, int workW, int workH});

/// Window around the object's bounding box ([bx],[by],[bw],[bh]) inside a
/// [imageW]×[imageH] photo. Pure geometry - covered by
/// test/segmentation/content_fill_window_test.dart.
FillWindow contentFillWindow(
  int imageW,
  int imageH,
  int bx,
  int by,
  int bw,
  int bh, {
  int maxSide = _maxWorkSide,
}) {
  final margin = math.max(
    _minMargin,
    (math.max(bw, bh) * _marginFactor).round(),
  );
  final x = math.max(0, bx - margin);
  final y = math.max(0, by - margin);
  final w = math.min(imageW, bx + bw + margin) - x;
  final h = math.min(imageH, by + bh + margin) - y;
  final longest = math.max(w, h);
  if (longest <= maxSide) {
    return (x: x, y: y, w: w, h: h, workW: w, workH: h);
  }
  final scale = maxSide / longest;
  return (
    x: x,
    y: y,
    w: w,
    h: h,
    workW: math.max(8, (w * scale).round()),
    workH: math.max(8, (h * scale).round()),
  );
}

Uint8List? _fill(Uint8List imageBytes, AlphaMask region) {
  final src = img.decodeImage(imageBytes);
  if (src == null) return null;
  final imageW = src.width;
  final imageH = src.height;

  final box = _regionBox(region, imageW, imageH);
  if (box == null) return null; // nothing marked
  final win = contentFillWindow(imageW, imageH, box.x, box.y, box.w, box.h);
  if (win.w <= 0 || win.h <= 0) return null;

  final base = src.getBytes(order: img.ChannelOrder.rgba);
  final workW = win.workW;
  final workH = win.workH;
  final n = workW * workH;

  // Sample the window (and the mask over it) down to the working grid in one
  // pass - a crop + resize through the image package would cost two more
  // full-window buffers for the same nearest-neighbour result.
  final rgb = Uint8List(n * 3);
  final raw = Uint8List(n);
  var holes = 0;
  for (var y = 0; y < workH; y++) {
    final iy = (win.y + (y + 0.5) * win.h / workH).floor().clamp(0, imageH - 1);
    final ry = (iy * region.height ~/ imageH).clamp(0, region.height - 1);
    for (var x = 0; x < workW; x++) {
      final ix = (win.x + (x + 0.5) * win.w / workW).floor().clamp(
        0,
        imageW - 1,
      );
      final rx = (ix * region.width ~/ imageW).clamp(0, region.width - 1);
      final p = y * workW + x;
      final o = (iy * imageW + ix) * 4;
      rgb[p * 3] = base[o];
      rgb[p * 3 + 1] = base[o + 1];
      rgb[p * 3 + 2] = base[o + 2];
      if (region.alpha[ry * region.width + rx] > _holeCutoff) {
        raw[p] = 1;
        holes++;
      }
    }
  }
  if (holes == 0 || holes > n * _maxHoleFraction) return null;

  // Two dilations, deliberately different sizes. The blend weight is a blurred
  // dilation, and a box blur only reaches 1.0 where the whole window is inside
  // the set - so the region actually SYNTHESIZED has to run one blur radius
  // wider than the region weighted at full strength, or the seam would fade
  // back into the object's own fringe instead of into clean photo.
  final filled = contentAwareFill(
    rgb,
    _dilate(raw, workW, workH, _guard + 2 * _seam),
    workW,
    workH,
  );
  final weight = _blur(
    _dilate(raw, workW, workH, _guard + _seam),
    workW,
    workH,
    _seam,
  );

  // Composite back over the FULL-resolution original: only the window is
  // touched, and only where the weight says so, so the rest stays untouched
  // bit-for-bit.
  for (var y = 0; y < win.h; y++) {
    final wy = (y + 0.5) * workH / win.h - 0.5;
    for (var x = 0; x < win.w; x++) {
      final wx = (x + 0.5) * workW / win.w - 0.5;
      final a = _sample(weight, workW, workH, 1, 0, wx, wy) / 255.0;
      if (a <= 0.004) continue;
      final o = ((win.y + y) * imageW + win.x + x) * 4;
      for (var c = 0; c < 3; c++) {
        final synth = _sample(filled, workW, workH, 3, c, wx, wy);
        final v = (base[o + c] + (synth - base[o + c]) * a).round();
        base[o + c] = v < 0 ? 0 : (v > 255 ? 255 : v);
      }
    }
  }

  return img.encodePng(
    img.Image.fromBytes(
      width: imageW,
      height: imageH,
      bytes: base.buffer,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    ),
  );
}

/// Bounding box of the marked region, in IMAGE pixels (the mask is often a
/// different resolution than the photo). Null when nothing is marked.
({int x, int y, int w, int h})? _regionBox(
  AlphaMask region,
  int imageW,
  int imageH,
) {
  var x0 = region.width, y0 = region.height, x1 = -1, y1 = -1;
  for (var y = 0; y < region.height; y++) {
    final row = y * region.width;
    for (var x = 0; x < region.width; x++) {
      if (region.alpha[row + x] <= _holeCutoff) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) return null;
  int mapX(int v) => (v * imageW ~/ region.width).clamp(0, imageW - 1);
  int mapY(int v) => (v * imageH ~/ region.height).clamp(0, imageH - 1);
  final ax = mapX(x0);
  final ay = mapY(y0);
  // +1 so the box covers the last marked pixel's full footprint in image space.
  final bx = math.min<int>(
    imageW,
    mapX(x1) + math.max(1, imageW ~/ region.width),
  );
  final by = math.min<int>(
    imageH,
    mapY(y1) + math.max(1, imageH ~/ region.height),
  );
  return (x: ax, y: ay, w: bx - ax, h: by - ay);
}

/// Grows a 0/1 mask by [radius] with a square element, separably (a square
/// dilation is the horizontal one followed by the vertical one).
Uint8List _dilate(Uint8List mask, int w, int h, int radius) {
  if (radius <= 0) return Uint8List.fromList(mask);
  final tmp = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      var on = 0;
      final lo = math.max(0, x - radius);
      final hi = math.min(w - 1, x + radius);
      for (var i = lo; i <= hi; i++) {
        if (mask[row + i] != 0) {
          on = 1;
          break;
        }
      }
      tmp[row + x] = on;
    }
  }
  final out = Uint8List(w * h);
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      var on = 0;
      final lo = math.max(0, y - radius);
      final hi = math.min(h - 1, y + radius);
      for (var i = lo; i <= hi; i++) {
        if (tmp[i * w + x] != 0) {
          on = 1;
          break;
        }
      }
      out[y * w + x] = on;
    }
  }
  return out;
}

/// Separable box blur of a 0/1 mask into 0…255 blend weights.
Uint8List _blur(Uint8List mask, int w, int h, int radius) {
  final win = 2 * radius + 1;
  final tmp = Uint16List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      var sum = 0;
      for (var k = -radius; k <= radius; k++) {
        sum += mask[row + (x + k).clamp(0, w - 1)] != 0 ? 255 : 0;
      }
      tmp[row + x] = sum ~/ win;
    }
  }
  final out = Uint8List(w * h);
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      var sum = 0;
      for (var k = -radius; k <= radius; k++) {
        sum += tmp[(y + k).clamp(0, h - 1) * w + x];
      }
      out[y * w + x] = sum ~/ win;
    }
  }
  return out;
}

/// Bilinear read of channel [c] of a [stride]-channel buffer at fractional
/// ([fx],[fy]). Used to lift the working-resolution fill and its blend weight
/// back to the window's real size.
double _sample(
  Uint8List data,
  int w,
  int h,
  int stride,
  int c,
  double fx,
  double fy,
) {
  // Manual bounds rather than `clamp`, which is declared on `num` and boxes:
  // this runs four times per pixel of the window, at full photo resolution.
  final cx = fx < 0 ? 0.0 : (fx > w - 1 ? w - 1.0 : fx);
  final cy = fy < 0 ? 0.0 : (fy > h - 1 ? h - 1.0 : fy);
  final x0 = cx.floor();
  final y0 = cy.floor();
  final x1 = x0 + 1 < w ? x0 + 1 : w - 1;
  final y1 = y0 + 1 < h ? y0 + 1 : h - 1;
  final tx = cx - x0;
  final ty = cy - y0;
  final v00 = data[(y0 * w + x0) * stride + c].toDouble();
  final v10 = data[(y0 * w + x1) * stride + c].toDouble();
  final v01 = data[(y1 * w + x0) * stride + c].toDouble();
  final v11 = data[(y1 * w + x1) * stride + c].toDouble();
  final top = v00 + (v10 - v00) * tx;
  final bottom = v01 + (v11 - v01) * tx;
  return top + (bottom - top) * ty;
}

final contentFillEngineProvider = Provider<ContentFillEngine>(
  (ref) => const ContentFillEngine(),
);
