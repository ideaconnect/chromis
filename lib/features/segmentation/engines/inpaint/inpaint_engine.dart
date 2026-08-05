import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../alpha_mask.dart';
import '../object/ort_graph.dart';

/// Bundled MI-GAN model. Converted by `model_conversion/convert_migan.py`; see
/// docs/inpaint-setup.md. Absent → "Fill in" still works, falling through to
/// `ContentFillEngine`, which is what makes this asset safe to drop.
const kInpaintModelAsset = 'assets/models/migan.onnx';

/// The MI-GAN working resolution (the model is trained at 512²).
const _side = 512;

/// The model's input / output tensor names. MUST match the bundled ONNX; adjust
/// here (and in docs/inpaint-setup.md) if your export uses different names.
const _inputName = 'input';
const _outputName = 'output';

/// On-device generative inpainting (MI-GAN): fills a removed region with
/// synthesized background instead of erasing it to transparency.
///
/// Signature this engine feeds (the standard MI-GAN export):
///   input  `[1, 4, 512, 512]` float32 - channel 0 = `keep - 0.5`
///     (keep: 1 outside the hole, 0 inside), channels 1..3 = `rgb/127.5 - 1`
///     multiplied by `keep` (the hole zeroed);
///   output `[1, 3, 512, 512]` float32 in [-1, 1].
/// The hole (synthesized) region is composited back over the FULL-resolution
/// original, so only the filled area is resampled - the rest stays sharp.
class InpaintEngine {
  InpaintEngine(this._openGraph);

  final Future<OrtGraph> Function() _openGraph;
  OrtGraph? _graph;

  Future<OrtGraph> _ensure() async => _graph ??= await _openGraph();

  /// Fills the [region] (alpha > 128 = the object to remove) in the photo at
  /// [imageBytes] with synthesized content, returning PNG bytes of the whole
  /// image with that region replaced - or null if the model can't run.
  Future<Uint8List?> inpaint(Uint8List imageBytes, AlphaMask region) async {
    try {
      final graph = await _ensure();
      // Heavy pixel work runs off the UI isolate; the native ORT run is on the
      // main isolate (platform channel) in between.
      final pre = await Isolate.run(() => _preprocess(imageBytes, region));
      final out = await graph.run(
        {
          _inputName: (data: pre.input, shape: const [1, 4, _side, _side]),
        },
        const [_outputName],
      );
      final flat = out[_outputName]!;
      return Isolate.run(
        () => _postprocess(
          flat,
          imageBytes,
          region,
          pre.width,
          pre.height,
          pre.box,
          pre.window,
          pre.weight,
        ),
      );
    } catch (e, stack) {
      // Returning null is correct - the caller falls through to content-aware
      // fill, which is the whole point of the ladder. But swallowing the reason
      // is how this feature shipped dead once already: a wrong tensor
      // signature, a missing op and an out-of-memory kill all look identical
      // from the outside, and all look like "the model is just bad". Say which
      // in debug, where someone is watching.
      if (kDebugMode) {
        debugPrint('InpaintEngine: generative fill failed, falling back - $e');
        debugPrintStack(stackTrace: stack, maxFrames: 6);
      }
      return null;
    }
  }

  Future<void> dispose() async {
    await _graph?.dispose();
    _graph = null;
  }
}

/// The rectangle (inside the 512² field) where the letterboxed photo sits.
typedef InpaintBox = ({int x, int y, int w, int h});

/// Fit-contain rect of a [w]×[h] photo centered in the square 512 field.
/// Pure geometry - covered by test/inpaint_letterbox_test.dart.
InpaintBox inpaintLetterbox(int w, int h) {
  final scale = _side / (w > h ? w : h);
  final lw = (w * scale).round().clamp(1, _side);
  final lh = (h * scale).round().clamp(1, _side);
  return (x: (_side - lw) ~/ 2, y: (_side - lh) ~/ 2, w: lw, h: lh);
}

/// The crop of the photo the model is shown, in image pixels.
typedef InpaintWindow = ({int x, int y, int w, int h});

/// Context kept around the object, as a fraction of its longer side.
const _windowMargin = 0.5;

/// Extra pixels (in the 512 field) filled beyond the mask.
///
/// Not a refinement - load-bearing. A segmentation mask's boundary is a BLEND
/// of object and background, and `alpha > 128` cuts INSIDE it, so feeding the
/// model the raw mask leaves a rim of the object in the visible context. The
/// model conditions on that rim and synthesises the whole region in the
/// object's colour. Measured on a soft-edged pink object: 1384 object-coloured
/// pixels survived and the entire fill came back pink; with dilation, zero.
/// `ContentFillEngine` always did this. The generative tier did not, which is
/// why it looked worse than the model actually is.
const _guard = 4;

/// Half-width of the ramp from filled to original, so the seam is a blend and
/// not a cut. The region SYNTHESISED runs a further [_seam] wider than the
/// region blended at full strength, or the ramp fades back into the object's
/// own fringe instead of into clean photo.
const _seam = 3;

/// A square-ish crop around the marked region, clamped to the photo.
///
/// The model input is a fixed 512², so feeding it the WHOLE photo is what
/// decides how many pixels the object actually gets: a person filling 7% of a
/// 2048 px frame is synthesized ~64 px wide and then blown back up. Cropping to
/// a window first measured ~90 px for the same run - and since the crop is
/// square it also fills the 512 field instead of wasting it on letterbox bars.
///
/// Pure geometry - covered by test/inpaint_letterbox_test.dart.
InpaintWindow inpaintWindow(
  int imageW,
  int imageH,
  int bx,
  int by,
  int bw,
  int bh,
) {
  final longer = bw > bh ? bw : bh;
  final margin = (longer * _windowMargin).round();
  var side = longer + 2 * margin;
  if (side > imageW) side = imageW;
  if (side > imageH) side = imageH;
  final cx = bx + bw ~/ 2;
  final cy = by + bh ~/ 2;
  final x = (cx - side ~/ 2).clamp(0, imageW - side);
  final y = (cy - side ~/ 2).clamp(0, imageH - side);
  return (x: x, y: y, w: side, h: side);
}

/// Bounding box of the marked region in IMAGE pixels, or null if nothing is
/// marked. The mask is routinely a different resolution than the photo.
({int x, int y, int w, int h})? inpaintRegionBox(
  AlphaMask region,
  int imageW,
  int imageH,
) {
  var x0 = region.width, y0 = region.height, x1 = -1, y1 = -1;
  for (var y = 0; y < region.height; y++) {
    final row = y * region.width;
    for (var x = 0; x < region.width; x++) {
      if (region.alpha[row + x] <= 128) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) return null;
  final sx = imageW / region.width;
  final sy = imageH / region.height;
  final ax = (x0 * sx).floor().clamp(0, imageW - 1);
  final ay = (y0 * sy).floor().clamp(0, imageH - 1);
  final bx = ((x1 + 1) * sx).ceil().clamp(1, imageW);
  final by = ((y1 + 1) * sy).ceil().clamp(1, imageH);
  return (x: ax, y: ay, w: bx - ax, h: by - ay);
}

/// Builds the MI-GAN 4-channel input from the source bytes + region mask.
///
/// The model sees a square WINDOW around the object rather than the whole
/// photo ([inpaintWindow]) - at a fixed 512² input that is what decides how
/// many pixels the object itself gets. The window is letterboxed fit-contain
/// into the field (it is only non-square where it was clamped to the photo's
/// edge), so geometry is never distorted; padding is edge-replicated and always
/// marked "keep" so it is never treated as a hole.
({
  Float32List input,
  int width,
  int height,
  InpaintBox box,
  InpaintWindow window,
  Uint8List weight,
})
_preprocess(Uint8List imageBytes, AlphaMask region) {
  final src = img.decodeImage(imageBytes)!;
  final w = src.width, h = src.height;
  final bbox = inpaintRegionBox(region, w, h);
  final window = bbox == null
      ? (x: 0, y: 0, w: w, h: h)
      : inpaintWindow(w, h, bbox.x, bbox.y, bbox.w, bbox.h);
  final cropped = img.copyCrop(
    src,
    x: window.x,
    y: window.y,
    width: window.w,
    height: window.h,
  );
  final box = inpaintLetterbox(window.w, window.h);
  final lx = box.x, ly = box.y, lw = box.w, lh = box.h;
  final fitted = img.copyResize(
    cropped,
    width: lw,
    height: lh,
    interpolation: img.Interpolation.average,
  );
  final rgba = fitted.getBytes(order: img.ChannelOrder.rgba);
  const plane = _side * _side;

  // Sample the mask into the 512 field FIRST, so it can be grown before
  // anything - the model or the composite - conditions on it.
  final raw = Uint8List(plane);
  for (var i = 0; i < plane; i++) {
    final x = i % _side, y = i ~/ _side;
    if (x < lx || x >= lx + lw || y < ly || y >= ly + lh) continue;
    // Window pixel -> image pixel -> mask pixel.
    final ix = window.x + ((x - lx) * window.w) ~/ lw;
    final iy = window.y + ((y - ly) * window.h) ~/ lh;
    final rx = ((ix * region.width) ~/ w).clamp(0, region.width - 1);
    final ry = ((iy * region.height) ~/ h).clamp(0, region.height - 1);
    if (region.alpha[ry * region.width + rx] > 128) raw[i] = 1;
  }
  final hole = _dilate(raw, _guard + 2 * _seam);
  final weight = _blur(_dilate(raw, _guard + _seam), _seam);

  final input = Float32List(4 * plane);
  for (var i = 0; i < plane; i++) {
    final x = i % _side, y = i ~/ _side;
    // Edge-replicate outside the window so padding is neutral known context.
    final fx = (x - lx).clamp(0, lw - 1);
    final fy = (y - ly).clamp(0, lh - 1);
    final keep = hole[i] != 0 ? 0.0 : 1.0;
    input[i] = keep - 0.5;
    final o = (fy * lw + fx) * 4;
    input[plane + i] = (rgba[o] / 127.5 - 1.0) * keep;
    input[2 * plane + i] = (rgba[o + 1] / 127.5 - 1.0) * keep;
    input[3 * plane + i] = (rgba[o + 2] / 127.5 - 1.0) * keep;
  }
  return (
    input: input,
    width: w,
    height: h,
    box: box,
    window: window,
    weight: weight,
  );
}

/// Grows a 0/1 mask over the 512 field by [radius], separably (a square
/// dilation is the horizontal pass followed by the vertical one).
Uint8List _dilate(Uint8List mask, int radius) {
  final tmp = Uint8List(_side * _side);
  for (var y = 0; y < _side; y++) {
    final row = y * _side;
    for (var x = 0; x < _side; x++) {
      final lo = x - radius < 0 ? 0 : x - radius;
      final hi = x + radius >= _side ? _side - 1 : x + radius;
      for (var i = lo; i <= hi; i++) {
        if (mask[row + i] != 0) {
          tmp[row + x] = 1;
          break;
        }
      }
    }
  }
  final out = Uint8List(_side * _side);
  for (var x = 0; x < _side; x++) {
    for (var y = 0; y < _side; y++) {
      final lo = y - radius < 0 ? 0 : y - radius;
      final hi = y + radius >= _side ? _side - 1 : y + radius;
      for (var i = lo; i <= hi; i++) {
        if (tmp[i * _side + x] != 0) {
          out[y * _side + x] = 1;
          break;
        }
      }
    }
  }
  return out;
}

/// Separable box blur of a 0/1 mask into 0…255 blend weights.
Uint8List _blur(Uint8List mask, int radius) {
  final win = 2 * radius + 1;
  final tmp = Uint16List(_side * _side);
  for (var y = 0; y < _side; y++) {
    final row = y * _side;
    for (var x = 0; x < _side; x++) {
      var sum = 0;
      for (var k = -radius; k <= radius; k++) {
        sum += mask[row + (x + k).clamp(0, _side - 1)] != 0 ? 255 : 0;
      }
      tmp[row + x] = sum ~/ win;
    }
  }
  final out = Uint8List(_side * _side);
  for (var x = 0; x < _side; x++) {
    for (var y = 0; y < _side; y++) {
      var sum = 0;
      for (var k = -radius; k <= radius; k++) {
        sum += tmp[(y + k).clamp(0, _side - 1) * _side + x];
      }
      out[y * _side + x] = sum ~/ win;
    }
  }
  return out;
}

/// Composites the model's fill (cropped out of the letterboxed 512 field and
/// scaled back to the window) over the full-res original, only inside the
/// region, and PNG-encodes the result.
Uint8List _postprocess(
  Float32List flat,
  Uint8List imageBytes,
  AlphaMask region,
  int width,
  int height,
  InpaintBox box,
  InpaintWindow window,
  Uint8List weight,
) {
  const plane = _side * _side;
  final fillRgba = Uint8List(plane * 4);
  for (var i = 0; i < plane; i++) {
    int chan(int ch) =>
        ((flat[ch * plane + i] + 1.0) * 127.5).round().clamp(0, 255);
    final o = i * 4;
    fillRgba[o] = chan(0);
    fillRgba[o + 1] = chan(1);
    fillRgba[o + 2] = chan(2);
    fillRgba[o + 3] = 255;
  }
  // Crop the fill back to the letterboxed area (undoing the fit-contain padding
  // from _preprocess), then scale it to the window.
  final fillCrop = img.copyCrop(
    img.Image.fromBytes(
      width: _side,
      height: _side,
      bytes: fillRgba.buffer,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    ),
    x: box.x,
    y: box.y,
    width: box.w,
    height: box.h,
  );
  // CUBIC, explicitly. `copyResize` defaults to Interpolation.nearest, and this
  // is an UPscale from 512 to the window's real size - nearest turns the
  // model's output into hard rectangular blocks, which is what shipped and what
  // looked like "the fill is terrible quality". The downscale above already
  // passed `average`; only the way back up was left on the default.
  final filledWindow = img.copyResize(
    fillCrop,
    width: window.w,
    height: window.h,
    interpolation: img.Interpolation.cubic,
  );
  final src = img.decodeImage(imageBytes)!;
  final base = src.getBytes(order: img.ChannelOrder.rgba);
  final fill = filledWindow.getBytes(order: img.ChannelOrder.rgba);
  // Only the window can contain marked pixels - it was built around their
  // bounding box - so walk it rather than the whole photo.
  //
  // The blend weight is the FEATHERED, dilated mask from _preprocess rather
  // than a hard `alpha > 128` test: a hard edge here re-exposes the object's
  // own boundary blend as a rim around otherwise-good output, and reads as a
  // cut-out pasted over the photo.
  for (var y = window.y; y < window.y + window.h; y++) {
    // Full-res window pixel -> the letterboxed 512 field the weight lives in.
    final wy = box.y + ((y - window.y) * box.h) ~/ window.h;
    final fy = wy < 0 ? 0 : (wy >= _side ? _side - 1 : wy);
    for (var x = window.x; x < window.x + window.w; x++) {
      final wx = box.x + ((x - window.x) * box.w) ~/ window.w;
      final fx = wx < 0 ? 0 : (wx >= _side ? _side - 1 : wx);
      final a = weight[fy * _side + fx];
      if (a == 0) continue;
      final o = (y * width + x) * 4;
      final f = ((y - window.y) * window.w + (x - window.x)) * 4;
      if (a == 255) {
        base[o] = fill[f];
        base[o + 1] = fill[f + 1];
        base[o + 2] = fill[f + 2]; // keep the original alpha
      } else {
        for (var c = 0; c < 3; c++) {
          base[o + c] = base[o + c] + ((fill[f + c] - base[o + c]) * a) ~/ 255;
        }
      }
    }
  }
  return img.encodePng(
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: base.buffer,
      order: img.ChannelOrder.rgba,
      numChannels: 4,
    ),
  );
}

final inpaintEngineProvider = Provider<InpaintEngine>((ref) {
  final engine = InpaintEngine(
    () => OrtGraphSession.fromAsset(kInpaintModelAsset),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

// There is deliberately NO `inpaintAvailableProvider` any more. It was a
// FutureProvider over the asset manifest, and gating this tier on it skipped
// the tier three separate times without ever saying so - most recently because
// a synchronous `ref.read(...).asData` on an uninitialised FutureProvider
// reads as AsyncLoading, i.e. "no model", for the first fill of every session.
// `inpaint` already returns null for a missing or unloadable asset, and null is
// the caller's signal to fall through, so the gate bought nothing and hid
// everything. See test/segmentation/inpaint_available_test.dart.
