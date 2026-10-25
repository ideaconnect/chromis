import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/models/layer.dart';
import '../../../core/models/project.dart';
import '../../../core/rendering/image_decode.dart';
import '../../../core/rendering/resample.dart';
import '../../segmentation/alpha_mask.dart';
import '../../segmentation/mask_store.dart';
import '../image_resize.dart';
import 'image_import.dart';

/// The pixel half of Resize image: every photo resampled, with the method the
/// user chose, to the size it will be drawn at once the picture is resized.
///
/// New files, never rewritten ones. The undo step before the resize still
/// points at the originals, and the cold-launch orphan sweep reclaims them
/// once no manifest does.
class PhotoResampler {
  PhotoResampler({required this.imports, required this.masks});

  final ImageImportService imports;
  final MaskStore masks;

  /// The resampled photos for resizing [project] to [width] x [height], keyed
  /// by layer id. A layer whose photo would come out the size it already is -
  /// or whose file is missing - is absent, and keeps its pixels.
  ///
  /// Hidden layers are included: they are part of the picture as soon as they
  /// are shown again, and a stale-sized photo would then be the one layer that
  /// was never resized.
  Future<Map<String, ResampledPhoto>> resample(
    Project project, {
    required int width,
    required int height,
    required ResampleMethod method,
  }) async {
    final resized = resizeProjectGeometry(project, width, height);
    final sources = <String, ui.Size?>{};
    // One resample per distinct photo, mask and size: every frame of an
    // animation carries its own copy of the same layer, and twelve frames must
    // not cost twelve resamples of the same picture.
    final jobs =
        <({String asset, String? mask, int width, int height}), List<String>>{};
    for (final frame in resized.frames) {
      for (final layer in frame.layers) {
        if (layer is! ImageLayer) continue;
        if (!sources.containsKey(layer.assetPath)) {
          sources[layer.assetPath] = await _sourceSize(layer.assetPath);
        }
        final source = sources[layer.assetPath];
        if (source == null) continue;
        final target = photoResampleTarget(layer, source);
        if (target == null) continue;
        jobs
            .putIfAbsent((
              asset: layer.assetPath,
              mask: layer.maskPath,
              width: target.width,
              height: target.height,
            ), () => [])
            .add(layer.id);
      }
    }

    // One at a time: each holds a full-size decode, and a 4096 px photo is
    // 50 MB of it.
    final result = <String, ResampledPhoto>{};
    for (final MapEntry(key: job, value: ids) in jobs.entries) {
      final asset = await _resamplePhoto(
        job.asset,
        job.width,
        job.height,
        method,
      );
      final mask = job.mask == null
          ? null
          : await _resampleMask(
              job.mask!,
              job.width,
              job.height,
              method,
              ids.first,
            );
      for (final id in ids) {
        result[id] = ResampledPhoto(
          fromAsset: job.asset,
          fromMask: job.mask,
          assetPath: asset,
          maskPath: mask,
        );
      }
    }
    return result;
  }

  static Future<ui.Size?> _sourceSize(String path) async {
    try {
      return await MaskStore.decodeImageSize(path);
    } catch (_) {
      return null; // missing or undecodable: the renderer skips it too
    }
  }

  Future<String> _resamplePhoto(
    String path,
    int width,
    int height,
    ResampleMethod method,
  ) async {
    // Full size: the resample has to see every source pixel to be the method
    // the user picked rather than the decoder's own downscale.
    final decoded = await decodeImageFile(path);
    if (decoded == null) throw StateError('could not decode $path');
    final image = decoded.image;
    final srcWidth = image.width;
    final srcHeight = image.height;
    final ByteData? data;
    try {
      data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    } finally {
      image.dispose();
    }
    if (data == null) throw StateError('could not read $path');
    final (bytes, ext) = await _resampleAndEncode(
      data.buffer.asUint8List(),
      srcWidth,
      srcHeight,
      width,
      height,
      method,
    );
    return imports.storeBytes(bytes, ext: ext);
  }

  Future<String> _resampleMask(
    String path,
    int width,
    int height,
    ResampleMethod method,
    String layerId,
  ) async {
    final mask = await masks.load(path);
    final alpha = await _resampleInIsolate(
      mask.alpha,
      mask.width,
      mask.height,
      width,
      height,
      method,
    );
    return masks.save(
      AlphaMask(width: width, height: height, alpha: alpha),
      id: layerId,
    );
  }
}

// Top-level, so the isolate closures capture their arguments and nothing else:
// a closure built inside a method can drag the whole object across with it.

Future<(Uint8List, String)> _resampleAndEncode(
  Uint8List rgba,
  int srcWidth,
  int srcHeight,
  int width,
  int height,
  ResampleMethod method,
) => Isolate.run(() {
  final out = resamplePixels(
    rgba,
    srcWidth: srcWidth,
    srcHeight: srcHeight,
    dstWidth: width,
    dstHeight: height,
    channels: 4,
    method: method,
  );
  final picture = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: out.buffer,
    numChannels: 4,
  );
  // A photo with no transparency goes back as a JPEG - a 4096 px PNG of one is
  // around 30 MB - at a quality a step above the import's, so a second
  // generation costs as little as it can. Anything with alpha in it (a merged
  // layer, a filled cut-out) has to stay PNG.
  return _isOpaque(out)
      ? (img.encodeJpg(picture, quality: 95), 'jpg')
      : (img.encodePng(picture), 'png');
});

Future<Uint8List> _resampleInIsolate(
  Uint8List alpha,
  int srcWidth,
  int srcHeight,
  int width,
  int height,
  ResampleMethod method,
) => Isolate.run(
  () => resamplePixels(
    alpha,
    srcWidth: srcWidth,
    srcHeight: srcHeight,
    dstWidth: width,
    dstHeight: height,
    channels: 1,
    method: method,
  ),
);

bool _isOpaque(Uint8List rgba) {
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 255) return false;
  }
  return true;
}

final photoResamplerProvider = Provider<PhotoResampler>(
  (ref) => PhotoResampler(
    imports: ref.watch(imageImportServiceProvider),
    masks: ref.watch(maskStoreProvider),
  ),
);
