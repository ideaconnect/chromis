import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show debugPrint, debugPrintStack, kDebugMode;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
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

/// Builds the MI-GAN 4-channel input from the source bytes + region mask.
///
/// The photo is *letterboxed* into the square 512 field (fit-contain, centered)
/// rather than squished, so the model sees undistorted geometry. Padding around
/// the photo is edge-replicated and always marked "keep" (never treated as a
/// hole to synthesize).
({Float32List input, int width, int height, InpaintBox box}) _preprocess(
  Uint8List imageBytes,
  AlphaMask region,
) {
  final src = img.decodeImage(imageBytes)!;
  final w = src.width, h = src.height;
  final box = inpaintLetterbox(w, h);
  final lx = box.x, ly = box.y, lw = box.w, lh = box.h;
  final fitted = img.copyResize(
    src,
    width: lw,
    height: lh,
    interpolation: img.Interpolation.average,
  );
  final rgba = fitted.getBytes(order: img.ChannelOrder.rgba);
  const plane = _side * _side;
  final input = Float32List(4 * plane);
  for (var i = 0; i < plane; i++) {
    final x = i % _side, y = i ~/ _side;
    final inside = x >= lx && x < lx + lw && y >= ly && y < ly + lh;
    // Edge-replicate outside the photo so padding is neutral known context.
    final fx = (x - lx).clamp(0, lw - 1);
    final fy = (y - ly).clamp(0, lh - 1);
    final rx = (fx * region.width) ~/ lw;
    final ry = (fy * region.height) ~/ lh;
    final keep = (inside && region.alpha[ry * region.width + rx] > 128)
        ? 0.0
        : 1.0;
    input[i] = keep - 0.5;
    final o = (fy * lw + fx) * 4;
    input[plane + i] = (rgba[o] / 127.5 - 1.0) * keep;
    input[2 * plane + i] = (rgba[o + 1] / 127.5 - 1.0) * keep;
    input[3 * plane + i] = (rgba[o + 2] / 127.5 - 1.0) * keep;
  }
  return (input: input, width: w, height: h, box: box);
}

/// Composites the model's fill (cropped out of the letterboxed 512 field and
/// upscaled) over the full-res original, only inside the region, and
/// PNG-encodes the result.
Uint8List _postprocess(
  Float32List flat,
  Uint8List imageBytes,
  AlphaMask region,
  int width,
  int height,
  InpaintBox box,
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
  // Crop the fill back to the letterboxed photo area (undoing the fit-contain
  // padding from _preprocess), then upscale that to the full resolution.
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
  final filledFull = img.copyResize(fillCrop, width: width, height: height);
  final src = img.decodeImage(imageBytes)!;
  final base = src.getBytes(order: img.ChannelOrder.rgba);
  final fill = filledFull.getBytes(order: img.ChannelOrder.rgba);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rx = (x * region.width) ~/ width;
      final ry = (y * region.height) ~/ height;
      if (region.alpha[ry * region.width + rx] > 128) {
        final o = (y * width + x) * 4;
        base[o] = fill[o];
        base[o + 1] = fill[o + 1];
        base[o + 2] = fill[o + 2]; // keep the original alpha
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

/// Whether the optional MI-GAN model is bundled - checked cheaply from the asset
/// manifest (no model load). Gates the "Fill" object-removal option.
final inpaintAvailableProvider = FutureProvider<bool>((ref) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().contains(kInpaintModelAsset);
  } catch (_) {
    return false;
  }
});
