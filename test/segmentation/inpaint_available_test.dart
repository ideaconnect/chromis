import 'dart:typed_data';

import 'package:chromis/features/segmentation/alpha_mask.dart';
import 'package:chromis/features/segmentation/engines/inpaint/inpaint_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Why the generative tier has no availability gate.
///
/// The decision "should we even try MI-GAN?" has been wrong three times, each
/// silently, and each looking like "the model is bad" rather than "the model
/// never ran":
///
///  1. The Fill/Erase chooser was built only when the asset was present, and no
///     shipped build had the asset - so the branch was dead.
///  2. Un-gating that chooser removed the only `ref.watch` of
///     `inpaintAvailableProvider`, which left `_tryInpaint` doing a SYNCHRONOUS
///     `ref.read(...).asData` on an uninitialised FutureProvider. That reads as
///     AsyncLoading, `.asData` is null, `?? false` means "no model" - so the
///     first fill of every session quietly used content-aware fill. Nastier
///     than a hard failure because reading the provider starts its future, so
///     the SECOND fill worked: a bug that fixes itself is one nobody reports
///     accurately.
///  3. …is what removing the gate entirely prevents.
///
/// `inpaint` returns null on ANY failure, and null is already the signal to
/// fall through to `ContentFillEngine`. That makes a gate redundant, and a
/// redundant gate whose failure mode is invisible is worse than none.
void main() {
  Uint8List photo() {
    final image = img.Image(width: 64, height: 64);
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        image.setPixelRgb(x, y, 40, 120, 60);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test('a model that cannot be opened falls through instead of throwing', () {
    // This is what makes the gate unnecessary: an absent or unloadable asset is
    // already reported as null, not as an exception the caller must catch.
    final engine = InpaintEngine(() async => throw StateError('no such asset'));
    expect(
      engine.inpaint(photo(), AlphaMask.filled(64, 64, 255)),
      completion(isNull),
    );
  });

  test('the asset path the app ships is the one the converter writes', () {
    // model_conversion/convert_migan.py writes exactly here; a rename on either
    // side would otherwise only show up as a silent fallback on-device.
    expect(kInpaintModelAsset, 'assets/models/migan.onnx');
  });
}
